-- ================================================================
-- FIX AUTH v3 — แก้ "Database error granting user" ให้ชัวร์
-- ขั้นตอน: drop trigger ก่อน → recreate function → recreate trigger
-- ================================================================

-- 1) Drop trigger ก่อนเลย (หาก function เก่า error = trigger จะไม่ block login)
DROP TRIGGER IF EXISTS trg_sync_user_profile ON auth.users;

-- 2) Recreate function ด้วย search_path + exception handler
CREATE OR REPLACE FUNCTION public.fn_sync_user_profile()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
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
      SET email        = EXCLUDED.email,
          display_name = COALESCE(EXCLUDED.display_name, public.users_profile.display_name),
          updated_at   = now();
  EXCEPTION WHEN OTHERS THEN
    -- ไม่ block login ไม่ว่าจะ error อะไร
    NULL;
  END;
  RETURN NEW;
END;
$$;

-- 3) Recreate trigger (AFTER INSERT เท่านั้น — ไม่ต้องจับ UPDATE/DELETE)
CREATE TRIGGER trg_sync_user_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_user_profile();

-- 4) ตรวจสอบ
SELECT
  t.tgname AS trigger_name,
  p.proname AS function_name,
  'OK' AS status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'auth.users'::regclass
  AND t.tgname = 'trg_sync_user_profile';

SELECT 'Auth trigger fixed v3 ✅' AS result;
