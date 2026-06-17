-- ================================================================
-- AR MODULE — ลูกหนี้ (AR Outstanding)
-- วิธีรัน: Supabase Dashboard → SQL Editor → วาง → Run
-- ================================================================

-- ----------------------------------------------------------------
-- STEP 1: เพิ่ม net_amount บน orders (ยอดขายต่อออเดอร์)
-- ----------------------------------------------------------------
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS net_amount numeric(18,2);

-- Backfill net_amount จาก order_items (SUM qty*price ต่อออเดอร์)
UPDATE orders o
SET net_amount = (
  SELECT COALESCE(SUM(oi.qty * oi.price), 0)
  FROM order_items oi
  WHERE oi.order_no = o.order_no
    AND oi.company  = o.company
)
WHERE o.net_amount IS NULL;

-- ----------------------------------------------------------------
-- STEP 2: สร้างตาราง ar_receipts (บันทึกรับเงิน)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ar_receipts (
  id              text        PRIMARY KEY,
  company_id      uuid        NOT NULL REFERENCES companies(id),
  order_no        text        NOT NULL,
  iv_no           text,
  received_date   date        NOT NULL,
  received_amount numeric(18,2) NOT NULL,
  bank_account    text,
  note            text,
  -- universal columns
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int         NOT NULL DEFAULT 1
);

-- ----------------------------------------------------------------
-- STEP 3: Indexes
-- ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ar_receipts_company    ON ar_receipts (company_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ar_receipts_order_no   ON ar_receipts (company_id, order_no) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ar_receipts_iv_no      ON ar_receipts (company_id, iv_no) WHERE deleted_at IS NULL AND iv_no IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ar_receipts_date       ON ar_receipts (company_id, received_date) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- STEP 4: updated_at + version trigger
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ar_receipts_updated_at ON ar_receipts;
CREATE TRIGGER trg_ar_receipts_updated_at
  BEFORE UPDATE ON ar_receipts
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ----------------------------------------------------------------
-- STEP 5: Audit trigger
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_ar_receipts ON ar_receipts;
CREATE TRIGGER trg_audit_ar_receipts
  AFTER INSERT OR UPDATE OR DELETE ON ar_receipts
  FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- ----------------------------------------------------------------
-- STEP 6: Soft-delete guard (ห้าม hard delete)
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_nodelete_ar_receipts ON ar_receipts;
CREATE TRIGGER trg_nodelete_ar_receipts
  BEFORE DELETE ON ar_receipts
  FOR EACH ROW EXECUTE FUNCTION fn_block_hard_delete();

-- ----------------------------------------------------------------
-- STEP 7: RLS
-- ----------------------------------------------------------------
ALTER TABLE ar_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ar_receipts_read  ON ar_receipts;
DROP POLICY IF EXISTS p_ar_receipts_write ON ar_receipts;
DROP POLICY IF EXISTS p_ar_receipts_update ON ar_receipts;

-- ทุก role ที่มีสิทธิ์บริษัทนั้นอ่านได้
CREATE POLICY p_ar_receipts_read ON ar_receipts FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()) AND deleted_at IS NULL);

-- finance_mgr, accountant, treasury, admin เขียนได้
CREATE POLICY p_ar_receipts_write ON ar_receipts FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

-- อัปเดต (soft delete, แก้ไข) — role เดียวกัน
CREATE POLICY p_ar_receipts_update ON ar_receipts FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury')
  );

-- ----------------------------------------------------------------
-- STEP 8: View (active only)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW v_ar_receipts AS
  SELECT * FROM ar_receipts WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- VERIFY
-- ----------------------------------------------------------------
SELECT
  (SELECT count(*) FROM ar_receipts)                         AS ar_receipts,
  (SELECT count(*) FROM orders WHERE net_amount IS NOT NULL) AS orders_with_amount,
  (SELECT count(*) FROM orders WHERE net_amount IS NULL)     AS orders_missing_amount,
  'AR Module ✅' AS status;
