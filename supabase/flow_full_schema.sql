-- ============================================================
-- Flow App — Complete Database Schema
-- Paste this into Supabase SQL Editor on a fresh project.
-- This is the single source of truth — covers everything.
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_net;   -- required for push notification trigger

-- ============================================================
-- 1. PROFILES
-- mirrors auth.users; created automatically via trigger below
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT        NOT NULL DEFAULT '',
  email       TEXT,
  role        TEXT        NOT NULL DEFAULT 'tenant'
                          CHECK (role IN ('landlord', 'tenant', 'contractor', 'agent')),
  deleted_at  TIMESTAMPTZ,              -- soft-delete (settings screen account deletion)
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create a profile row when a user signs up
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
-- 2. PROPERTIES
-- One row per physical property. Owned by a landlord.
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

-- ============================================================
-- 3. TENANCIES
-- Legal relationship between a property and a tenant.
-- Multiple rows can share the same tenancy_id (group key = property id)
-- to represent multiple tenants on the same tenancy.
-- tenant_id is nullable: a row can be created for an invited email
-- address before the tenant has signed up (invited_email stores it).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tenancies (
  id                          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id                  UUID        NOT NULL,   -- group key, equals property_id
  property_id                 UUID        NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  landlord_id                 UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tenant_id                   UUID        REFERENCES public.profiles(id) ON DELETE CASCADE,  -- nullable for pending invites
  invited_email               TEXT,       -- email of invited tenant who hasn't signed up yet
  status                      TEXT        NOT NULL DEFAULT 'pending'
                                          CHECK (status IN ('pending', 'active', 'notice_given', 'ended')),
  monthly_rent                NUMERIC(10,2),
  weekly_rent                 NUMERIC(10,2),
  deposit_amount              NUMERIC(10,2),
  min_tenancy_length          INTEGER,
  move_in_date                DATE,
  -- end-of-tenancy workflow
  notice_given_at             TIMESTAMPTZ,
  notice_type                 TEXT        CHECK (notice_type IN ('s21', 's8', 'mutual', 'surrender')),
  vacate_date                 DATE,
  end_of_tenancy_date         DATE,
  deposit_returned_at         TIMESTAMPTZ,
  deposit_deduction_amount    NUMERIC(10,2),
  deposit_deduction_reason    TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookup by invited email (used in auth signup auto-link)
CREATE INDEX IF NOT EXISTS tenancies_invited_email_idx
  ON public.tenancies (invited_email)
  WHERE invited_email IS NOT NULL;

-- ============================================================
-- 4. INCIDENTS
-- Maintenance issues reported by tenants.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.incidents (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id              UUID        REFERENCES public.tenancies(id) ON DELETE CASCADE,
  tenant_id               UUID        REFERENCES public.profiles(id),
  contractor_id           UUID        REFERENCES public.profiles(id),
  title                   TEXT        NOT NULL DEFAULT '',
  description             TEXT        NOT NULL DEFAULT '',
  status                  TEXT        NOT NULL DEFAULT 'reported'
                                      CHECK (status IN ('reported','approved','quoted','in_progress','completed')),
  category                TEXT,
  media_urls              TEXT[]      NOT NULL DEFAULT '{}',
  declined_by             TEXT[]      NOT NULL DEFAULT '{}',
  quote_amount            NUMERIC(10,2),
  is_tenant_completed     BOOLEAN     NOT NULL DEFAULT FALSE,
  is_contractor_completed BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. CONTRACTOR DETAILS
-- Profile extension for contractor users.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.contractor_details (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  contractor_id         UUID        UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  work_types            TEXT[]      NOT NULL DEFAULT '{}',
  service_areas         JSONB       NOT NULL DEFAULT '[]',
  is_setup_completed    BOOLEAN     NOT NULL DEFAULT FALSE,
  -- verification / cert columns (added in migration 009)
  insurance_cert_number TEXT,
  insurance_expiry      DATE,
  gas_safe_number       TEXT,
  gas_safe_expiry       DATE,
  niceic_number         TEXT,
  niceic_expiry         DATE,
  average_rating        NUMERIC(3,2) NOT NULL DEFAULT 0,
  total_ratings         INT          NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 6. COMPLIANCE DOCS
-- Legal/safety documents for a property (stored by property id).
-- tenancy_id column is named historically but stores properties.id.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.compliance_docs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id  UUID        NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  doc_type    TEXT        NOT NULL,
  file_path   TEXT        NOT NULL,
  file_name   TEXT        NOT NULL,
  uploaded_by UUID        REFERENCES public.profiles(id),
  issue_date  DATE,
  expiry_date DATE,
  cert_number TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Required for upsert in compliance_docs_panel.dart (onConflict: 'tenancy_id, doc_type')
CREATE UNIQUE INDEX IF NOT EXISTS compliance_docs_tenancy_doc_type_idx
  ON public.compliance_docs (tenancy_id, doc_type);

-- ============================================================
-- 7. PROPERTY LISTINGS
-- A landlord can advertise a vacant property for applications.
-- One active listing per property.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.property_listings (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id         UUID        NOT NULL UNIQUE,   -- one active listing per property
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

-- ============================================================
-- 8. APPLICATIONS
-- Prospective tenants apply via a shared listing link.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.applications (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id         UUID        NOT NULL REFERENCES public.property_listings(id) ON DELETE CASCADE,
  property_id        UUID        NOT NULL,   -- denormalised for easy querying
  landlord_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  applicant_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  employment_status  TEXT,                   -- 'employed'|'self_employed'|'student'|'unemployed'|'retired'
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
  status             TEXT        NOT NULL DEFAULT 'pending',  -- 'pending'|'approved'|'rejected'
  rejection_reason   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent duplicate applications (one per applicant per listing)
CREATE UNIQUE INDEX IF NOT EXISTS applications_listing_applicant_unique
  ON public.applications (listing_id, applicant_id);

-- ============================================================
-- 9. RENT PAYMENTS
-- Monthly payment records logged by the landlord.
-- tenancy_id here is the group UUID (= properties.id).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rent_payments (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id  UUID          NOT NULL,   -- group UUID = properties.id
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

CREATE INDEX IF NOT EXISTS rent_payments_tenancy_id_idx
  ON public.rent_payments (tenancy_id, due_date DESC);

CREATE INDEX IF NOT EXISTS rent_payments_landlord_id_idx
  ON public.rent_payments (landlord_id);

-- ============================================================
-- 10. INCIDENT COMMENTS
-- Threaded messages on an incident (landlord / tenant / contractor).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.incident_comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID        NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  author_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  author_role TEXT        NOT NULL CHECK (author_role IN ('landlord', 'tenant', 'contractor')),
  body        TEXT        NOT NULL CHECK (char_length(body) > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS incident_comments_incident_id_idx
  ON public.incident_comments (incident_id, created_at ASC);

-- ============================================================
-- 11. NOTIFICATIONS
-- In-app notification inbox. Written only by SECURITY DEFINER triggers.
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

CREATE INDEX IF NOT EXISTS notifications_user_id_idx
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON public.notifications (user_id, is_read)
  WHERE is_read = FALSE;

-- ============================================================
-- 12. JOB RATINGS
-- Tenants rate completed jobs (one rating per incident per tenant).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.job_ratings (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   UUID        NOT NULL REFERENCES public.incidents(id)  ON DELETE CASCADE,
  tenant_id     UUID        NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  contractor_id UUID        NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  rating        INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (incident_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS job_ratings_contractor_idx
  ON public.job_ratings (contractor_id);

-- ============================================================
-- 13. FCM TOKENS
-- One row per device per user. Deleted on sign-out.
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

CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx ON public.fcm_tokens (user_id);

-- ============================================================
-- 14. NOTIFICATION PREFERENCES
-- Per-user opt-in/out for each notification category.
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

-- ============================================================
-- ROW LEVEL SECURITY — enable on all tables
-- ============================================================

ALTER TABLE public.profiles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenancies              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_details     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_docs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_listings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_comments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_ratings            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- PROFILES
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- PROPERTIES
-- Tightened contractor access: must be explicitly assigned to an incident (not just any open one)
CREATE POLICY "properties_select" ON public.properties FOR SELECT USING (
  landlord_id = auth.uid()
  OR id IN (
    SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
    WHERE t.property_id = properties.id
      AND i.contractor_id = auth.uid()
  )
);

CREATE POLICY "properties_insert" ON public.properties
  FOR INSERT WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "properties_update" ON public.properties
  FOR UPDATE USING (landlord_id = auth.uid());

CREATE POLICY "properties_delete" ON public.properties
  FOR DELETE USING (landlord_id = auth.uid());

-- TENANCIES
-- SELECT: landlord sees all their tenancies; tenant sees their own; also allow reads
-- for rows where tenant_id is null but invited_email matches current user's email
-- (needed so the tenant can see pending invitations before auto-link)
CREATE POLICY "tenancies_select" ON public.tenancies
  FOR SELECT USING (
    auth.uid() = landlord_id
    OR auth.uid() = tenant_id
  );

CREATE POLICY "tenancies_insert" ON public.tenancies
  FOR INSERT WITH CHECK (auth.uid() = landlord_id);

CREATE POLICY "tenancies_update" ON public.tenancies
  FOR UPDATE USING (auth.uid() = landlord_id OR auth.uid() = tenant_id);

CREATE POLICY "tenancies_delete" ON public.tenancies
  FOR DELETE USING (auth.uid() = landlord_id);

-- INCIDENTS
CREATE POLICY "incidents_select" ON public.incidents FOR SELECT USING (
  auth.uid() = tenant_id
  OR auth.uid() = contractor_id
  OR (status = 'approved' AND contractor_id IS NULL)
  OR EXISTS (
    SELECT 1 FROM public.tenancies t
    WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid()
  )
);

CREATE POLICY "incidents_insert" ON public.incidents
  FOR INSERT WITH CHECK (auth.uid() = tenant_id);

CREATE POLICY "incidents_update" ON public.incidents FOR UPDATE USING (
  auth.uid() = tenant_id
  OR auth.uid() = contractor_id
  OR EXISTS (
    SELECT 1 FROM public.tenancies t
    WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid()
  )
);

-- CONTRACTOR DETAILS
CREATE POLICY "contractor_details_select" ON public.contractor_details
  FOR SELECT USING (true);

CREATE POLICY "contractor_details_insert" ON public.contractor_details
  FOR INSERT WITH CHECK (auth.uid() = contractor_id);

CREATE POLICY "contractor_details_update" ON public.contractor_details
  FOR UPDATE USING (auth.uid() = contractor_id);

-- COMPLIANCE DOCS
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

-- PROPERTY LISTINGS
CREATE POLICY "listings_landlord_all" ON public.property_listings
  FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

-- Anyone can read active listings (needed for the public apply page)
CREATE POLICY "listings_public_select" ON public.property_listings
  FOR SELECT USING (is_active = true);

-- APPLICATIONS
CREATE POLICY "applications_applicant_insert" ON public.applications
  FOR INSERT WITH CHECK (applicant_id = auth.uid());

CREATE POLICY "applications_applicant_select" ON public.applications
  FOR SELECT USING (applicant_id = auth.uid());

CREATE POLICY "applications_landlord_select" ON public.applications
  FOR SELECT USING (landlord_id = auth.uid());

CREATE POLICY "applications_landlord_update" ON public.applications
  FOR UPDATE
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

-- RENT PAYMENTS
CREATE POLICY "rent_payments_landlord_all" ON public.rent_payments
  FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "rent_payments_tenant_select" ON public.rent_payments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.tenancies t
      WHERE t.tenancy_id = rent_payments.tenancy_id
        AND t.tenant_id = auth.uid()
    )
  );

-- INCIDENT COMMENTS
CREATE POLICY "incident_comments_select" ON public.incident_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.incidents i
      JOIN public.tenancies t ON t.id = i.tenancy_id
      WHERE i.id = incident_comments.incident_id
        AND t.landlord_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.incidents i
      WHERE i.id = incident_comments.incident_id
        AND (i.tenant_id = auth.uid() OR i.contractor_id = auth.uid())
    )
  );

CREATE POLICY "incident_comments_insert" ON public.incident_comments
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND (
      EXISTS (
        SELECT 1 FROM public.incidents i
        JOIN public.tenancies t ON t.id = i.tenancy_id
        WHERE i.id = incident_id AND t.landlord_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = incident_id
          AND (i.tenant_id = auth.uid() OR i.contractor_id = auth.uid())
      )
    )
  );

-- NOTIFICATIONS
CREATE POLICY "notifications_user_select" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notifications_user_update" ON public.notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- JOB RATINGS
CREATE POLICY "tenants_insert_ratings" ON public.job_ratings
  FOR INSERT WITH CHECK (tenant_id = auth.uid());

CREATE POLICY "authenticated_read_ratings" ON public.job_ratings
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- FCM TOKENS — full CRUD for own tokens (DELETE used on sign-out)
CREATE POLICY "fcm_tokens_select" ON public.fcm_tokens
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "fcm_tokens_insert" ON public.fcm_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_tokens_update" ON public.fcm_tokens
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_tokens_delete" ON public.fcm_tokens
  FOR DELETE USING (user_id = auth.uid());

-- NOTIFICATION PREFERENCES — full CRUD (DELETE on account deletion)
CREATE POLICY "notif_prefs_select" ON public.notification_preferences
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notif_prefs_insert" ON public.notification_preferences
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "notif_prefs_update" ON public.notification_preferences
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "notif_prefs_delete" ON public.notification_preferences
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- ============================================================
-- Helper: insert a notification row (called by all triggers below)
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id   UUID,
  p_type      TEXT,
  p_title     TEXT,
  p_body      TEXT,
  p_data      JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data);
END;
$$;

-- ============================================================
-- Trigger: new application → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_new_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_landlord_id UUID;
  v_address     TEXT;
BEGIN
  SELECT p.landlord_id,
         COALESCE(p.address_line_1 || ', ' || p.postcode, 'your property')
    INTO v_landlord_id, v_address
    FROM public.properties p
   WHERE p.id = NEW.property_id;

  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id,
      'new_application',
      'New Application',
      'Someone applied for ' || v_address,
      jsonb_build_object('listing_id', NEW.listing_id, 'property_id', NEW.property_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_application ON public.applications;
CREATE TRIGGER trg_notify_new_application
  AFTER INSERT ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_application();

-- ============================================================
-- Trigger: incident reported (INSERT) → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_incident_reported()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_landlord_id UUID;
  v_address     TEXT;
BEGIN
  SELECT t.landlord_id,
         COALESCE(p.address_line_1 || ', ' || p.postcode, 'your property')
    INTO v_landlord_id, v_address
    FROM public.tenancies t
    JOIN public.properties p ON p.id = t.property_id
   WHERE t.id = NEW.tenancy_id
   LIMIT 1;

  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id,
      'incident_status_change',
      'New Incident Reported',
      COALESCE(NEW.title, 'A new incident') || ' reported at ' || v_address,
      jsonb_build_object('incident_id', NEW.id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_incident_reported ON public.incidents;
CREATE TRIGGER trg_notify_incident_reported
  AFTER INSERT ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.notify_incident_reported();

-- ============================================================
-- Trigger: incident status change (UPDATE) → notify relevant parties
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_incident_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_landlord_id UUID;
  v_tenant_id   UUID;
  v_title_text  TEXT;
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  SELECT t.landlord_id, i.tenant_id
    INTO v_landlord_id, v_tenant_id
    FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
   WHERE i.id = NEW.id
   LIMIT 1;

  v_title_text := COALESCE(NEW.title, 'An incident');

  IF NEW.status = 'quoted' THEN
    IF v_landlord_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_landlord_id, 'quote_submitted', 'Quote Ready for Approval',
        v_title_text || ' — £' || COALESCE(NEW.quote_amount::TEXT, '?') || ' quoted',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  ELSIF NEW.status = 'in_progress' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id, 'job_approved', 'Job In Progress',
        v_title_text || ' is now being worked on',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  ELSIF NEW.status = 'completed' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id, 'incident_status_change', 'Job Completed',
        v_title_text || ' has been marked as complete',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  ELSIF NEW.status = 'approved' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id, 'incident_status_change', 'Incident Approved',
        v_title_text || ' has been approved — contractors are being contacted',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_incident_status ON public.incidents;
CREATE TRIGGER trg_notify_incident_status
  AFTER UPDATE ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.notify_incident_status_change();

-- ============================================================
-- Trigger: tenancy created OR tenant auto-linked → notify tenant
-- Fires on:
--   INSERT where tenant_id is already set (registered tenant)
--   UPDATE where tenant_id changes NULL → value (auto-link on signup)
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_address TEXT;
BEGIN
  IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.tenant_id IS NOT NULL THEN RETURN NEW; END IF;

  SELECT COALESCE(p.address_line_1 || ', ' || p.postcode, 'a property')
    INTO v_address
    FROM public.properties p
   WHERE p.id = NEW.property_id;

  PERFORM public.create_notification(
    NEW.tenant_id,
    'invitation_received',
    'Tenancy Invitation',
    'You''ve been invited to ' || v_address,
    jsonb_build_object('tenancy_id', NEW.tenancy_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_invitation ON public.tenancies;
CREATE TRIGGER trg_notify_invitation
  AFTER INSERT OR UPDATE OF tenant_id ON public.tenancies
  FOR EACH ROW EXECUTE FUNCTION public.notify_invitation_received();

-- ============================================================
-- Trigger: compliance doc expiry set/updated → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_compliance_expiring()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_landlord_id UUID;
  v_days_left   INT;
BEGIN
  IF NEW.expiry_date IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.expiry_date = NEW.expiry_date THEN RETURN NEW; END IF;

  v_days_left := NEW.expiry_date - CURRENT_DATE;
  IF v_days_left > 60 THEN RETURN NEW; END IF;

  SELECT p.landlord_id INTO v_landlord_id
    FROM public.properties p WHERE p.id = NEW.tenancy_id;

  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id,
      'compliance_expiring',
      CASE
        WHEN v_days_left < 0 THEN 'Compliance Document Expired'
        WHEN v_days_left = 0 THEN 'Compliance Document Expires Today'
        ELSE 'Compliance Document Expiring Soon'
      END,
      NEW.doc_type || CASE
        WHEN v_days_left < 0 THEN ' expired ' || ABS(v_days_left) || ' days ago'
        WHEN v_days_left = 0 THEN ' expires today'
        ELSE ' expires in ' || v_days_left || ' days'
      END,
      jsonb_build_object('tenancy_id', NEW.tenancy_id, 'doc_type', NEW.doc_type)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_compliance ON public.compliance_docs;
CREATE TRIGGER trg_notify_compliance
  AFTER INSERT OR UPDATE ON public.compliance_docs
  FOR EACH ROW EXECUTE FUNCTION public.notify_compliance_expiring();

-- ============================================================
-- Trigger: rent payment marked late → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_rent_overdue()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'late' AND (OLD.status IS NULL OR OLD.status <> 'late') THEN
    PERFORM public.create_notification(
      NEW.landlord_id,
      'rent_overdue',
      'Rent Overdue',
      '£' || NEW.amount_due::TEXT || ' rent due ' || NEW.due_date::TEXT || ' is overdue',
      jsonb_build_object('tenancy_id', NEW.tenancy_id, 'payment_id', NEW.id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_rent_overdue ON public.rent_payments;
CREATE TRIGGER trg_notify_rent_overdue
  AFTER INSERT OR UPDATE ON public.rent_payments
  FOR EACH ROW EXECUTE FUNCTION public.notify_rent_overdue();

-- ============================================================
-- Trigger: push notification via Edge Function on every notification INSERT
-- Requires pg_net + app.supabase_project_url + app.supabase_service_role_key
-- to be configured (see post-migration steps at bottom of this file).
-- ============================================================

CREATE OR REPLACE FUNCTION public.send_push_on_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_url TEXT;
  v_key TEXT;
BEGIN
  v_url := current_setting('app.supabase_project_url', true);
  v_key := current_setting('app.supabase_service_role_key', true);

  IF v_url IS NULL OR v_url = '' THEN RETURN NEW; END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', NEW.user_id,
      'type',    NEW.type,
      'title',   NEW.title,
      'body',    NEW.body,
      'data',    NEW.data
    )::text
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_send_push ON public.notifications;
CREATE TRIGGER trg_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.send_push_on_notification();

-- ============================================================
-- Trigger: recalculate contractor average_rating after each new rating
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_contractor_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.contractor_details
  SET
    total_ratings  = (SELECT COUNT(*)    FROM public.job_ratings WHERE contractor_id = NEW.contractor_id),
    average_rating = (SELECT AVG(rating) FROM public.job_ratings WHERE contractor_id = NEW.contractor_id)
  WHERE contractor_id = NEW.contractor_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_contractor_rating ON public.job_ratings;
CREATE TRIGGER trg_update_contractor_rating
  AFTER INSERT ON public.job_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_contractor_rating();

-- ============================================================
-- STORAGE — compliance-docs bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'compliance-docs',
  'compliance-docs',
  false,
  10485760,  -- 10 MB
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Landlords can upload docs for their own properties
CREATE POLICY "landlords_upload_compliance_docs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'compliance-docs'
    AND auth.uid() IN (
      SELECT landlord_id FROM public.properties
      WHERE id::text = split_part(name, '/', 1)
    )
  );

-- Landlords + tenants of that property can view / download
CREATE POLICY "landlords_tenants_view_compliance_docs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'compliance-docs'
    AND (
      auth.uid() IN (
        SELECT landlord_id FROM public.properties
        WHERE id::text = split_part(name, '/', 1)
      )
      OR auth.uid() IN (
        SELECT tenant_id FROM public.tenancies
        WHERE property_id::text = split_part(name, '/', 1)
      )
    )
  );

-- Landlords can delete / replace docs
CREATE POLICY "landlords_delete_compliance_docs"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'compliance-docs'
    AND auth.uid() IN (
      SELECT landlord_id FROM public.properties
      WHERE id::text = split_part(name, '/', 1)
    )
  );

-- ============================================================
-- VIEWS
-- ============================================================

-- Convenience view for landlord application dashboard
-- (Flutter can also query applications directly; this view is
--  available for admin tooling and future use)
CREATE OR REPLACE VIEW public.landlord_applications AS
SELECT
  a.*,
  p.full_name          AS applicant_name,
  p.email              AS applicant_email,
  prop.address_line_1,
  prop.postcode,
  l.asking_rent
FROM public.applications     a
JOIN public.profiles          p    ON p.id    = a.applicant_id
JOIN public.properties        prop ON prop.id = a.property_id
JOIN public.property_listings l    ON l.id    = a.listing_id;

ALTER VIEW public.landlord_applications SET (security_invoker = true);

-- ============================================================
-- POST-SETUP: manual steps required after running this script
-- ============================================================
--
-- 1. Configure the database so the push trigger can call your Edge Function:
--
--      ALTER DATABASE postgres
--        SET app.supabase_project_url = 'https://YOUR_PROJECT_REF.supabase.co';
--      ALTER DATABASE postgres
--        SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--
--    (Both values are in Supabase Dashboard → Settings → API)
--
-- 2. Deploy the Edge Functions from the repo root:
--
--      supabase functions deploy send-push
--      supabase functions deploy send-invitation-email
--
-- 3. Set Edge Function secrets:
--
--      supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
--      supabase secrets set FROM_EMAIL=noreply@yourdomain.com
--      supabase secrets set APP_URL=https://yourapp.com
--      supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
--
-- 4. Firebase (Flutter app):
--
--      Run:  flutterfire configure
--      Then uncomment the Firebase lines in lib/main.dart
-- ============================================================
