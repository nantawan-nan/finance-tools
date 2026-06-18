-- ================================================================
-- FIX AUTH v7 — ROOT CAUSE: users_profile ไม่มี + trigger เรียกถึง
-- error: "relation users_profile does not exist (SQLSTATE 42P01)"
-- กลยุทธ์: สร้าง users_profile + drop ทุก trigger/function ที่อ้างถึงมัน
-- ================================================================

-- 1) สร้าง users_profile (IF NOT EXISTS) — ปลอดภัย ไม่ทับของเดิม
CREATE TABLE IF NOT EXISTS public.users_profile (
  id            uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         text,
  display_name  text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- 2) Grant สิทธิ์ครบ (supabase_auth_admin ต้องอ่าน/เขียนได้)
GRANT ALL ON public.users_profile TO supabase_auth_admin;
GRANT ALL ON public.users_profile TO authenticated;
GRANT ALL ON public.users_profile TO service_role;
GRANT SELECT ON public.users_profile TO anon;

-- 3) ปิด RLS ก่อน เพื่อให้ trigger เขียนได้แน่นอน (จะเปิด policy ทีหลัง)
ALTER TABLE public.users_profile DISABLE ROW LEVEL SECURITY;

-- 4) Drop trigger ทุกตัวบน auth.users ที่ไม่ใช่ internal (สำคัญ!)
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
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users CASCADE', r.tgname);
    RAISE NOTICE 'Dropped trigger on auth.users: %', r.tgname;
  END LOOP;

  FOR r IN
    SELECT n.nspname AS s, c.relname AS t, tg.tgname
    FROM pg_trigger tg
    JOIN pg_class c ON c.oid = tg.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND NOT tg.tgisinternal
      AND tg.tgname NOT LIKE 'pg_%'
      AND tg.tgname NOT LIKE 'RI_%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I CASCADE', r.tgname, r.s, r.t);
    RAISE NOTICE 'Dropped trigger on %.%: %', r.s, r.t, r.tgname;
  END LOOP;
END $$;

-- 5) Drop ทุก function ที่อ้างถึง users_profile (CASCADE จะลบ trigger ที่ใช้ด้วย)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT n.nspname AS s, p.proname AS fname, oidvectortypes(p.proargtypes) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'auth')
      AND pg_get_functiondef(p.oid) ILIKE '%users_profile%'
  LOOP
    BEGIN
      EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE',
                     r.s, r.fname, r.args);
      RAISE NOTICE 'Dropped function: %.%(%)', r.s, r.fname, r.args;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not drop %.%: %', r.s, r.fname, SQLERRM;
    END;
  END LOOP;
END $$;

-- 6) สร้าง trigger ใหม่ที่ปลอดภัย (มี exception handler แน่นหนา)
CREATE OR REPLACE FUNCTION public.fn_sync_user_profile_safe()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, auth
AS $$
BEGIN
  BEGIN
    INSERT INTO public.users_profile (id, email, display_name)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email,'@',1))
    )
    ON CONFLICT (id) DO UPDATE
      SET email = EXCLUDED.email,
          updated_at = now();
  EXCEPTION WHEN OTHERS THEN
    -- ไม่ block login ไม่ว่าจะเกิดอะไรขึ้น
    NULL;
  END;
  RETURN NEW;
END;
$$;

-- 7) สิทธิ์ของ function ให้ครบ
GRANT EXECUTE ON FUNCTION public.fn_sync_user_profile_safe() TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.fn_sync_user_profile_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_sync_user_profile_safe() TO service_role;

-- 8) สร้าง trigger ใหม่ (AFTER INSERT เท่านั้น — ไม่จับ UPDATE)
CREATE TRIGGER trg_sync_user_profile_v7
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_user_profile_safe();

-- 9) Backfill (one-time) — user ที่มีอยู่ใน auth.users แต่ยังไม่มีใน users_profile
INSERT INTO public.users_profile (id, email, display_name)
SELECT u.id, u.email,
       COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email,'@',1))
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.users_profile p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- 10) สรุปสถานะ
SELECT
  (SELECT count(*) FROM auth.users) AS users,
  (SELECT count(*) FROM public.users_profile) AS profiles,
  (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal) AS auth_user_triggers,
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users_profile') AS users_profile_exists;

SELECT 'Auth v7 fix ✅ — users_profile created + safe trigger installed' AS result;
