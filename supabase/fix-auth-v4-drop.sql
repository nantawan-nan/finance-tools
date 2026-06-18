-- ================================================================
-- FIX AUTH v4 — DROP trigger ทั้งหมดบน auth.users (ฉุกเฉิน)
-- ทำให้ login ทำงานได้ทันที — sync profile ทีหลังด้วย backfill
-- ================================================================

-- 1) ลบ trigger ของเราออกจาก auth.users (ไม่ block login อีก)
DROP TRIGGER IF EXISTS trg_sync_user_profile ON auth.users;

-- 2) ตรวจว่ามี trigger อื่นที่เราอาจเผลอใส่ไว้บน auth.users มั้ย
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tgname
    FROM pg_trigger
    WHERE tgrelid = 'auth.users'::regclass
      AND tgname NOT LIKE 'pg_%'              -- ข้าม internal trigger
      AND tgname NOT LIKE 'RI_%'              -- ข้าม FK trigger
      AND tgisinternal = false                -- ไม่ใช่ internal
      AND tgname LIKE 'trg_%'                 -- ของเราตั้งชื่อ trg_*
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', r.tgname);
    RAISE NOTICE 'Dropped trigger: %', r.tgname;
  END LOOP;
END $$;

-- 3) Backfill users_profile จาก auth.users (สำหรับ user ที่มีอยู่แล้ว)
INSERT INTO public.users_profile (id, email, display_name)
SELECT u.id, u.email,
       COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email,'@',1))
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.users_profile p WHERE p.id = u.id
);

-- 4) แสดง trigger ที่เหลืออยู่บน auth.users (ตรวจสอบ)
SELECT
  t.tgname AS trigger_name,
  pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal;

SELECT 'Auth triggers cleared ✅ — login ใช้ได้แล้ว' AS result;
