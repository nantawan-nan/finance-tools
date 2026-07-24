-- ================================================================
-- Marketplace withdrawals: ยอดยกมา/ยกไป (carry) + shortfall flag
-- งวดถอนที่คร่อมวัน (TikTok ถอนบางส่วน) — เช็คของออเดอร์ออกงวดที่มันอยู่
-- แต่เงินถอนงวดถัดไป → เก็บเป็น carry_in / carry_out เพื่อให้สมการบาลานซ์:
--   carry_in + Σเช็ครับ − ค่าใช้จ่าย − carry_out = ยอดถอน
-- Idempotent · prefix zz- ให้รันหลังสุด (หลัง bankrec-mp-phase2.sql)
-- ================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'brec_mp_withdrawals') THEN
    ALTER TABLE brec_mp_withdrawals ADD COLUMN IF NOT EXISTS carry_in       numeric(18,2) NOT NULL DEFAULT 0;
    ALTER TABLE brec_mp_withdrawals ADD COLUMN IF NOT EXISTS carry_out      numeric(18,2) NOT NULL DEFAULT 0;
    ALTER TABLE brec_mp_withdrawals ADD COLUMN IF NOT EXISTS carry_shortfall boolean       NOT NULL DEFAULT false;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'zz-bankrec-mp-carry: %', SQLERRM;
END $$;

NOTIFY pgrst, 'reload schema';
