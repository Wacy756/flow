-- ============================================================
-- Abode — Critical & High Security Fixes
-- Migration 010
--
-- Fixes:
--   C1. Block is_admin self-escalation via profiles UPDATE
--   C6. Replace open incidents_write policy with scoped policies
--   H2. Replace open compliance_docs policy with scoped policies
--   H3. Replace open contractor_details policy with scoped policies
--   H5. Add RLS for invited-tenant invitation read + accept
-- ============================================================


-- ── C1. Block is_admin self-escalation ───────────────────────────────────────
--
-- Any authenticated user could previously run:
--   UPDATE profiles SET is_admin = true WHERE id = auth.uid()
-- because the profiles_update policy is USING (auth.uid() = id) with no
-- column restriction.  This trigger prevents non-admins from changing
-- is_admin.  service_role (auth.uid() = null) is always allowed so that
-- admins can be seeded via the Supabase Dashboard or CLI.

CREATE OR REPLACE FUNCTION prevent_admin_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    -- Allow service_role bypass (auth.uid() is null for service_role)
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true
    ) THEN
      RAISE EXCEPTION 'Insufficient privileges: is_admin can only be changed by an existing admin';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_admin_escalation ON profiles;
CREATE TRIGGER trg_prevent_admin_escalation
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION prevent_admin_escalation();


-- ── C6. Replace open incidents_write policy ───────────────────────────────────
--
-- The original "incidents_write" policy was FOR ALL USING (true) — any
-- authenticated user could set payout_status='released' or
-- landlord_approved=true on ANY incident.

DROP POLICY IF EXISTS "incidents_write" ON incidents;

-- Tenants can create incidents on their own active tenancy
CREATE POLICY "incidents_tenant_insert" ON incidents FOR INSERT
  WITH CHECK (
    auth.uid() = tenant_id AND
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND tenant_id = auth.uid())
  );

-- Tenants can update incidents in their own tenancy
-- (mark complete, confirm visit, etc.)
CREATE POLICY "incidents_tenant_update" ON incidents FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM tenancies t
            WHERE t.id = incidents.tenancy_id AND t.tenant_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies t
            WHERE t.id = incidents.tenancy_id AND t.tenant_id = auth.uid())
  );

-- Landlords have full write access to incidents on their own tenancies
CREATE POLICY "incidents_landlord_write" ON incidents FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies t
            WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies t
            WHERE t.id = incidents.tenancy_id AND t.landlord_id = auth.uid())
  );

-- Approved contractors can claim an unassigned approved job
-- (SubmitQuote / RequestVisit both set contractor_id for the first time)
CREATE POLICY "incidents_contractor_claim" ON incidents FOR UPDATE
  USING (
    contractor_id IS NULL AND
    status IN ('approved') AND
    EXISTS (
      SELECT 1 FROM contractor_details
      WHERE contractor_id = auth.uid() AND verification_status = 'approved'
    )
  )
  WITH CHECK (
    contractor_id = auth.uid()  -- must assign the job to themselves
  );

-- Approved contractors can update their own assigned incidents
-- (mark complete, submit job report, release job, visit slots, decline)
CREATE POLICY "incidents_contractor_update" ON incidents FOR UPDATE
  USING (
    auth.uid() = contractor_id AND contractor_id IS NOT NULL
  )
  WITH CHECK (
    -- contractor_id must remain their own id after the update
    auth.uid() = contractor_id
  );

-- Approved contractors can update declined_by on unassigned approved incidents
-- (DeclineJob path — contractor_id stays null, only declined_by changes)
CREATE POLICY "incidents_contractor_decline" ON incidents FOR UPDATE
  USING (
    contractor_id IS NULL AND
    status = 'approved' AND
    EXISTS (
      SELECT 1 FROM contractor_details
      WHERE contractor_id = auth.uid() AND verification_status = 'approved'
    )
  )
  WITH CHECK (contractor_id IS NULL);

-- Agents can write to all incidents in their managed portfolio
CREATE POLICY "incidents_agent_write" ON incidents FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent'));

