-- ============================================================
-- Migration 004: Compliance Intelligence
-- Adds expiry tracking to compliance_docs
-- ============================================================

ALTER TABLE public.compliance_docs
  ADD COLUMN IF NOT EXISTS issue_date   DATE,
  ADD COLUMN IF NOT EXISTS expiry_date  DATE,
  ADD COLUMN IF NOT EXISTS cert_number  TEXT;

-- No RLS changes needed — existing policies on compliance_docs cover everything.
