-- ============================================================
-- Migration 001: Separate properties from tenancies
-- Run this in the Supabase SQL Editor (one-time migration)
-- ============================================================

-- STEP 1: Create the properties table
CREATE TABLE IF NOT EXISTS public.properties (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  address_line_1 TEXT        NOT NULL DEFAULT '',
  address_line_2 TEXT,
  address_line_3 TEXT,
  town           TEXT,
  postcode       TEXT        NOT NULL DEFAULT '',
  latitude       FLOAT8,
  longitude      FLOAT8,
  property_type  TEXT,
  num_bedrooms   INTEGER,
  num_bathrooms  INTEGER,
  max_tenants    INTEGER,
  furnishing     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- STEP 2: Migrate existing property data (one property per tenancy group)
-- We reuse tenancy_id as the property id — this is the key trick that makes
-- all existing references (compliance_docs, etc.) work without data rewrites.
INSERT INTO public.properties (
  id, landlord_id, address_line_1, address_line_2, address_line_3,
  town, postcode, latitude, longitude,
  property_type, num_bedrooms, num_bathrooms, max_tenants, furnishing, created_at
)
SELECT DISTINCT ON (tenancy_id)
  tenancy_id,
  landlord_id,
  COALESCE(address_line_1, ''),
  address_line_2,
  address_line_3,
  town,
  COALESCE(postcode, ''),
  latitude,
  longitude,
  property_type,
  num_bedrooms,
  num_bathrooms,
  max_tenants,
  furnishing,
  created_at
FROM public.tenancies
ORDER BY tenancy_id, created_at ASC
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Add property_id FK to tenancies
ALTER TABLE public.tenancies
  ADD COLUMN IF NOT EXISTS property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE;

-- STEP 4: Populate property_id (equals tenancy_id since we reused it above)
UPDATE public.tenancies SET property_id = tenancy_id WHERE property_id IS NULL;

-- STEP 5: Make property_id required
ALTER TABLE public.tenancies ALTER COLUMN property_id SET NOT NULL;

-- STEP 6: Fix compliance_docs FK — remap from tenancies.id to properties.id
-- First, update any existing rows (maps individual row id → property id)
ALTER TABLE public.compliance_docs
  DROP CONSTRAINT IF EXISTS compliance_docs_tenancy_id_fkey;

UPDATE public.compliance_docs cd
SET tenancy_id = t.tenancy_id
FROM public.tenancies t
WHERE cd.tenancy_id = t.id;

ALTER TABLE public.compliance_docs
  ADD CONSTRAINT compliance_docs_tenancy_id_fkey
  FOREIGN KEY (tenancy_id) REFERENCES public.properties(id) ON DELETE CASCADE;

-- STEP 7: Enable RLS on properties
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "properties_select" ON public.properties FOR SELECT USING (
  landlord_id = auth.uid()
  OR id IN (SELECT property_id FROM public.tenancies WHERE tenant_id = auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.incidents i
    JOIN public.tenancies t ON t.id = i.tenancy_id
    WHERE t.property_id = properties.id
      AND (i.contractor_id = auth.uid() OR (i.status = 'approved' AND i.contractor_id IS NULL))
  )
);

CREATE POLICY "properties_insert" ON public.properties FOR INSERT
  WITH CHECK (landlord_id = auth.uid());

CREATE POLICY "properties_update" ON public.properties FOR UPDATE
  USING (landlord_id = auth.uid());

CREATE POLICY "properties_delete" ON public.properties FOR DELETE
  USING (landlord_id = auth.uid());

-- STEP 8: Remove property fields from tenancies (they now live in properties)
ALTER TABLE public.tenancies
  DROP COLUMN IF EXISTS address_line_1,
  DROP COLUMN IF EXISTS address_line_2,
  DROP COLUMN IF EXISTS address_line_3,
  DROP COLUMN IF EXISTS town,
  DROP COLUMN IF EXISTS postcode,
  DROP COLUMN IF EXISTS latitude,
  DROP COLUMN IF EXISTS longitude,
  DROP COLUMN IF EXISTS property_type,
  DROP COLUMN IF EXISTS num_bedrooms,
  DROP COLUMN IF EXISTS num_bathrooms,
  DROP COLUMN IF EXISTS max_tenants,
  DROP COLUMN IF EXISTS furnishing;

-- Done. tenancies now holds: id, tenancy_id (grouping), property_id, landlord_id,
-- tenant_id, status, monthly_rent, weekly_rent, deposit_amount,
-- min_tenancy_length, move_in_date, created_at
