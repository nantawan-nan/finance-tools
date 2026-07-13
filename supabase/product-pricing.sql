-- ================================================================
-- PRODUCT_PRICES — ราคาขายต่อผลิตภัณฑ์ (แก้ไขได้ในหน้า "ต้นทุนผลิตภัณฑ์")
-- ต้นทุน/รูป มาจากไฟล์ Product Cost (embed ในแอป · window.PRODUCT_COST)
-- ตารางนี้เก็บเฉพาะ "ราคาขาย" ที่ผู้ใช้กรอก → คำนวณกำไร/มาร์จิน
-- 1 แถว = 1 บริษัท × 1 ผลิตภัณฑ์ (product_key = {co}-{n})
-- ================================================================

CREATE TABLE IF NOT EXISTS product_prices (
  company_id   uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  product_key  text        NOT NULL,
  sell_price   numeric,
  note         text,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   uuid        REFERENCES auth.users(id),
  PRIMARY KEY (company_id, product_key)
);

GRANT ALL ON product_prices TO supabase_auth_admin;
GRANT ALL ON product_prices TO authenticated;
GRANT ALL ON product_prices TO service_role;

ALTER TABLE product_prices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_prodprice_read   ON product_prices;
DROP POLICY IF EXISTS p_prodprice_write  ON product_prices;
DROP POLICY IF EXISTS p_prodprice_update ON product_prices;
DROP POLICY IF EXISTS p_prodprice_delete ON product_prices;

CREATE POLICY p_prodprice_read ON product_prices FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));

CREATE POLICY p_prodprice_write ON product_prices FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury','sales_ops')
  );

CREATE POLICY p_prodprice_update ON product_prices FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury','sales_ops')
  )
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury','sales_ops')
  );

CREATE POLICY p_prodprice_delete ON product_prices FOR DELETE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr')
  );

NOTIFY pgrst, 'reload schema';
SELECT 'product_prices table created' AS result;
