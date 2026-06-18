-- ================================================================
-- FIX 2: เพิ่มฟิลด์ planned_payment_date + internal_note บน ap_invoices
-- planned_payment_date = วันที่ จนท.การเงิน ตั้งจะจ่าย (null = ยังไม่กำหนด)
-- internal_note = หมายเหตุเพิ่มที่ จนท. กรอกเอง (ไม่ถูกจำกัดอักษรเหมือน remark)
-- ================================================================

ALTER TABLE ap_invoices
  ADD COLUMN IF NOT EXISTS planned_payment_date date,
  ADD COLUMN IF NOT EXISTS internal_note text;

CREATE INDEX IF NOT EXISTS idx_ap_planned_date
  ON ap_invoices (company_id, planned_payment_date)
  WHERE deleted_at IS NULL AND planned_payment_date IS NOT NULL;

SELECT 'ap_invoices: +planned_payment_date +internal_note' AS status;
