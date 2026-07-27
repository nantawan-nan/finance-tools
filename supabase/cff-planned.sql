-- ================================================================
-- CFF_PLANNED — รายการวางแผนล่วงหน้าสำหรับ Cash Flow Forecast
-- แยกจาก "ยอดจริง" (bank_balances) — เป็นสิ่งที่ "จะเกิด" แต่ยังไม่เกิด
--   kind: transfer (โอนระหว่างบัญชี) · inflow (รับเงินคาดการณ์ เช่น เงินกู้) · outflow (จ่ายคาดการณ์ นอกเหนือ AP)
--   → forecast โปรเจกต์ยอดอนาคตต่อบัญชี โดยยอดจริงยังสะอาด
-- ================================================================
CREATE TABLE IF NOT EXISTS cff_planned (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  kind            text NOT NULL,          -- 'transfer' | 'inflow' | 'outflow'
  from_account_id uuid,                    -- ต้นทาง (transfer/outflow)
  to_account_id   uuid,                    -- ปลายทาง (transfer/inflow)
  amount          numeric NOT NULL DEFAULT 0,
  plan_date       date,
  category        text,                    -- ป้าย/หมวด (inflow เช่น "เงินกู้" · outflow เช่น "ค่าใช้จ่ายอื่น")
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid
);
CREATE INDEX IF NOT EXISTS idx_cff_planned_co ON cff_planned (company_id, plan_date) WHERE deleted_at IS NULL;

GRANT ALL ON cff_planned TO authenticated;
GRANT ALL ON cff_planned TO service_role;

ALTER TABLE cff_planned ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_cff_planned_read   ON cff_planned;
DROP POLICY IF EXISTS p_cff_planned_write  ON cff_planned;
DROP POLICY IF EXISTS p_cff_planned_update ON cff_planned;
DROP POLICY IF EXISTS p_cff_planned_delete ON cff_planned;
CREATE POLICY p_cff_planned_read ON cff_planned FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_cff_planned_write ON cff_planned FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_cff_planned_update ON cff_planned FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
  WITH CHECK (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_cff_planned_delete ON cff_planned FOR DELETE TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));

NOTIFY pgrst, 'reload schema';
