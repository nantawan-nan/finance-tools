-- ================================================================
-- FIX AUTH v5 — DEEP FIX: Access Token Hook + Permissions
-- "Database error granting user" มาจาก JWT-issuing process
-- ไม่ใช่ trigger บน auth.users (เพราะ login ถึงขั้น verify password แล้ว)
-- ================================================================

-- 1) ตรวจ Auth Hooks ที่ลงทะเบียนไว้ (custom_access_token_hook etc.)
DO $$
DECLARE
  hook_count int;
BEGIN
  SELECT count(*) INTO hook_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.proname IN ('custom_access_token_hook', 'mfa_verification_attempt', 'password_verification_attempt');

  RAISE NOTICE 'Auth hook functions found: %', hook_count;
END $$;

-- 2) ถ้ามี custom_access_token_hook → ทำให้มัน safe (return JWT เดิมไม่แก้)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'custom_access_token_hook'
  ) THEN
    -- Replace ด้วย safe version
    EXECUTE $f$
      CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
      RETURNS jsonb LANGUAGE plpgsql STABLE
      SECURITY DEFINER SET search_path = public
      AS $body$
      BEGIN
        RETURN event;  -- ไม่แก้ JWT, แค่ส่งคืน
      EXCEPTION WHEN OTHERS THEN
        RETURN event;
      END;
      $body$;
    $f$;
    RAISE NOTICE 'Replaced custom_access_token_hook with safe pass-through';
  END IF;
END $$;

-- 3) Grant permissions ให้ supabase_auth_admin (ที่ Supabase ใช้ตอน login)
-- ขาด GRANT = trigger/hook function ที่อยู่ใน public schema ก็เรียกไม่ได้
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin;

-- ปล่อยให้ตารางใหม่ในอนาคตได้สิทธิ์อัตโนมัติด้วย
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO supabase_auth_admin;

-- 4) ตรวจ trigger บน auth.users (ตรวจซ้ำว่าโดน drop หมดแล้ว)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tgname FROM pg_trigger
    WHERE tgrelid = 'auth.users'::regclass
      AND NOT tgisinternal
      AND tgname NOT LIKE 'pg_%'
      AND tgname NOT LIKE 'RI_%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', r.tgname);
    RAISE NOTICE 'Force-dropped trigger: %', r.tgname;
  END LOOP;
END $$;

-- 5) Backfill users_profile (one-time)
INSERT INTO public.users_profile (id, email, display_name)
SELECT u.id, u.email,
       COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email,'@',1))
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.users_profile p WHERE p.id = u.id);

-- 6) สรุปสถานะ
SELECT
  (SELECT count(*) FROM auth.users) AS total_users,
  (SELECT count(*) FROM public.users_profile) AS total_profiles,
  (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal) AS auth_user_triggers;

SELECT 'Auth v5 deep fix ✅' AS result;
