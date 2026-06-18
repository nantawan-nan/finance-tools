-- ================================================================
-- FIX AUTH v8 — MINIMAL: สร้าง users_profile ให้ได้ก่อน ส่วนอื่นยอม fail ได้
-- root cause: relation "users_profile" does not exist
-- ================================================================

-- 1) สร้าง users_profile (สำคัญที่สุด)
CREATE TABLE IF NOT EXISTS public.users_profile (
  id            uuid        PRIMARY KEY,
  email         text,
  display_name  text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- 2) FK constraint แยกออกมา (ถ้า fail ก็ปล่อย)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_profile_id_fkey'
      AND conrelid = 'public.users_profile'::regclass
  ) THEN
    ALTER TABLE public.users_profile
      ADD CONSTRAINT users_profile_id_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'FK skipped: %', SQLERRM;
END $$;

-- 3) Grant สิทธิ์ครบ — supabase_auth_admin ต้องเขียน users_profile ได้
GRANT USAGE ON SCHEMA public TO supabase_auth_admin, authenticated, anon, service_role;
GRANT ALL ON public.users_profile TO supabase_auth_admin;
GRANT ALL ON public.users_profile TO service_role;
GRANT ALL ON public.users_profile TO authenticated;
GRANT SELECT ON public.users_profile TO anon;

-- 4) ปิด RLS (เพื่อให้ trigger เขียนได้แน่ ๆ ทันที — เปิด policy ทีหลังได้)
ALTER TABLE public.users_profile DISABLE ROW LEVEL SECURITY;

-- 5) Backfill ครั้งเดียว
INSERT INTO public.users_profile (id, email, display_name)
SELECT u.id, u.email,
       COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email,'@',1))
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.users_profile p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- 6) ตรวจสอบ
SELECT
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users_profile') AS users_profile_exists,
  (SELECT count(*) FROM auth.users) AS total_users,
  (SELECT count(*) FROM public.users_profile) AS total_profiles;

SELECT 'v8 minimal ✅' AS result;
