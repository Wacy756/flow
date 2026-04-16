-- ============================================================
-- Migration 009: Contractor Verification & Job Ratings
-- ============================================================

-- 1. Add cert / rating columns to contractor_details
ALTER TABLE public.contractor_details
  ADD COLUMN IF NOT EXISTS insurance_cert_number TEXT,
  ADD COLUMN IF NOT EXISTS insurance_expiry       DATE,
  ADD COLUMN IF NOT EXISTS gas_safe_number        TEXT,
  ADD COLUMN IF NOT EXISTS gas_safe_expiry        DATE,
  ADD COLUMN IF NOT EXISTS niceic_number          TEXT,
  ADD COLUMN IF NOT EXISTS niceic_expiry          DATE,
  ADD COLUMN IF NOT EXISTS average_rating         NUMERIC(3,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ratings          INT          NOT NULL DEFAULT 0;

-- 2. Job ratings table (one per incident per tenant)
CREATE TABLE IF NOT EXISTS public.job_ratings (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   UUID        NOT NULL REFERENCES public.incidents(id)  ON DELETE CASCADE,
  tenant_id     UUID        NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  contractor_id UUID        NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  rating        INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (incident_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS job_ratings_contractor_idx
  ON public.job_ratings (contractor_id);

ALTER TABLE public.job_ratings ENABLE ROW LEVEL SECURITY;

-- Tenants insert their own ratings
CREATE POLICY "tenants_insert_ratings"
  ON public.job_ratings FOR INSERT
  WITH CHECK (tenant_id = auth.uid());

-- All authenticated users can read ratings
CREATE POLICY "authenticated_read_ratings"
  ON public.job_ratings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- 3. Trigger: recalculate contractor average_rating after each new rating
CREATE OR REPLACE FUNCTION public.update_contractor_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.contractor_details
  SET
    total_ratings  = (SELECT COUNT(*)    FROM public.job_ratings WHERE contractor_id = NEW.contractor_id),
    average_rating = (SELECT AVG(rating) FROM public.job_ratings WHERE contractor_id = NEW.contractor_id)
  WHERE contractor_id = NEW.contractor_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_contractor_rating ON public.job_ratings;
CREATE TRIGGER trg_update_contractor_rating
  AFTER INSERT ON public.job_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_contractor_rating();
