-- ============================================================
-- Document Center (docs) — เก็บเอกสาร PDF (STM / เมมโม่ / อนุมัติจ่าย ฯลฯ)
-- ไฟล์จริงเก็บใน Supabase Storage bucket 'documents' · meta เก็บในตาราง documents
-- idempotent · RLS ปิดบนตาราง (app scope ด้วย company_id) · storage มี policy ให้ authenticated
-- ============================================================

-- ---- ตาราง meta ----
CREATE TABLE IF NOT EXISTS public.documents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    uuid,
  title         text,
  category      text,
  file_name     text,
  storage_path  text,
  mime_type     text,
  size_bytes    bigint,
  doc_date      date,
  note          text,
  uploaded_by   text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    text,
  deleted_at    timestamptz,
  deleted_by    text
);

ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS company_id   uuid;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS title        text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS category     text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS file_name    text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS storage_path text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS mime_type    text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS size_bytes   bigint;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS doc_date     date;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS note         text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS uploaded_by  text;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS deleted_at   timestamptz;
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS deleted_by   text;

CREATE INDEX IF NOT EXISTS idx_documents_company  ON public.documents (company_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents (company_id, category)        WHERE deleted_at IS NULL;

ALTER TABLE public.documents DISABLE ROW LEVEL SECURITY;

-- ---- Storage bucket (private) ----
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('documents', 'documents', false, 52428800)
ON CONFLICT (id) DO UPDATE SET file_size_limit = EXCLUDED.file_size_limit;

-- ---- Storage policies: ให้ผู้ใช้ที่ login แล้ว (authenticated) อ่าน/อัป/ลบ ในบัคเก็ต documents ----
DROP POLICY IF EXISTS p_docs_read   ON storage.objects;
CREATE POLICY p_docs_read   ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'documents');

DROP POLICY IF EXISTS p_docs_insert ON storage.objects;
CREATE POLICY p_docs_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'documents');

DROP POLICY IF EXISTS p_docs_update ON storage.objects;
CREATE POLICY p_docs_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'documents') WITH CHECK (bucket_id = 'documents');

DROP POLICY IF EXISTS p_docs_delete ON storage.objects;
CREATE POLICY p_docs_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'documents');

NOTIFY pgrst, 'reload schema';
