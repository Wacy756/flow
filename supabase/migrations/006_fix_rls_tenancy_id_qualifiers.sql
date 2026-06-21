-- ============================================================
-- Abode — Fix RLS policy tenancy_id column ambiguity
-- Migration 006
--
-- Several policies in migration 005 used unqualified `tenancy_id`
-- inside an EXISTS subquery that joins the tenancies table. Because
-- tenancies itself has a column named tenancy_id (the human-readable
-- text reference), Postgres resolved it to tenancies.tenancy_id
-- (a text-to-uuid comparison that never matches) instead of the outer
-- table's UUID FK. This patch explicitly qualifies every reference.
-- ============================================================


-- ── compliance_certificates ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "certs_select" ON compliance_certificates;
DROP POLICY IF EXISTS "certs_write"  ON compliance_certificates;

CREATE POLICY "certs_select" ON compliance_certificates FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM properties WHERE id = compliance_certificates.property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = compliance_certificates.tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = compliance_certificates.tenancy_id  AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "certs_write" ON compliance_certificates FOR ALL
  USING (
    EXISTS (SELECT 1 FROM properties WHERE id = compliance_certificates.property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = compliance_certificates.tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM properties WHERE id = compliance_certificates.property_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies  WHERE id = compliance_certificates.tenancy_id  AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles   WHERE id = auth.uid() AND role = 'agent')
  );


-- ── pet_requests ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pet_requests_select"          ON pet_requests;
DROP POLICY IF EXISTS "pet_requests_tenant_insert"   ON pet_requests;
DROP POLICY IF EXISTS "pet_requests_landlord_update" ON pet_requests;

CREATE POLICY "pet_requests_select" ON pet_requests FOR SELECT
  USING (
    auth.uid() = tenant_id OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = pet_requests.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "pet_requests_tenant_insert" ON pet_requests FOR INSERT
  WITH CHECK (
    auth.uid() = tenant_id AND
    EXISTS (SELECT 1 FROM tenancies WHERE id = pet_requests.tenancy_id AND tenant_id = auth.uid())
  );

CREATE POLICY "pet_requests_landlord_update" ON pet_requests FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = pet_requests.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );


-- ── rent_reviews ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "rent_reviews_select" ON rent_reviews;
DROP POLICY IF EXISTS "rent_reviews_write"  ON rent_reviews;

CREATE POLICY "rent_reviews_select" ON rent_reviews FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_reviews.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_reviews.tenancy_id AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "rent_reviews_write" ON rent_reviews FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_reviews.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies WHERE id = rent_reviews.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );


-- ── section8_grounds ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "s8_select" ON section8_grounds;
DROP POLICY IF EXISTS "s8_write"  ON section8_grounds;

CREATE POLICY "s8_select" ON section8_grounds FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = section8_grounds.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM tenancies WHERE id = section8_grounds.tenancy_id AND tenant_id   = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );

CREATE POLICY "s8_write" ON section8_grounds FOR ALL
  USING (
    EXISTS (SELECT 1 FROM tenancies WHERE id = section8_grounds.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM tenancies WHERE id = section8_grounds.tenancy_id AND landlord_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM profiles  WHERE id = auth.uid() AND role = 'agent')
  );
