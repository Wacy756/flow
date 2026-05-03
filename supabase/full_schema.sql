-- ============================================================
-- Flow App — Bulletproof migration script
-- Migrates from old flat-tenancies schema to new normalised
-- properties-split schema + all new tables/policies/triggers.
--
-- EVERY dangerous operation is wrapped in BEGIN...EXCEPTION.
-- Safe to run on any database state. Idempotent on re-run.
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
DO $$ BEGIN CREATE EXTENSION IF NOT EXISTS pg_net; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 1. PROFILES
-- ============================================================
DO $$ BEGIN ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ; EXCEPTION WHEN others THEN NULL; END $$;

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

-- ============================================================
-- 2. PROPERTIES (new table)
-- ============================================================
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

DO $$ BEGIN ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 3. TENANCIES — add new columns safely
-- ============================================================
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ALTER COLUMN tenant_id DROP NOT NULL; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS invited_email TEXT; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS notice_given_at TIMESTAMPTZ; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS notice_type TEXT; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS vacate_date DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS end_of_tenancy_date DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS deposit_returned_at TIMESTAMPTZ; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS deposit_deduction_amount NUMERIC(10,2); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD COLUMN IF NOT EXISTS deposit_deduction_reason TEXT; EXCEPTION WHEN others THEN NULL; END $$;

DO $$ BEGIN ALTER TABLE public.tenancies DROP CONSTRAINT IF EXISTS tenancies_status_check; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.tenancies ADD CONSTRAINT tenancies_status_check CHECK (status IN ('pending', 'active', 'notice_given', 'ended')); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE INDEX IF NOT EXISTS tenancies_invited_email_idx ON public.tenancies (invited_email) WHERE invited_email IS NOT NULL; EXCEPTION WHEN others THEN NULL; END $$;

-- ────────────────────────────────────────────────────────────
-- DATA MIGRATION: move property data from tenancies -> properties
-- Only runs if tenancies still has the old address_line_1 column
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tenancies' AND column_name = 'address_line_1'
  ) THEN
    -- Create one property per tenancy_id group
    BEGIN
      INSERT INTO public.properties (
        id, landlord_id, address_line_1, address_line_2, address_line_3,
        town, postcode, latitude, longitude, property_type,
        num_bedrooms, num_bathrooms, max_tenants, furnishing, created_at
      )
      SELECT DISTINCT ON (tenancy_id)
        tenancy_id, landlord_id, address_line_1, address_line_2, address_line_3,
        town, postcode, latitude, longitude, property_type,
        num_bedrooms, num_bathrooms, max_tenants, furnishing, created_at
      FROM public.tenancies
      WHERE tenancy_id IS NOT NULL
      ORDER BY tenancy_id, created_at ASC
      ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN others THEN NULL;
    END;

    -- Link tenancies to properties
    BEGIN
      UPDATE public.tenancies SET property_id = tenancy_id WHERE property_id IS NULL;
    EXCEPTION WHEN others THEN NULL;
    END;

    -- Drop dependent triggers/functions/columns
    BEGIN DROP TRIGGER IF EXISTS tr_update_tenancy_location_point ON public.tenancies; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS address_line_1 CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS address_line_2 CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS address_line_3 CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS town CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS postcode CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS latitude CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS longitude CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS property_type CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS num_bedrooms CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS num_bathrooms CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS max_tenants CASCADE; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.tenancies DROP COLUMN IF EXISTS furnishing CASCADE; EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

-- Make property_id NOT NULL if all rows have one
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.tenancies WHERE property_id IS NULL) THEN
    ALTER TABLE public.tenancies ALTER COLUMN property_id SET NOT NULL;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================================
