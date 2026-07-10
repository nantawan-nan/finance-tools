-- ================================================================
-- FINANCIAL_STATEMENTS — เก็บงบการเงินทางบัญชี (P&L + งบแสดงฐานะการเงิน) บน server
-- 1 แถว = 1 บริษัท × 1 ชนิดงบ (kind: 'pnl' | 'balance')
-- data = parser output (JSONB) · shared ทุกอุปกรณ์ผ่าน RLS
-- อัปไฟล์ "งบการเงิน" (xlsx) → parse → upsert · seed ในแอปโชว์ก่อนได้ (client fallback)
-- ================================================================

CREATE TABLE IF NOT EXISTS financial_statements (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  kind        text        NOT NULL CHECK (kind IN ('pnl','balance')),
  data        jsonb       NOT NULL,
  file_name   text,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid        REFERENCES auth.users(id),
  version     int         NOT NULL DEFAULT 1
);

-- 1 งบ/บริษัท/ชนิด → upsert ด้วย (company_id, kind)
CREATE UNIQUE INDEX IF NOT EXISTS uq_financial_statements_co_kind
  ON financial_statements (company_id, kind);

GRANT ALL ON financial_statements TO supabase_auth_admin;
GRANT ALL ON financial_statements TO authenticated;
GRANT ALL ON financial_statements TO service_role;

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_financial_statements_updated_at ON financial_statements;
CREATE TRIGGER trg_financial_statements_updated_at
  BEFORE UPDATE ON financial_statements
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- RLS — เข้าบริษัทได้ = อ่านได้ · admin/finance_mgr/accountant/treasury เขียนได้
ALTER TABLE financial_statements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fin_stmt_read   ON financial_statements;
DROP POLICY IF EXISTS p_fin_stmt_write  ON financial_statements;
DROP POLICY IF EXISTS p_fin_stmt_update ON financial_statements;
DROP POLICY IF EXISTS p_fin_stmt_delete ON financial_statements;

CREATE POLICY p_fin_stmt_read ON financial_statements FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));

CREATE POLICY p_fin_stmt_write ON financial_statements FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

CREATE POLICY p_fin_stmt_update ON financial_statements FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  )
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

CREATE POLICY p_fin_stmt_delete ON financial_statements FOR DELETE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr')
  );

NOTIFY pgrst, 'reload schema';
SELECT 'financial_statements table created' AS result;
