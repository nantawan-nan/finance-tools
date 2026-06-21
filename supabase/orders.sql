-- ================================================================
-- ORDER LEDGER — ทะเบียนคำสั่งซื้อกลาง (consolidated, defensive)
-- 1 order = 1 row ต่อบริษัท (key company_id + order_id) · iv_no เติมทีหลัง
-- ทุก statement เสี่ยงห่อ DO/EXCEPTION → ไฟล์ไม่ fail ทั้งก้อน
-- Idempotent
-- ================================================================
CREATE TABLE IF NOT EXISTS orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL,
  order_id        text,
  iv_no           text,
  channel         text,
  channel_group   text,
  customer        text,
  status          text NOT NULL DEFAULT 'active',
  order_date      date,
  iv_date         date,
  sale_amount     numeric(18,2),
  sale_keyed_at   timestamptz,
  sale_src        text,
  products        text,
  item_count      int,
  order_total     numeric(18,2),
  shipping_fee    numeric(18,2),
  seller_discount numeric(18,2),
  returned_qty    int,
  is_returned     boolean NOT NULL DEFAULT false,
  sale_status_raw text,
  order_src       text,
  order_ingested_at timestamptz,
  ar_outstanding  numeric(18,2),
  ar_uploaded_at  timestamptz,
  re_no           text,
  cheque_no       text,
  receipt_gross   numeric(18,2),
  receipt_net     numeric(18,2),
  receipt_fee     numeric(18,2),
  received_at     timestamptz,
  bq_no           text,
  deposit_date    date,
  bank_in_date    date,
  bank_amount     numeric(18,2),
  bank_matched    boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1
);

-- เผื่อตารางเคยถูกสร้างบางส่วน — เติม column ที่ขาด (idempotent)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS products        text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS item_count      int;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_total     numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_fee    numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_discount numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS returned_qty    int;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_returned     boolean NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS sale_status_raw text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_src       text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_ingested_at timestamptz;
ALTER TABLE orders ALTER COLUMN iv_no DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_company_orderid
  ON orders (company_id, order_id) WHERE deleted_at IS NULL AND order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_company_iv
  ON orders (company_id, iv_no) WHERE deleted_at IS NULL AND iv_no IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_company_channel
  ON orders (company_id, channel_group, order_date) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS order_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   uuid NOT NULL,
  order_uid    uuid,
  iv_no        text,
  order_id     text,
  stage        text NOT NULL,
  detail       jsonb,
  src_file     text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid
);
CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events (order_uid, created_at);

-- GRANT + trigger + RLS (ห่อ exception ทีละ statement กัน fail ทั้งไฟล์)
DO $$
BEGIN
  BEGIN GRANT ALL ON orders TO authenticated; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN GRANT ALL ON orders TO service_role; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN GRANT ALL ON order_events TO authenticated; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN GRANT ALL ON order_events TO service_role; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
    CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
      FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

DO $$
BEGIN
  BEGIN ALTER TABLE orders ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN ALTER TABLE order_events ENABLE ROW LEVEL SECURITY; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DROP POLICY IF EXISTS p_orders_read ON orders; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DROP POLICY IF EXISTS p_orders_write ON orders; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DROP POLICY IF EXISTS p_orders_update ON orders; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DROP POLICY IF EXISTS p_orders_delete ON orders; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_orders_read ON orders FOR SELECT TO authenticated
      USING (company_id IN (SELECT fn_my_companies()));
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_orders_write ON orders FOR INSERT TO authenticated
      WITH CHECK (company_id IN (SELECT fn_my_companies())
        AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_orders_update ON orders FOR UPDATE TO authenticated
      USING (company_id IN (SELECT fn_my_companies())
        AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
      WITH CHECK (fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_orders_delete ON orders FOR DELETE TO authenticated
      USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) = 'admin');
  EXCEPTION WHEN OTHERS THEN NULL; END;
  -- order_events RLS
  BEGIN DROP POLICY IF EXISTS p_oe_read ON order_events; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DROP POLICY IF EXISTS p_oe_write ON order_events; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_oe_read ON order_events FOR SELECT TO authenticated
      USING (company_id IN (SELECT fn_my_companies()));
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    CREATE POLICY p_oe_write ON order_events FOR INSERT TO authenticated
      WITH CHECK (company_id IN (SELECT fn_my_companies())
        AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
