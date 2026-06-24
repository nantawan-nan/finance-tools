-- ================================================================
-- ORDER PIPELINE — schema (Stage 1)
-- ★ ยึด BigSeller `orders` เป็น order master · เพิ่ม lifecycle (IV/RE/BQ/bank) + recon + adjustment + shop registry
-- cardinality: 1 Order = 1 IV = 1 RE (flat columns) · ฝากเช็ค 1 BQ : หลายเช็ค → ใช้ brec_mp_* เดิม
-- `orders`/`order_items` ใช้คอลัมน์ `company` (text 'mbark'/'benya') — ไม่ใช่ company_id uuid
-- ตั้งชื่อไฟล์ให้ sort หลัง orders.sql (เพื่อ ALTER order_events ได้) · ทุก statement idempotent + EXCEPTION-wrapped
-- ================================================================

-- ----------------------------------------------------------------
-- 0. baseline (กัน clone ใหม่ที่ยังไม่เคย import BigSeller → ตารางยังไม่มี)
--    บน prod ที่มีตารางแล้ว: IF NOT EXISTS ข้ามให้ ไม่กระทบ
-- ----------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS orders (
      id text PRIMARY KEY,
      order_no text, company text,
      platform text, shop_name text, brand text,
      sale_date date, cust_code text, iv_no text,
      net_amount numeric(18,2), status text,
      key_date date, updated_at timestamptz DEFAULT now()
    )';
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS order_items (
      id text PRIMARY KEY,
      order_no text, company text,
      sku text, qty numeric, price numeric, ship numeric, discount numeric
    )';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ----------------------------------------------------------------
-- 1. ขยาย orders — lifecycle columns (nullable, ไม่กระทบ bsImport/exkLoad เดิม)
-- ----------------------------------------------------------------
DO $$
DECLARE c text;
BEGIN
  FOREACH c IN ARRAY ARRAY[
    'iv_date date','iv_amount numeric(18,2)','iv_status text','iv_keyed_at timestamptz','iv_src text',
    're_no text','cheque_no text','receipt_gross numeric(18,2)','receipt_net numeric(18,2)',
    'receipt_fee numeric(18,2)','received_at timestamptz','ar_outstanding numeric(18,2)',
    'bq_no text','deposit_date date','bank_in_date date','bank_amount numeric(18,2)','bank_matched boolean',
    'recon_status text','recon_checked_at timestamptz',
    'gross_sales numeric(18,2)','net_sales numeric(18,2)',
    'source_type text','approval_status text','return_status text'
  ] LOOP
    BEGIN EXECUTE 'ALTER TABLE orders ADD COLUMN IF NOT EXISTS '||c; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
  -- order_items: partial return (line-level)
  FOREACH c IN ARRAY ARRAY[
    'returned_qty int','refund_amount numeric(18,2)','return_date date','net_qty int'
  ] LOOP
    BEGIN EXECUTE 'ALTER TABLE order_items ADD COLUMN IF NOT EXISTS '||c; EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
  -- indexes
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_iv_status ON orders (company, iv_status)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_recon     ON orders (company, recon_status)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_sale_date ON orders (company, sale_date)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_iv_no     ON orders (company, iv_no)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_bq_no     ON orders (company, bq_no)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_approval  ON orders (company, source_type, approval_status)'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ----------------------------------------------------------------
-- 2. order_recon_runs — header ต่อการตรวจ 1 ครั้ง
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_recon_runs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company         text NOT NULL,
  run_at          timestamptz NOT NULL DEFAULT now(),
  sale_date_from  date,
  sale_date_to    date,
  channels        text[],
  bs_file         text,
  be_files        text[],
  n_total         int NOT NULL DEFAULT 0,
  n_matched       int NOT NULL DEFAULT 0,
  n_needs_review  int NOT NULL DEFAULT 0,
  n_only_bs       int NOT NULL DEFAULT 0,
  n_only_be       int NOT NULL DEFAULT 0,
  n_amount_diff   int NOT NULL DEFAULT 0,
  n_sku_diff      int NOT NULL DEFAULT 0,
  created_by      uuid,
  deleted_at      timestamptz
);

