-- ============================================================
-- AP: identity = เลขเอกสารตั้งหนี้ (doc_no / RR) แทน "เลขที่บิล" (invoice_no)
-- เพราะเลขที่บิล (เช่น MEMO.2026-07-01) ซ้ำกันได้ คนละ RR = คนละใบ
-- idempotent · run-safe
-- ============================================================

-- 1) คอลัมน์ doc_no (RR/RW/AC = เลขเอกสารตั้งหนี้)
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS doc_no text;

-- 2) backfill จาก remark "Express:xxx" ที่มีอยู่เดิม
UPDATE ap_invoices
   SET doc_no = substring(remark from 'Express:\s*([^\s·|]+)')
 WHERE doc_no IS NULL AND remark ~ 'Express:';

-- 3) เลขที่บิลซ้ำได้ → ถอด unique เดิมบน invoice_no
ALTER TABLE ap_invoices DROP CONSTRAINT IF EXISTS ap_invoices_company_id_invoice_no_key;

-- 4) identity ใหม่ = (company_id, doc_no) · partial (เฉพาะที่มี doc_no)
--    ห่อ EXCEPTION เหมือน unique index อื่นทั้ง repo (กัน migrate แดงถ้ามี doc_no ซ้ำค้างจาก data เก่า)
DO $$ BEGIN
  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_ap_invoices_doc
           ON ap_invoices (company_id, doc_no)
           WHERE doc_no IS NOT NULL AND deleted_at IS NULL';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'uq_ap_invoices_doc skipped: %', SQLERRM; END $$;

NOTIFY pgrst, 'reload schema';
