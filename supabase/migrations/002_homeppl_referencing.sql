-- Homeppl referencing integration fields
ALTER TABLE tenancies
  ADD COLUMN IF NOT EXISTS homeppl_application_id  text,
  ADD COLUMN IF NOT EXISTS homeppl_report_url       text,
  ADD COLUMN IF NOT EXISTS referencing_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS referencing_completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS referencing_result       jsonb;

-- Allow webhook to update referencing status without full auth
-- (edge function uses service role key, so RLS is bypassed — no policy needed)

COMMENT ON COLUMN tenancies.homeppl_application_id  IS 'Homeppl application UUID returned on POST /applications';
COMMENT ON COLUMN tenancies.homeppl_report_url       IS 'URL to the Homeppl PDF report (populated via webhook)';
COMMENT ON COLUMN tenancies.referencing_requested_at IS 'When the landlord/agent triggered the Homeppl check';
COMMENT ON COLUMN tenancies.referencing_completed_at IS 'When Homeppl webhook fired with a final result';
COMMENT ON COLUMN tenancies.referencing_result       IS 'Raw Homeppl result payload for audit trail';
