-- ================================================================
-- FIX: ลบ check constraint bal_no_future
-- เหตุผล: ไฟล์ Excel มีวันที่อนาคต (เช่น 2026-09-10) ตอน import
-- ผู้ใช้รู้ดีกว่าระบบว่ายอดของวันไหน — ไม่ควรบล็อก
-- ================================================================

ALTER TABLE bank_balances DROP CONSTRAINT IF EXISTS bal_no_future;

SELECT 'bal_no_future constraint removed' AS status;
