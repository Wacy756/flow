-- ============================================================
-- Migration 005: Rent Payments
-- Tracks monthly rent payments, arrears, and partial payments
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rent_payments (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id    UUID          NOT NULL,   -- group UUID = properties.id (tenancy_id column)
  landlord_id   UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_due    NUMERIC(10,2) NOT NULL,
  amount_paid   NUMERIC(10,2) NOT NULL DEFAULT 0,
  due_date      DATE          NOT NULL,
  paid_at       TIMESTAMPTZ,
  status        TEXT          NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'paid', 'partial', 'late')),
  notes         TEXT,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS rent_payments_tenancy_id_idx
  ON public.rent_payments (tenancy_id, due_date DESC);

CREATE INDEX IF NOT EXISTS rent_payments_landlord_id_idx
  ON public.rent_payments (landlord_id);

-- RLS
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;

-- Landlord: full access to own records
CREATE POLICY "Landlord manages own rent payments"
  ON public.rent_payments
  FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

-- Tenant: read-only access via tenancy group membership
CREATE POLICY "Tenant reads rent payments for their tenancy"
  ON public.rent_payments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tenancies t
      WHERE t.tenancy_id = rent_payments.tenancy_id
        AND t.tenant_id = auth.uid()
    )
  );
