-- ================================================================
-- EXEC_CASHFLOW — เก็บข้อมูล Executive Cash Flow Dashboard บน server
-- 1 แถว = 1 บริษัท ใส่ data parser output ใน JSONB
-- ใช้ shared ทุกอุปกรณ์ที่ login ผ่าน RLS
-- ================================================================

CREATE TABLE IF NOT EXISTS exec_cashflow (
  company_id  uuid        PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  data        jsonb       NOT NULL,
  file_name   text,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid        REFERENCES auth.users(id),
  version     int         NOT NULL DEFAULT 1
);

-- Grant สิทธิ์ให้ supabase_auth_admin (กัน trigger fail ตอน insert)
GRANT ALL ON exec_cashflow TO supabase_auth_admin;
GRANT ALL ON exec_cashflow TO authenticated;
GRANT ALL ON exec_cashflow TO service_role;

-- updated_at + version trigger
DROP TRIGGER IF EXISTS trg_exec_cashflow_updated_at ON exec_cashflow;
CREATE TRIGGER trg_exec_cashflow_updated_at
  BEFORE UPDATE ON exec_cashflow
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- RLS — ใครเข้าบริษัทได้ก็อ่านได้ admin/finance_mgr/accountant/treasury เขียนได้
ALTER TABLE exec_cashflow ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_exec_cashflow_read   ON exec_cashflow;
DROP POLICY IF EXISTS p_exec_cashflow_write  ON exec_cashflow;
DROP POLICY IF EXISTS p_exec_cashflow_update ON exec_cashflow;
DROP POLICY IF EXISTS p_exec_cashflow_delete ON exec_cashflow;

CREATE POLICY p_exec_cashflow_read ON exec_cashflow FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));

CREATE POLICY p_exec_cashflow_write ON exec_cashflow FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

CREATE POLICY p_exec_cashflow_update ON exec_cashflow FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  )
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

CREATE POLICY p_exec_cashflow_delete ON exec_cashflow FOR DELETE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr')
  );

SELECT 'exec_cashflow table created' AS result;
