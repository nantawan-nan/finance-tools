-- ================================================================
-- upload_tasks — งานอัปโหลดที่ "แอดมินมอบหมาย" ต่อบริษัท × แหล่ง
--   admin ตั้ง: ความถี่ (day/week/month) · วัน (weekday สำหรับ week · monthday สำหรับ month) · มอบหมายให้ใคร
--   user ที่ถูกมอบหมาย: เห็นเตือนที่หน้าหลัก (read-only)
-- ================================================================
CREATE TABLE IF NOT EXISTS upload_tasks (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  source_key    text NOT NULL,               -- ตรงกับ UTK_SOURCES key (bigseller/recon/iv141/...)
  frequency     text,                          -- 'day' | 'week' | 'month' (null = ใช้ default)
  weekday       int,                           -- 0=อา .. 6=ส (สำหรับ week)
  monthday      int,                           -- 1-31 (สำหรับ month)
  assignee_id   uuid,                          -- user_id (auth) ที่มอบหมาย
  assignee_name text,                          -- ชื่อ/อีเมล (เก็บไว้โชว์)
  active        boolean NOT NULL DEFAULT true,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  updated_by    uuid
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_upload_tasks_co_src ON upload_tasks (company_id, source_key);
CREATE INDEX IF NOT EXISTS idx_upload_tasks_assignee ON upload_tasks (assignee_id) WHERE active;

GRANT ALL ON upload_tasks TO authenticated;
GRANT ALL ON upload_tasks TO service_role;

ALTER TABLE upload_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_upload_tasks_read   ON upload_tasks;
DROP POLICY IF EXISTS p_upload_tasks_write  ON upload_tasks;
DROP POLICY IF EXISTS p_upload_tasks_update ON upload_tasks;
DROP POLICY IF EXISTS p_upload_tasks_delete ON upload_tasks;
-- อ่าน: ทุกคนในบริษัท (user ต้องเห็นงานที่มอบหมายให้ตัวเอง)
CREATE POLICY p_upload_tasks_read ON upload_tasks FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
-- เขียน/แก้/ลบ: เฉพาะ admin/finance_mgr (คนมอบหมาย)
CREATE POLICY p_upload_tasks_write ON upload_tasks FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr'));
CREATE POLICY p_upload_tasks_update ON upload_tasks FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr'))
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr'));
CREATE POLICY p_upload_tasks_delete ON upload_tasks FOR DELETE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr'));

NOTIFY pgrst, 'reload schema';
