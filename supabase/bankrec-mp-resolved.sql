-- ================================================================
-- BANK RECONCILIATION — MP: เพิ่ม "resolved" flag ต่อ order
-- ให้ฝ่ายการเงินติ๊กว่า order ที่ไม่ตรง "แก้ไขแล้ว" → withdrawal กลับมา export ได้
-- Idempotent: ปลอดภัยรันซ้ำได้
-- ================================================================
ALTER TABLE brec_mp_orders ADD COLUMN IF NOT EXISTS resolved     boolean NOT NULL DEFAULT false;
ALTER TABLE brec_mp_orders ADD COLUMN IF NOT EXISTS resolved_at  timestamptz;
ALTER TABLE brec_mp_orders ADD COLUMN IF NOT EXISTS resolved_by  uuid;
ALTER TABLE brec_mp_orders ADD COLUMN IF NOT EXISTS resolved_note text;
