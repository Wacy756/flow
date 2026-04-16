-- ============================================================
-- Flow — Complete SQL Migration Script
-- All database changes made during this development session.
-- Run each section in order in the Supabase SQL Editor.
-- ============================================================
-- Covers migrations 010 through 013:
--   010 — Supabase Storage (compliance-docs bucket)
--   011 — FCM Push Notifications (fcm_tokens, notification_preferences, push trigger)
--   012 — Schema Fixes (profiles.deleted_at, RLS policy splits, landlord_applications view)
--   013 — invited_email + RLS tightening + incident reported trigger + invitation UPDATE trigger
-- ============================================================

-- ============================================================
-- PRE-FLIGHT: extensions required by 011
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================
-- MIGRATION 010: Supabase Storage — compliance-docs bucket
-- ============================================================

-- 1. Create the compliance-docs storage bucket (private, 10 MB, PDF + images)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'compliance-docs',
  'compliance-docs',
  false,
  10485760,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS — landlords can upload docs for their properties
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'landlords_upload_compliance_docs'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "landlords_upload_compliance_docs"
        ON storage.objects FOR INSERT
        WITH CHECK (
          bucket_id = 'compliance-docs'
          AND auth.uid() IN (
            SELECT landlord_id FROM public.properties
            WHERE id::text = split_part(name, '/', 1)
          )
        )
    $p$;
  END IF;
END $$;

-- 3. Storage RLS — landlords + tenants can view / download
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'landlords_tenants_view_compliance_docs'
  ) THEN
    EXECUTE $p$
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
        )
    $p$;
  END IF;
END $$;

-- 4. Storage RLS — landlords can delete / replace their docs
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'landlords_delete_compliance_docs'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "landlords_delete_compliance_docs"
        ON storage.objects FOR DELETE
        USING (
          bucket_id = 'compliance-docs'
          AND auth.uid() IN (
            SELECT landlord_id FROM public.properties
            WHERE id::text = split_part(name, '/', 1)
          )
        )
    $p$;
  END IF;
END $$;

-- 5. Unique index on (tenancy_id, doc_type) — required for upsert conflict resolution
--    in compliance_docs_panel.dart (onConflict: 'tenancy_id, doc_type')
CREATE UNIQUE INDEX IF NOT EXISTS compliance_docs_tenancy_doc_type_idx
  ON public.compliance_docs (tenancy_id, doc_type);


-- ============================================================
-- MIGRATION 011: FCM Push Notifications
-- ============================================================

-- 1. FCM device token registry
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL,
  platform   TEXT        NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx ON public.fcm_tokens (user_id);

-- 2. Per-user notification preferences
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

-- 3. Trigger function: send push notification via Edge Function on every new notification row
CREATE OR REPLACE FUNCTION public.send_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url  TEXT;
  v_key  TEXT;
BEGIN
  v_url := current_setting('app.supabase_project_url', true);
  v_key := current_setting('app.supabase_service_role_key', true);

  IF v_url IS NULL OR v_url = '' THEN
    RETURN NEW;
  END IF;

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
-- MIGRATION 012: Schema Fixes
-- ============================================================

-- 1. Soft-delete support for account deletion in settings screen
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. notification_preferences — drop combined policy from 011,
--    replace with explicit per-operation policies
DROP POLICY IF EXISTS "Users manage own notification preferences"
  ON public.notification_preferences;

CREATE POLICY "Users select own notification preferences"
  ON public.notification_preferences FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users insert own notification preferences"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users update own notification preferences"
  ON public.notification_preferences FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 3. fcm_tokens — drop combined policy from 011,
--    replace with explicit per-operation policies (including DELETE for sign-out)
DROP POLICY IF EXISTS "Users manage own FCM tokens"
  ON public.fcm_tokens;

CREATE POLICY "Users select own FCM tokens"
  ON public.fcm_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users insert own FCM tokens"
  ON public.fcm_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users update own FCM tokens"
  ON public.fcm_tokens FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users delete own FCM tokens"
  ON public.fcm_tokens FOR DELETE
  USING (user_id = auth.uid());

-- 4. landlord_applications convenience view
--    (Flutter queries the table directly; view is available for future use / admin tooling)
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
-- MIGRATION 013: invited_email + RLS fixes + trigger fixes
-- ============================================================

-- 1. invited_email column on tenancies
--    Landlord stores the invitee's email when they don't yet have a Flow account.
--    auth_notifier.dart queries this on signup to auto-link the tenant.
ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS invited_email TEXT;

CREATE INDEX IF NOT EXISTS tenancies_invited_email_idx
  ON public.tenancies (invited_email)
  WHERE invited_email IS NOT NULL;

-- Ensure landlords can insert tenancy rows where tenant_id is NULL
-- (required for the pending invite rows created for unregistered email addresses)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'tenancies'
      AND policyname = 'landlords_insert_tenancies'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "landlords_insert_tenancies"
        ON public.tenancies FOR INSERT
        WITH CHECK (landlord_id = auth.uid())
    $policy$;
  END IF;
END
$$;

-- 2. Tighten properties_select RLS
--    Contractors previously could see any property with an *unassigned* approved incident.
--    Now they can only see properties where they are explicitly assigned.
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

-- 3. Add missing DELETE policy for notification_preferences
--    (allows users to wipe their prefs row when deleting their account)
CREATE POLICY "Users delete own notification preferences"
  ON public.notification_preferences FOR DELETE
  USING (user_id = auth.uid());

-- 4. New trigger: incident INSERT → notify landlord
--    Migration 008 only covered status *changes* (UPDATE). The initial INSERT
--    (tenant reporting a new incident) was never notified to the landlord.
CREATE OR REPLACE FUNCTION public.notify_incident_reported()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

-- 5. Update invitation notification trigger to also fire on UPDATE
--    When auth_notifier.dart auto-links a tenant (UPDATE tenancies SET tenant_id = ...)
--    the original INSERT trigger doesn't fire. The new trigger handles both paths:
--    — INSERT with tenant_id already set (landlord invites registered tenant)
--    — UPDATE where tenant_id changes from NULL to a value (tenant signs up via invite link)
CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_address TEXT;
BEGIN
  IF NEW.tenant_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- For UPDATE: only fire when tenant_id transitions NULL → value
  IF TG_OP = 'UPDATE' AND OLD.tenant_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

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
-- POST-MIGRATION MANUAL STEPS (run once per environment)
-- ============================================================
-- These cannot be scripted as plain SQL — run them in the Supabase dashboard
-- or via the CLI after applying this migration.
--
-- 1. Set database connection settings (required for send-push trigger):
--      ALTER DATABASE postgres
--        SET app.supabase_project_url = 'https://YOUR_PROJECT_REF.supabase.co';
--      ALTER DATABASE postgres
--        SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--
-- 2. Deploy Edge Functions:
--      supabase functions deploy send-push
--      supabase functions deploy send-invitation-email
--
-- 3. Set Edge Function secrets:
--      supabase secrets set RESEND_API_KEY=re_...
--      supabase secrets set FROM_EMAIL=noreply@yourdomain.com
--      supabase secrets set APP_URL=https://yourapp.com
--      supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
--
-- 4. Firebase (Flutter app):
--      Run: flutterfire configure
--      Then uncomment the Firebase lines in lib/main.dart
-- ============================================================
