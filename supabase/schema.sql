-- ============================================================
-- Flow App — Full Database Schema
-- Run this in the Supabase SQL Editor (fresh setup)
-- For migrations on existing DB, run migrations/001_properties_split.sql
-- ============================================================

-- 1. PROFILES (mirrors auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT        NOT NULL DEFAULT '',
  email        TEXT,
  role         TEXT        NOT NULL DEFAULT 'tenant'
                           CHECK (role IN ('landlord', 'tenant', 'contractor', 'agent')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. TRIGGER: auto-create profile row on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'tenant')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. PROPERTIES (permanent physical asset — one row per property)
CREATE TABLE IF NOT EXISTS public.properties (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  address_line_1 TEXT        NOT NULL DEFAULT '',
  address_line_2 TEXT,
  address_line_3 TEXT,
  town           TEXT,
  postcode       TEXT        NOT NULL DEFAULT '',
  latitude       FLOAT8,
  longitude      FLOAT8,
  property_type  TEXT,
  num_bedrooms   INTEGER,
  num_bathrooms  INTEGER,
  max_tenants    INTEGER,
  furnishing     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TENANCIES (legal relationship: property ↔ tenant group, time-bounded)
CREATE TABLE IF NOT EXISTS public.tenancies (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id         UUID        NOT NULL,  -- groups multiple tenant rows for same tenancy
  property_id        UUID        NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  landlord_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tenant_id          UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status             TEXT        NOT NULL DEFAULT 'pending'
                                 CHECK (status IN ('pending', 'active')),
  monthly_rent       NUMERIC(10,2),
  weekly_rent        NUMERIC(10,2),
  deposit_amount     NUMERIC(10,2),
  min_tenancy_length INTEGER,
  move_in_date       DATE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. INCIDENTS
CREATE TABLE IF NOT EXISTS public.incidents (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id             UUID        REFERENCES public.tenancies(id) ON DELETE CASCADE,
  tenant_id              UUID        REFERENCES public.profiles(id),
  contractor_id          UUID        REFERENCES public.profiles(id),
  title                  TEXT        NOT NULL DEFAULT '',
  description            TEXT        NOT NULL DEFAULT '',
  status                 TEXT        NOT NULL DEFAULT 'reported'
                                     CHECK (status IN ('reported','approved','quoted','in_progress','completed')),
  category               TEXT,
  media_urls             TEXT[]      NOT NULL DEFAULT '{}',
  declined_by            TEXT[]      NOT NULL DEFAULT '{}',
  quote_amount           NUMERIC(10,2),
  is_tenant_completed    BOOLEAN     NOT NULL DEFAULT FALSE,
  is_contractor_completed BOOLEAN    NOT NULL DEFAULT FALSE,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. CONTRACTOR DETAILS
CREATE TABLE IF NOT EXISTS public.contractor_details (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  contractor_id       UUID        UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  work_types          TEXT[]      NOT NULL DEFAULT '{}',
  service_areas       JSONB       NOT NULL DEFAULT '[]',
  is_setup_completed  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. COMPLIANCE DOCS (per property — referenced by property id)
CREATE TABLE IF NOT EXISTS public.compliance_docs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id  UUID        NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  doc_type    TEXT        NOT NULL,
  file_path   TEXT        NOT NULL,
  file_name   TEXT        NOT NULL,
  uploaded_by UUID        REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenancies         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_docs   ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "profiles_select_all"  ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own"  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own"  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- PROPERTIES
CREATE POLICY "properties_select" ON public.properties FOR SELECT USING (
  landlord_id = auth.uid()
  OR id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
    WHERE t.property_id = properties.id
      AND (i.contractor_id = auth.uid() OR (i.status = 'approved' AND i.contractor_id IS NULL))
  )
);
CREATE POLICY "properties_insert" ON public.properties FOR INSERT
  WITH CHECK (landlord_id = auth.uid());
CREATE POLICY "properties_update" ON public.properties FOR UPDATE
  USING (landlord_id = auth.uid());
CREATE POLICY "properties_delete" ON public.properties FOR DELETE
  USING (landlord_id = auth.uid());

-- TENANCIES
CREATE POLICY "tenancies_select" ON public.tenancies FOR SELECT
  USING (auth.uid() = landlord_id OR auth.uid() = tenant_id);
CREATE POLICY "tenancies_insert" ON public.tenancies FOR INSERT
  WITH CHECK (auth.uid() = landlord_id);
CREATE POLICY "tenancies_update" ON public.tenancies FOR UPDATE
  USING (auth.uid() = landlord_id OR auth.uid() = tenant_id);
CREATE POLICY "tenancies_delete" ON public.tenancies FOR DELETE
  USING (auth.uid() = landlord_id);

-- INCIDENTS — own + landlord's properties + approved unassigned (contractors)
CREATE POLICY "incidents_select" ON public.incidents FOR SELECT USING (
  auth.uid() = tenant_id
  OR auth.uid() = contractor_id
  OR (status = 'approved' AND contractor_id IS NULL)
  OR EXISTS (
    SELECT 1 FROM public.tenancies t
    WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid()
  )
);
CREATE POLICY "incidents_insert" ON public.incidents FOR INSERT
  WITH CHECK (auth.uid() = tenant_id);
CREATE POLICY "incidents_update" ON public.incidents FOR UPDATE USING (
  auth.uid() = tenant_id
  OR auth.uid() = contractor_id
  OR EXISTS (
    SELECT 1 FROM public.tenancies t
    WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid()
  )
);

-- CONTRACTOR DETAILS
CREATE POLICY "contractor_details_select" ON public.contractor_details FOR SELECT USING (true);
CREATE POLICY "contractor_details_insert" ON public.contractor_details FOR INSERT
  WITH CHECK (auth.uid() = contractor_id);
CREATE POLICY "contractor_details_update" ON public.contractor_details FOR UPDATE
  USING (auth.uid() = contractor_id);

-- COMPLIANCE DOCS (tenancy_id column actually stores the property id)
CREATE POLICY "compliance_docs_select" ON public.compliance_docs FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = compliance_docs.tenancy_id
      AND (p.landlord_id = auth.uid()
           OR p.id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()))
  )
);
CREATE POLICY "compliance_docs_insert" ON public.compliance_docs FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = compliance_docs.tenancy_id
      AND (p.landlord_id = auth.uid()
           OR p.id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()))
  )
);
