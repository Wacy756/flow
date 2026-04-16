-- ============================================================
-- Migration 002: Property Listings
-- Run this in the Supabase SQL Editor
-- Can run independently of migration 001
-- property_id stores the tenancy group UUID (= properties.id after 001 runs)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.property_listings (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id        UUID        NOT NULL UNIQUE, -- one active listing per property
  landlord_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  asking_rent        NUMERIC(10,2),
  available_from     DATE,
  deposit_amount     NUMERIC(10,2),
  min_tenancy_months INTEGER,
  description        TEXT,
  is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
  share_token        TEXT        NOT NULL UNIQUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.property_listings ENABLE ROW LEVEL SECURITY;

-- Landlords can do everything with their own listings
CREATE POLICY "listings_landlord_all" ON public.property_listings
  FOR ALL
  USING (landlord_id = auth.uid())
  WITH CHECK (landlord_id = auth.uid());

-- Anyone can read active listings (needed for the public apply page)
CREATE POLICY "listings_public_select" ON public.property_listings
  FOR SELECT
  USING (is_active = true);
