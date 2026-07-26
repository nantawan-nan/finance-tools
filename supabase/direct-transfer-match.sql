-- ================================================================
-- BREC_DIRECT_MATCH — จับคู่ "ออเดอร์โอนตรง (Prepaid)" ↔ เงินเข้าใน STM (บุคคลธรรมดา)
-- 1 แถว = 1 บริษัท · matches jsonb = { order_id: bank_row_id }  (ผู้ใช้เลือกเอง · ห้าม auto)
-- ================================================================
CREATE TABLE IF NOT EXISTS brec_direct_match (
  company_id  uuid        PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  matches     jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);
GRANT ALL ON brec_direct_match TO authenticated;
GRANT ALL ON brec_direct_match TO service_role;
ALTER TABLE brec_direct_match ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_brec_direct_read   ON brec_direct_match;
DROP POLICY IF EXISTS p_brec_direct_write  ON brec_direct_match;
DROP POLICY IF EXISTS p_brec_direct_update ON brec_direct_match;
DROP POLICY IF EXISTS p_brec_direct_delete ON brec_direct_match;
CREATE POLICY p_brec_direct_read ON brec_direct_match FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_brec_direct_write ON brec_direct_match FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_brec_direct_update ON brec_direct_match FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_brec_direct_delete ON brec_direct_match FOR DELETE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
NOTIFY pgrst, 'reload schema';
