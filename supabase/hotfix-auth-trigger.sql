-- ================================================================
-- HOTFIX: fn_sync_user_profile — แก้ "Database error granting user"
-- สาเหตุ: SECURITY DEFINER ขาด SET search_path + ไม่มี exception handler
-- ================================================================

-- แก้ function ให้ระบุ search_path ชัดเจน + กัน login block
CREATE OR REPLACE FUNCTION fn_sync_user_profile()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users_profile (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'display_name'
  )
  ON CONFLICT (id) DO UPDATE
    SET email        = EXCLUDED.email,
        display_name = COALESCE(EXCLUDED.display_name, public.users_profile.display_name),
        updated_at   = now();
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- ไม่ block login แม้ sync จะ error
  RETURN NEW;
END;
$$;

-- แก้ audit trigger ให้มี search_path เช่นกัน
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, auth
AS $$
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

  INSERT INTO public.audit_log_v2 (
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
EXCEPTION WHEN OTHERS THEN
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- แก้ fn_set_updated_at ให้มี search_path
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  NEW.version    = COALESCE(OLD.version, 0) + 1;
  RETURN NEW;
END;
$$;

-- แก้ fn_block_hard_delete ให้มี search_path
CREATE OR REPLACE FUNCTION fn_block_hard_delete()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Hard delete ถูกปิดบน "%" — ใช้ soft delete แทน', TG_TABLE_NAME;
END;
$$;

-- แก้ fn_my_companies + fn_my_role
CREATE OR REPLACE FUNCTION fn_my_companies()
RETURNS SETOF uuid LANGUAGE sql
SECURITY DEFINER SET search_path = public
STABLE AS $$
  SELECT company_id FROM public.user_company_access
  WHERE user_id = auth.uid() AND is_active = true AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_my_role(p_company_id uuid)
RETURNS text LANGUAGE sql
SECURITY DEFINER SET search_path = public
STABLE AS $$
  SELECT role FROM public.user_company_access
  WHERE user_id = auth.uid()
    AND company_id = p_company_id
    AND is_active = true
    AND deleted_at IS NULL
  LIMIT 1;
$$;

SELECT 'Hotfix auth trigger ✅' AS status;
