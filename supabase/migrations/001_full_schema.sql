-- ============================================================
-- Abode — Full Database Schema
-- Run this in the Supabase SQL editor (Dashboard > SQL Editor)
-- Safe to re-run: uses CREATE TABLE IF NOT EXISTS throughout
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for future search


-- ============================================================
-- PROFILES  (extends auth.users — created on signup)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     text NOT NULL DEFAULT '',
  role          text NOT NULL CHECK (role IN ('landlord','tenant','contractor','agent'))
                DEFAULT 'tenant',
  email         text,
  phone         text,
  avatar_url    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Auto-create profile row when a user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'tenant'),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ============================================================
-- PROPERTIES
-- ============================================================
CREATE TABLE IF NOT EXISTS properties (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  landlord_id      uuid REFERENCES profiles(id) ON DELETE SET NULL,
  address_line_1   text NOT NULL DEFAULT '',
  address_line_2   text,
  address_line_3   text,
  town             text,
  postcode         text NOT NULL DEFAULT '',
  latitude         double precision,
  longitude        double precision,
  property_type    text,           -- 'house' | 'flat' | 'bungalow' | 'hmo' | 'studio'
  num_bedrooms     int,
  num_bathrooms    int,
  max_tenants      int,
  furnishing       text,           -- 'furnished' | 'unfurnished' | 'part_furnished'
  epc_rating       text,           -- 'A'..'G'
  council_tax_band text,           -- 'A'..'H'
  created_at       timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- TENANCIES
-- ============================================================
CREATE TABLE IF NOT EXISTS tenancies (
  id                     uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id             uuid NOT NULL,              -- group key (= property_id after migration)
  landlord_id            uuid REFERENCES profiles(id) ON DELETE SET NULL,
  tenant_id              uuid REFERENCES profiles(id) ON DELETE SET NULL,
  property_id            uuid REFERENCES properties(id) ON DELETE CASCADE,
  invited_email          text,                       -- unregistered tenant invite
  status                 text NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','active','expiring_soon','expired',
                                           'holding_over','terminated','notice_given','ended')),
  monthly_rent           numeric(10,2),
  weekly_rent            numeric(10,2),
  deposit_amount         numeric(10,2),
  deposit_scheme         text,                       -- 'DPS' | 'myDeposits' | 'TDS'
  deposit_ref            text,
  min_tenancy_length     int,                        -- months
  move_in_date           date,
  start_date             date,
  end_date               date,
  break_clause_date      date,
  referencing_status     text NOT NULL DEFAULT 'not_started'
                         CHECK (referencing_status IN ('not_started','in_progress',
                                                       'passed','failed','conditional')),
  -- RRA / Renters' Rights Act fields
  notice_served_date     date,
  notice_given_by        text CHECK (notice_given_by IN ('tenant','landlord')),
  notice_type            text,
  expected_vacate_date   date,
  vacate_date            date,
  notice_given_at        timestamptz,
  last_rent_increase_date date,
  next_rent_review_date  date,
  prs_registration_ref   text,
  pet_permitted          boolean NOT NULL DEFAULT false,
  ombudsman_ref          text,
  end_of_tenancy_date    date,
  deposit_returned_at    timestamptz,
  deposit_deduction_amount numeric(10,2),
  deposit_deduction_reason text,
  created_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tenancies_landlord  ON tenancies(landlord_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_tenant    ON tenancies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_property  ON tenancies(property_id);
CREATE INDEX IF NOT EXISTS idx_tenancies_tenancy_id ON tenancies(tenancy_id);


-- ============================================================
-- INCIDENTS  (maintenance requests)
-- ============================================================
CREATE TABLE IF NOT EXISTS incidents (
  id                      uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id              uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  tenant_id               uuid REFERENCES profiles(id) ON DELETE SET NULL,
  contractor_id           uuid REFERENCES profiles(id) ON DELETE SET NULL,
  title                   text NOT NULL,
  description             text NOT NULL DEFAULT '',
  category                text,       -- 'plumbing' | 'electrical' | 'structural' | 'damp' | 'heating' | 'other'
  status                  text NOT NULL DEFAULT 'reported'
                          CHECK (status IN ('reported','approved','quoted','in_progress','completed')),
  quote_amount            numeric(10,2),
  media_urls              text[] DEFAULT '{}',
  declined_by             text[] DEFAULT '{}',
  -- Awaab's Law fields
  is_awaabs_law           boolean NOT NULL DEFAULT false,
  awaabs_category         text,
  is_emergency            boolean NOT NULL DEFAULT false,
  hazard_identified_at    timestamptz,
  emergency_deadline      timestamptz,
  investigation_deadline  timestamptz,
  repair_start_deadline   timestamptz,
  -- Completion flags
  is_tenant_completed     boolean NOT NULL DEFAULT false,
  is_contractor_completed boolean NOT NULL DEFAULT false,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_incidents_tenancy    ON incidents(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_incidents_contractor ON incidents(contractor_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status     ON incidents(status);


-- ============================================================
-- COMPLIANCE CERTIFICATES
-- ============================================================
CREATE TABLE IF NOT EXISTS compliance_certificates (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id   uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  property_id  uuid REFERENCES properties(id) ON DELETE CASCADE,
  cert_type    text NOT NULL
               CHECK (cert_type IN ('gas_safety','eicr','epc','pat_test',
                                    'fire_risk','legionella','other')),
  cert_ref     text,
  issued_date  date NOT NULL,
  expiry_date  date NOT NULL,
  issued_by    text,
  document_url text,
  status       text NOT NULL DEFAULT 'valid'
               CHECK (status IN ('valid','expiring_soon','expired','missing')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_certs_tenancy ON compliance_certificates(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_certs_expiry  ON compliance_certificates(expiry_date);

-- Auto-update cert status based on expiry date
CREATE OR REPLACE FUNCTION update_cert_status()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.status := CASE
    WHEN NEW.expiry_date < CURRENT_DATE         THEN 'expired'
    WHEN NEW.expiry_date < CURRENT_DATE + 30    THEN 'expiring_soon'
    ELSE 'valid'
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cert_status ON compliance_certificates;
CREATE TRIGGER trg_cert_status
  BEFORE INSERT OR UPDATE OF expiry_date ON compliance_certificates
  FOR EACH ROW EXECUTE FUNCTION update_cert_status();


-- ============================================================
-- RENT REVIEWS  (Section 13 notices)
-- ============================================================
CREATE TABLE IF NOT EXISTS rent_reviews (
  id                 uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id         uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  current_rent       numeric(10,2) NOT NULL,
  proposed_rent      numeric(10,2) NOT NULL,
  notice_served_date date NOT NULL,
  effective_date     date NOT NULL,
  status             text NOT NULL DEFAULT 'notice_served'
                     CHECK (status IN ('notice_served','tenant_accepted',
                                       'tribunal_referred','tribunal_determined','withdrawn')),
  determined_rent    numeric(10,2),
  tribunal_ref       text,
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rent_reviews_tenancy   ON rent_reviews(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_rent_reviews_effective ON rent_reviews(effective_date);


-- ============================================================
-- SECTION 8 GROUNDS  (possession notices)
-- ============================================================
CREATE TABLE IF NOT EXISTS section8_grounds (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id          uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  ground_number       text NOT NULL,   -- '8' | '10' | '11' | '12' | '13' | '14' | '14A' | '17'
  ground_type         text NOT NULL DEFAULT 'discretionary'
                      CHECK (ground_type IN ('mandatory','discretionary')),
  description         text NOT NULL DEFAULT '',
  notice_served_date  date NOT NULL,
  earliest_court_date date,
  arrears_amount      numeric(10,2),
  notes               text,
  status              text NOT NULL DEFAULT 'notice_served'
                      CHECK (status IN ('notice_served','court_applied','hearing_listed',
                                        'order_granted','withdrawn')),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_s8_tenancy ON section8_grounds(tenancy_id);


-- ============================================================
-- PET REQUESTS  (RRA — tenant right to request a pet)
-- ============================================================
CREATE TABLE IF NOT EXISTS pet_requests (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id        uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  tenant_id         uuid REFERENCES profiles(id) ON DELETE CASCADE,
  pet_type          text NOT NULL DEFAULT 'other',   -- 'dog'|'cat'|'rabbit'|'bird'|'fish'|'other'
  pet_breed         text NOT NULL DEFAULT '',
  pet_name          text,
  pet_description   text,
  requested_at      timestamptz NOT NULL DEFAULT now(),
  response_deadline timestamptz NOT NULL             -- requested_at + 42 days
                    GENERATED ALWAYS AS (requested_at + interval '42 days') STORED,
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','refused','conditionally_approved')),
  refusal_reason    text,
  conditions        text,
  responded_at      timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pet_requests_tenancy ON pet_requests(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_pet_requests_tenant  ON pet_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pet_requests_status  ON pet_requests(status);


-- ============================================================
-- COMPLIANCE DOCS  (per-property uploaded documents — legacy)
-- ============================================================
CREATE TABLE IF NOT EXISTS compliance_docs (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id  uuid REFERENCES tenancies(id) ON DELETE CASCADE,
  doc_type    text NOT NULL,
  file_url    text,
  expiry_date date,
  uploaded_at timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- INCIDENT COMMENTS  (threaded discussion per incident)
-- ============================================================
CREATE TABLE IF NOT EXISTS incident_comments (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_id uuid NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  author_id   uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  author_role text NOT NULL,   -- 'landlord' | 'tenant' | 'contractor' | 'agent'
  body        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_incident ON incident_comments(incident_id);


-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type       text NOT NULL,     -- 'incident_update' | 'rent_discrepancy' | 'cert_expiry' | etc.
  title      text NOT NULL,
  body       text NOT NULL DEFAULT '',
  data       jsonb DEFAULT '{}',
  is_read    boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE NOT is_read;

-- Enable realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;


-- ============================================================
-- RENT PAYMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS rent_payments (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenancy_id  uuid NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  landlord_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  amount_due  numeric(10,2) NOT NULL,
  amount_paid numeric(10,2) NOT NULL DEFAULT 0,
  due_date    date NOT NULL,
  paid_at     timestamptz,
  status      text NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','paid','partial','late','missed')),
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_tenancy  ON rent_payments(tenancy_id);
CREATE INDEX IF NOT EXISTS idx_payments_due_date ON rent_payments(due_date);


-- ============================================================
-- JOB RATINGS  (tenant rates contractor after completion)
-- ============================================================
CREATE TABLE IF NOT EXISTS job_ratings (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_id   uuid NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  tenant_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rating        int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment       text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (incident_id, tenant_id)
);


-- ============================================================
-- CONTRACTOR DETAILS
-- ============================================================
CREATE TABLE IF NOT EXISTS contractor_details (
  id                   uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  contractor_id        uuid NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  work_types           text[] DEFAULT '{}',
  service_areas        jsonb DEFAULT '[]',
  is_setup_completed   boolean NOT NULL DEFAULT false,
  insurance_cert_number text,
  insurance_expiry      date,
  gas_safe_number       text,
  gas_safe_expiry       date,
  niceic_number         text,
  niceic_expiry         date,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- PROPERTY LISTINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS property_listings (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id         uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  landlord_id         uuid REFERENCES profiles(id) ON DELETE SET NULL,
  asking_rent         numeric(10,2),
  available_from      date,
  deposit_amount      numeric(10,2),
  min_tenancy_months  int,
  description         text,
  is_active           boolean NOT NULL DEFAULT true,
  share_token         text UNIQUE,
  monthly_rent        numeric(10,2),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- APPLICATIONS  (tenant applies via share link)
-- ============================================================
CREATE TABLE IF NOT EXISTS applications (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  listing_id        uuid REFERENCES property_listings(id) ON DELETE CASCADE,
  property_id       uuid REFERENCES properties(id) ON DELETE SET NULL,
  landlord_id       uuid REFERENCES profiles(id) ON DELETE SET NULL,
  applicant_id      uuid REFERENCES profiles(id) ON DELETE CASCADE,
  employment_status text,
  employer_name     text,
  monthly_income    numeric(10,2),
  move_in_preference text,
  num_adults        int NOT NULL DEFAULT 1,
  num_children      int NOT NULL DEFAULT 0,
  has_pets          boolean NOT NULL DEFAULT false,
  pet_details       text,
  is_smoker         boolean NOT NULL DEFAULT false,
  has_ccj           boolean NOT NULL DEFAULT false,
  ccj_details       text,
  notes             text,
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','rejected','withdrawn')),
  rejection_reason  text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- profiles: users can read all, update only their own
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select" ON profiles;
DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- properties: landlords manage own, everyone can read
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "properties_select" ON properties;
DROP POLICY IF EXISTS "properties_landlord_write" ON properties;
CREATE POLICY "properties_select"        ON properties FOR SELECT USING (true);
CREATE POLICY "properties_landlord_write" ON properties FOR ALL
  USING (auth.uid() = landlord_id) WITH CHECK (auth.uid() = landlord_id);

-- tenancies: landlord + their tenant can read; landlord can write
ALTER TABLE tenancies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tenancies_read" ON tenancies;
DROP POLICY IF EXISTS "tenancies_landlord_write" ON tenancies;
CREATE POLICY "tenancies_read" ON tenancies FOR SELECT
  USING (auth.uid() = landlord_id OR auth.uid() = tenant_id);
CREATE POLICY "tenancies_landlord_write" ON tenancies FOR ALL
  USING (auth.uid() = landlord_id) WITH CHECK (auth.uid() = landlord_id);
-- Agents and contractors can read all tenancies
CREATE POLICY "tenancies_agent_read" ON tenancies FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('agent','contractor')));

-- incidents: tenant, landlord, contractor, agent all have access
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "incidents_read" ON incidents;
DROP POLICY IF EXISTS "incidents_write" ON incidents;
CREATE POLICY "incidents_read" ON incidents FOR SELECT USING (
  auth.uid() = tenant_id
  OR auth.uid() = contractor_id
  OR EXISTS (
    SELECT 1 FROM tenancies t WHERE t.id = tenancy_id AND t.landlord_id = auth.uid()
  )
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent')
);
CREATE POLICY "incidents_write" ON incidents FOR ALL USING (true) WITH CHECK (true);

-- compliance_certificates: landlord + agent
ALTER TABLE compliance_certificates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "certs_all" ON compliance_certificates;
CREATE POLICY "certs_all" ON compliance_certificates FOR ALL USING (true) WITH CHECK (true);

-- rent_reviews
ALTER TABLE rent_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rent_reviews_all" ON rent_reviews;
CREATE POLICY "rent_reviews_all" ON rent_reviews FOR ALL USING (true) WITH CHECK (true);

-- section8_grounds
ALTER TABLE section8_grounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "s8_all" ON section8_grounds;
CREATE POLICY "s8_all" ON section8_grounds FOR ALL USING (true) WITH CHECK (true);

-- pet_requests
ALTER TABLE pet_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pet_requests_all" ON pet_requests;
CREATE POLICY "pet_requests_all" ON pet_requests FOR ALL USING (true) WITH CHECK (true);

-- compliance_docs
ALTER TABLE compliance_docs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compliance_docs_all" ON compliance_docs;
CREATE POLICY "compliance_docs_all" ON compliance_docs FOR ALL USING (true) WITH CHECK (true);

-- incident_comments
ALTER TABLE incident_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "comments_all" ON incident_comments;
CREATE POLICY "comments_all" ON incident_comments FOR ALL USING (true) WITH CHECK (true);

-- notifications: users see only their own
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications_own" ON notifications;
CREATE POLICY "notifications_own" ON notifications FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- rent_payments
ALTER TABLE rent_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rent_payments_all" ON rent_payments;
CREATE POLICY "rent_payments_all" ON rent_payments FOR ALL USING (true) WITH CHECK (true);

-- job_ratings
ALTER TABLE job_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ratings_all" ON job_ratings;
CREATE POLICY "ratings_all" ON job_ratings FOR ALL USING (true) WITH CHECK (true);

-- contractor_details
ALTER TABLE contractor_details ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "contractor_details_all" ON contractor_details;
CREATE POLICY "contractor_details_all" ON contractor_details FOR ALL USING (true) WITH CHECK (true);

-- property_listings: public read, landlord write
ALTER TABLE property_listings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "listings_read" ON property_listings;
DROP POLICY IF EXISTS "listings_write" ON property_listings;
CREATE POLICY "listings_read" ON property_listings FOR SELECT USING (is_active = true OR auth.uid() = landlord_id);
CREATE POLICY "listings_write" ON property_listings FOR ALL
  USING (auth.uid() = landlord_id) WITH CHECK (auth.uid() = landlord_id);

-- applications
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "applications_all" ON applications;
CREATE POLICY "applications_all" ON applications FOR ALL USING (
  auth.uid() = applicant_id OR auth.uid() = landlord_id
) WITH CHECK (true);


-- ============================================================
-- STORAGE BUCKETS  (run via Supabase dashboard Storage tab)
-- ============================================================
-- Create these buckets manually in Storage > New Bucket:
--   compliance-docs   (private, 20MB limit)
--   incident-media    (private, 50MB limit)
--   avatars           (public,  5MB limit)


-- ============================================================
-- DONE ✓
-- ============================================================
SELECT 'Schema created successfully' AS result;