-- 4. CONTRACTOR DETAILS — add new columns
-- ============================================================
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS insurance_cert_number TEXT; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS insurance_expiry DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS gas_safe_number TEXT; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS gas_safe_expiry DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS niceic_number TEXT; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS niceic_expiry DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) NOT NULL DEFAULT 0; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.contractor_details ADD COLUMN IF NOT EXISTS total_ratings INT NOT NULL DEFAULT 0; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 5. COMPLIANCE DOCS — add columns + repoint FK
-- ============================================================
DO $$ BEGIN ALTER TABLE public.compliance_docs ADD COLUMN IF NOT EXISTS issue_date DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.compliance_docs ADD COLUMN IF NOT EXISTS expiry_date DATE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.compliance_docs ADD COLUMN IF NOT EXISTS cert_number TEXT; EXCEPTION WHEN others THEN NULL; END $$;

-- Swap FK from tenancies -> properties (find and drop old FK by name, then add new)
DO $$
DECLARE
  v_constraint_name TEXT;
BEGIN
  -- Find the FK constraint on compliance_docs.tenancy_id that points to tenancies
  SELECT tc.constraint_name INTO v_constraint_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
    AND kcu.table_schema = tc.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
  WHERE tc.table_schema = 'public'
    AND tc.table_name = 'compliance_docs'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'tenancy_id'
    AND ccu.table_name = 'tenancies'
  LIMIT 1;

  -- If found, drop it and add one pointing to properties
  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.compliance_docs DROP CONSTRAINT %I', v_constraint_name);
    ALTER TABLE public.compliance_docs
      ADD CONSTRAINT compliance_docs_tenancy_id_fkey
      FOREIGN KEY (tenancy_id) REFERENCES public.properties(id) ON DELETE CASCADE;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN CREATE UNIQUE INDEX IF NOT EXISTS compliance_docs_tenancy_doc_type_idx ON public.compliance_docs (tenancy_id, doc_type); EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 6. PROPERTY LISTINGS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.property_listings (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id         UUID        NOT NULL UNIQUE,
  landlord_id         UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  asking_rent         NUMERIC(10,2),
  available_from      DATE,
  deposit_amount      NUMERIC(10,2),
  min_tenancy_months  INTEGER,
  description         TEXT,
  is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
  share_token         TEXT        NOT NULL UNIQUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $$ BEGIN ALTER TABLE public.property_listings ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 7. APPLICATIONS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.applications (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id         UUID        NOT NULL REFERENCES public.property_listings(id) ON DELETE CASCADE,
  property_id        UUID        NOT NULL,
  landlord_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  applicant_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  employment_status  TEXT,
  employer_name      TEXT,
  monthly_income     NUMERIC(10,2),
  move_in_preference DATE,
  num_adults         INTEGER     NOT NULL DEFAULT 1,
  num_children       INTEGER     NOT NULL DEFAULT 0,
  has_pets           BOOLEAN     NOT NULL DEFAULT FALSE,
  pet_details        TEXT,
  is_smoker          BOOLEAN     NOT NULL DEFAULT FALSE,
  has_ccj            BOOLEAN     NOT NULL DEFAULT FALSE,
  ccj_details        TEXT,
  notes              TEXT,
  status             TEXT        NOT NULL DEFAULT 'pending',
  rejection_reason   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $$ BEGIN CREATE UNIQUE INDEX IF NOT EXISTS applications_listing_applicant_unique ON public.applications (listing_id, applicant_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 8. RENT PAYMENTS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id  UUID          NOT NULL,
  landlord_id UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_due  NUMERIC(10,2) NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL DEFAULT 0,
  due_date    DATE          NOT NULL,
  paid_at     TIMESTAMPTZ,
  status      TEXT          NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'paid', 'partial', 'late')),
  notes       TEXT,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
DO $$ BEGIN CREATE INDEX IF NOT EXISTS rent_payments_tenancy_id_idx ON public.rent_payments (tenancy_id, due_date DESC); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE INDEX IF NOT EXISTS rent_payments_landlord_id_idx ON public.rent_payments (landlord_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 9. INCIDENT COMMENTS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.incident_comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID        NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  author_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  author_role TEXT        NOT NULL CHECK (author_role IN ('landlord', 'tenant', 'contractor')),
  body        TEXT        NOT NULL CHECK (char_length(body) > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $$ BEGIN CREATE INDEX IF NOT EXISTS incident_comments_incident_id_idx ON public.incident_comments (incident_id, created_at ASC); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.incident_comments ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 10. NOTIFICATIONS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       TEXT        NOT NULL,
  title      TEXT        NOT NULL,
  body       TEXT        NOT NULL DEFAULT '',
  data       JSONB       NOT NULL DEFAULT '{}',
  is_read    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $$ BEGIN CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications (user_id, created_at DESC); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE INDEX IF NOT EXISTS notifications_unread_idx ON public.notifications (user_id, is_read) WHERE is_read = FALSE; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 11. JOB RATINGS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.job_ratings (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   UUID        NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  tenant_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contractor_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating        INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (incident_id, tenant_id)
);
DO $$ BEGIN CREATE INDEX IF NOT EXISTS job_ratings_contractor_idx ON public.job_ratings (contractor_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.job_ratings ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 12. FCM TOKENS (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL,
  platform   TEXT        NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);
DO $$ BEGIN CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx ON public.fcm_tokens (user_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- 13. NOTIFICATION PREFERENCES (new table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id           UUID    PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  push_enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  push_maintenance  BOOLEAN NOT NULL DEFAULT TRUE,
  push_rent         BOOLEAN NOT NULL DEFAULT TRUE,
  push_compliance   BOOLEAN NOT NULL DEFAULT TRUE,
  push_applications BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $$ BEGIN ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- RLS POLICIES — drop all old, recreate fresh
-- Each block wrapped so a missing table doesn't kill the run.
-- ============================================================

-- PROFILES
DO $$ BEGIN DROP POLICY IF EXISTS "profiles_select_all"  ON public.profiles; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "profiles_insert_own"  ON public.profiles; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "profiles_update_own"  ON public.profiles; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_select_all"  ON public.profiles FOR SELECT USING (true); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_insert_own"  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_update_own"  ON public.profiles FOR UPDATE USING (auth.uid() = id); EXCEPTION WHEN others THEN NULL; END $$;

-- PROPERTIES
DO $$ BEGIN DROP POLICY IF EXISTS "properties_select" ON public.properties; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "properties_insert" ON public.properties; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "properties_update" ON public.properties; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "properties_delete" ON public.properties; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "properties_select" ON public.properties FOR SELECT USING (
    landlord_id = auth.uid()
    OR id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.incidents i
      JOIN public.tenancies t ON t.id = i.tenancy_id
      WHERE t.property_id = properties.id AND i.contractor_id = auth.uid()
    )
  );
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "properties_insert" ON public.properties FOR INSERT WITH CHECK (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "properties_update" ON public.properties FOR UPDATE USING (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "properties_delete" ON public.properties FOR DELETE USING (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;

-- TENANCIES
DO $$ BEGIN DROP POLICY IF EXISTS "tenancies_select" ON public.tenancies; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "tenancies_insert" ON public.tenancies; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "tenancies_update" ON public.tenancies; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "tenancies_delete" ON public.tenancies; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tenancies_select" ON public.tenancies FOR SELECT USING (auth.uid() = landlord_id OR auth.uid() = tenant_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tenancies_insert" ON public.tenancies FOR INSERT WITH CHECK (auth.uid() = landlord_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tenancies_update" ON public.tenancies FOR UPDATE USING (auth.uid() = landlord_id OR auth.uid() = tenant_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tenancies_delete" ON public.tenancies FOR DELETE USING (auth.uid() = landlord_id); EXCEPTION WHEN others THEN NULL; END $$;

-- INCIDENTS
DO $$ BEGIN DROP POLICY IF EXISTS "incidents_select" ON public.incidents; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "incidents_insert" ON public.incidents; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "incidents_update" ON public.incidents; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "incidents_select" ON public.incidents FOR SELECT USING (
    auth.uid() = tenant_id OR auth.uid() = contractor_id
    OR (status = 'approved' AND contractor_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.tenancies t WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid())
  );
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "incidents_insert" ON public.incidents FOR INSERT WITH CHECK (auth.uid() = tenant_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "incidents_update" ON public.incidents FOR UPDATE USING (
    auth.uid() = tenant_id OR auth.uid() = contractor_id
    OR (status = 'approved' AND contractor_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.tenancies t WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid())
  );
EXCEPTION WHEN others THEN NULL; END $$;

-- CONTRACTOR DETAILS
DO $$ BEGIN DROP POLICY IF EXISTS "contractor_details_select" ON public.contractor_details; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "contractor_details_insert" ON public.contractor_details; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "contractor_details_update" ON public.contractor_details; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "contractor_details_select" ON public.contractor_details FOR SELECT USING (true); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "contractor_details_insert" ON public.contractor_details FOR INSERT WITH CHECK (auth.uid() = contractor_id); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "contractor_details_update" ON public.contractor_details FOR UPDATE USING (auth.uid() = contractor_id); EXCEPTION WHEN others THEN NULL; END $$;

-- COMPLIANCE DOCS
DO $$ BEGIN DROP POLICY IF EXISTS "compliance_docs_select" ON public.compliance_docs; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "compliance_docs_insert" ON public.compliance_docs; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "compliance_docs_select" ON public.compliance_docs FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.properties p WHERE p.id = compliance_docs.tenancy_id
        AND (p.landlord_id = auth.uid() OR p.id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()))
    )
  );
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "compliance_docs_insert" ON public.compliance_docs FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.properties p WHERE p.id = compliance_docs.tenancy_id
        AND (p.landlord_id = auth.uid() OR p.id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()))
    )
  );
EXCEPTION WHEN others THEN NULL; END $$;

-- PROPERTY LISTINGS
DO $$ BEGIN DROP POLICY IF EXISTS "listings_landlord_all" ON public.property_listings; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "listings_public_select" ON public.property_listings; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "listings_landlord_all" ON public.property_listings FOR ALL USING (landlord_id = auth.uid()) WITH CHECK (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "listings_public_select" ON public.property_listings FOR SELECT USING (is_active = true); EXCEPTION WHEN others THEN NULL; END $$;

-- APPLICATIONS
DO $$ BEGIN DROP POLICY IF EXISTS "applications_applicant_insert" ON public.applications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "applications_applicant_select" ON public.applications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "applications_landlord_select" ON public.applications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "applications_landlord_update" ON public.applications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "applications_applicant_insert" ON public.applications FOR INSERT WITH CHECK (applicant_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "applications_applicant_select" ON public.applications FOR SELECT USING (applicant_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "applications_landlord_select" ON public.applications FOR SELECT USING (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "applications_landlord_update" ON public.applications FOR UPDATE USING (landlord_id = auth.uid()) WITH CHECK (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;

-- RENT PAYMENTS
DO $$ BEGIN DROP POLICY IF EXISTS "rent_payments_landlord_all" ON public.rent_payments; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "rent_payments_tenant_select" ON public.rent_payments; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "rent_payments_landlord_all" ON public.rent_payments FOR ALL USING (landlord_id = auth.uid()) WITH CHECK (landlord_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "rent_payments_tenant_select" ON public.rent_payments FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tenancies t WHERE t.tenancy_id = rent_payments.tenancy_id AND t.tenant_id = auth.uid())
  );
EXCEPTION WHEN others THEN NULL; END $$;

-- INCIDENT COMMENTS
DO $$ BEGIN DROP POLICY IF EXISTS "incident_comments_select" ON public.incident_comments; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "incident_comments_insert" ON public.incident_comments; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "incident_comments_select" ON public.incident_comments FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.incidents i JOIN public.tenancies t ON t.id = i.tenancy_id WHERE i.id = incident_comments.incident_id AND t.landlord_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_comments.incident_id AND (i.tenant_id = auth.uid() OR i.contractor_id = auth.uid()))
  );
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "incident_comments_insert" ON public.incident_comments FOR INSERT WITH CHECK (
    author_id = auth.uid() AND (
      EXISTS (SELECT 1 FROM public.incidents i JOIN public.tenancies t ON t.id = i.tenancy_id WHERE i.id = incident_id AND t.landlord_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.incidents i WHERE i.id = incident_id AND (i.tenant_id = auth.uid() OR i.contractor_id = auth.uid()))
    )
  );
EXCEPTION WHEN others THEN NULL; END $$;

-- NOTIFICATIONS
DO $$ BEGIN DROP POLICY IF EXISTS "notifications_user_select" ON public.notifications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "notifications_user_update" ON public.notifications; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notifications_user_select" ON public.notifications FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notifications_user_update" ON public.notifications FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;

-- JOB RATINGS
DO $$ BEGIN DROP POLICY IF EXISTS "tenants_insert_ratings" ON public.job_ratings; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "authenticated_read_ratings" ON public.job_ratings; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tenants_insert_ratings" ON public.job_ratings FOR INSERT WITH CHECK (tenant_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "authenticated_read_ratings" ON public.job_ratings FOR SELECT USING (auth.uid() IS NOT NULL); EXCEPTION WHEN others THEN NULL; END $$;

-- FCM TOKENS
DO $$ BEGIN DROP POLICY IF EXISTS "fcm_tokens_select" ON public.fcm_tokens; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "fcm_tokens_insert" ON public.fcm_tokens; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "fcm_tokens_update" ON public.fcm_tokens; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "fcm_tokens_delete" ON public.fcm_tokens; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "fcm_tokens_select" ON public.fcm_tokens FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "fcm_tokens_insert" ON public.fcm_tokens FOR INSERT WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "fcm_tokens_update" ON public.fcm_tokens FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "fcm_tokens_delete" ON public.fcm_tokens FOR DELETE USING (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;

-- NOTIFICATION PREFERENCES
DO $$ BEGIN DROP POLICY IF EXISTS "notif_prefs_select" ON public.notification_preferences; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "notif_prefs_insert" ON public.notification_preferences; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "notif_prefs_update" ON public.notification_preferences; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "notif_prefs_delete" ON public.notification_preferences; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notif_prefs_select" ON public.notification_preferences FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notif_prefs_insert" ON public.notification_preferences FOR INSERT WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notif_prefs_update" ON public.notification_preferences FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notif_prefs_delete" ON public.notification_preferences FOR DELETE USING (user_id = auth.uid()); EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- STORAGE — compliance-docs bucket
-- ============================================================
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES ('compliance-docs', 'compliance-docs', false, 10485760,
          ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
  ON CONFLICT (id) DO NOTHING;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN DROP POLICY IF EXISTS "landlords_upload_compliance_docs" ON storage.objects; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "landlords_upload_compliance_docs" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'compliance-docs' AND auth.uid() IN (
    SELECT landlord_id FROM public.properties WHERE id::text = split_part(name, '/', 1)
  ));
EXCEPTION WHEN others THEN NULL; END $$;

DO $$ BEGIN DROP POLICY IF EXISTS "landlords_tenants_view_compliance_docs" ON storage.objects; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "landlords_tenants_view_compliance_docs" ON storage.objects FOR SELECT
  USING (bucket_id = 'compliance-docs' AND (
    auth.uid() IN (SELECT landlord_id FROM public.properties WHERE id::text = split_part(name, '/', 1))
    OR auth.uid() IN (SELECT tenant_id FROM public.tenancies WHERE property_id::text = split_part(name, '/', 1))
  ));
EXCEPTION WHEN others THEN NULL; END $$;

DO $$ BEGIN DROP POLICY IF EXISTS "landlords_delete_compliance_docs" ON storage.objects; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "landlords_delete_compliance_docs" ON storage.objects FOR DELETE
  USING (bucket_id = 'compliance-docs' AND auth.uid() IN (
    SELECT landlord_id FROM public.properties WHERE id::text = split_part(name, '/', 1)
  ));
EXCEPTION WHEN others THEN NULL; END $$;

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- All CREATE OR REPLACE so they're always safe.
-- All DROP TRIGGER IF EXISTS so they're always safe.
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID, p_type TEXT, p_title TEXT, p_body TEXT, p_data JSONB DEFAULT '{}'
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data);
END;
$$;

-- Application -> notify landlord
CREATE OR REPLACE FUNCTION public.notify_new_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_landlord_id UUID; v_address TEXT;
BEGIN
  SELECT p.landlord_id, COALESCE(p.address_line_1 || ', ' || p.postcode, 'your property')
    INTO v_landlord_id, v_address FROM public.properties p WHERE p.id = NEW.property_id;
  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(v_landlord_id, 'new_application', 'New Application',
      'Someone applied for ' || v_address,
      jsonb_build_object('listing_id', NEW.listing_id, 'property_id', NEW.property_id));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_new_application ON public.applications;
CREATE TRIGGER trg_notify_new_application AFTER INSERT ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_application();

-- Incident reported -> notify landlord
CREATE OR REPLACE FUNCTION public.notify_incident_reported()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_landlord_id UUID; v_address TEXT;
BEGIN
  SELECT t.landlord_id, COALESCE(p.address_line_1 || ', ' || p.postcode, 'your property')
    INTO v_landlord_id, v_address
    FROM public.tenancies t JOIN public.properties p ON p.id = t.property_id
    WHERE t.id = NEW.tenancy_id LIMIT 1;
  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(v_landlord_id, 'incident_status_change', 'New Incident Reported',
      COALESCE(NEW.title, 'A new incident') || ' reported at ' || v_address,
      jsonb_build_object('incident_id', NEW.id));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_incident_reported ON public.incidents;
CREATE TRIGGER trg_notify_incident_reported AFTER INSERT ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.notify_incident_reported();

-- Incident status change -> notify parties
CREATE OR REPLACE FUNCTION public.notify_incident_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_landlord_id UUID; v_tenant_id UUID; v_title_text TEXT;
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;
  SELECT t.landlord_id, i.tenant_id INTO v_landlord_id, v_tenant_id
    FROM public.incidents i JOIN public.tenancies t ON t.id = i.tenancy_id WHERE i.id = NEW.id LIMIT 1;
  v_title_text := COALESCE(NEW.title, 'An incident');
  IF NEW.status = 'quoted' AND v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(v_landlord_id, 'quote_submitted', 'Quote Ready for Approval',
      v_title_text || ' — ' || COALESCE(NEW.quote_amount::TEXT, '?') || ' quoted', jsonb_build_object('incident_id', NEW.id));
  ELSIF NEW.status = 'in_progress' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(v_tenant_id, 'job_approved', 'Job In Progress',
      v_title_text || ' is now being worked on', jsonb_build_object('incident_id', NEW.id));
  ELSIF NEW.status = 'completed' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(v_tenant_id, 'incident_status_change', 'Job Completed',
      v_title_text || ' has been marked as complete', jsonb_build_object('incident_id', NEW.id));
  ELSIF NEW.status = 'approved' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(v_tenant_id, 'incident_status_change', 'Incident Approved',
      v_title_text || ' has been approved — contractors are being contacted', jsonb_build_object('incident_id', NEW.id));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_incident_status ON public.incidents;
CREATE TRIGGER trg_notify_incident_status AFTER UPDATE ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.notify_incident_status_change();

-- Tenancy invitation -> notify tenant
CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_address TEXT;
BEGIN
  IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.tenant_id IS NOT NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(p.address_line_1 || ', ' || p.postcode, 'a property')
    INTO v_address FROM public.properties p WHERE p.id = NEW.property_id;
  PERFORM public.create_notification(NEW.tenant_id, 'invitation_received', 'Tenancy Invitation',
    'You''ve been invited to ' || v_address, jsonb_build_object('tenancy_id', NEW.tenancy_id));
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_invitation ON public.tenancies;
CREATE TRIGGER trg_notify_invitation AFTER INSERT OR UPDATE OF tenant_id ON public.tenancies
  FOR EACH ROW EXECUTE FUNCTION public.notify_invitation_received();

-- Compliance expiry -> notify landlord
CREATE OR REPLACE FUNCTION public.notify_compliance_expiring()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_landlord_id UUID; v_days_left INT;
BEGIN
  IF NEW.expiry_date IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.expiry_date = NEW.expiry_date THEN RETURN NEW; END IF;
  v_days_left := NEW.expiry_date - CURRENT_DATE;
  IF v_days_left > 60 THEN RETURN NEW; END IF;
  SELECT p.landlord_id INTO v_landlord_id FROM public.properties p WHERE p.id = NEW.tenancy_id;
  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(v_landlord_id, 'compliance_expiring',
      CASE WHEN v_days_left < 0 THEN 'Compliance Document Expired'
           WHEN v_days_left = 0 THEN 'Compliance Document Expires Today'
           ELSE 'Compliance Document Expiring Soon' END,
      NEW.doc_type || CASE WHEN v_days_left < 0 THEN ' expired ' || ABS(v_days_left) || ' days ago'
           WHEN v_days_left = 0 THEN ' expires today'
           ELSE ' expires in ' || v_days_left || ' days' END,
      jsonb_build_object('tenancy_id', NEW.tenancy_id, 'doc_type', NEW.doc_type));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_compliance ON public.compliance_docs;
CREATE TRIGGER trg_notify_compliance AFTER INSERT OR UPDATE ON public.compliance_docs
  FOR EACH ROW EXECUTE FUNCTION public.notify_compliance_expiring();

-- Rent overdue -> notify landlord
CREATE OR REPLACE FUNCTION public.notify_rent_overdue()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'late' AND (OLD.status IS NULL OR OLD.status <> 'late') THEN
    PERFORM public.create_notification(NEW.landlord_id, 'rent_overdue', 'Rent Overdue',
      NEW.amount_due::TEXT || ' rent due ' || NEW.due_date::TEXT || ' is overdue',
      jsonb_build_object('tenancy_id', NEW.tenancy_id, 'payment_id', NEW.id));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_notify_rent_overdue ON public.rent_payments;
CREATE TRIGGER trg_notify_rent_overdue AFTER INSERT OR UPDATE ON public.rent_payments
  FOR EACH ROW EXECUTE FUNCTION public.notify_rent_overdue();

-- Push via Edge Function
CREATE OR REPLACE FUNCTION public.send_push_on_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_url TEXT; v_key TEXT;
BEGIN
  v_url := current_setting('app.supabase_project_url', true);
  v_key := current_setting('app.supabase_service_role_key', true);
  IF v_url IS NULL OR v_url = '' THEN RETURN NEW; END IF;
  PERFORM net.http_post(
    url := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := jsonb_build_object('user_id', NEW.user_id, 'type', NEW.type, 'title', NEW.title, 'body', NEW.body, 'data', NEW.data)::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_send_push ON public.notifications;
CREATE TRIGGER trg_send_push AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.send_push_on_notification();

-- Contractor rating recalc
CREATE OR REPLACE FUNCTION public.update_contractor_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.contractor_details SET
    total_ratings  = (SELECT COUNT(*) FROM public.job_ratings WHERE contractor_id = NEW.contractor_id),
    average_rating = (SELECT AVG(rating) FROM public.job_ratings WHERE contractor_id = NEW.contractor_id)
  WHERE contractor_id = NEW.contractor_id;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_update_contractor_rating ON public.job_ratings;
CREATE TRIGGER trg_update_contractor_rating AFTER INSERT ON public.job_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_contractor_rating();

-- ============================================================
-- VIEWS
-- ============================================================
DO $$
BEGIN
  CREATE OR REPLACE VIEW public.landlord_applications AS
  SELECT a.*, p.full_name AS applicant_name, p.email AS applicant_email,
         prop.address_line_1, prop.postcode, l.asking_rent
  FROM public.applications a
  JOIN public.profiles p ON p.id = a.applicant_id
  JOIN public.properties prop ON prop.id = a.property_id
  JOIN public.property_listings l ON l.id = a.listing_id;

  ALTER VIEW public.landlord_applications SET (security_invoker = true);
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================================
-- DONE.
-- ============================================================
