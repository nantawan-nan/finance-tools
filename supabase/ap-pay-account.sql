-- ================================================================
-- AP Outstanding + Recurring — "ตัดจากบัญชีไหน" (pay-from account)
-- เพิ่มช่องบัญชีที่จะตัดเงินจ่าย (จนท. เลือกได้) — default ฝั่ง client = บัญชีลงท้าย 4889
-- idempotent — run ซ้ำได้
-- ================================================================

-- AP invoice: บัญชีที่ "ตั้งใจจะตัดจ่าย" (ต่างจาก ap_payments.bank_account_id ที่เป็นบัญชีที่จ่ายจริง)
ALTER TABLE ap_invoices
  ADD COLUMN IF NOT EXISTS pay_from_account_id uuid REFERENCES bank_accounts(id);

-- recurring: บัญชีที่ตัดจ่ายประจำ (base schema มีอยู่แล้ว — กัน clone DB เก่าที่ยังไม่มี)
ALTER TABLE recurring_expenses
  ADD COLUMN IF NOT EXISTS bank_account_id uuid REFERENCES bank_accounts(id);

-- กัน PGRST204 (column not in schema cache) หลัง DDL
NOTIFY pgrst, 'reload schema';
