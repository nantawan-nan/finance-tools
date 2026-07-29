-- ================================================================
-- re_export_config — ตั้งค่า "เลือก Bank {Down N}" ต่อบริษัท สำหรับ RE โอนตรง/COD
--   (แต่ละบริษัทโอนตรง/COD เข้าคนละบัญชี · ตำแหน่งใน dropdown ของ Express ต่างกัน)
--   เดิม hardcode เฉพาะ M Bark (โอนตรง={Down 2} · FACE COD={Down 10}) → ทำเป็นช่องกรอกในแอป
-- ================================================================
CREATE TABLE IF NOT EXISTS re_export_config (
  company_id  uuid PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  direct_down int,      -- {Down N} สำหรับ RE โอนตรง (Prepaid · เงินเข้าแบงค์ตรง)
  cod_down    int,      -- {Down N} สำหรับ RE COD (FACE/LINE/Dealer เก็บเงินปลายทาง)
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);
GRANT ALL ON re_export_config TO authenticated;
GRANT ALL ON re_export_config TO service_role;

ALTER TABLE re_export_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_re_cfg_read   ON re_export_config;
DROP POLICY IF EXISTS p_re_cfg_write  ON re_export_config;
DROP POLICY IF EXISTS p_re_cfg_update ON re_export_config;
CREATE POLICY p_re_cfg_read ON re_export_config FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_re_cfg_write ON re_export_config FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant'));
CREATE POLICY p_re_cfg_update ON re_export_config FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant'))
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant'));

NOTIFY pgrst, 'reload schema';
