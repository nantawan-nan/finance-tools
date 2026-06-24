-- ============================================================
-- Bank Reconciliation Phase B — Import Batch + History
-- ============================================================
-- เป้าหมาย:
-- 1. ตั้ง batch_no ที่อ่านง่าย (IMP-{SRC}-YYYYMMDD-NNN) — track ได้ในอนาคต
-- 2. เก็บสถิติ rows_added/rows_dup/rows_ambiguous/rows_failed/uploader_email — สำหรับ history page
-- 3. เพิ่ม row_summary jsonb — เก็บ detail เพิ่มเช่น period/file_size/bank_code
--
-- Idempotent · ไม่กระทบ schema เดิม (column ใหม่ optional ทั้งหมด)
-- ============================================================

ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS batch_no       text;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS rows_added     int  NOT NULL DEFAULT 0;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS rows_dup       int  NOT NULL DEFAULT 0;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS rows_ambiguous int  NOT NULL DEFAULT 0;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS rows_failed    int  NOT NULL DEFAULT 0;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS uploader_email text;
ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS summary_json   jsonb;

-- batch_no unique per company (ถ้ามีค่า)
CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_imports_batch_no
  ON brec_imports (company_id, batch_no)
  WHERE batch_no IS NOT NULL AND deleted_at IS NULL;

-- index สำหรับ listing history เร็ว
CREATE INDEX IF NOT EXISTS idx_brec_imports_created
  ON brec_imports (company_id, created_at DESC)
  WHERE deleted_at IS NULL;

NOTIFY pgrst, 'reload schema';
