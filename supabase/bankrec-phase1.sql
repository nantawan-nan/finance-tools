-- ================================================================
-- BANK RECONCILIATION — PHASE 1
-- Express GL ↔ Bank Statement (Full Bank Recon)
--   - Strict same-date matching (no tolerance)
--   - Exact match via reference (SCB Note column ↔ Express เลขที่)
--   - Suggested match via same-day + same-amount (BBL — no ref)
-- ใช้ fn_my_companies / fn_my_role / fn_set_updated_at จาก phase0
-- Idempotent: ปลอดภัยรันซ้ำได้
-- ================================================================

-- ----------------------------------------------------------------
-- 1. IMPORTS — ประวัติการอัปโหลด + กันไฟล์ซ้ำ
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_imports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id uuid REFERENCES bank_accounts(id) ON DELETE SET NULL,
  source          text NOT NULL CHECK (source IN ('express','scb_stmt','bbl_stmt')),
  filename        text,
  file_hash       text,
  period_from     date,
  period_to       date,
  row_count       int NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'imported',
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_imports_hash
  ON brec_imports (company_id, source, file_hash)
  WHERE file_hash IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_imports_co_acct
  ON brec_imports (company_id, bank_account_id, period_from, period_to)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 2. EXPRESS ROWS — สมุดบัญชีธนาคารฝั่ง Express
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_express_rows (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
  import_id       uuid REFERENCES brec_imports(id) ON DELETE CASCADE,
  txn_date        date NOT NULL,
  mne             text,                   -- DEQ / CHQ / W/D / TRF / TRD / ---
  doc_no          text,                   -- เลขที่ — QPPS.../BT.../BQ...
  withdrawal      numeric(18,2) NOT NULL DEFAULT 0,
  deposit         numeric(18,2) NOT NULL DEFAULT 0,
  balance         numeric(18,2),
  cheque_status   text,
  remark          text,
  raw_row         int,                    -- เลขแถวในไฟล์ต้นทาง (debug)
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_brec_ex_acct_date
  ON brec_express_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_ex_docno
  ON brec_express_rows (company_id, doc_no)
  WHERE deleted_at IS NULL AND doc_no IS NOT NULL;

-- ----------------------------------------------------------------
-- 3. BANK ROWS — รายการจากธนาคาร (SCB BusinessNet / BBL iBanking)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_bank_rows (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
  import_id       uuid REFERENCES brec_imports(id) ON DELETE CASCADE,
  txn_date        date NOT NULL,
  value_date      date,
  tr_code         text,
  tr_desc         text,
  channel         text,
  cheque_no       text,
  withdrawal      numeric(18,2) NOT NULL DEFAULT 0,
  deposit         numeric(18,2) NOT NULL DEFAULT 0,
  balance         numeric(18,2),
  description     text,
  ref_note        text,                   -- ฟิลด์ "Note" ของ SCB — มีเลขใบสำคัญ
  raw_row         int,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_brec_bk_acct_date
  ON brec_bank_rows (bank_account_id, txn_date)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_bk_refnote
  ON brec_bank_rows (company_id, ref_note)
  WHERE deleted_at IS NULL AND ref_note IS NOT NULL;

-- ----------------------------------------------------------------
-- 4. MATCHES — ผลการจับคู่
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS brec_matches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
  express_row_id  uuid REFERENCES brec_express_rows(id) ON DELETE CASCADE,
  bank_row_id     uuid REFERENCES brec_bank_rows(id) ON DELETE CASCADE,
  status          text NOT NULL CHECK (status IN ('suggested','confirmed','manual','excluded','interaccount')),
  confidence      text,                   -- exact / suggested / manual
  match_reason    text,                   -- เหตุผลที่จับคู่ (debug + UI tooltip)
  txn_date        date,                   -- snapshot date ของ pair (ใช้กรอง period)
  amount          numeric(18,2),          -- snapshot amount (debug)
  note            text,
  confirmed_at    timestamptz,
  confirmed_by    uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1
);
-- กันคู่ซ้ำ — แต่ละ row จับคู่ได้ครั้งเดียว
CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_match_express
  ON brec_matches (express_row_id)
  WHERE express_row_id IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_match_bank
  ON brec_matches (bank_row_id)
  WHERE bank_row_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_brec_match_acct_date
  ON brec_matches (bank_account_id, txn_date)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- 5. GRANT + updated_at trigger
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'brec_imports','brec_express_rows','brec_bank_rows','brec_matches'
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
-- 6. RLS — read = ทุก user ของ company / write = admin/finance/account/treasury
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'brec_imports','brec_express_rows','brec_bank_rows','brec_matches'
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
