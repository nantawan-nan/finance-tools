-- ================================================================
-- PHASE 0: Foundation Migration
-- Finance Operations Platform — M Bark + Benya
-- วิธีรัน: Supabase Dashboard → SQL Editor → วาง → Run
-- ================================================================

-- ----------------------------------------------------------------
-- STEP 1: COMPANIES (master)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS companies (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text        NOT NULL,
  name          text        NOT NULL,
  legal_name    text,
  tax_id        text,
  base_currency char(3)     NOT NULL DEFAULT 'THB',
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  updated_by    uuid,
  deleted_at    timestamptz,
  deleted_by    uuid,
  version       int         NOT NULL DEFAULT 1,
  CONSTRAINT companies_code_unique UNIQUE (code)
);

-- Seed บริษัท
INSERT INTO companies (code, name, legal_name, is_active) VALUES
  ('MBARC', 'M Bark',  'M Bark Co., Ltd.',                       true),
  ('BENYA', 'Benya',   'Benya Medical Innovations Co., Ltd.',     true)
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------
-- STEP 2: USERS PROFILE (mirrors auth.users)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_profile (
  id            uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         text        NOT NULL,
  display_name  text,
  is_active     boolean     NOT NULL DEFAULT true,
  last_login_at timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  updated_by    uuid,
  deleted_at    timestamptz,
  deleted_by    uuid,
  version       int         NOT NULL DEFAULT 1
);

-- Auto-sync เมื่อ Supabase Auth สร้าง user ใหม่
-- ⚠️ SAFE VERSION: AFTER INSERT only + exception handler — ไม่ block login
CREATE OR REPLACE FUNCTION fn_sync_user_profile()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  BEGIN
    INSERT INTO public.users_profile (id, email, display_name)
    VALUES (NEW.id, NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email,'@',1)))
    ON CONFLICT (id) DO UPDATE
      SET email        = EXCLUDED.email,
          display_name = COALESCE(EXCLUDED.display_name, public.users_profile.display_name),
          updated_at   = now();
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- ห้าม block login เด็ดขาด
  END;
  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_sync_user_profile() TO supabase_auth_admin;

DROP TRIGGER IF EXISTS trg_sync_user_profile ON auth.users;
CREATE TRIGGER trg_sync_user_profile
  AFTER INSERT ON auth.users   -- ★ INSERT only — UPDATE (login last_sign_in) จะไม่ fire
  FOR EACH ROW EXECUTE FUNCTION fn_sync_user_profile();

-- Backfill users ที่มีอยู่แล้ว
INSERT INTO users_profile (id, email, display_name)
SELECT id, email, raw_user_meta_data->>'display_name'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------
-- STEP 3: USER_COMPANY_ACCESS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_company_access (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid    NOT NULL REFERENCES auth.users(id),
  company_id  uuid    NOT NULL REFERENCES companies(id),
  role        text    NOT NULL CHECK (role IN (
    'admin','finance_mgr','accountant','treasury',
    'sales_ops','approver','executive','viewer'
  )),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid,
  deleted_at  timestamptz,
  deleted_by  uuid,
  version     int     NOT NULL DEFAULT 1,
  CONSTRAINT uca_user_company_unique UNIQUE (user_id, company_id)
);

-- Grant แนน (admin) ทั้งสองบริษัท
-- หลังรัน SQL นี้ ให้รัน INSERT เพิ่มอีกครั้งเมื่อรู้ UUID ของแนน:
-- INSERT INTO user_company_access (user_id, company_id, role)
-- SELECT '<UUID ของแนน>', id, 'admin' FROM companies
-- ON CONFLICT (user_id, company_id) DO NOTHING;

