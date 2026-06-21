-- ORDER LEDGER — minimal isolation test
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
GRANT ALL ON orders TO authenticated;
GRANT ALL ON orders TO service_role;
