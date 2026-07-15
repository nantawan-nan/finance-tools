-- ============================================================
-- AP Payment Settlement + Transfer Setup (ตั้งโอน) + Vendor Bank Registry
-- นำเข้ารายงานจ่ายชำระหนี้ (PS → RR/RW/AC) → mark AP จ่ายแล้ว + สร้างบิลที่ยังไม่มี
-- ตั้งโอน = จัดกลุ่มตาม PS + ดึงเลขบัญชีผู้รับจากทะเบียน (vendors)
-- idempotent · run-safe (รันซ้ำได้ทุกครั้งตาม migrate workflow)
-- ============================================================

-- 1) ทะเบียนบัญชีผู้รับเงิน — เก็บบน vendors (seed จากไฟล์ "ผู้จำหน่าย")
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS bank_code       text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS bank_name       text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS bank_account_no text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS account_name    text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS account_type    text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS notify_email    text;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS bank_note_raw   text;

-- 2) ใบสำคัญจ่าย (Payment Voucher = PS) — 1 PS จ่ายได้หลาย RR/RW/AC
CREATE TABLE IF NOT EXISTS ap_payment_vouchers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  ps_no           text NOT NULL,
  pay_date        date,
  vendor_id       uuid REFERENCES vendors(id),
  vendor_name     text,
  gross_amount    numeric(18,2) NOT NULL DEFAULT 0,   -- ยอดตามใบรับ (รวมก่อนหักส่วนลด/ภาษี)
  net_amount      numeric(18,2) NOT NULL DEFAULT 0,   -- จ่ายเป็นเงินสด/โอนจริง (ใช้ตั้งโอน)
  discount_amount numeric(18,2) NOT NULL DEFAULT 0,   -- ส่วนลด + ภาษีหัก ณ ที่จ่าย
  bank_label      text,                               -- ป้ายจากรายงาน เช่น SCB-4889
  bank_account_id uuid REFERENCES bank_accounts(id),  -- บัญชีบริษัทที่จ่ายออก
  cheque_no       text,
  cheque_date     date,
  cheque_status   text,                               -- เช็คผ่าน / เช็คจ่าย
  pay_method      text,                               -- cheque / transfer
  note            text,
  import_id       uuid,
  source          text,
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1,
  UNIQUE (company_id, ps_no)
);
CREATE INDEX IF NOT EXISTS idx_ap_vouchers_co_date
  ON ap_payment_vouchers (company_id, pay_date) WHERE deleted_at IS NULL;

-- 3) ผูก ap_payments กับ voucher (PS) + เก็บเลขใบรับ (RR/RW/AC)
ALTER TABLE ap_payments ADD COLUMN IF NOT EXISTS voucher_id uuid REFERENCES ap_payment_vouchers(id);
ALTER TABLE ap_payments ADD COLUMN IF NOT EXISTS receipt_no text;   -- RR/RW/AC (เลขที่ใบรับที่จ่าย)
ALTER TABLE ap_payments ADD COLUMN IF NOT EXISTS cheque_no  text;

-- 4) grants + RLS ปิด (client gate ด้วย fopCanWrite เหมือนโมดูลใหม่ล่าสุด)
ALTER TABLE ap_payment_vouchers DISABLE ROW LEVEL SECURITY;
GRANT ALL ON ap_payment_vouchers TO authenticated;
GRANT ALL ON ap_payment_vouchers TO service_role;

NOTIFY pgrst, 'reload schema';

-- (diagnostic trigger: surface failing migration file in step summary)
-- trigger2
