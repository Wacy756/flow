-- ============================================================
-- Migration 007: Incident Comments
-- Threaded comments on incidents for landlord/tenant/contractor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.incident_comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID        NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
  author_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  author_role TEXT        NOT NULL CHECK (author_role IN ('landlord', 'tenant', 'contractor')),
  body        TEXT        NOT NULL CHECK (char_length(body) > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast thread fetch
CREATE INDEX IF NOT EXISTS incident_comments_incident_id_idx
  ON public.incident_comments (incident_id, created_at ASC);

-- RLS
ALTER TABLE public.incident_comments ENABLE ROW LEVEL SECURITY;

-- SELECT: landlord who owns the property, tenant who reported, or assigned contractor
CREATE POLICY "Incident participants can read comments"
  ON public.incident_comments
  FOR SELECT
  USING (
    -- Landlord: owns the tenancy linked to the incident
    EXISTS (
      SELECT 1 FROM public.incidents i
      JOIN public.tenancies t ON t.id = i.tenancy_id
      WHERE i.id = incident_comments.incident_id
        AND t.landlord_id = auth.uid()
    )
    OR
    -- Tenant: reported the incident
    EXISTS (
      SELECT 1 FROM public.incidents i
      WHERE i.id = incident_comments.incident_id
        AND i.tenant_id = auth.uid()
    )
    OR
    -- Contractor: assigned to the incident
    EXISTS (
      SELECT 1 FROM public.incidents i
      WHERE i.id = incident_comments.incident_id
        AND i.contractor_id = auth.uid()
    )
  );

-- INSERT: same parties, must set their own author_id
CREATE POLICY "Incident participants can post comments"
  ON public.incident_comments
  FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND (
      EXISTS (
        SELECT 1 FROM public.incidents i
        JOIN public.tenancies t ON t.id = i.tenancy_id
        WHERE i.id = incident_id
          AND t.landlord_id = auth.uid()
      )
      OR
      EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = incident_id
          AND i.tenant_id = auth.uid()
      )
      OR
      EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = incident_id
          AND i.contractor_id = auth.uid()
      )
    )
  );

-- No UPDATE or DELETE — comments are permanent
