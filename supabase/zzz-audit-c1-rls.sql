-- =====================================================================
-- zzz-audit-c1-rls.sql  (Pre-production audit · Phase 0 · C1)
--   เปิด RLS (ด่านกั้นสิทธิ์ฝั่ง server) บนตารางการเงินที่เดิม "ปิด RLS + GRANT ALL TO authenticated"
--   → กันข้อมูลข้ามบริษัท: ผู้ใช้เห็น/เขียนได้เฉพาะบริษัทที่ตัวเองมีสิทธิ์ (user_company_access)
--
-- ★ ทำเฉพาะตารางที่ใช้ company_id (uuid) — จับคู่ fn_my_companies() ได้สะอาด
--   (แพทเทิร์นเดียวกับ finops-phase1 ที่เปิด RLS อยู่แล้วและใช้งานได้ปกติ = พิสูจน์แล้วกับ DB นี้)
-- ★ ตาราง company text ('benya'/'mbark') — order_recon/order_recon_runs/import_column_map/
--   shop_registry/order_adjustments/recon_reports — ★ ยังไม่ทำที่นี่ (code 'MBARC' ≠ ค่าเก็บ 'mbark'
--   ต้อง map ให้ตรงก่อน กันล็อก M Bark) → ทำแยกรอบถัดไปหลังตรวจค่าที่เก็บจริง
-- ★ user_presence / users_profile — ไม่ใช่ตารางการเงิน + เคยถูกปิด RLS โดยตั้งใจ (fix-auth-v8) → เว้นไว้
--
-- ★ WRITE policy = scope ด้วย "บริษัท" (ไม่ล็อกด้วย role) เพื่อไม่ให้เวิร์กโฟลว์ของ role ใด role หนึ่งพัง
--   (เช่น sales_ops import ออเดอร์, catbot เขียน rules) — การกั้น role รายตาราง = Phase 2 หลังตรวจครบ
--   ★ ปิดรูรั่วหลัก (ข้ามบริษัท + บัญชี present จากที่อื่น) ได้แล้วด้วย company scope
--
-- ★ idempotent · EXCEPTION-wrapped ต่อ "ตาราง" → ตารางใดพลาดไม่ทำ CI แดง/ไม่กระทบตารางอื่น
-- ★ ROLLBACK: push migration ที่ ALTER TABLE <t> DISABLE ROW LEVEL SECURITY (หรือ Supabase SQL editor)
-- =====================================================================
DO $$
DECLARE
  t text;
  tbls text[] := ARRAY[
    'order_ledger','order_events',
    'sales_income_rows','re_export_batches',
    'ap_payment_vouchers',
    'petty_cash','petty_cash_rounds',
    'advances','sku_master','catbot_rules',
    'iv_export_batches','documents'
  ];
BEGIN
  FOREACH t IN ARRAY tbls LOOP
    BEGIN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format('DROP POLICY IF EXISTS p_%s_r ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS p_%s_w ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS p_%s_u ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS p_%s_d ON public.%I', t, t);
      -- อ่าน: เฉพาะบริษัทที่มีสิทธิ์
      EXECUTE format(
        'CREATE POLICY p_%s_r ON public.%I FOR SELECT TO authenticated
           USING (company_id IN (SELECT fn_my_companies()))', t, t);
      -- เพิ่ม: ลงได้เฉพาะบริษัทของตัวเอง
      EXECUTE format(
        'CREATE POLICY p_%s_w ON public.%I FOR INSERT TO authenticated
           WITH CHECK (company_id IN (SELECT fn_my_companies()))', t, t);
      -- แก้: เฉพาะแถวบริษัทของตัวเอง (soft-delete = UPDATE ด้วย)
      EXECUTE format(
        'CREATE POLICY p_%s_u ON public.%I FOR UPDATE TO authenticated
           USING (company_id IN (SELECT fn_my_companies()))
           WITH CHECK (company_id IN (SELECT fn_my_companies()))', t, t);
      -- ลบจริง (hard delete): เฉพาะบริษัทของตัวเอง (ปกติแอปใช้ soft-delete)
      EXECUTE format(
        'CREATE POLICY p_%s_d ON public.%I FOR DELETE TO authenticated
           USING (company_id IN (SELECT fn_my_companies()))', t, t);
      RAISE NOTICE 'RLS enabled: %', t;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'RLS % skipped: %', t, SQLERRM;
    END;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
