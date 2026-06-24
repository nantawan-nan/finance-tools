-- ============================================================
-- HOTFIX — Restore bank/express rows ที่ถูก Phase A cleanup ลบ
-- ทั้งที่ยังมี match ชี้อยู่ (orphaned match)
-- ============================================================
-- ตัวอย่างเคสที่เจอ:
-- - Bank row A (เก่า, 20 มิ.ย.) + Bank row B (ใหม่, 22 มิ.ย.) มี stable key เดียวกัน
-- - User จับคู่ Match → ชี้ไป B (อัป statement ใหม่กว่า)
-- - Phase A cleanup เลือกเก็บ A (created_at ASC) ลบ B → Match กำพร้า
--
-- Strategy: restore ทุกแถวที่ถูก soft-delete หลัง 24 มิ.ย. 2026 ที่มี match ชี้
-- + ตั้ง ambiguous=true (bypass unique partial index) ให้ผู้ใช้ review เอง
-- ============================================================

DO $$
DECLARE
  ex_restored int;
  bk_restored int;
BEGIN
  -- Bank rows
  WITH targets AS (
    SELECT DISTINCT b.id
      FROM brec_bank_rows b
      JOIN brec_matches m ON m.bank_row_id = b.id AND m.deleted_at IS NULL
     WHERE b.deleted_at IS NOT NULL
  )
  UPDATE brec_bank_rows
     SET deleted_at = NULL,
         ambiguous = TRUE,    -- bypass unique partial index
         updated_at = now()
   WHERE id IN (SELECT id FROM targets);
  GET DIAGNOSTICS bk_restored = ROW_COUNT;

  -- Express rows
  WITH targets AS (
    SELECT DISTINCT e.id
      FROM brec_express_rows e
      JOIN brec_matches m ON m.express_row_id = e.id AND m.deleted_at IS NULL
     WHERE e.deleted_at IS NOT NULL
  )
  UPDATE brec_express_rows
     SET deleted_at = NULL,
         ambiguous = TRUE,
         updated_at = now()
   WHERE id IN (SELECT id FROM targets);
  GET DIAGNOSTICS ex_restored = ROW_COUNT;

  RAISE NOTICE 'Restored: bank_rows=%, express_rows=%', bk_restored, ex_restored;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'restore failed: %', SQLERRM;
END $$;

-- หมายเหตุ: row ที่ถูก restore ตั้ง ambiguous=true → ไม่อยู่ในเงื่อนไข unique
-- ดังนั้นจะมี dup กับแถว original ที่ Phase A เก็บไว้
-- ผู้ใช้ต้อง resolve ใน Phase C UI (ที่จะทำต่อไป) — ตอนนี้ match จะกลับมาแสดงครบ

NOTIFY pgrst, 'reload schema';
