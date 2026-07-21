-- ★ เงินสดย่อย: เพิ่ม แผนก + ไฟล์แนบ (+ reimburse_round มีอยู่แล้ว)
-- idempotent · รันซ้ำได้ · petty_cash มีอยู่แล้ว (petty-cash.sql)
-- (re-trigger migrate 2026-07-20 · หลังต่ออายุ SUPABASE_ACCESS_TOKEN #2)
alter table public.petty_cash add column if not exists department  text;
alter table public.petty_cash add column if not exists attachments jsonb;   -- [{name, path, size, type}]
alter table public.petty_cash add column if not exists fund_holder text;     -- เจ้าของวงเงินสดย่อย (สรุปคงเหลือรายคน)
alter table public.petty_cash add column if not exists is_paid boolean not null default true;  -- จ่าย/โอนแล้ว (false = คุมในทะเบียนไว้ก่อน ยังไม่โอน) · ของเก่า default true

-- reload PostgREST schema cache (กัน PGRST204 หลัง DDL)
notify pgrst, 'reload schema';
