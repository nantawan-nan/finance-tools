-- เพิ่มคอลัมน์เก็บ "ผลตรวจการคีย์ (verify)" ต่อใบส่งออก IV
-- ★ idempotent · รันซ้ำได้ · ต้องรันหลัง iv_export_batches.sql
--   (ชื่อไฟล์ "iv_export_batches_verify.sql" sort หลัง "iv_export_batches.sql" เพราะ '.' < '_')
-- verify_status : exported | partial | verified   (ค่าว่าง = ยังไม่ตรวจ)
-- verify_result : {expected,keyed,missing[],extra[],checked_at,checked_by}
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='iv_export_batches') then
    alter table public.iv_export_batches add column if not exists verify_status  text;
    alter table public.iv_export_batches add column if not exists verified_at    timestamptz;
    alter table public.iv_export_batches add column if not exists verified_email text;
    alter table public.iv_export_batches add column if not exists verify_result  jsonb;
  end if;
end $$;

notify pgrst, 'reload schema';
