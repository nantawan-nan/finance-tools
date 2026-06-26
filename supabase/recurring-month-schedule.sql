-- ============================================================
-- Recurring Expenses: month_schedule — กำหนดวันจ่ายแยกต่อเดือนได้
-- ============================================================
-- ปัญหาเดิม: day_of_month คงที่ทั้งปี (ครบกำหนด 25 ทุกเดือน)
-- ปัญหาใหม่: ผู้บริหารอยากให้เลือกเข้ารอบจ่ายของบริษัทแทน (เช่น ศุกร์ที่ 3 ของเดือน)
--
-- Solution: เพิ่ม column month_schedule jsonb
--   - key = "YYYY-MM" หรือ "MM" (per-month-of-year)
--   - value = "YYYY-MM-DD" (วันที่จ่ายจริงสำหรับเดือนนั้น)
--   - ถ้าไม่มี key → fallback ใช้ day_of_month เดิม
--
-- Idempotent + NOTIFY pgrst
-- ============================================================

ALTER TABLE recurring_expenses
  ADD COLUMN IF NOT EXISTS month_schedule jsonb;

COMMENT ON COLUMN recurring_expenses.month_schedule IS
  'Override day_of_month per specific month. JSON: {"YYYY-MM": "YYYY-MM-DD"} หรือ {"MM": day_of_month}. ใช้แทน day_of_month สำหรับเดือนที่มี key';

NOTIFY pgrst, 'reload schema';