-- Admins can write to all incidents
CREATE POLICY "incidents_admin_write" ON incidents FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));


-- ── Server-side guard: contractors cannot touch payout/approval fields ─────────
--
-- Even with the new scoped update policy above, a contractor updating their
-- own assigned incident could try to set payout_status='released' or
-- landlord_approved=true.  This trigger blocks those changes from non-landlord,
-- non-admin callers.  service_role (edge functions) is exempted.

CREATE OR REPLACE FUNCTION prevent_contractor_payout_manipulation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Skip for service_role (auth.uid() is null) and admins
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN NEW;
  END IF;

  -- Contractors may not change payout/approval fields
  IF EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'contractor') THEN
    IF NEW.payout_status      IS DISTINCT FROM OLD.payout_status      OR
       NEW.landlord_approved  IS DISTINCT FROM OLD.landlord_approved  OR
       NEW.payment_status     IS DISTINCT FROM OLD.payment_status     OR
       NEW.platform_fee       IS DISTINCT FROM OLD.platform_fee       OR
       NEW.contractor_payout  IS DISTINCT FROM OLD.contractor_payout
    THEN
      RAISE EXCEPTION 'Contractors are not permitted to modify payout or approval fields';
    END IF;
  END IF;

  -- Tenants may not change payout/approval fields either
  IF EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'tenant') THEN
    IF NEW.payout_status      IS DISTINCT FROM OLD.payout_status      OR
       NEW.landlord_approved  IS DISTINCT FROM OLD.landlord_approved  OR
       NEW.payment_status     IS DISTINCT FROM OLD.payment_status
    THEN
      RAISE EXCEPTION 'Tenants are not permitted to modify payout or approval fields';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_contractor_payout_manipulation ON incidents;
CREATE TRIGGER trg_prevent_contractor_payout_manipulation
  BEFORE UPDATE ON incidents
  FOR EACH ROW EXECUTE FUNCTION prevent_contractor_payout_manipulation();


-- ── H2. Fix compliance_docs RLS ───────────────────────────────────────────────
DROP POLICY IF EXISTS "compliance_docs_all" ON compliance_docs;

CREATE POLICY "compliance_docs_select" ON compliance_docs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies
            WHERE id = compliance_docs.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies
            WHERE id = compliance_docs.tenancy_id AND tenant_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "compliance_docs_write" ON compliance_docs FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies
            WHERE id = compliance_docs.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies
            WHERE id = compliance_docs.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent')
  );


-- ── H3. Fix contractor_details RLS ────────────────────────────────────────────
DROP POLICY IF EXISTS "contractor_details_all" ON contractor_details;

-- Contractors can fully manage their own row
CREATE POLICY "contractor_details_own" ON contractor_details FOR ALL
  USING  (contractor_id = auth.uid())
  WITH CHECK (contractor_id = auth.uid());

-- Landlords and agents can read contractor details (for hiring/vetting)
CREATE POLICY "contractor_details_read" ON contractor_details FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('landlord','agent'))
  );

-- Admins can update any contractor_details row (for vetting approval/rejection)
CREATE POLICY "contractor_details_admin_write" ON contractor_details FOR UPDATE
  USING  (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));


-- ── H5. Invited-tenant invitation RLS ─────────────────────────────────────────
--
-- Pending tenancy rows have tenant_id = NULL; the tenant_read policy checks
-- auth.uid() = tenant_id which is always false for NULL.  Invitations were
-- unreadable by the invited tenant — the accept flow was silently broken.

CREATE POLICY "tenancies_invited_read" ON tenancies FOR SELECT
  USING (
    invited_email = auth.email() AND status = 'pending'
  );

-- Allows the invited tenant to accept their invitation by setting tenant_id
-- to their own uid and clearing invited_email.
CREATE POLICY "tenancies_invited_accept" ON tenancies FOR UPDATE
  USING (
    invited_email = auth.email() AND status = 'pending'
  )
  WITH CHECK (
    -- After update: tenant_id must be the accepting user's own id
    tenant_id = auth.uid()
  );
