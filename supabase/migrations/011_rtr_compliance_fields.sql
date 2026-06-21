-- ============================================================
-- Abode — Right to Rent Compliance Fields
-- Migration 011
--
-- The existing rtr_checklist_mask records WHICH documents were seen
-- but not WHEN the check was performed or via which method.  UK Home
-- Office guidance (Landlord's guide to Right to Rent checks) requires
-- landlords to record:
--   • The date the check was carried out
--   • The method used (manual in-person, video call, or online via IDVT)
--   • The expiry date of any time-limited right-to-rent documents
--     (for follow-up check scheduling)
--
-- These fields are required to demonstrate compliance to a Home Office
-- inspection and to support Awaab's Law follow-up scheduling.
-- ============================================================

ALTER TABLE tenancies
  ADD COLUMN IF NOT EXISTS rtr_check_date    DATE,
  ADD COLUMN IF NOT EXISTS rtr_check_method  TEXT
    CHECK (rtr_check_method IN ('manual_in_person','video_call','online_idvt','not_required','online_gov','physical_document')),
  ADD COLUMN IF NOT EXISTS rtr_expiry_date   DATE;

COMMENT ON COLUMN tenancies.rtr_check_date   IS 'Date the Right to Rent check was performed';
COMMENT ON COLUMN tenancies.rtr_check_method IS 'How the check was done: manual_in_person | video_call | online_idvt | not_required | online_gov | physical_document';
COMMENT ON COLUMN tenancies.rtr_expiry_date  IS 'Expiry of time-limited right-to-rent document — triggers follow-up check reminder';
