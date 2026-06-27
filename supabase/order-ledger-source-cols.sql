-- ================================================================
-- ORDER LEDGER — เพิ่ม source_cols (jsonb) เก็บ "คอลัมน์ที่มา" ในไฟล์ source
-- ใช้เพื่อโชว์ "(คอลัม S)" ใต้ค่าแต่ละ row ในตารางเทียบยอด → user ตรวจย้อนในไฟล์ได้
-- รูปแบบ: { "gross":"S", "ship":"T", "disc":"U", "voucher":"V" }  (คอลัมน์ Excel letter จาก headers.indexOf)
-- ★ Idempotent · EXCEPTION-wrapped · NOTIFY pgrst
-- ================================================================
ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS source_cols jsonb;

DO $$
BEGIN
  -- (no extra grants/indexes needed — jsonb column inherits table permissions)
  NULL;
END $$;

NOTIFY pgrst, 'reload schema';
