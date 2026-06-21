-- ============================================================
-- Abode — Security Hardening & Schema Fixes
-- Migration 005
--
-- The live DB already has all required columns (platform_fee,
-- contractor_payout, payment_status, is_admin, average_rating,
-- total_ratings) from prior timestamped migrations.
--
-- This migration:
--   1. Server-side payout fee calculation trigger
--   2. Job report photo constraint (server-side)
--   3. Fix 7 tables with FOR ALL USING (true) RLS policies
--   4. Fix rent_payments landlord policy (broken tenancy_id join)
--   5. Add missing indexes
-- ============================================================


-- ── 1. Server-side payout fee calculation trigger ─────────────────────────────
--
-- Recalculates platform_fee and contractor_payout whenever quote_amount is
-- written. The client values are always overwritten — removes the client-side
-- fee manipulation vector entirely.

CREATE OR REPLACE FUNCTION calculate_payout()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.quote_amount IS NOT NULL THEN
    NEW.platform_fee      := ROUND(NEW.quote_amount * (COALESCE(NEW.platform_fee_pct, 4) / 100.0), 2);
    NEW.contractor_payout := ROUND(NEW.quote_amount - NEW.platform_fee, 2);
  ELSE
    NEW.platform_fee      := NULL;
    NEW.contractor_payout := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_payout ON incidents;
CREATE TRIGGER trg_calculate_payout
  BEFORE INSERT OR UPDATE OF quote_amount ON incidents
  FOR EACH ROW EXECUTE FUNCTION calculate_payout();


-- ── 2. Job report photo enforcement ──────────────────────────────────────────
--
-- Prevents bypassing the client-side photo check via direct API calls.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_job_report_photos'
      AND conrelid = 'job_reports'::regclass
  ) THEN
    ALTER TABLE job_reports
      ADD CONSTRAINT chk_job_report_photos
      CHECK (array_length(photo_urls, 1) >= 1);
  END IF;
END
$$;


-- ── 3. Fix RLS policies ───────────────────────────────────────────────────────


-- ── 3a. compliance_certificates — currently FOR ALL USING (true) ──────────────
DROP POLICY IF EXISTS "certs_all" ON compliance_certificates;

CREATE POLICY "certs_select" ON compliance_certificates FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = tenancy_id  AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid()  AND role = 'agent')
  );

CREATE POLICY "certs_write" ON compliance_certificates FOR ALL
  USING (
    EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid()  AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid()  AND role = 'agent')
  );


-- ── 3b. incident_comments — currently FOR ALL USING (true) ────────────────────
DROP POLICY IF EXISTS "comments_all" ON incident_comments;

-- Any party to the incident can read its thread
CREATE POLICY "comments_select" ON incident_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM incidents i WHERE i.id = incident_id AND (
        auth.uid() = i.tenant_id     OR
        auth.uid() = i.contractor_id OR
        EXISTS (SELECT 1 FROM tenancies t WHERE t.id = i.tenancy_id AND t.landlord_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM profiles  p WHERE p.id = auth.uid()   AND p.role = 'agent')
      )
    )
  );

-- Parties can post comments as themselves
CREATE POLICY "comments_insert" ON incident_comments FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    EXISTS (
      SELECT 1 FROM incidents i WHERE i.id = incident_id AND (
        auth.uid() = i.tenant_id     OR
        auth.uid() = i.contractor_id OR
        EXISTS (SELECT 1 FROM tenancies t WHERE t.id = i.tenancy_id AND t.landlord_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM profiles  p WHERE p.id = auth.uid()   AND p.role = 'agent')
      )
    )
  );

-- Authors can delete their own comments only
CREATE POLICY "comments_delete" ON incident_comments FOR DELETE
  USING (auth.uid() = author_id);


-- ── 3c. job_ratings — currently FOR ALL USING (true) ─────────────────────────
DROP POLICY IF EXISTS "ratings_all" ON job_ratings;

CREATE POLICY "job_ratings_select" ON job_ratings FOR SELECT
  USING (
    auth.uid() = tenant_id     OR
    auth.uid() = contractor_id OR
    EXISTS (
      SELECT 1 FROM incidents i
      JOIN   tenancies t ON t.id = i.tenancy_id
      WHERE  i.id = incident_id AND t.landlord_id = auth.uid()
    )
  );

-- Only the tenant who raised the incident can submit a rating
CREATE POLICY "job_ratings_insert" ON job_ratings FOR INSERT
  WITH CHECK (
    auth.uid() = tenant_id AND
    EXISTS (SELECT 1 FROM incidents WHERE id = incident_id AND tenant_id = auth.uid())
  );


-- ── 3d. pet_requests — currently FOR ALL USING (true) ────────────────────────
DROP POLICY IF EXISTS "pet_requests_all" ON pet_requests;

CREATE POLICY "pet_requests_select" ON pet_requests FOR SELECT
  USING (
    auth.uid() = tenant_id OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

-- Tenants submit requests for their own tenancy
CREATE POLICY "pet_requests_tenant_insert" ON pet_requests FOR INSERT
  WITH CHECK (
    auth.uid() = tenant_id AND
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND tenant_id = auth.uid())
  );

-- Landlords and agents respond (approve/deny)
CREATE POLICY "pet_requests_landlord_update" ON pet_requests FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );


-- ── 3e. rent_payments — fix broken join + overly-permissive agent policy ──────
--
-- "landlord full access" joins via tenancies.tenancy_id (a text field) instead
-- of tenancies.id (the UUID PK) — it never matches. "agent_all_rent_payments"
-- gives all agents unrestricted access. Both are replaced.

DROP POLICY IF EXISTS "agent_all_rent_payments"  ON rent_payments;
DROP POLICY IF EXISTS "landlord full access"      ON rent_payments;
DROP POLICY IF EXISTS "tenant read access"        ON rent_payments;

-- Landlords: full access to payments on their tenancies
CREATE POLICY "rent_payments_landlord" ON rent_payments FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_payments.tenancy_id AND landlord_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_payments.tenancy_id AND landlord_id = auth.uid())
  );

-- Tenants: read-only access to their own tenancy payments
CREATE POLICY "rent_payments_tenant_select" ON rent_payments FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_payments.tenancy_id AND tenant_id = auth.uid())
  );

-- Agents: read/write access to payments on tenancies they manage
CREATE POLICY "rent_payments_agent" ON rent_payments FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent'));


-- ── 3f. rent_reviews — currently FOR ALL USING (true) ────────────────────────
DROP POLICY IF EXISTS "rent_reviews_all" ON rent_reviews;

CREATE POLICY "rent_reviews_select" ON rent_reviews FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "rent_reviews_write" ON rent_reviews FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );


-- ── 3g. section8_grounds — currently FOR ALL USING (true) ────────────────────
DROP POLICY IF EXISTS "s8_all" ON section8_grounds;

CREATE POLICY "s8_select" ON section8_grounds FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "s8_write" ON section8_grounds FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies WHERE id = tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );


-- ── 4. Missing indexes ────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_incidents_tenant       ON incidents(tenant_id);
CREATE INDEX IF NOT EXISTS idx_incidents_contractor   ON incidents(contractor_id);
CREATE INDEX IF NOT EXISTS idx_comments_author        ON incident_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_payments_landlord      ON rent_payments(landlord_id)
  WHERE landlord_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_job_ratings_contractor ON job_ratings(contractor_id);
CREATE INDEX IF NOT EXISTS idx_ratings_landlord       ON contractor_ratings(landlord_id);
