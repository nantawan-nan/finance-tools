-- ----------------------------------------------------------------
-- order_ledger: เพิ่ม seller_voucher (Voucher ของร้านค้า = ส่วนลดผู้ขาย) + gross_total (ราคาสินค้าเดิม)
-- ★ ต้นเหตุ TikTok recon +100: parser อ่าน "Voucher ของร้านค้า" แล้ว แต่ insert ไม่ได้เซฟ
--   + order_ledger ไม่มีคอลัมน์ -> recon เห็น seller_voucher=0 -> ไม่หักส่วนลดผู้ขาย TikTok
-- (ตั้งชื่อ orders_voucher_gross ให้ sort หลัง orders.sql + orders_pipeline.sql)
-- ----------------------------------------------------------------
DO $$ BEGIN
  BEGIN EXECUTE 'ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS seller_voucher numeric(18,2)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS gross_total    numeric(18,2)'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ★ บังคับ PostgREST reload schema cache (กัน 400 "column not in schema cache" หลัง DDL)
NOTIFY pgrst, 'reload schema';
