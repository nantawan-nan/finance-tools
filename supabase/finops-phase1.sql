-- ================================================================
-- FINOPS PHASE 1 — Bank Balance + AP Outstanding + Recurring Expenses
-- ใช้ fn_my_companies / fn_my_role / fn_set_updated_at / fn_audit_trigger
-- จาก phase0-foundation
-- ================================================================

-- ----------------------------------------------------------------
-- 1. BANK ACCOUNTS + BALANCES (append-only history)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bank_accounts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_code     text NOT NULL,
  account_no    text NOT NULL,
  nickname      text,
  account_type  text,
  branch        text,
  is_active     boolean NOT NULL DEFAULT true,
  display_order int DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  updated_by    uuid,
  deleted_at    timestamptz,
  deleted_by    uuid,
  version       int NOT NULL DEFAULT 1,
  UNIQUE (company_id, bank_code, account_no)
);

CREATE TABLE IF NOT EXISTS bank_balances (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
  balance_date    date NOT NULL,
  amount          numeric(18,2) NOT NULL CHECK (amount >= 0),
  hold_amount     numeric(18,2) NOT NULL DEFAULT 0,
  source          text NOT NULL DEFAULT 'manual',
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  deleted_at      timestamptz,
  deleted_by      uuid,
  version         int NOT NULL DEFAULT 1,
  CONSTRAINT bal_no_future CHECK (balance_date <= current_date + INTERVAL '1 day')
);
CREATE INDEX IF NOT EXISTS idx_bal_acct_date ON bank_balances (bank_account_id, balance_date DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bal_company_date ON bank_balances (company_id, balance_date DESC)
  WHERE deleted_at IS NULL;

-- helper: balance as-of date per account
CREATE OR REPLACE FUNCTION fn_balance_as_of(p_company uuid, p_as_of date)
RETURNS TABLE (
  bank_account_id uuid,
  bank_code text, account_no text, nickname text,
  amount numeric, hold numeric, dated_at date
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT DISTINCT ON (b.bank_account_id)
    b.bank_account_id, a.bank_code, a.account_no, a.nickname,
    b.amount, b.hold_amount, b.balance_date
  FROM bank_balances b
  JOIN bank_accounts a ON a.id = b.bank_account_id
  WHERE b.company_id = p_company
    AND b.deleted_at IS NULL
    AND a.deleted_at IS NULL
    AND b.balance_date <= p_as_of
  ORDER BY b.bank_account_id, b.balance_date DESC, b.created_at DESC;
$$;

-- ----------------------------------------------------------------
-- 2. VENDORS + AP INVOICES + AP PAYMENTS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vendors (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  external_code text,
  name          text NOT NULL,
  tax_id        text,
  default_terms_days int,
  bank_info     text,
  created_at    timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at    timestamptz, deleted_by uuid,
  version       int NOT NULL DEFAULT 1,
  UNIQUE (company_id, external_code)
);

CREATE TABLE IF NOT EXISTS csv_imports (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  target_table      text NOT NULL,
  file_name         text,
  file_storage_path text,
  row_count         int DEFAULT 0,
  ok_count          int DEFAULT 0,
  error_count       int DEFAULT 0,
  status            text NOT NULL DEFAULT 'pending',
  uploaded_at       timestamptz NOT NULL DEFAULT now(),
  uploaded_by       uuid,
  committed_at      timestamptz,
  committed_by      uuid,
  remark            text
);

CREATE TABLE IF NOT EXISTS ap_invoices (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  vendor_id       uuid REFERENCES vendors(id),
  vendor_name_raw text,
  invoice_no      text NOT NULL,
  invoice_date    date NOT NULL,
  due_date        date NOT NULL,
  amount_total    numeric(18,2) NOT NULL CHECK (amount_total >= 0),
  amount_paid     numeric(18,2) NOT NULL DEFAULT 0,
  amount_outstanding numeric(18,2) GENERATED ALWAYS AS (amount_total - amount_paid) STORED,
  status          text NOT NULL DEFAULT 'open',  -- open|partial|paid|void|disputed
  category        text,
  csv_import_id   uuid REFERENCES csv_imports(id),
  source_row_no   int,
  remark          text,
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1,
  UNIQUE (company_id, invoice_no)
);
CREATE INDEX IF NOT EXISTS idx_ap_due ON ap_invoices (company_id, due_date)
  WHERE deleted_at IS NULL AND status NOT IN ('paid','void');

CREATE TABLE IF NOT EXISTS ap_payments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  ap_invoice_id   uuid NOT NULL REFERENCES ap_invoices(id) ON DELETE CASCADE,
  paid_date       date NOT NULL,
  amount          numeric(18,2) NOT NULL CHECK (amount > 0),
  bank_account_id uuid REFERENCES bank_accounts(id),
  pv_no           text,
  method          text,
  remark          text,
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1
);

-- auto-recompute ap_invoices.amount_paid + status from payments
CREATE OR REPLACE FUNCTION fn_ap_recompute() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invoice uuid := COALESCE(NEW.ap_invoice_id, OLD.ap_invoice_id);
  v_paid numeric;
  v_total numeric;
BEGIN
  SELECT COALESCE(SUM(amount),0) INTO v_paid
    FROM ap_payments WHERE ap_invoice_id = v_invoice AND deleted_at IS NULL;
  SELECT amount_total INTO v_total FROM ap_invoices WHERE id = v_invoice;
  UPDATE ap_invoices
    SET amount_paid = v_paid,
        status = CASE
          WHEN v_paid >= v_total THEN 'paid'
          WHEN v_paid > 0 THEN 'partial'
          ELSE 'open' END,
        updated_at = now()
    WHERE id = v_invoice;
  RETURN COALESCE(NEW, OLD);
END $$;

DROP TRIGGER IF EXISTS trg_ap_payments_recompute ON ap_payments;
CREATE TRIGGER trg_ap_payments_recompute
  AFTER INSERT OR UPDATE OR DELETE ON ap_payments
  FOR EACH ROW EXECUTE FUNCTION fn_ap_recompute();

-- ----------------------------------------------------------------
-- 3. RECURRING EXPENSES + OCCURRENCES
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recurring_expenses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name            text NOT NULL,
  category        text NOT NULL,
  vendor_id       uuid REFERENCES vendors(id),
  expected_amount numeric(18,2) NOT NULL CHECK (expected_amount > 0),
  amount_variance_pct numeric(5,2) NOT NULL DEFAULT 5,
  frequency       text NOT NULL CHECK (frequency IN ('monthly','quarterly','yearly','one_time')),
  day_of_month    smallint CHECK (day_of_month IS NULL OR (day_of_month BETWEEN -1 AND 31)),
  start_date      date NOT NULL,
  end_date        date,
  bank_account_id uuid REFERENCES bank_accounts(id),
  is_active       boolean NOT NULL DEFAULT true,
  remark          text,
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS recurring_occurrences (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  recurring_id    uuid NOT NULL REFERENCES recurring_expenses(id) ON DELETE CASCADE,
  due_date        date NOT NULL,
  expected_amount numeric(18,2) NOT NULL,
  status          text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','matched','skipped','paid')),
  matched_ap_id   uuid REFERENCES ap_invoices(id),
  matched_payment_id uuid REFERENCES ap_payments(id),
  created_at      timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at      timestamptz, deleted_by uuid,
  version         int NOT NULL DEFAULT 1,
  UNIQUE (recurring_id, due_date)
);
CREATE INDEX IF NOT EXISTS idx_recocc_company_date ON recurring_occurrences (company_id, due_date)
  WHERE deleted_at IS NULL;

-- materialise future occurrences for next N months (called by cron)
CREATE OR REPLACE FUNCTION fn_materialise_recurring(p_company uuid, p_months int DEFAULT 6)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r record;
  d date;
  end_horizon date := current_date + (p_months || ' months')::interval;
  n_added int := 0;
BEGIN
  FOR r IN
    SELECT * FROM recurring_expenses
    WHERE company_id = p_company AND is_active = true AND deleted_at IS NULL
      AND (end_date IS NULL OR end_date >= current_date)
  LOOP
    d := GREATEST(r.start_date, date_trunc('month', current_date)::date);
    WHILE d <= end_horizon LOOP
      -- align to day_of_month (negative = last day)
      IF r.day_of_month IS NOT NULL THEN
        IF r.day_of_month = -1 THEN
          d := (date_trunc('month', d) + INTERVAL '1 month - 1 day')::date;
        ELSE
          d := date_trunc('month', d)::date + (LEAST(r.day_of_month, EXTRACT(DAY FROM (date_trunc('month', d) + INTERVAL '1 month - 1 day'))::int) - 1);
        END IF;
      END IF;
      IF d >= r.start_date AND (r.end_date IS NULL OR d <= r.end_date) AND d >= current_date - INTERVAL '7 days' THEN
        INSERT INTO recurring_occurrences (company_id, recurring_id, due_date, expected_amount)
        VALUES (r.company_id, r.id, d, r.expected_amount)
        ON CONFLICT (recurring_id, due_date) DO NOTHING;
        GET DIAGNOSTICS n_added = ROW_COUNT;
      END IF;
      -- advance by frequency
      d := CASE r.frequency
        WHEN 'monthly'   THEN (d + INTERVAL '1 month')::date
        WHEN 'quarterly' THEN (d + INTERVAL '3 months')::date
        WHEN 'yearly'    THEN (d + INTERVAL '1 year')::date
        ELSE end_horizon + INTERVAL '1 day' -- one_time: stop
      END;
    END LOOP;
  END LOOP;
  RETURN n_added;
END $$;

-- ----------------------------------------------------------------
-- 4. GRANT + updated_at trigger + audit trigger (universal)
-- ----------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bank_accounts','bank_balances','vendors','ap_invoices','ap_payments',
    'recurring_expenses','recurring_occurrences','csv_imports'
  ] LOOP
    EXECUTE format('GRANT ALL ON %I TO authenticated', t);
    EXECUTE format('GRANT ALL ON %I TO service_role', t);
    EXECUTE format('GRANT ALL ON %I TO supabase_auth_admin', t);
    -- updated_at trigger (skip if function lacks version col handling)
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
      EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                      FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', t, t);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

-- ----------------------------------------------------------------
-- 5. RLS — per-company + per-role
-- ----------------------------------------------------------------
-- read: any user with company access
-- write: admin / finance_mgr / accountant (existing roles in user_company_access)

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bank_accounts','bank_balances','vendors','ap_invoices','ap_payments',
    'recurring_expenses','recurring_occurrences','csv_imports'
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

    -- soft delete = UPDATE, hard delete blocked at DB level (only admin can hard-delete via service_role)
    EXECUTE format('CREATE POLICY p_%s_delete ON %I FOR DELETE TO authenticated
                    USING (fn_my_role(company_id) IN (''admin'',''finance_mgr''))', t, t);
  END LOOP;
END $$;

SELECT 'finops phase1 schema ready' AS status;
