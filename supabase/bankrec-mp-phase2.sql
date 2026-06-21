-- ================================================================
-- BANK RECONCILIATION — PHASE 2 (Marketplace Withdrawal Recon)
-- รวม Shopee balance + Express รับชำระ + Express เช็ครับ
--   - จัดกลุ่ม orders ตาม withdrawal event ของ Shopee wallet
--   - gen BQ ต่อ withdrawal (YYMMDD + seq)
--   - ตรวจ mismatch ระหว่าง Express gross vs Shopee
-- ใช้ fn_my_companies / fn_my_role / fn_set_updated_at จาก phase0
-- Idempotent: ปลอดภัยรันซ้ำได้
-- ================================================================

-- ----------------------------------------------------------------
-- 1. MP IMPORTS — ประวัติการอัป (3 ไฟล์ต่อ batch)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_mp_imports (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id         uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id    uuid REFERENCES bank_accounts(id) ON DELETE SET NULL,
  channel            text NOT NULL,            -- shopee / tiktok / lazada
  shop_name          text,                     -- mommam_official / benya_official / betra_brand
  shopee_filename    text,
  receipt_filename   text,
  cheque_filename    text,
  file_hash          text,
  period_from        date,
  period_to          date,
  withdrawal_count   int NOT NULL DEFAULT 0,
  order_count        int NOT NULL DEFAULT 0,
  mismatch_count     int NOT NULL DEFAULT 0,
  status             text NOT NULL DEFAULT 'imported',
  note               text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  created_by         uuid,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  updated_by         uuid,
  deleted_at         timestamptz,
  deleted_by         uuid,
  version            int NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_mp_imports_hash
  ON brec_mp_imports (company_id, channel, file_hash)
  WHERE file_hash IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_mp_imports_co_ch
  ON brec_mp_imports (company_id, channel, period_from)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 2. MP WITHDRAWALS — 1 row = 1 withdrawal event
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_mp_withdrawals (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id         uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id    uuid REFERENCES bank_accounts(id) ON DELETE SET NULL,
  import_id          uuid REFERENCES brec_mp_imports(id) ON DELETE CASCADE,
  channel            text NOT NULL,
  shop_name          text,
  withdraw_datetime  timestamptz NOT NULL,
  withdraw_date      date NOT NULL,
  withdraw_amount    numeric(18,2) NOT NULL,    -- ยอด net ที่เข้าธนาคาร
  bq_number          text,                       -- generated เลขที่ BQ (เช่น 2606040001)
  description        text,                       -- "รับเงินจากการขาย Shopee Qi care"
  order_count        int NOT NULL DEFAULT 0,
  sum_gross          numeric(18,2) NOT NULL DEFAULT 0,
  sum_net            numeric(18,2) NOT NULL DEFAULT 0,
  total_fee          numeric(18,2) NOT NULL DEFAULT 0,
  adjustment_amount  numeric(18,2) NOT NULL DEFAULT 0,
  mismatch_count     int NOT NULL DEFAULT 0,
  bank_row_id        uuid REFERENCES brec_bank_rows(id) ON DELETE SET NULL,
  bank_match_status  text DEFAULT 'unmatched',  -- unmatched / suggested / confirmed
  created_at         timestamptz NOT NULL DEFAULT now(),
  created_by         uuid,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  updated_by         uuid,
  deleted_at         timestamptz,
  deleted_by         uuid,
  version            int NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_brec_mp_wd_co_date
  ON brec_mp_withdrawals (company_id, withdraw_date)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_mp_wd_acct_date
  ON brec_mp_withdrawals (bank_account_id, withdraw_date)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 3. MP ORDERS — 1 row = 1 order ภายใน withdrawal
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_mp_orders (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id         uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  withdrawal_id      uuid NOT NULL REFERENCES brec_mp_withdrawals(id) ON DELETE CASCADE,
  channel            text NOT NULL,
  order_id           text NOT NULL,             -- Shopee order ID (no SP prefix)
  cheque_no          text,                       -- SP + order ID (เลขที่เช็ค)
  txn_datetime       timestamptz,
  txn_type           text,                       -- order / adjustment / refund
  express_gross      numeric(18,2),              -- จาก รับชำระ AR receipt
  shopee_net         numeric(18,2),              -- จาก Shopee balance
  fee_diff           numeric(18,2),              -- gross − net
  receipt_no         text,                       -- RE2605000003 (จาก รับชำระ)
  has_receipt        boolean NOT NULL DEFAULT false,
  has_cheque_deposit boolean NOT NULL DEFAULT false,   -- มีใน "เช็ครับ" แล้ว
  existing_bq        text,                       -- BQ ที่เคยถูก deposit แล้ว (ถ้ามีใน เช็ครับ)
  mismatch_flag      boolean NOT NULL DEFAULT false,
  mismatch_reason    text,                       -- "missing in รับชำระ" / "amount differ" / etc.
  note               text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  created_by         uuid,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  updated_by         uuid,
  deleted_at         timestamptz,
  deleted_by         uuid,
  version            int NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_brec_mp_ord_wd
  ON brec_mp_orders (withdrawal_id)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_mp_ord_orderid
  ON brec_mp_orders (company_id, order_id)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_mp_ord_mismatch
  ON brec_mp_orders (company_id, mismatch_flag)
  WHERE deleted_at IS NULL AND mismatch_flag = true;

-- ----------------------------------------------------------------
-- 4. GRANT + updated_at trigger
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'brec_mp_imports','brec_mp_withdrawals','brec_mp_orders'
  ] LOOP
    EXECUTE format('GRANT ALL ON %I TO authenticated', t);
    EXECUTE format('GRANT ALL ON %I TO service_role', t);
    EXECUTE format('GRANT ALL ON %I TO supabase_auth_admin', t);
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
      EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                      FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', t, t);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

-- ----------------------------------------------------------------
-- 5. RLS
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'brec_mp_imports','brec_mp_withdrawals','brec_mp_orders'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_read   ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_write  ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_update ON %I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS p_%s_delete ON %I', t, t);

    EXECUTE format('CREATE POLICY p_%s_read ON %I FOR SELECT TO authenticated
                    USING (company_id IN (SELECT fn_my_companies()))', t, t);

    EXECUTE format('CREATE POLICY p_%s_write ON %I FOR INSERT TO authenticated
                    WITH CHECK (
                      company_id IN (SELECT fn_my_companies())
                      AND fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury'')
                    )', t, t);

    EXECUTE format('CREATE POLICY p_%s_update ON %I FOR UPDATE TO authenticated
                    USING (company_id IN (SELECT fn_my_companies())
                           AND fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury''))
                    WITH CHECK (fn_my_role(company_id) IN (''admin'',''finance_mgr'',''accountant'',''treasury''))', t, t);

    EXECUTE format('CREATE POLICY p_%s_delete ON %I FOR DELETE TO authenticated
                    USING (company_id IN (SELECT fn_my_companies())
                           AND fn_my_role(company_id) = ''admin'')', t, t);
  END LOOP;
END $$;
