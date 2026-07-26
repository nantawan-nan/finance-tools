-- ================================================================
-- BREC_COD_DATA — เก็บข้อมูล COD ขนส่ง (iShip) บน server (กัน refresh แล้วหาย)
-- 1 แถว = 1 บริษัท · เก็บ parcels + transfers (raw parsed) เป็น JSONB
-- โหลดมา regroup + re-link (เบอร์/ยอด) ใหม่ตอนโหลด → link อัปเดตตาม order_ledger ล่าสุด
-- ================================================================
CREATE TABLE IF NOT EXISTS brec_cod_data (
  company_id  uuid        PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  parcels     jsonb,
  transfers   jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);

ALTER TABLE brec_cod_data ADD COLUMN IF NOT EXISTS manual jsonb;   -- ★ ผู้ใช้เลือกออเดอร์เอง (key=เลขพัสดุ → order_id)

GRANT ALL ON brec_cod_data TO authenticated;
GRANT ALL ON brec_cod_data TO service_role;

ALTER TABLE brec_cod_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_brec_cod_data_read   ON brec_cod_data;
DROP POLICY IF EXISTS p_brec_cod_data_write  ON brec_cod_data;
DROP POLICY IF EXISTS p_brec_cod_data_update ON brec_cod_data;
DROP POLICY IF EXISTS p_brec_cod_data_delete ON brec_cod_data;

CREATE POLICY p_brec_cod_data_read ON brec_cod_data FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_brec_cod_data_write ON brec_cod_data FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_brec_cod_data_update ON brec_cod_data FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
  WITH CHECK (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_brec_cod_data_delete ON brec_cod_data FOR DELETE TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));

NOTIFY pgrst, 'reload schema';
