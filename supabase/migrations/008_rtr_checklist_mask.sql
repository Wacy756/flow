-- Stores the Right to Rent checklist completion state as a bitmask.
-- Bit 0 = item 0, bit 1 = item 1, ..., bit 6 = item 6.
-- All 7 bits set (127) = fully completed.
ALTER TABLE tenancies
  ADD COLUMN IF NOT EXISTS rtr_checklist_mask INTEGER NOT NULL DEFAULT 0;
