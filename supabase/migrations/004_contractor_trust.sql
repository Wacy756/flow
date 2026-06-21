-- ============================================================
-- Abode — Contractor Trust & Accountability System
-- Migration 004
-- ============================================================

-- ── 1. Job lifecycle columns on incidents ──────────────────────────────────────
ALTER TABLE incidents
  ADD COLUMN IF NOT EXISTS contractor_report_text    TEXT,
  ADD COLUMN IF NOT EXISTS contractor_report_photos  TEXT[]  DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS contractor_submitted_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS landlord_reviewed_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS landlord_approved         BOOLEAN,
  ADD COLUMN IF NOT EXISTS dispute_reason            TEXT,
  ADD COLUMN IF NOT EXISTS dispute_raised_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payout_status             TEXT    DEFAULT 'pending'
    CHECK (payout_status IN ('pending','held','released','withheld'));

-- Valid status values now include work_submitted + disputed
-- (ALTER CHECK not needed — Postgres CHECK is advisory and existing rows are fine;
--  new inserts/updates will use application-level validation)

-- ── 2. job_reports — per-job evidence record ──────────────────────────────────
CREATE TABLE IF NOT EXISTS job_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id          UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  contractor_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  report_text     TEXT NOT NULL,
  photo_urls      TEXT[]  DEFAULT '{}',
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  landlord_approved BOOLEAN,
  reviewed_at     TIMESTAMPTZ,
  dispute_reason  TEXT,
  payout_status   TEXT DEFAULT 'pending'
    CHECK (payout_status IN ('pending','held','released','withheld')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_job_reports_job_id        ON job_reports(job_id);
CREATE INDEX IF NOT EXISTS idx_job_reports_contractor_id ON job_reports(contractor_id);

ALTER TABLE job_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "job_reports_contractor_select" ON job_reports
  FOR SELECT USING (contractor_id = auth.uid());

CREATE POLICY "job_reports_contractor_insert" ON job_reports
  FOR INSERT WITH CHECK (contractor_id = auth.uid());

-- Landlords see reports for jobs on their properties
CREATE POLICY "job_reports_landlord_select" ON job_reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM incidents i
      JOIN tenancies t ON t.id = i.tenancy_id
      WHERE i.id = job_reports.job_id
        AND t.landlord_id = auth.uid()
    )
  );

-- Landlords can update (approve/dispute)
CREATE POLICY "job_reports_landlord_update" ON job_reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM incidents i
      JOIN tenancies t ON t.id = i.tenancy_id
      WHERE i.id = job_reports.job_id
        AND t.landlord_id = auth.uid()
    )
  );

-- ── 3. contractor_ratings — landlord rates contractor after job ───────────────
CREATE TABLE IF NOT EXISTS contractor_ratings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contractor_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  job_id          UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  landlord_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  stars           INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (job_id, landlord_id)
);

CREATE INDEX IF NOT EXISTS idx_contractor_ratings_contractor ON contractor_ratings(contractor_id);
CREATE INDEX IF NOT EXISTS idx_contractor_ratings_job        ON contractor_ratings(job_id);

ALTER TABLE contractor_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contractor_ratings_select" ON contractor_ratings
  FOR SELECT USING (contractor_id = auth.uid() OR landlord_id = auth.uid());

CREATE POLICY "contractor_ratings_insert" ON contractor_ratings
  FOR INSERT WITH CHECK (landlord_id = auth.uid());

-- ── 4. DB trigger — keep contractor_details rating stats in sync ──────────────
CREATE OR REPLACE FUNCTION update_contractor_rating_stats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  avg_r NUMERIC(3,2);
  cnt   INTEGER;
BEGIN
  SELECT AVG(stars)::NUMERIC(3,2), COUNT(*)::INTEGER
    INTO avg_r, cnt
    FROM contractor_ratings
    WHERE contractor_id = COALESCE(NEW.contractor_id, OLD.contractor_id);

  UPDATE contractor_details
    SET average_rating = COALESCE(avg_r, 0),
        total_ratings  = COALESCE(cnt, 0)
    WHERE contractor_id = COALESCE(NEW.contractor_id, OLD.contractor_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contractor_rating_sync ON contractor_ratings;
CREATE TRIGGER trg_contractor_rating_sync
  AFTER INSERT OR UPDATE OR DELETE ON contractor_ratings
  FOR EACH ROW EXECUTE FUNCTION update_contractor_rating_stats();

-- ── 5. Terms-of-service timestamp on profiles ─────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS contractor_terms_accepted_at TIMESTAMPTZ;

-- ── 6. Payout holdback: edge-function release log ─────────────────────────────
CREATE TABLE IF NOT EXISTS payout_releases (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id      UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  released_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  released_by UUID REFERENCES profiles(id),  -- null = system/function
  amount      NUMERIC(10,2),
  notes       TEXT
);

ALTER TABLE payout_releases ENABLE ROW LEVEL SECURITY;

-- Admins / system only — no direct user access
CREATE POLICY "payout_releases_admin_only" ON payout_releases
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ── 7. Storage bucket for job report photos ───────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('job-reports', 'job-reports', false)
  ON CONFLICT (id) DO NOTHING;

CREATE POLICY "job_reports_storage_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'job-reports' AND auth.role() = 'authenticated'
  );

CREATE POLICY "job_reports_storage_select" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'job-reports' AND auth.role() = 'authenticated'
  );
