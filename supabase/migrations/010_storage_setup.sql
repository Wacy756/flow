-- ============================================================
-- Migration 010: Supabase Storage — compliance-docs bucket
-- ============================================================
-- The Flutter upload code in compliance_docs_panel.dart is already
-- complete. This migration provisions the storage bucket and the
-- unique constraint required for upsert conflict resolution.
-- ============================================================

-- 1. Create the compliance-docs bucket (private, 10 MB, PDF + images)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'compliance-docs',
  'compliance-docs',
  false,
  10485760,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS — landlords can upload docs for their properties
DROP POLICY IF EXISTS "landlords_upload_compliance_docs" ON storage.objects;
CREATE POLICY "landlords_upload_compliance_docs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'compliance-docs'
    AND auth.uid() IN (
      SELECT landlord_id FROM public.properties
      WHERE id::text = split_part(name, '/', 1)
    )
  );

-- 3. Storage RLS — landlords + tenants can view / download
DROP POLICY IF EXISTS "landlords_tenants_view_compliance_docs" ON storage.objects;
CREATE POLICY "landlords_tenants_view_compliance_docs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'compliance-docs'
    AND (
      auth.uid() IN (
        SELECT landlord_id FROM public.properties
        WHERE id::text = split_part(name, '/', 1)
      )
      OR auth.uid() IN (
        SELECT tenant_id FROM public.tenancies
        WHERE property_id::text = split_part(name, '/', 1)
      )
    )
  );

-- 4. Storage RLS — landlords can delete / replace their docs
DROP POLICY IF EXISTS "landlords_delete_compliance_docs" ON storage.objects;
CREATE POLICY "landlords_delete_compliance_docs"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'compliance-docs'
    AND auth.uid() IN (
      SELECT landlord_id FROM public.properties
      WHERE id::text = split_part(name, '/', 1)
    )
  );

-- 5. Unique index on (tenancy_id, doc_type) — required for the
--    upsert in compliance_docs_panel.dart which uses
--    onConflict: 'tenancy_id, doc_type'. Safe to run even if the
--    table already has distinct rows per (tenancy_id, doc_type).
CREATE UNIQUE INDEX IF NOT EXISTS compliance_docs_tenancy_doc_type_idx
  ON public.compliance_docs (tenancy_id, doc_type);