-- ----------------------------------------------------------------
-- 3. order_recon — ผลเทียบรายออเดอร์ (แช่ทั้ง 2 ฝั่ง → กู้คืนได้)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_recon (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company       text NOT NULL,
  run_id        uuid REFERENCES order_recon_runs(id) ON DELETE CASCADE,
  sale_date     date,
  channel       text,
  order_no      text NOT NULL,
  bs_present    boolean NOT NULL DEFAULT false,
  bs_gross      numeric(18,2),
  bs_ship       numeric(18,2),
  bs_discount   numeric(18,2),
  bs_item_count int,
  bs_sku_sig    text,
  bs_raw        jsonb,
  be_present    boolean NOT NULL DEFAULT false,
  be_gross      numeric(18,2),
  be_ship       numeric(18,2),
  be_discount   numeric(18,2),
  be_item_count int,
  be_sku_sig    text,
  be_raw        jsonb,
  status        text NOT NULL,   -- matched|only_in_bigseller|only_in_backend|amount_diff|sku_diff
  diff_fields   text[],
  diff_detail   jsonb,
  resolved      boolean NOT NULL DEFAULT false,
  resolve_action text,
  resolve_note  text,
  resolved_by   uuid,
  resolved_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

-- ----------------------------------------------------------------
-- 4. import_column_map — จดจำ map คอลัมน์ (เรียนรู้จากชื่อหัวคอลัมน์)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS import_column_map (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company     text NOT NULL,
  channel     text NOT NULL,
  field       text NOT NULL,
  header_text text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);

-- ----------------------------------------------------------------
-- 5. shop_registry — ทะเบียนร้าน → บริษัท (แยกบริษัทอัตโนมัติตอน import)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shop_registry (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name   text NOT NULL,
  shop_key    text NOT NULL,
  company     text NOT NULL,
  brand       text,
  channel     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);

-- ----------------------------------------------------------------
-- 6. order_adjustments — ปรับยอดย้อนหลังจาก platform (append-only)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_adjustments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company     text NOT NULL,
  order_no    text,
  iv_no       text,
  adj_type    text NOT NULL,        -- refund|penalty|affiliate_fee|fee_adjustment|other
  amount      numeric(18,2) NOT NULL,
  adj_date    date,
  reason      text,
  src_file    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);

-- ----------------------------------------------------------------
-- 7. order_events — เพิ่มคอลัมน์ให้เกาะ orders (เดิมมี company_id uuid จาก orders.sql)
--    ★ EXCEPTION-wrapped กัน clone ใหม่ที่ order_events ยังไม่ถูกสร้าง (orders.sql รันก่อน/หลังก็ปลอดภัย)
-- ----------------------------------------------------------------
DO $$
BEGIN
  BEGIN EXECUTE 'ALTER TABLE order_events ADD COLUMN IF NOT EXISTS company  text'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE order_events ADD COLUMN IF NOT EXISTS order_no text'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_events_co_ord ON order_events (company, order_no, created_at)'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ----------------------------------------------------------------
-- 8. indexes ตารางใหม่
-- ----------------------------------------------------------------
DO $$
BEGIN
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_recon_runs_co  ON order_recon_runs (company, run_at DESC) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_recon_run      ON order_recon (run_id) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_recon_co_ord   ON order_recon (company, order_no) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_recon_review   ON order_recon (company, status, resolved) WHERE deleted_at IS NULL AND resolved = false'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_colmap   ON import_column_map (company, channel, field, header_text) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_shop_registry_key ON shop_registry (shop_key) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_adj_co_ord ON order_adjustments (company, order_no) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_adj_co_iv  ON order_adjustments (company, iv_no)    WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ----------------------------------------------------------------
-- 9. GRANT + ปิด RLS (แอปกรอง company เองอยู่แล้ว — ตาม orders.sql เดิม)
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'order_recon_runs','order_recon','import_column_map','shop_registry','order_adjustments'
  ] LOOP
    BEGIN EXECUTE format('GRANT ALL ON %I TO authenticated', t); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('GRANT ALL ON %I TO service_role', t);  EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('GRANT ALL ON %I TO supabase_auth_admin', t); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t); EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

-- ----------------------------------------------------------------
-- 10. order_ledger.items — รายการสินค้าต่อออเดอร์ (รหัส/ชื่อ/จำนวน/ราคา)
-- ----------------------------------------------------------------
DO $$ BEGIN
  BEGIN EXECUTE 'ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS items jsonb'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ★ บังคับ PostgREST reload schema cache (กัน 400 "column not in schema cache" หลัง DDL)
NOTIFY pgrst, 'reload schema';
