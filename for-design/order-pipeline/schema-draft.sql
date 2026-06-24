-- ================================================================
-- ORDER PIPELINE — schema DRAFT (review ก่อน) — ยังไม่ auto-run
-- เมื่อ approve: ย้ายไป supabase/order-pipeline.sql (workflow จะรันให้)
-- ★ ยึด BigSeller `orders` เป็น master · เพิ่ม lifecycle + recon + events
-- Idempotent ทุก statement (IF NOT EXISTS / ห่อ EXCEPTION)
-- หมายเหตุ: `orders`/`order_items` ใช้คอลัมน์ `company` (text 'mbark'/'benya')
--           ไม่ใช่ company_id uuid — คงรูปแบบเดิมไว้
-- ================================================================

-- ----------------------------------------------------------------
-- 1. ขยาย orders — คอลัมน์ lifecycle (nullable, ไม่กระทบ bsImport/exkLoad เดิม)
-- ----------------------------------------------------------------
ALTER TABLE orders ADD COLUMN IF NOT EXISTS iv_date        date;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS iv_amount      numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS iv_status      text;       -- no_iv|keyed_ok|amount_mismatch|needs_fix|voided
ALTER TABLE orders ADD COLUMN IF NOT EXISTS iv_keyed_at    timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS iv_src         text;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS re_no          text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cheque_no      text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS receipt_gross  numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS receipt_net    numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS receipt_fee    numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS received_at    timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS ar_outstanding numeric(18,2);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS bq_no          text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS deposit_date   date;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bank_in_date   date;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bank_amount    numeric(18,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bank_matched   boolean DEFAULT false;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS recon_status     text;     -- not_checked|matched|needs_review|resolved
ALTER TABLE orders ADD COLUMN IF NOT EXISTS recon_checked_at timestamptz;

-- ★ ข้อ 13: แยกชั้นเงินให้ชัด (อย่าเก็บแค่ยอดรวม) + รองรับคืนสินค้า + workflow คีย์มือ
ALTER TABLE orders ADD COLUMN IF NOT EXISTS gross_sales     numeric(18,2);  -- Σ(price×qty) ก่อนหักส่วนลด/คืน
ALTER TABLE orders ADD COLUMN IF NOT EXISTS net_sales       numeric(18,2);  -- หลังส่วนลด + หักคืน
ALTER TABLE orders ADD COLUMN IF NOT EXISTS source_type     text DEFAULT 'auto';  -- auto (platform) | manual (FB/LINE)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS approval_status text;           -- draft|submitted|sales_reviewed|accounting_accepted (เฉพาะ manual)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS return_status   text;           -- none|partial|full
-- ★ cardinality (เจ้าของยืนยัน 2026-06-24): 1 order = 1 IV = 1 RE เป๊ะ (flat columns บน orders พอ)
--   มีแค่ตอนฝากเช็ค: 1 BQ : หลายเลขที่เช็ค → ใช้ brec_mp_withdrawals/brec_mp_orders เดิม (ไม่ต้องตารางใหม่)

CREATE INDEX IF NOT EXISTS idx_orders_iv_status   ON orders (company, iv_status);
CREATE INDEX IF NOT EXISTS idx_orders_recon       ON orders (company, recon_status);
CREATE INDEX IF NOT EXISTS idx_orders_sale_date   ON orders (company, sale_date);
CREATE INDEX IF NOT EXISTS idx_orders_iv_no       ON orders (company, iv_no);
CREATE INDEX IF NOT EXISTS idx_orders_approval    ON orders (company, source_type, approval_status);

-- ★ ข้อ 13: คืนบางสินค้า (partial return) — ระดับ line item
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS returned_qty   int DEFAULT 0;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS refund_amount  numeric(18,2) DEFAULT 0;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS return_date    date;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS net_qty        int;   -- qty - returned_qty (ที่นับเป็นยอดขายจริง)

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
CREATE INDEX IF NOT EXISTS idx_recon_runs_co ON order_recon_runs (company, run_at DESC) WHERE deleted_at IS NULL;

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
  -- ฝั่ง BigSeller (copy ณ เวลาตรวจ) — แยก gross/ship/discount เพื่อชี้จุดต่างได้ (strict 0 tolerance)
  bs_present    boolean NOT NULL DEFAULT false,
  bs_gross      numeric(18,2),   -- Σ(price×qty) ก่อนหักส่วนลด
  bs_ship       numeric(18,2),   -- ค่าส่งเรียกเก็บลูกค้า (ใช้ยื่นภาษีขาย — ต้องตรง)
  bs_discount   numeric(18,2),
  bs_item_count int,
  bs_sku_sig    text,
  bs_raw        jsonb,
  -- ฝั่งหลังบ้าน
  be_present    boolean NOT NULL DEFAULT false,
  be_gross      numeric(18,2),
  be_ship       numeric(18,2),
  be_discount   numeric(18,2),
  be_item_count int,
  be_sku_sig    text,
  be_raw        jsonb,
  -- ผล
  status        text NOT NULL,   -- matched|only_in_bigseller|only_in_backend|amount_diff|sku_diff
  diff_fields   text[],          -- ['gross','ship','discount','sku'] ที่ต่าง
  diff_detail   jsonb,
  -- resolve
  resolved      boolean NOT NULL DEFAULT false,
  resolve_action text,
  resolve_note  text,
  resolved_by   uuid,
  resolved_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);
