-- ================================================================
-- ORDER LEDGER — ทะเบียนคำสั่งซื้อกลาง (consolidated, bulletproof)
-- 1 order = 1 row ต่อบริษัท (company_id + order_id) · iv_no เติมทีหลัง
-- ทุก statement หลัง CREATE TABLE ห่อ EXECUTE+EXCEPTION → ไฟล์ไม่ fail ทั้งก้อน
-- RLS: ปิดไว้ก่อน (เปิดด้วย GRANT) — แอป query กรอง company_id เองอยู่แล้ว
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
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1
);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS products text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_total numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_fee numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_discount numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS item_count int;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS returned_qty int;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_returned boolean NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS sale_status_raw text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_src text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_ingested_at timestamptz;
ALTER TABLE orders ALTER COLUMN iv_no DROP NOT NULL;

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

-- ทุก statement เสี่ยงห่อ EXECUTE+EXCEPTION (valid plpgsql) → กัน fail ทั้งไฟล์
DO $$
BEGIN
  BEGIN EXECUTE 'GRANT ALL ON orders TO authenticated'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON orders TO service_role'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON orders TO supabase_auth_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON order_events TO authenticated'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON order_events TO service_role'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON order_events TO supabase_auth_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- ปิด RLS เพื่อให้แอปใช้ได้แน่นอน (กันกรณี prior run เปิด RLS ไว้แต่ไม่มี policy)
  BEGIN EXECUTE 'ALTER TABLE orders DISABLE ROW LEVEL SECURITY'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE order_events DISABLE ROW LEVEL SECURITY'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- indexes (non-unique กันชนข้อมูลซ้ำ)
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_orders_company_orderid'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_orders_company_iv'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_company_orderid ON orders (company_id, order_id) WHERE deleted_at IS NULL AND order_id IS NOT NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_company_iv ON orders (company_id, iv_no) WHERE deleted_at IS NULL AND iv_no IS NOT NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_company_channel ON orders (company_id, channel_group, order_date) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events (order_uid, created_at)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- updated_at trigger
  BEGIN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders';
    EXECUTE 'CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ★ บังคับ PostgREST reload schema cache (กัน 400 "column not in schema cache" หลัง DDL)
NOTIFY pgrst, 'reload schema';