-- ----------------------------------------------------------------
-- STEP 4: AUDIT LOG V2 (append-only, trigger-driven)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log_v2 (
  id             bigserial   PRIMARY KEY,
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  user_id        uuid,
  user_email     text,
  company_id     uuid,
  table_name     text        NOT NULL,
  row_id         text,
  action         text        NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE','RESTORE')),
  old_data       jsonb,
  new_data       jsonb,
  changed_fields text[]
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_auditv2_table_row  ON audit_log_v2 (table_name, row_id);
CREATE INDEX IF NOT EXISTS idx_auditv2_occurred   ON audit_log_v2 (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_auditv2_user       ON audit_log_v2 (user_id);
CREATE INDEX IF NOT EXISTS idx_auditv2_company    ON audit_log_v2 (company_id, occurred_at DESC);

-- Append-only: revoke modification
REVOKE UPDATE, DELETE ON audit_log_v2 FROM authenticated, anon;

-- ----------------------------------------------------------------
-- STEP 5: UNIVERSAL COLUMNS บนตารางที่มีอยู่
-- ----------------------------------------------------------------

-- orders
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS company_id  uuid REFERENCES companies(id),
  ADD COLUMN IF NOT EXISTS created_by  uuid,
  ADD COLUMN IF NOT EXISTS updated_by  uuid,
  ADD COLUMN IF NOT EXISTS deleted_at  timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by  uuid,
  ADD COLUMN IF NOT EXISTS version     int NOT NULL DEFAULT 1;

-- Backfill company_id จาก text column 'company'
UPDATE orders o
SET company_id = c.id
FROM companies c
WHERE LOWER(o.company) = LOWER(c.code)
  AND o.company_id IS NULL;

-- order_items
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS company_id  uuid REFERENCES companies(id),
  ADD COLUMN IF NOT EXISTS created_at  timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_by  uuid,
  ADD COLUMN IF NOT EXISTS updated_at  timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_by  uuid,
  ADD COLUMN IF NOT EXISTS deleted_at  timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by  uuid,
  ADD COLUMN IF NOT EXISTS version     int NOT NULL DEFAULT 1;

-- Backfill order_items company_id จาก orders
UPDATE order_items oi
SET company_id = o.company_id
FROM orders o
WHERE oi.order_no = o.order_no
  AND oi.company_id IS NULL;

-- sku_master
ALTER TABLE sku_master
  ADD COLUMN IF NOT EXISTS company_id  uuid REFERENCES companies(id),
  ADD COLUMN IF NOT EXISTS updated_at  timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_by  uuid,
  ADD COLUMN IF NOT EXISTS deleted_at  timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by  uuid,
  ADD COLUMN IF NOT EXISTS version     int NOT NULL DEFAULT 1;

-- Backfill sku_master company_id
UPDATE sku_master s
SET company_id = c.id
FROM companies c
WHERE LOWER(s.company) = LOWER(c.code)
  AND s.company_id IS NULL;

-- SR columns (pending from last session)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS sr_no   text,
  ADD COLUMN IF NOT EXISTS sr_date date;

-- ----------------------------------------------------------------
-- STEP 6: UPDATED_AT + VERSION TRIGGER
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  NEW.version    = COALESCE(OLD.version, 0) + 1;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_updated_at     ON orders;
DROP TRIGGER IF EXISTS trg_sku_updated_at        ON sku_master;
DROP TRIGGER IF EXISTS trg_companies_updated_at  ON companies;
DROP TRIGGER IF EXISTS trg_uca_updated_at        ON user_company_access;

CREATE TRIGGER trg_orders_updated_at     BEFORE UPDATE ON orders            FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_sku_updated_at        BEFORE UPDATE ON sku_master        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_companies_updated_at  BEFORE UPDATE ON companies         FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_uca_updated_at        BEFORE UPDATE ON user_company_access FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ----------------------------------------------------------------
-- STEP 7: AUDIT TRIGGER
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_changed text[];
  v_uid     uuid;
  v_email   text;
  v_company uuid;
BEGIN
  BEGIN
    v_uid   := auth.uid();
    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL; v_email := 'system';
  END;

  v_company := CASE WHEN TG_OP = 'DELETE' THEN OLD.company_id ELSE NEW.company_id END;

  IF TG_OP = 'UPDATE' THEN
    SELECT array_agg(key) INTO v_changed
    FROM jsonb_each(to_jsonb(NEW)) n
    WHERE to_jsonb(OLD)->key IS DISTINCT FROM n.value
      AND key NOT IN ('updated_at','updated_by','version');

    IF v_changed IS NULL OR cardinality(v_changed) = 0 THEN
      RETURN NEW;
    END IF;
  END IF;

  INSERT INTO audit_log_v2 (
    occurred_at, user_id, user_email, company_id,
    table_name, row_id, action,
    old_data, new_data, changed_fields
  ) VALUES (
    now(), v_uid, v_email, v_company,
    TG_TABLE_NAME,
    COALESCE(NEW.id::text, OLD.id::text),
    TG_OP,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END,
    v_changed
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_orders  ON orders;
DROP TRIGGER IF EXISTS trg_audit_items   ON order_items;
DROP TRIGGER IF EXISTS trg_audit_sku     ON sku_master;
DROP TRIGGER IF EXISTS trg_audit_uca     ON user_company_access;

CREATE TRIGGER trg_audit_orders  AFTER INSERT OR UPDATE OR DELETE ON orders            FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_items   AFTER INSERT OR UPDATE OR DELETE ON order_items       FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_sku     AFTER INSERT OR UPDATE OR DELETE ON sku_master        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_uca     AFTER INSERT OR UPDATE OR DELETE ON user_company_access FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- ----------------------------------------------------------------
-- STEP 8: SOFT DELETE GUARD (ห้าม hard delete บน orders)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_block_hard_delete()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION
    'Hard delete ถูกปิดบน "%" — ใช้ soft delete: UPDATE % SET deleted_at=now(), deleted_by=auth.uid() WHERE id=''%''',
    TG_TABLE_NAME, TG_TABLE_NAME, OLD.id;
END;
$$;

DROP TRIGGER IF EXISTS trg_nodelete_orders ON orders;
DROP TRIGGER IF EXISTS trg_nodelete_items  ON order_items;

CREATE TRIGGER trg_nodelete_orders BEFORE DELETE ON orders       FOR EACH ROW EXECUTE FUNCTION fn_block_hard_delete();
CREATE TRIGGER trg_nodelete_items  BEFORE DELETE ON order_items  FOR EACH ROW EXECUTE FUNCTION fn_block_hard_delete();

-- ----------------------------------------------------------------
-- STEP 9: VIEWS (active rows only)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW v_orders AS
  SELECT * FROM orders WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW v_order_items AS
  SELECT * FROM order_items WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW v_sku_master AS
  SELECT * FROM sku_master WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- STEP 10: RLS — HELPER FUNCTIONS + POLICIES
-- ----------------------------------------------------------------
ALTER TABLE companies          ENABLE ROW LEVEL SECURITY;
ALTER TABLE users_profile      ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_company_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log_v2       ENABLE ROW LEVEL SECURITY;

-- Helper: บริษัทที่ user มีสิทธิ์
CREATE OR REPLACE FUNCTION fn_my_companies()
RETURNS SETOF uuid LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT company_id FROM user_company_access
  WHERE user_id = auth.uid() AND is_active = true AND deleted_at IS NULL;
$$;

-- Helper: role ของ user ในบริษัทนั้น
CREATE OR REPLACE FUNCTION fn_my_role(p_company_id uuid)
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM user_company_access
  WHERE user_id = auth.uid()
    AND company_id = p_company_id
    AND is_active = true
    AND deleted_at IS NULL
  LIMIT 1;
$$;

-- companies
DROP POLICY IF EXISTS p_companies_read ON companies;
CREATE POLICY p_companies_read ON companies FOR SELECT TO authenticated
  USING (id IN (SELECT fn_my_companies()));

-- users_profile — เห็นได้ทุก user ใน authenticated (สำหรับ dropdown assign)
DROP POLICY IF EXISTS p_profile_read ON users_profile;
CREATE POLICY p_profile_read ON users_profile FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS p_profile_write ON users_profile;
CREATE POLICY p_profile_write ON users_profile FOR ALL TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- user_company_access
DROP POLICY IF EXISTS p_uca_read   ON user_company_access;
DROP POLICY IF EXISTS p_uca_admin  ON user_company_access;

CREATE POLICY p_uca_read ON user_company_access FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR company_id IN (
    SELECT company_id FROM user_company_access
    WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true
  ));

CREATE POLICY p_uca_admin ON user_company_access FOR ALL TO authenticated
  USING (fn_my_role(company_id) = 'admin')
  WITH CHECK (fn_my_role(company_id) = 'admin');

-- audit_log_v2 — finance_mgr + admin อ่านได้
DROP POLICY IF EXISTS p_audit_read ON audit_log_v2;
CREATE POLICY p_audit_read ON audit_log_v2 FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr'));

-- orders — อัปเดต policy ให้ใช้ company_id UUID
DROP POLICY IF EXISTS p_orders_read   ON orders;
DROP POLICY IF EXISTS p_orders_write  ON orders;
DROP POLICY IF EXISTS p_orders_update ON orders;

CREATE POLICY p_orders_read ON orders FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));

CREATE POLICY p_orders_write ON orders FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','sales_ops')
  );

CREATE POLICY p_orders_update ON orders FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT fn_my_companies())
    AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','sales_ops')
  );

-- ----------------------------------------------------------------
-- STEP 11: INDEXES
-- ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_company     ON orders (company_id)                   WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_status      ON orders (company_id, status)            WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_sale_date   ON orders (company_id, sale_date DESC)    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_iv_no       ON orders (company_id, iv_no)             WHERE deleted_at IS NULL AND iv_no IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_items_order_no     ON order_items (order_no, company_id);
CREATE INDEX IF NOT EXISTS idx_sku_company_sku    ON sku_master (company_id, sku)           WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- VERIFY
-- ----------------------------------------------------------------
SELECT
  (SELECT count(*) FROM companies)            AS companies,
  (SELECT count(*) FROM users_profile)        AS users_profile,
  (SELECT count(*) FROM orders)               AS orders,
  (SELECT count(*) FROM orders WHERE company_id IS NOT NULL) AS orders_with_company_id,
  (SELECT count(*) FROM sku_master)           AS sku_master,
  'Phase 0 Foundation ✅'                     AS status;
