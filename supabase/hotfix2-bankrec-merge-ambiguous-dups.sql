-- ============================================================
-- HOTFIX 2 — Merge ambiguous duplicates ที่ stable key เดียวกัน
-- ============================================================
-- หลัง hotfix แรก: restore deleted rows ที่มี match → ตั้ง ambiguous=true
-- แต่ data ยังมี duplicate (active row ambig=false + restored row ambig=true ที่ key เดียวกัน)
-- → ทำให้แท็บ "ทั้งหมด" แสดง row ซ้ำ
--
-- Strategy:
-- 1. หา dup pair: ambig=true + ambig=false (winner) ที่ stable key + bank_account_id ตรงกัน
-- 2. migrate match references ของ ambig=true → winner
-- 3. soft-delete ambig=true rows ที่ตอนนี้ไม่มี match ชี้แล้ว
--
-- Note: no DO block / no EXCEPTION — error จะโผล่ชัด ถ้า migration พังจริง
-- (DO block + EXCEPTION WHEN OTHERS เคย swallow error ก่อนหน้านี้)
-- ============================================================

-- ===== Express: migrate matches =====
UPDATE brec_matches m
   SET express_row_id = w.id, updated_at = now()
  FROM brec_express_rows a
  JOIN brec_express_rows w
    ON w.company_id      = a.company_id
   AND w.bank_account_id = a.bank_account_id
   AND w.txn_date        = a.txn_date
   AND w.withdrawal      = a.withdrawal
   AND w.deposit         = a.deposit
   AND COALESCE(w.doc_no,'') = COALESCE(a.doc_no,'')
   AND w.id              <> a.id
   AND w.deleted_at IS NULL
   AND w.ambiguous = FALSE
 WHERE m.express_row_id = a.id
   AND m.deleted_at IS NULL
   AND a.deleted_at IS NULL
   AND a.ambiguous = TRUE;

-- ===== Express: soft-delete ambig rows ที่ migrate match ออกหมดแล้ว =====
UPDATE brec_express_rows e
   SET deleted_at = now(), updated_at = now()
 WHERE e.ambiguous = TRUE
   AND e.deleted_at IS NULL
   AND EXISTS (
     SELECT 1 FROM brec_express_rows w
      WHERE w.company_id      = e.company_id
        AND w.bank_account_id = e.bank_account_id
        AND w.txn_date        = e.txn_date
        AND w.withdrawal      = e.withdrawal
        AND w.deposit         = e.deposit
        AND COALESCE(w.doc_no,'') = COALESCE(e.doc_no,'')
        AND w.id              <> e.id
        AND w.deleted_at IS NULL
        AND w.ambiguous = FALSE
   )
   AND NOT EXISTS (
     SELECT 1 FROM brec_matches m
      WHERE m.express_row_id = e.id
        AND m.deleted_at IS NULL
   );

-- ===== Bank: migrate matches =====
UPDATE brec_matches m
   SET bank_row_id = w.id, updated_at = now()
  FROM brec_bank_rows a
  JOIN brec_bank_rows w
    ON w.company_id      = a.company_id
   AND w.bank_account_id = a.bank_account_id
   AND w.txn_date        = a.txn_date
   AND w.withdrawal      = a.withdrawal
   AND w.deposit         = a.deposit
   AND COALESCE(w.cheque_no,'') = COALESCE(a.cheque_no,'')
   AND COALESCE(w.ref_note,'')  = COALESCE(a.ref_note,'')
   AND w.id              <> a.id
   AND w.deleted_at IS NULL
   AND w.ambiguous = FALSE
 WHERE m.bank_row_id = a.id
   AND m.deleted_at IS NULL
   AND a.deleted_at IS NULL
   AND a.ambiguous = TRUE;

-- ===== Bank: soft-delete ambig rows ที่ migrate match ออกหมดแล้ว =====
UPDATE brec_bank_rows b
   SET deleted_at = now(), updated_at = now()
 WHERE b.ambiguous = TRUE
   AND b.deleted_at IS NULL
   AND EXISTS (
     SELECT 1 FROM brec_bank_rows w
      WHERE w.company_id      = b.company_id
        AND w.bank_account_id = b.bank_account_id
        AND w.txn_date        = b.txn_date
        AND w.withdrawal      = b.withdrawal
        AND w.deposit         = b.deposit
        AND COALESCE(w.cheque_no,'') = COALESCE(b.cheque_no,'')
        AND COALESCE(w.ref_note,'')  = COALESCE(b.ref_note,'')
        AND w.id              <> b.id
        AND w.deleted_at IS NULL
        AND w.ambiguous = FALSE
   )
   AND NOT EXISTS (
     SELECT 1 FROM brec_matches m
      WHERE m.bank_row_id = b.id
        AND m.deleted_at IS NULL
   );

NOTIFY pgrst, 'reload schema';
