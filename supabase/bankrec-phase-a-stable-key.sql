-- ============================================================
-- Bank Reconciliation Phase A — Stable Transaction Key + Unique Constraint
-- ============================================================
-- เป้าหมาย: เลิกใช้ running balance ในการ dedup → เมื่อยกเลิก PS กลางงวด ยอดสะสมของแถวหลังเปลี่ยน
-- แต่รายการจริงไม่ได้เปลี่ยน → ต้องไม่ insert ซ้ำ
--
-- Stable Key:
--   Express: (bank_account_id, txn_date, withdrawal, deposit, doc_no)
--   Bank:    (bank_account_id, txn_date, withdrawal, deposit, cheque_no, ref_note)
--
-- กรณีรายการซ้ำกันจริง (กฎเดียวกันมีหลายแถว) → mark ambiguous=true (ไม่อยู่ในเงื่อนไข unique)
-- ผู้ใช้ตัดสินเอง — ห้ามระบบ merge อัตโนมัติ
--
-- Idempotent: รันซ้ำได้ ทำซ้ำได้ปลอดภัย
-- ============================================================

-- 1) เพิ่ม column ambiguous (กันรายการที่แยกไม่ได้)
ALTER TABLE brec_express_rows ADD COLUMN IF NOT EXISTS ambiguous boolean NOT NULL DEFAULT false;
ALTER TABLE brec_bank_rows    ADD COLUMN IF NOT EXISTS ambiguous boolean NOT NULL DEFAULT false;

-- 2) Cleanup existing duplicates (ก่อนเพิ่ม unique constraint)
--    เก็บแถวที่จับคู่แล้ว (มี match) ไว้ก่อน, ที่เหลือเก็บแถวเก่าสุด, soft-delete ที่เหลือ
DO $$
BEGIN
  -- Express rows
  WITH ranked AS (
    SELECT id,
           bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,'') AS k,
           EXISTS (SELECT 1 FROM brec_matches m WHERE m.express_row_id = e.id AND m.deleted_at IS NULL) AS has_match,
           created_at,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,'')
             ORDER BY EXISTS (SELECT 1 FROM brec_matches m WHERE m.express_row_id = e.id AND m.deleted_at IS NULL) DESC, created_at ASC
           ) AS rn
      FROM brec_express_rows e
     WHERE deleted_at IS NULL
  )
  UPDATE brec_express_rows
     SET deleted_at = now(),
         updated_at = now()
   WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

  -- Bank rows
  WITH ranked AS (
    SELECT id,
           bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,'') AS c, COALESCE(ref_note,'') AS rf,
           EXISTS (SELECT 1 FROM brec_matches m WHERE m.bank_row_id = b.id AND m.deleted_at IS NULL) AS has_match,
           created_at,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,'')
             ORDER BY EXISTS (SELECT 1 FROM brec_matches m WHERE m.bank_row_id = b.id AND m.deleted_at IS NULL) DESC, created_at ASC
           ) AS rn
      FROM brec_bank_rows b
     WHERE deleted_at IS NULL
  )
  UPDATE brec_bank_rows
     SET deleted_at = now(),
         updated_at = now()
   WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'duplicate cleanup skipped: %', SQLERRM;
END $$;

-- 3) Unique partial index — ป้องกัน insert ซ้ำที่ระดับ DB
--    เงื่อนไข: WHERE deleted_at IS NULL AND ambiguous = false
--    → soft-delete แล้ว insert ใหม่ได้ · ambiguous เก็บได้หลายแถว
CREATE UNIQUE INDEX IF NOT EXISTS uniq_brec_ex_stable
  ON brec_express_rows (bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,''))
  WHERE deleted_at IS NULL AND ambiguous = false;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_brec_bk_stable
  ON brec_bank_rows (bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,''))
  WHERE deleted_at IS NULL AND ambiguous = false;

-- 4) Optional: index สำหรับ query ambiguous เร็ว
CREATE INDEX IF NOT EXISTS idx_brec_ex_ambig
  ON brec_express_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL AND ambiguous = true;
CREATE INDEX IF NOT EXISTS idx_brec_bk_ambig
  ON brec_bank_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL AND ambiguous = true;

-- 5) NOTIFY PostgREST — reload schema (กัน PGRST204 หลัง DDL)
NOTIFY pgrst, 'reload schema';
