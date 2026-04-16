-- ============================================================
-- Migration 013: invited_email + RLS fixes + trigger fixes
-- ============================================================

-- ============================================================
-- 1. Add invited_email to tenancies
-- ============================================================
-- Stores the email address of an invited tenant who hasn't signed up yet.
-- auth_notifier.dart queries this column on signup to auto-link the account.
-- Once linked, tenant_id is set and invited_email can be cleared.

ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS invited_email TEXT;

-- Index for fast signup lookup
CREATE INDEX IF NOT EXISTS tenancies_invited_email_idx
  ON public.tenancies (invited_email)
  WHERE invited_email IS NOT NULL;

-- RLS: ensure landlords can insert tenancy rows with null tenant_id
-- (needed for the pending invite rows created by AddTenancy for unregistered emails)
-- The base schema has a policy allowing landlord_id = auth.uid() on INSERT;
-- this DO NOTHING ensures we don't create a duplicate.
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

-- ============================================================
-- 2. Tighten properties_select RLS — contractors only see
--    properties where they are personally assigned to an incident
-- ============================================================

DROP POLICY IF EXISTS "properties_select" ON public.properties;

CREATE POLICY "properties_select" ON public.properties FOR SELECT USING (
  -- Landlord owns the property
  landlord_id = auth.uid()
  -- Tenant lives there
  OR id IN (
    SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid()
  )
  -- Contractor is assigned to an incident at this property
  OR EXISTS (
    SELECT 1 FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
    WHERE t.property_id = properties.id
      AND i.contractor_id = auth.uid()  -- must be explicitly assigned, not just any open incident
  )
);

-- ============================================================
-- 3. Add missing DELETE policy for notification_preferences
-- ============================================================

CREATE POLICY "Users delete own notification preferences"
  ON public.notification_preferences FOR DELETE
  USING (user_id = auth.uid());

-- ============================================================
-- 4. New trigger: incident INSERT → notify landlord
-- ============================================================
-- Migration 008 only notifies on status changes, not on the initial
-- report. This trigger fills that gap so landlords are alerted immediately.

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

-- ============================================================
-- 5. Update invitation trigger to also fire on UPDATE
-- ============================================================
-- When auth_notifier.dart auto-links a signed-up tenant by doing
--   UPDATE tenancies SET tenant_id = ... WHERE invited_email = ...
-- the original INSERT trigger doesn't fire. Replace it with one
-- that covers both INSERT (tenant_id set at creation) and UPDATE
-- (tenant_id set after auto-link).

CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_address TEXT;
BEGIN
  -- Only fire when tenant_id is actually set
  IF NEW.tenant_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- For UPDATE, only fire when tenant_id changes from NULL → a value
  -- (prevents re-notifying if other columns are updated later)
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

-- Recreate trigger covering both INSERT and UPDATE of tenant_id
DROP TRIGGER IF EXISTS trg_notify_invitation ON public.tenancies;
CREATE TRIGGER trg_notify_invitation
  AFTER INSERT OR UPDATE OF tenant_id ON public.tenancies
  FOR EACH ROW EXECUTE FUNCTION public.notify_invitation_received();

-- ============================================================
-- 6. Fix landlord_applications view — wrong column name
-- ============================================================
-- Migration 012 referenced l.monthly_rent but property_listings uses asking_rent.

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
