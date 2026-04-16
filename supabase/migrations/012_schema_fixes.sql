-- ============================================================
-- Migration 012: Schema fixes
-- ============================================================

-- 1. Add deleted_at to profiles (soft-delete for account deletion)
-- ============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. Fix notification_preferences RLS — add explicit INSERT + UPDATE policies
--    (the single policy in 011 only covers SELECT in older Postgres/Supabase versions)
-- ============================================================

-- Drop the combined policy from 011 if it exists, then recreate split policies
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

-- 3. Fix fcm_tokens RLS — same split (SELECT + INSERT + UPDATE + DELETE)
-- ============================================================
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

-- 4. Add landlord_applications view — all applications for a landlord's listings
--    so the dashboard can show them without per-listing queries
-- ============================================================
CREATE OR REPLACE VIEW public.landlord_applications AS
SELECT
  a.*,
  p.full_name   AS applicant_name,
  p.email       AS applicant_email,
  prop.address_line_1,
  prop.postcode,
  l.monthly_rent
FROM public.applications   a
JOIN public.profiles        p    ON p.id    = a.applicant_id
JOIN public.properties      prop ON prop.id = a.property_id
JOIN public.property_listings l  ON l.id   = a.listing_id;

-- RLS: Only the landlord can read their own applications via the view
-- (the underlying tables already have RLS; this view inherits security_invoker behaviour)
ALTER VIEW public.landlord_applications SET (security_invoker = true);
