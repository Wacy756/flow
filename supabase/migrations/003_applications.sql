-- ============================================================
-- Migration 003: Tenant Applications
-- Run after 002_property_listings.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS public.applications (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id           UUID        NOT NULL REFERENCES public.property_listings(id) ON DELETE CASCADE,
  property_id          UUID        NOT NULL,   -- denormalised for easy querying
  landlord_id          UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  applicant_id         UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  employment_status    TEXT,                   -- 'employed' | 'self_employed' | 'student' | 'unemployed' | 'retired'
  employer_name        TEXT,
  monthly_income       NUMERIC(10,2),
  move_in_preference   DATE,
  num_adults           INTEGER     NOT NULL DEFAULT 1,
  num_children         INTEGER     NOT NULL DEFAULT 0,
  has_pets             BOOLEAN     NOT NULL DEFAULT FALSE,
  pet_details          TEXT,
  is_smoker            BOOLEAN     NOT NULL DEFAULT FALSE,
  has_ccj              BOOLEAN     NOT NULL DEFAULT FALSE,
  ccj_details          TEXT,
  notes                TEXT,
  status               TEXT        NOT NULL DEFAULT 'pending', -- 'pending' | 'approved' | 'rejected'
  rejection_reason     TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

-- Applicants can insert and view their own applications
CREATE POLICY "applications_applicant_insert" ON public.applications
  FOR INSERT
  WITH CHECK (applicant_id = auth.uid());

CREATE POLICY "applications_applicant_select" ON public.applications
  FOR SELECT
  USING (applicant_id = auth.uid());

-- Landlords can view and update applications for their properties
CREATE POLICY "applications_landlord_select" ON public.applications
  FOR SELECT
  USING (landlord_id = auth.uid());

CREATE POLICY "applications_landlord_update" ON public.applications
  FOR UPDATE
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

-- Prevent duplicate applications (one per applicant per listing)
CREATE UNIQUE INDEX IF NOT EXISTS applications_listing_applicant_unique
  ON public.applications (listing_id, applicant_id);
