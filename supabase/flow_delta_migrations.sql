-- ============================================================
-- Flow App — Delta Migrations Script
-- Run this on top of the existing base schema (schema.sql).
-- Covers everything added in migrations 001–013.
-- Safe to run once — uses IF NOT EXISTS / DROP IF EXISTS throughout.
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================
-- PROFILES — add soft-delete column
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ============================================================
-- TENANCIES — schema changes
-- ============================================================

-- Make tenant_id nullable so landlords can create pending invite
-- rows for tenants who haven't signed up yet
ALTER TABLE public.tenancies
  ALTER COLUMN tenant_id DROP NOT NULL;

-- Extend status to include end-of-tenancy values
ALTER TABLE public.tenancies
  DROP CONSTRAINT IF EXISTS tenancies_status_check;

ALTER TABLE public.tenancies
  ADD CONSTRAINT tenancies_status_check
  CHECK (status IN ('pending', 'active', 'notice_given', 'ended'));

-- End-of-tenancy columns
ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS notice_given_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notice_type              TEXT
    CHECK (notice_type IN ('s21', 's8', 'mutual', 'surrender')),
  ADD COLUMN IF NOT EXISTS vacate_date              DATE,
  ADD COLUMN IF NOT EXISTS end_of_tenancy_date      DATE,
  ADD COLUMN IF NOT EXISTS deposit_returned_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deposit_deduction_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS deposit_deduction_reason TEXT;

-- Invited email — for unregistered tenant invitations
ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS invited_email TEXT;

CREATE INDEX IF NOT EXISTS tenancies_invited_email_idx
  ON public.tenancies (invited_email)
  WHERE invited_email IS NOT NULL;

-- ============================================================
-- COMPLIANCE DOCS — expiry tracking columns + upsert index
-- ============================================================

ALTER TABLE public.compliance_docs
  ADD COLUMN IF NOT EXISTS issue_date  DATE,
  ADD COLUMN IF NOT EXISTS expiry_date DATE,
  ADD COLUMN IF NOT EXISTS cert_number TEXT;

-- Required for onConflict: 'tenancy_id, doc_type' in Flutter
CREATE UNIQUE INDEX IF NOT EXISTS compliance_docs_tenancy_doc_type_idx
  ON public.compliance_docs (tenancy_id, doc_type);

-- ============================================================
-- CONTRACTOR DETAILS — verification + rating columns
-- ============================================================

ALTER TABLE public.contractor_details
  ADD COLUMN IF NOT EXISTS insurance_cert_number TEXT,
  ADD COLUMN IF NOT EXISTS insurance_expiry       DATE,
  ADD COLUMN IF NOT EXISTS gas_safe_number        TEXT,
  ADD COLUMN IF NOT EXISTS gas_safe_expiry        DATE,
  ADD COLUMN IF NOT EXISTS niceic_number          TEXT,
  ADD COLUMN IF NOT EXISTS niceic_expiry          DATE,
  ADD COLUMN IF NOT EXISTS average_rating         NUMERIC(3,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ratings          INT          NOT NULL DEFAULT 0;

-- ============================================================
-- PROPERTY LISTINGS (new table)
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

ALTER TABLE public.property_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "listings_landlord_all" ON public.property_listings
  FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "listings_public_select" ON public.property_listings
  FOR SELECT USING (is_active = true);

-- ============================================================
-- APPLICATIONS (new table)
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

CREATE UNIQUE INDEX IF NOT EXISTS applications_listing_applicant_unique
  ON public.applications (listing_id, applicant_id);

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

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

-- ============================================================
-- RENT PAYMENTS (new table)
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

CREATE INDEX IF NOT EXISTS rent_payments_tenancy_id_idx
  ON public.rent_payments (tenancy_id, due_date DESC);

CREATE INDEX IF NOT EXISTS rent_payments_landlord_id_idx
  ON public.rent_payments (landlord_id);

ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;

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

-- ============================================================
-- INCIDENT COMMENTS (new table)
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

ALTER TABLE public.incident_comments ENABLE ROW LEVEL SECURITY;

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

-- ============================================================
-- NOTIFICATIONS (new table)
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

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_user_select" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notifications_user_update" ON public.notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- JOB RATINGS (new table)
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

ALTER TABLE public.job_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenants_insert_ratings" ON public.job_ratings
  FOR INSERT WITH CHECK (tenant_id = auth.uid());

CREATE POLICY "authenticated_read_ratings" ON public.job_ratings
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================
-- FCM TOKENS (new table)
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

CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx
  ON public.fcm_tokens (user_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcm_tokens_select" ON public.fcm_tokens
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "fcm_tokens_insert" ON public.fcm_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_tokens_update" ON public.fcm_tokens
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_tokens_delete" ON public.fcm_tokens
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- NOTIFICATION PREFERENCES (new table)
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

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_prefs_select" ON public.notification_preferences
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notif_prefs_insert" ON public.notification_preferences
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "notif_prefs_update" ON public.notification_preferences
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "notif_prefs_delete" ON public.notification_preferences
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- RLS POLICY UPDATES — fix existing policies on base tables
-- ============================================================

-- PROPERTIES: tighten contractor access — must be explicitly assigned,
-- not just any property with an open unassigned incident
DROP POLICY IF EXISTS "properties_select" ON public.properties;

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

-- ============================================================
-- STORAGE — compliance-docs bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'compliance-docs',
  'compliance-docs',
  false,
  10485760,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "landlords_upload_compliance_docs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'compliance-docs'
    AND auth.uid() IN (
      SELECT landlord_id FROM public.properties
      WHERE id::text = split_part(name, '/', 1)
    )
  );

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
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Helper: insert a notification (called by all triggers)
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID, p_type TEXT, p_title TEXT, p_body TEXT, p_data JSONB DEFAULT '{}'
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data);
END;
$$;

