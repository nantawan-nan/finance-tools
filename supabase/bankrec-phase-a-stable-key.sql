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
--    Order:
--      a) ก่อนลบ → MIGRATE match references จาก row ที่จะลบ ไป "winner" (rn=1) ที่จะเก็บ
--         (กัน orphaned match ตอน user อัปไฟล์ซ้ำแล้ว match ดันชี้ไป row ใหม่ที่ Phase A เลือกลบ)
--      b) winner = matched ก่อน, ถ้าหลายตัวมี match → ตัวที่มี match มากสุด, แล้วเก่าสุด
--      c) Soft-delete row ที่ rn > 1
DO $$
BEGIN
  -- ===== Express rows =====
  -- a) migrate matches: ถ้า row จะถูกลบ (rn>1) มี match ชี้, redirect ไป winner ที่ stable key เดียว
  WITH ranked AS (
    SELECT id, bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,'') AS k,
           (SELECT COUNT(*) FROM brec_matches m WHERE m.express_row_id = e.id AND m.deleted_at IS NULL) AS n_match,
           created_at,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,'')
             ORDER BY (SELECT COUNT(*) FROM brec_matches m2 WHERE m2.express_row_id = e.id AND m2.deleted_at IS NULL) DESC,
                      created_at ASC
           ) AS rn
      FROM brec_express_rows e
     WHERE deleted_at IS NULL AND ambiguous = false   -- ★ อย่าแตะแถว ambiguous (รายการซ้ำจริงที่ user ต้องเก็บทั้งคู่)
  ),
  winners AS (
    SELECT bank_account_id, txn_date, withdrawal, deposit, k, id AS winner_id FROM ranked WHERE rn = 1
  ),
  losers AS (
    SELECT r.id AS loser_id, w.winner_id
      FROM ranked r
      JOIN winners w USING (bank_account_id, txn_date, withdrawal, deposit, k)
     WHERE r.rn > 1
  )
  UPDATE brec_matches m
     SET express_row_id = l.winner_id, updated_at = now()
    FROM losers l
   WHERE m.express_row_id = l.loser_id AND m.deleted_at IS NULL AND l.winner_id IS NOT NULL;

  -- b) soft-delete the losers
  WITH ranked AS (
    SELECT id,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,'')
             ORDER BY (SELECT COUNT(*) FROM brec_matches m WHERE m.express_row_id = e.id AND m.deleted_at IS NULL) DESC,
                      created_at ASC
           ) AS rn
      FROM brec_express_rows e
     WHERE deleted_at IS NULL AND ambiguous = false   -- ★ อย่าแตะแถว ambiguous (รายการซ้ำจริงที่ user ต้องเก็บทั้งคู่)
  )
  UPDATE brec_express_rows
     SET deleted_at = now(), updated_at = now()
   WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

  -- ===== Bank rows =====
  WITH ranked AS (
    SELECT id, bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,'') AS c, COALESCE(ref_note,'') AS rf,
           created_at,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,'')
             ORDER BY (SELECT COUNT(*) FROM brec_matches m WHERE m.bank_row_id = b.id AND m.deleted_at IS NULL) DESC,
                      created_at ASC
           ) AS rn
      FROM brec_bank_rows b
     WHERE deleted_at IS NULL AND ambiguous = false   -- ★ อย่าแตะแถว ambiguous (รายการซ้ำจริงที่ user ต้องเก็บทั้งคู่)
  ),
  winners AS (
    SELECT bank_account_id, txn_date, withdrawal, deposit, c, rf, id AS winner_id FROM ranked WHERE rn = 1
  ),
  losers AS (
    SELECT r.id AS loser_id, w.winner_id
      FROM ranked r
      JOIN winners w USING (bank_account_id, txn_date, withdrawal, deposit, c, rf)
     WHERE r.rn > 1
  )
  UPDATE brec_matches m
     SET bank_row_id = l.winner_id, updated_at = now()
    FROM losers l
   WHERE m.bank_row_id = l.loser_id AND m.deleted_at IS NULL AND l.winner_id IS NOT NULL;

  WITH ranked AS (
    SELECT id,
           row_number() OVER (
             PARTITION BY bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,'')
             ORDER BY (SELECT COUNT(*) FROM brec_matches m WHERE m.bank_row_id = b.id AND m.deleted_at IS NULL) DESC,
                      created_at ASC
           ) AS rn
      FROM brec_bank_rows b
     WHERE deleted_at IS NULL AND ambiguous = false   -- ★ อย่าแตะแถว ambiguous (รายการซ้ำจริงที่ user ต้องเก็บทั้งคู่)
  )
  UPDATE brec_bank_rows
     SET deleted_at = now(), updated_at = now()
   WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'duplicate cleanup skipped: %', SQLERRM;
