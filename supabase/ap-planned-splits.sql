-- idempotent: เพิ่มคอลัมน์ planned_splits (jsonb) สำหรับ แบ่งจ่ายหลายงวด
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS planned_splits jsonb DEFAULT NULL;
NOTIFY pgrst, 'reload schema';
