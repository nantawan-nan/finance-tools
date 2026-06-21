-- ================================================================
-- ORDER LEDGER — Phase A
-- ทะเบียนคำสั่งซื้อกลาง · 1 order = 1 IV (key = company + iv_no)
-- ทุกการอัปโหลด (รายงานขาย/ลูกหนี้/รับชำระ/statement) จะ "แท็ก" ลงบน order เดียวกัน
-- Phase A: ป้อนจากรายงานขาย 723-5 (stage ขาย) · stage อื่นเตรียม column ไว้
-- Idempotent
-- ================================================================
CREATE TABLE IF NOT EXISTS orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

  -- identity
  order_id        text,                 -- รหัสคำสั่งซื้อ (อ้างอิง) — marketplace order code
  iv_no           text NOT NULL,        -- เลขที่ IV (1:1 กับ order) — ใช้เป็น key
  channel         text,                 -- ชื่อช่องทางจาก section เช่น "Shopee Betra"
  channel_group   text,                 -- normalize: shopee/tiktok/lazada/offline/other
  customer        text,                 -- ชื่อลูกค้า section
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled')),

  -- ── stage 1: ขาย (รายงานขาย 723-5) ──
  order_date      date,
  iv_date         date,
  sale_amount     numeric(18,2),
  sale_keyed_at   timestamptz,
  sale_src        text,

  -- ── stage 2: ลูกหนี้คงค้าง (เฟสถัดไป) ──
  ar_outstanding  numeric(18,2),
  ar_uploaded_at  timestamptz,

  -- ── stage 3: รับชำระ (เฟสถัดไป) ──
  re_no           text,
  cheque_no       text,                 -- SP/SB/SI...
  receipt_gross   numeric(18,2),
  receipt_net     numeric(18,2),
  receipt_fee     numeric(18,2),
  received_at     timestamptz,

  -- ── stage 4: ฝากเช็ค (เฟสถัดไป) ──
  bq_no           text,
  deposit_date    date,

  -- ── stage 5: เงินเข้าแบงค์ (เฟสถัดไป) ──
  bank_in_date    date,
  bank_amount     numeric(18,2),
  bank_matched    boolean NOT NULL DEFAULT false,

  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1
);
-- 1 order = 1 IV → unique ต่อบริษัท (upsert key)
CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_company_iv
  ON orders (company_id, iv_no) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_company_orderid
  ON orders (company_id, order_id) WHERE deleted_at IS NULL AND order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_company_channel
  ON orders (company_id, channel_group, order_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_company_date
  ON orders (company_id, order_date) WHERE deleted_at IS NULL;

-- timeline / audit log (append-only)
CREATE TABLE IF NOT EXISTS order_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  order_uid    uuid REFERENCES orders(id) ON DELETE CASCADE,
  iv_no        text,
  order_id     text,
  stage        text NOT NULL,           -- sale / ar / receipt / deposit / bank / cancel
  detail       jsonb,
  src_file     text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid
);
CREATE INDEX IF NOT EXISTS idx_order_events_order
  ON order_events (order_uid, created_at);
CREATE INDEX IF NOT EXISTS idx_order_events_company_stage
  ON order_events (company_id, stage, created_at);

-- ----------------------------------------------------------------
-- GRANT + updated_at trigger + RLS
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['orders','order_events'] LOOP
    EXECUTE format('GRANT ALL ON %I TO authenticated', t);
    EXECUTE format('GRANT ALL ON %I TO service_role', t);
    EXECUTE format('GRANT ALL ON %I TO supabase_auth_admin', t);
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
      EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                      FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', t, t);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_read   ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_write  ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_update ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_delete ON %I', t, t);
    EXECUTE format('CREATE POLICY p_%s_read ON %I FOR SELECT TO authenticated
                    USING (company_id IN (SELECT fn_my_companies()))', t, t);
    EXECUTE format('CREATE POLICY p_%s_write ON %I FOR INSERT TO authenticated
                    WITH CHECK (company_id IN (SELECT fn_my_companies())
                      AND fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury''))', t, t);
    EXECUTE format('CREATE POLICY p_%s_update ON %I FOR UPDATE TO authenticated
                    USING (company_id IN (SELECT fn_my_companies())
                      AND fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury''))
                    WITH CHECK (fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury''))', t, t);
    EXECUTE format('CREATE POLICY p_%s_delete ON %I FOR DELETE TO authenticated
                    USING (company_id IN (SELECT fn_my_companies()) AND fn_my_role(company_id) = ''admin'')', t, t);
  END LOOP;
END $$;