END $$;

-- 2b) Safety net: ถ้า cleanup ข้างบน abort กลางคัน (เช่น redirect match ชน unique(brec_matches))
--     → ยังเหลือแถว stable-key ซ้ำ ที่ทำให้ CREATE UNIQUE INDEX ข้างล่าง fail ทุก run
--     mark แถวซ้ำที่เหลือเป็น ambiguous=true (partial index มี WHERE ambiguous=false → สร้างได้)
--     ★ ตรงกับ design ของไฟล์นี้ (รายการซ้ำจริง = ambiguous ให้ user ตัดสินเอง) · ไม่ลบข้อมูล
UPDATE brec_express_rows e SET ambiguous = true, updated_at = now()
 WHERE deleted_at IS NULL AND ambiguous = false
   AND EXISTS (
     SELECT 1 FROM brec_express_rows e2
      WHERE e2.deleted_at IS NULL AND e2.ambiguous = false AND e2.id <> e.id
        AND e2.bank_account_id = e.bank_account_id
        AND e2.txn_date = e.txn_date
        AND e2.withdrawal = e.withdrawal
        AND e2.deposit = e.deposit
        AND COALESCE(e2.doc_no,'') = COALESCE(e.doc_no,'')
   );
UPDATE brec_bank_rows b SET ambiguous = true, updated_at = now()
 WHERE deleted_at IS NULL AND ambiguous = false
   AND EXISTS (
     SELECT 1 FROM brec_bank_rows b2
      WHERE b2.deleted_at IS NULL AND b2.ambiguous = false AND b2.id <> b.id
        AND b2.bank_account_id = b.bank_account_id
        AND b2.txn_date = b.txn_date
        AND b2.withdrawal = b.withdrawal
        AND b2.deposit = b.deposit
        AND COALESCE(b2.cheque_no,'') = COALESCE(b.cheque_no,'')
        AND COALESCE(b2.ref_note,'') = COALESCE(b.ref_note,'')
   );

-- 3) Unique partial index — ป้องกัน insert ซ้ำที่ระดับ DB
--    เงื่อนไข: WHERE deleted_at IS NULL AND ambiguous = false
--    → soft-delete แล้ว insert ใหม่ได้ · ambiguous เก็บได้หลายแถว
--    ★ ห่อ EXCEPTION เหมือน unique index อื่นทั้ง repo — กัน migrate ทั้ง run แดงถ้ายังเหลือ dup edge
DO $$ BEGIN
  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uniq_brec_ex_stable
    ON brec_express_rows (bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,''''))
    WHERE deleted_at IS NULL AND ambiguous = false';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'uniq_brec_ex_stable skipped: %', SQLERRM; END $$;

DO $$ BEGIN
  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uniq_brec_bk_stable
    ON brec_bank_rows (bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''''), COALESCE(ref_note,''''))
    WHERE deleted_at IS NULL AND ambiguous = false';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'uniq_brec_bk_stable skipped: %', SQLERRM; END $$;

-- 4) Optional: index สำหรับ query ambiguous เร็ว
CREATE INDEX IF NOT EXISTS idx_brec_ex_ambig
  ON brec_express_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL AND ambiguous = true;
CREATE INDEX IF NOT EXISTS idx_brec_bk_ambig
  ON brec_bank_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL AND ambiguous = true;

-- 5) NOTIFY PostgREST — reload schema (กัน PGRST204 หลัง DDL)
NOTIFY pgrst, 'reload schema';
