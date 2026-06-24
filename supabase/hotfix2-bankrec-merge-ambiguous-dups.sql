-- ============================================================
-- HOTFIX 2 — Merge ambiguous duplicates ที่ stable key เดียวกัน
-- ============================================================
-- หลัง hotfix แรก: restore deleted rows ที่มี match → ตั้ง ambiguous=true
-- แต่ data ยังมี duplicate (active row ambig=false + restored row ambig=true ที่ key เดียวกัน)
-- → ทำให้แท็บ "ทั้งหมด" แสดง row ซ้ำ
--
-- Fix:
-- 1. หา dup pair: ambig=true + ambig=false ที่ stable key + bank_account_id ตรงกัน
-- 2. winner = ambig=false (อันที่ Phase A เก็บไว้ — active, ไม่ต้อง resolve)
-- 3. migrate match references ของ ambig=true → winner
-- 4. soft-delete + ambiguous=false ของ row ที่ ambig=true (เพราะมี dup ไป winner แล้ว)
--
-- หลัง fix: 33 matches ชี้ rows ที่ unique จริง · ไม่มี dup ใน view
-- ============================================================

DO $$
DECLARE
  ex_merged int := 0;
  bk_merged int := 0;
  ex_deleted int := 0;
  bk_deleted int := 0;
BEGIN
  -- ===== Express =====
  -- ของแต่ละ ambig row, หา winner (non-ambig + same stable key + active)
  WITH dup_pairs AS (
    SELECT a.id AS ambig_id, w.id AS winner_id
      FROM brec_express_rows a
      JOIN brec_express_rows w
        ON w.company_id      = a.company_id
       AND w.bank_account_id = a.bank_account_id
       AND w.txn_date        = a.txn_date
       AND w.withdrawal      = a.withdrawal
       AND w.deposit         = a.deposit
       AND COALESCE(w.doc_no,'') = COALESCE(a.doc_no,'')
       AND w.id <> a.id
       AND w.deleted_at IS NULL
       AND w.ambiguous = FALSE
     WHERE a.deleted_at IS NULL
       AND a.ambiguous = TRUE
  )
  UPDATE brec_matches m
     SET express_row_id = dp.winner_id, updated_at = now()
    FROM dup_pairs dp
   WHERE m.express_row_id = dp.ambig_id AND m.deleted_at IS NULL;
  GET DIAGNOSTICS ex_merged = ROW_COUNT;

  -- soft-delete ambig rows ที่ตอนนี้มี winner แล้ว (match migrate ไปหมดแล้ว)
  WITH dup_pairs AS (
    SELECT a.id AS ambig_id
      FROM brec_express_rows a
      JOIN brec_express_rows w
        ON w.company_id      = a.company_id
       AND w.bank_account_id = a.bank_account_id
       AND w.txn_date        = a.txn_date
       AND w.withdrawal      = a.withdrawal
       AND w.deposit         = a.deposit
       AND COALESCE(w.doc_no,'') = COALESCE(a.doc_no,'')
       AND w.id <> a.id
       AND w.deleted_at IS NULL
       AND w.ambiguous = FALSE
     WHERE a.deleted_at IS NULL
       AND a.ambiguous = TRUE
  )
  UPDATE brec_express_rows
     SET deleted_at = now(), updated_at = now()
   WHERE id IN (SELECT ambig_id FROM dup_pairs)
     AND NOT EXISTS (SELECT 1 FROM brec_matches m WHERE m.express_row_id = brec_express_rows.id AND m.deleted_at IS NULL);
  GET DIAGNOSTICS ex_deleted = ROW_COUNT;

  -- ===== Bank =====
  WITH dup_pairs AS (
    SELECT a.id AS ambig_id, w.id AS winner_id
      FROM brec_bank_rows a
      JOIN brec_bank_rows w
        ON w.company_id      = a.company_id
       AND w.bank_account_id = a.bank_account_id
       AND w.txn_date        = a.txn_date
       AND w.withdrawal      = a.withdrawal
       AND w.deposit         = a.deposit
       AND COALESCE(w.cheque_no,'') = COALESCE(a.cheque_no,'')
       AND COALESCE(w.ref_note,'') = COALESCE(a.ref_note,'')
       AND w.id <> a.id
       AND w.deleted_at IS NULL
       AND w.ambiguous = FALSE
     WHERE a.deleted_at IS NULL
       AND a.ambiguous = TRUE
  )
  UPDATE brec_matches m
     SET bank_row_id = dp.winner_id, updated_at = now()
    FROM dup_pairs dp
   WHERE m.bank_row_id = dp.ambig_id AND m.deleted_at IS NULL;
  GET DIAGNOSTICS bk_merged = ROW_COUNT;

  WITH dup_pairs AS (
    SELECT a.id AS ambig_id
      FROM brec_bank_rows a
      JOIN brec_bank_rows w
        ON w.company_id      = a.company_id
       AND w.bank_account_id = a.bank_account_id
       AND w.txn_date        = a.txn_date
       AND w.withdrawal      = a.withdrawal
       AND w.deposit         = a.deposit
       AND COALESCE(w.cheque_no,'') = COALESCE(a.cheque_no,'')
       AND COALESCE(w.ref_note,'') = COALESCE(a.ref_note,'')
       AND w.id <> a.id
       AND w.deleted_at IS NULL
       AND w.ambiguous = FALSE
     WHERE a.deleted_at IS NULL
       AND a.ambiguous = TRUE
  )
  UPDATE brec_bank_rows
     SET deleted_at = now(), updated_at = now()
   WHERE id IN (SELECT ambig_id FROM dup_pairs)
     AND NOT EXISTS (SELECT 1 FROM brec_matches m WHERE m.bank_row_id = brec_bank_rows.id AND m.deleted_at IS NULL);
  GET DIAGNOSTICS bk_deleted = ROW_COUNT;

  RAISE NOTICE 'merged: ex_matches=%, bk_matches=%; soft-deleted: ex_rows=%, bk_rows=%',
               ex_merged, bk_merged, ex_deleted, bk_deleted;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'merge ambiguous skipped: %', SQLERRM;
END $$;

NOTIFY pgrst, 'reload schema';
