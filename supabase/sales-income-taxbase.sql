-- เพิ่มคอลัมน์ "ฐานภาษี" + "ค่าส่งผู้ซื้อจ่าย" ให้ sales_income_rows
-- GROSS ใหม่ = ฐานภาษี (ราคาสินค้าหลังหักส่วนลดผู้ขาย + ค่าส่งผู้ซื้อจ่าย) → ตรงมูลค่าที่จะคีย์ IV
-- รายจ่าย (fee_total) = tax_base - net_received (reconcile ได้: ฐานภาษี − รายจ่าย = สุทธิ)
DO $$
BEGIN
  BEGIN ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS tax_base numeric; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS buyer_shipping numeric; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
