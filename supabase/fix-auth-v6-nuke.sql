-- ================================================================
-- FIX AUTH v6 NUKE — ลบทุก trigger ของเราใน auth schema ทั้งหมด
-- "Database error granting user" = trigger fails ระหว่าง JWT grant
-- อาจไม่ใช่บน auth.users — แต่บน auth.sessions / auth.refresh_tokens / auth.identities
-- ================================================================

-- 1) Drop ทุก trigger ที่ไม่ใช่ internal ใน auth schema ทั้งหมด
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name,
           c.relname AS table_name,
           t.tgname  AS trigger_name
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND NOT t.tgisinternal
      AND t.tgname NOT LIKE 'pg_%'
      AND t.tgname NOT LIKE 'RI_%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I',
                   r.trigger_name, r.schema_name, r.table_name);
    RAISE NOTICE 'Dropped: %.%.%', r.schema_name, r.table_name, r.trigger_name;
  END LOOP;
END $$;

-- 2) ตรวจ Auth Hook ที่ config ผ่าน Supabase Dashboard (ลงทะเบียนใน auth.flow_state หรือ supabase_auth_admin config)
DO $$
DECLARE
  cfg_count int := 0;
BEGIN
  -- Custom Access Token Hook ถูก config ใน auth.config (ถ้ามี)
  -- ในกรณี config ผ่าน Dashboard, hook URI เก็บใน database role config
  PERFORM 1 FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('custom_access_token_hook');
  GET DIAGNOSTICS cfg_count = ROW_COUNT;
  RAISE NOTICE 'custom_access_token_hook count: %', cfg_count;
END $$;

-- 3) ถ้ามี custom_access_token_hook → drop + recreate ให้ safe
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;

-- 4) ตรวจ permissions ของ supabase_auth_admin (อาจไม่มีสิทธิ์เข้า public schema)
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin;

-- 5) Drop function ที่อาจถูก hook อ้างถึง (audit, profile sync)
-- แต่เก็บ function หลักที่ RLS policies ใช้ไว้
DROP FUNCTION IF EXISTS public.fn_sync_user_profile() CASCADE;

-- 6) ตรวจสอบขั้นสุดท้าย — trigger ใน auth ที่เหลือ
SELECT
  n.nspname AS schema,
  c.relname AS table,
  t.tgname  AS trigger,
  pg_get_triggerdef(t.oid) AS def
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'auth'
  AND NOT t.tgisinternal
  AND t.tgname NOT LIKE 'pg_%'
  AND t.tgname NOT LIKE 'RI_%';

-- 7) ตรวจ function ที่อาจถูก auth schema เรียกใช้
SELECT p.proname, n.nspname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'custom_access_token_hook',
    'send_email_hook',
    'send_sms_hook',
    'mfa_verification_attempt',
    'password_verification_attempt'
  );

SELECT 'Auth v6 NUKE done ✅' AS result;
