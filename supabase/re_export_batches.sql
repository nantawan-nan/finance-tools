-- ใบส่งออก RE (รับชำระ) — จำว่าส่งออเดอร์ไหนไปคีย์ RE + เก็บผลตรวจกลับจากรายงาน 1.9.1
-- ★ mirror iv_export_batches · idempotent · RLS ปิด (แอปกรอง company_id เอง) · รันซ้ำได้
-- verify_status : exported | partial | verified   (ค่าว่าง = ยังไม่ตรวจ)
create table if not exists public.re_export_batches (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null,
  batch_no       text not null,
  date_from      date,
  date_to        date,
  channels       text[],
  start_re       text,
  end_re         text,
  order_count    int not null default 0,
  order_ids      jsonb,
  file_name      text,
  exported_by    uuid,
  exported_email text,
  exported_at    timestamptz default now(),
  note           text,
  verify_status  text,
  verified_at    timestamptz,
  verified_email text,
  verify_result  jsonb,
  created_at     timestamptz default now(),
  deleted_at     timestamptz
);

-- กัน clone เก่าที่ตารางมีอยู่แต่ยังไม่มีคอลัมน์ verify (idempotent)
alter table public.re_export_batches add column if not exists verify_status  text;
alter table public.re_export_batches add column if not exists verified_at    timestamptz;
alter table public.re_export_batches add column if not exists verified_email text;
alter table public.re_export_batches add column if not exists verify_result  jsonb;

create unique index if not exists uq_re_export_batches_no
  on public.re_export_batches(company_id, batch_no) where deleted_at is null;
create index if not exists idx_re_export_batches_exported
  on public.re_export_batches(company_id, exported_at desc) where deleted_at is null;

alter table public.re_export_batches disable row level security;

notify pgrst, 'reload schema';
