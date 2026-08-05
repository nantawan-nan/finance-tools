-- ================================================================
-- CATBOT_SESSION — เก็บงาน "จัดหมวด (AI)" ที่ยังไม่ได้ยืนยัน (กัน refresh แล้วหาย)
-- 1 แถว = 1 บริษัท · accounts jsonb = ผลอ่านไฟล์ + หมวดที่ผู้ใช้เลือกไว้
-- ยืนยัน & เรียนรู้ สำเร็จ / กดล้าง → ลบแถวนี้ทิ้ง
-- ================================================================
CREATE TABLE IF NOT EXISTS catbot_session (
  company_id  uuid        PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  accounts    jsonb,
  file_names  jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);

GRANT ALL ON catbot_session TO authenticated;
GRANT ALL ON catbot_session TO service_role;

ALTER TABLE catbot_session ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_catbot_session_read   ON catbot_session;
DROP POLICY IF EXISTS p_catbot_session_write  ON catbot_session;
DROP POLICY IF EXISTS p_catbot_session_update ON catbot_session;
DROP POLICY IF EXISTS p_catbot_session_delete ON catbot_session;

CREATE POLICY p_catbot_session_read ON catbot_session FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_catbot_session_write ON catbot_session FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_catbot_session_update ON catbot_session FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
  WITH CHECK (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_catbot_session_delete ON catbot_session FOR DELETE TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));

NOTIFY pgrst, 'reload schema';
