-- Agency-landlord managed relationships
-- An agent (agency) can manage multiple landlord accounts
CREATE TABLE IF NOT EXISTS agency_landlords (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  landlord_id   uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','active','revoked')),
  invited_email text,
  invited_at    timestamptz DEFAULT now(),
  accepted_at   timestamptz,
  created_at    timestamptz DEFAULT now(),
  UNIQUE (agency_id, landlord_id)
);

-- RLS
ALTER TABLE agency_landlords ENABLE ROW LEVEL SECURITY;

-- Agents see their own managed landlords
CREATE POLICY "agency_landlords_agent_select" ON agency_landlords
  FOR SELECT USING (agency_id = auth.uid());

-- Landlords see invitations directed at them
CREATE POLICY "agency_landlords_landlord_select" ON agency_landlords
  FOR SELECT USING (landlord_id = auth.uid());

-- Agents can invite landlords
CREATE POLICY "agency_landlords_insert" ON agency_landlords
  FOR INSERT WITH CHECK (
    agency_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'agent')
  );

-- Agents can update (revoke); landlords can accept
CREATE POLICY "agency_landlords_update" ON agency_landlords
  FOR UPDATE USING (agency_id = auth.uid() OR landlord_id = auth.uid());

-- FCM tokens table for push notifications
CREATE TABLE IF NOT EXISTS push_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token      text NOT NULL,
  platform   text NOT NULL CHECK (platform IN ('ios','android')),
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_tokens_own" ON push_tokens
  FOR ALL USING (user_id = auth.uid());
