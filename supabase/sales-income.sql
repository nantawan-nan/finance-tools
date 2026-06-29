-- ================================================================
-- SALES INCOME — ทะเบียนรับชำระเงินจาก Marketplace (Shopee/TikTok/Lazada)
-- ★ sales_income_rows  — แต่ละออเดอร์ที่โอนเงินเข้า (gross/fee/net per platform)
-- ★ re_export_batches  — ประวัติส่งออก RE → AutoKey (เหมือน iv_export_batches)
-- ★ ALTER order_ledger — เพิ่ม re_no / re_date / re_keyed_at (tag หลัง verify)
-- ทุก statement idempotent · EXCEPTION-wrapped · NOTIFY pgrst
-- ================================================================

/* ---------- sales_income_rows ---------- */
CREATE TABLE IF NOT EXISTS sales_income_rows (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL,
  order_id        text,
  channel_group   text,
  paid_date       date,
  order_date      date,
  gross           numeric(15,2) NOT NULL DEFAULT 0,
  ship_buyer      numeric(15,2) NOT NULL DEFAULT 0,
  ship_seller     numeric(15,2) NOT NULL DEFAULT 0,
  seller_discount numeric(15,2) NOT NULL DEFAULT 0,
  fee_total       numeric(15,2) NOT NULL DEFAULT 0,
  fee_breakdown   jsonb,
  adjustment      numeric(15,2) NOT NULL DEFAULT 0,
  net_received    numeric(15,2) NOT NULL DEFAULT 0,
  source_file     text,
  imported_at     timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  deleted_at      timestamptz
);

-- ADD COLUMN IF NOT EXISTS สำหรับ schema เก่า
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS company_id      uuid;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS order_id        text;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS channel_group   text;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS paid_date       date;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS order_date      date;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS gross           numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS ship_buyer      numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS ship_seller     numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS seller_discount numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS fee_total       numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS fee_breakdown   jsonb;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS adjustment      numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS net_received    numeric(15,2) NOT NULL DEFAULT 0;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS source_file     text;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS imported_at     timestamptz NOT NULL DEFAULT now();
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS created_by      uuid;
ALTER TABLE sales_income_rows ADD COLUMN IF NOT EXISTS deleted_at      timestamptz;

/* ---------- re_export_batches ---------- */
CREATE TABLE IF NOT EXISTS re_export_batches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL,
  batch_no        text NOT NULL,
  date_from       date,
  date_to         date,
  channels        text[],
  start_re        text,
  end_re          text,
  order_count     int NOT NULL DEFAULT 0,
  order_ids       jsonb,
  file_name       text,
  exported_by     uuid,
  exported_email  text,
  exported_at     timestamptz NOT NULL DEFAULT now(),
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS company_id     uuid;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS batch_no       text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS date_from      date;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS date_to        date;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS channels       text[];
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS start_re       text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS end_re         text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS order_count    int NOT NULL DEFAULT 0;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS order_ids      jsonb;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS file_name      text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS exported_by    uuid;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS exported_email text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS exported_at    timestamptz NOT NULL DEFAULT now();
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS note           text;
ALTER TABLE re_export_batches ADD COLUMN IF NOT EXISTS deleted_at     timestamptz;

/* ---------- extend order_ledger ---------- */
-- re_no / re_date = เลข RE + วันที่ที่คีย์จริงใน 1.9.1 (tag หลัง verify)
-- re_keyed_at    = timestamp ที่ระบบ tag RE สำเร็จ
DO $$
BEGIN
  BEGIN ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS re_no      text;         EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS re_date    date;         EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS re_keyed_at timestamptz; EXCEPTION WHEN undefined_table THEN NULL; END;
END $$;

/* ---------- grants + RLS off + indexes ---------- */
DO $$
BEGIN
  BEGIN EXECUTE 'GRANT ALL ON sales_income_rows TO authenticated';  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON sales_income_rows TO service_role';   EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON re_export_batches TO authenticated';  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON re_export_batches TO service_role';   EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN EXECUTE 'ALTER TABLE sales_income_rows DISABLE ROW LEVEL SECURITY';  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE re_export_batches DISABLE ROW LEVEL SECURITY';  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_sales_income_co_paid ON sales_income_rows (company_id, paid_date DESC) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_income_co_order ON sales_income_rows (company_id, order_id, channel_group) WHERE deleted_at IS NULL AND order_id IS NOT NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_re_export_batches_co_at ON re_export_batches (company_id, exported_at DESC) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_re_export_batches_no ON re_export_batches (company_id, batch_no) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
