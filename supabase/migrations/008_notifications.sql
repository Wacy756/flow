-- ============================================================
-- Migration 008: In-App Notifications
-- Table + DB trigger functions for all notification events
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL,
  title       TEXT        NOT NULL,
  body        TEXT        NOT NULL DEFAULT '',
  data        JSONB       NOT NULL DEFAULT '{}',
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS notifications_user_id_idx
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON public.notifications (user_id, is_read)
  WHERE is_read = FALSE;

-- RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "Users read own notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

-- Users can mark their own notifications as read
CREATE POLICY "Users update own notifications"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- No client INSERT — triggers only (SECURITY DEFINER functions bypass RLS)

-- ============================================================
-- Helper: insert a notification row (used by all triggers)
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
-- Trigger 1: New application received → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_new_application()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_landlord_id UUID;
  v_address     TEXT;
BEGIN
  -- Get landlord_id and address from property
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
-- Trigger 2: Incident status changes → notify relevant parties
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_incident_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_landlord_id UUID;
  v_tenant_id   UUID;
  v_title_text  TEXT;
BEGIN
  -- Only fire on actual status change
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Get landlord and tenant IDs
  SELECT t.landlord_id, i.tenant_id
    INTO v_landlord_id, v_tenant_id
    FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
   WHERE i.id = NEW.id
   LIMIT 1;

  v_title_text := COALESCE(NEW.title, 'An incident');

  -- quoted → notify landlord for approval
  IF NEW.status = 'quoted' THEN
    IF v_landlord_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_landlord_id,
        'quote_submitted',
        'Quote Ready for Approval',
        v_title_text || ' — £' || COALESCE(NEW.quote_amount::TEXT, '?') || ' quoted',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  -- in_progress → notify tenant their job was approved
  ELSIF NEW.status = 'in_progress' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id,
        'job_approved',
        'Job In Progress',
        v_title_text || ' is now being worked on',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  -- completed → notify tenant
  ELSIF NEW.status = 'completed' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id,
        'incident_status_change',
        'Job Completed',
        v_title_text || ' has been marked as complete',
        jsonb_build_object('incident_id', NEW.id)
      );
    END IF;

  -- approved → notify tenant their report was approved
  ELSIF NEW.status = 'approved' THEN
    IF v_tenant_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_tenant_id,
        'incident_status_change',
        'Incident Approved',
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
-- Trigger 3: Tenancy created → notify tenant (invitation)
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_invitation_received()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_address TEXT;
BEGIN
  SELECT COALESCE(p.address_line_1 || ', ' || p.postcode, 'a property')
    INTO v_address
    FROM public.properties p
   WHERE p.id = NEW.property_id;

  IF NEW.tenant_id IS NOT NULL THEN
    PERFORM public.create_notification(
      NEW.tenant_id,
      'invitation_received',
      'Tenancy Invitation',
      'You''ve been invited to ' || v_address,
      jsonb_build_object('tenancy_id', NEW.tenancy_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_invitation ON public.tenancies;
CREATE TRIGGER trg_notify_invitation
  AFTER INSERT ON public.tenancies
  FOR EACH ROW EXECUTE FUNCTION public.notify_invitation_received();

-- ============================================================
-- Trigger 4: Compliance doc expiry set/updated → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_compliance_expiring()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_landlord_id UUID;
  v_days_left   INT;
BEGIN
  -- Only when an expiry date is set or changed
  IF NEW.expiry_date IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.expiry_date = NEW.expiry_date THEN
    RETURN NEW;
  END IF;

  v_days_left := NEW.expiry_date - CURRENT_DATE;

  -- Only notify if within 60 days or already expired
  IF v_days_left > 60 THEN
    RETURN NEW;
  END IF;

  SELECT p.landlord_id
    INTO v_landlord_id
    FROM public.properties p
   WHERE p.id = NEW.tenancy_id;

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
      jsonb_build_object(
        'tenancy_id', NEW.tenancy_id,
        'doc_type',   NEW.doc_type
      )
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
-- Trigger 5: Rent payment marked late → notify landlord
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_rent_overdue()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'late' AND (OLD.status IS NULL OR OLD.status <> 'late') THEN
    PERFORM public.create_notification(
      NEW.landlord_id,
      'rent_overdue',
      'Rent Overdue',
      '£' || NEW.amount_due::TEXT || ' rent due ' || NEW.due_date::TEXT || ' is overdue',
      jsonb_build_object(
        'tenancy_id', NEW.tenancy_id,
        'payment_id', NEW.id
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_rent_overdue ON public.rent_payments;
CREATE TRIGGER trg_notify_rent_overdue
  AFTER INSERT OR UPDATE ON public.rent_payments
  FOR EACH ROW EXECUTE FUNCTION public.notify_rent_overdue();
