-- ============================================================
-- Migration 006: Tenancy End Workflow
-- Adds notice, vacate, and deposit return fields to tenancies
-- ============================================================

-- Extend the status CHECK constraint (requires drop + recreate)
ALTER TABLE public.tenancies
  DROP CONSTRAINT IF EXISTS tenancies_status_check;

ALTER TABLE public.tenancies
  ADD CONSTRAINT tenancies_status_check
  CHECK (status IN ('pending', 'active', 'notice_given', 'ended'));

-- New end-of-tenancy columns
ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS notice_given_at            TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notice_type                TEXT
    CHECK (notice_type IN ('s21', 's8', 'mutual', 'surrender')),
  ADD COLUMN IF NOT EXISTS vacate_date                DATE,
  ADD COLUMN IF NOT EXISTS end_of_tenancy_date        DATE,
  ADD COLUMN IF NOT EXISTS deposit_returned_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deposit_deduction_amount   NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS deposit_deduction_reason   TEXT;

-- No RLS changes needed — existing landlord UPDATE policy covers these columns.
