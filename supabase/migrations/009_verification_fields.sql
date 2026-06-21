ALTER TABLE contractor_details
  ADD COLUMN IF NOT EXISTS gas_safe_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS gas_safe_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS gas_safe_verified_name TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS companies_house_name TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_number TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_status TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_verified_at TIMESTAMPTZ;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS companies_house_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS companies_house_name TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_status TEXT,
  ADD COLUMN IF NOT EXISTS companies_house_verified_at TIMESTAMPTZ;