-- -------------------------------------------------------
-- New application → notify landlord
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_new_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_landlord_id UUID;
  v_address     TEXT;
BEGIN
  SELECT p.landlord_id,
         COALESCE(p.address_line_1 || ', ' || p.postcode, 'your property')
    INTO v_landlord_id, v_address
    FROM public.properties p WHERE p.id = NEW.property_id;

  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id, 'new_application', 'New Application',
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

-- -------------------------------------------------------
-- Incident INSERT → notify landlord
-- -------------------------------------------------------
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
   WHERE t.id = NEW.tenancy_id LIMIT 1;

  IF v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id, 'incident_status_change', 'New Incident Reported',
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

-- -------------------------------------------------------
-- Incident status change → notify relevant parties
-- -------------------------------------------------------
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
   WHERE i.id = NEW.id LIMIT 1;

  v_title_text := COALESCE(NEW.title, 'An incident');

  IF NEW.status = 'quoted' AND v_landlord_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_landlord_id, 'quote_submitted', 'Quote Ready for Approval',
      v_title_text || ' — £' || COALESCE(NEW.quote_amount::TEXT, '?') || ' quoted',
      jsonb_build_object('incident_id', NEW.id)
    );
  ELSIF NEW.status = 'in_progress' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_tenant_id, 'job_approved', 'Job In Progress',
      v_title_text || ' is now being worked on',
      jsonb_build_object('incident_id', NEW.id)
    );
  ELSIF NEW.status = 'completed' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_tenant_id, 'incident_status_change', 'Job Completed',
      v_title_text || ' has been marked as complete',
      jsonb_build_object('incident_id', NEW.id)
    );
  ELSIF NEW.status = 'approved' AND v_tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_tenant_id, 'incident_status_change', 'Incident Approved',
      v_title_text || ' has been approved — contractors are being contacted',
      jsonb_build_object('incident_id', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_incident_status ON public.incidents;
CREATE TRIGGER trg_notify_incident_status
  AFTER UPDATE ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.notify_incident_status_change();

-- -------------------------------------------------------
-- Tenancy created / tenant auto-linked → notify tenant
-- Fires on INSERT (registered tenant) and on UPDATE when
-- tenant_id changes NULL → value (signup auto-link)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_address TEXT;
BEGIN
  IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.tenant_id IS NOT NULL THEN RETURN NEW; END IF;

  SELECT COALESCE(p.address_line_1 || ', ' || p.postcode, 'a property')
    INTO v_address
    FROM public.properties p WHERE p.id = NEW.property_id;

  PERFORM public.create_notification(
    NEW.tenant_id, 'invitation_received', 'Tenancy Invitation',
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

-- -------------------------------------------------------
-- Compliance doc expiry set/updated → notify landlord
-- -------------------------------------------------------
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

-- -------------------------------------------------------
-- Rent payment marked late → notify landlord
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_rent_overdue()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'late' AND (OLD.status IS NULL OR OLD.status <> 'late') THEN
    PERFORM public.create_notification(
      NEW.landlord_id, 'rent_overdue', 'Rent Overdue',
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

-- -------------------------------------------------------
-- Push notification via Edge Function on every notification INSERT
-- Silently skips if app.supabase_project_url is not configured yet
-- -------------------------------------------------------
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
    body := jsonb_build_object(
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

-- -------------------------------------------------------
-- Recalculate contractor average_rating after each new rating
-- -------------------------------------------------------
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
-- VIEWS
-- ============================================================

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
-- POST-SETUP: run these manually after this script completes
-- ============================================================
--
-- 1. Set database settings for push notifications:
--      ALTER DATABASE postgres SET app.supabase_project_url = 'https://YOUR_REF.supabase.co';
--      ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--    (Both values: Supabase Dashboard → Settings → API)
--
-- 2. Deploy Edge Functions:
--      supabase functions deploy send-push
--      supabase functions deploy send-invitation-email
--
-- 3. Set Edge Function secrets:
--      supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
--      supabase secrets set FROM_EMAIL=noreply@yourdomain.com
--      supabase secrets set APP_URL=https://yourapp.com
--      supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
--
-- 4. Firebase (Flutter):
--      Run: flutterfire configure
--      Then uncomment the Firebase lines in lib/main.dart
-- ============================================================