CREATE INDEX IF NOT EXISTS idx_recon_run    ON order_recon (run_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_recon_co_ord ON order_recon (company, order_no) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_recon_review ON order_recon (company, status, resolved)
  WHERE deleted_at IS NULL AND resolved = false;

-- ----------------------------------------------------------------
-- 4. order_events — เพิ่มคอลัมน์ให้เกาะ orders (เดิมมี company_id uuid)
-- ----------------------------------------------------------------
ALTER TABLE order_events ADD COLUMN IF NOT EXISTS company  text;
ALTER TABLE order_events ADD COLUMN IF NOT EXISTS order_no text;
CREATE INDEX IF NOT EXISTS idx_order_events_co_ord ON order_events (company, order_no, created_at);

-- ----------------------------------------------------------------
-- 4.5 import_column_map — จดจำการ map คอลัมน์ (เรียนรู้จากชื่อหัวคอลัมน์)
--     กันกรณีไฟล์ SH/TT/LZ ขยับคอลัมน์/เปลี่ยนชื่อหัวข้อระหว่างเดือน
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS import_column_map (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company     text NOT NULL,
  channel     text NOT NULL,        -- shopee|tiktok|lazada|bigseller|express
  field       text NOT NULL,        -- order_no|gross|ship|discount|sku|qty|status|date ...
  header_text text NOT NULL,        -- ชื่อหัวคอลัมน์ที่ผู้ใช้ยืนยันให้ map กับ field นี้
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_colmap
  ON import_column_map (company, channel, field, header_text)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 4.6 shop_registry — ทะเบียนร้าน → บริษัท (แยกบริษัทอัตโนมัติตอน import)
--     แทน localStorage wtp-bs-shopbrand-v1 (per-browser) → shared ทุกเครื่อง
--     ★ ไม่มี company filter ในตัวเอง — เป็น registry กลาง (ร้านบอกว่าเป็นของบริษัทไหน)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shop_registry (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name   text NOT NULL,           -- ชื่อร้านจากคอลัมน์ "ร้านค้าเพลตฟอร์ม"
  shop_key    text NOT NULL,           -- lower(trim(shop_name)) — ใช้ join
  company     text NOT NULL,           -- 'benya' | 'mbark' (ร้านนี้สังกัดบริษัทไหน)
  brand       text,                    -- BT|QI|MB ...
  channel     text,                    -- SP|TT|LZ
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_shop_registry_key
  ON shop_registry (shop_key) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 4.7 order_adjustments — ปรับยอดย้อนหลังจาก platform (append-only)
--     Refund / Penalty / Affiliate Fee / Fee Adjustment ที่มาทีหลัง
--     ผูก 1:1 กับ order/iv (ไม่ N:M) · ไม่แก้ยอดเดิม แต่บันทึกเป็นรายการปรับ
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_adjustments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company     text NOT NULL,
  order_no    text,
  iv_no       text,
  adj_type    text NOT NULL,        -- refund|penalty|affiliate_fee|fee_adjustment|other
  amount      numeric(18,2) NOT NULL,  -- + เพิ่ม / − ลด เงินเข้าสุทธิ
  adj_date    date,
  reason      text,
  src_file    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  deleted_at  timestamptz
);
CREATE INDEX IF NOT EXISTS idx_order_adj_co_ord ON order_adjustments (company, order_no) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_order_adj_co_iv  ON order_adjustments (company, iv_no)    WHERE deleted_at IS NULL;

-- หมายเหตุ workflow คีย์มือ FB/LINE: ใช้ orders.source_type='manual' + orders.approval_status
--   (draft→submitted→sales_reviewed→accounting_accepted) + บันทึก log ใน order_events (stage='approval')
--   ไม่ต้องตารางแยก

-- ----------------------------------------------------------------
-- 5. GRANT + ปิด RLS (แอปกรอง company เองอยู่แล้ว — ตาม orders.sql เดิม)
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['order_recon_runs','order_recon','import_column_map','shop_registry','order_adjustments'] LOOP
    BEGIN EXECUTE format('GRANT ALL ON %I TO authenticated', t); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('GRANT ALL ON %I TO service_role', t);  EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('GRANT ALL ON %I TO supabase_auth_admin', t); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t); EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

-- ★ บังคับ PostgREST reload schema cache
NOTIFY pgrst, 'reload schema';
