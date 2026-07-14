-- ทะเบียนคุมเงินทดรองจ่าย (Advance / Imprest Register) — ต่อบริษัท ต่อพนักงาน
-- ★ idempotent · RLS ปิด (แอปกรอง company_id เอง เหมือน petty_cash)
create table if not exists public.advances (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null,
  employee_name  text not null,           -- พนักงานผู้เบิก
  advance_no     text,                    -- ชุดเบิก (เลขเอกสารเบิก)
  advance_date   date,                    -- วันที่เบิก
  purpose        text,                    -- เบิกค่าอะไร / วัตถุประสงค์
  category       text,                    -- หมวด (เดินทาง/จัดซื้อ ...)
  amount         numeric default 0,       -- ยอดเบิก
  cleared_amount numeric default 0,       -- เคลียร์แล้ว (บาท)
  clear_no       text,                    -- เคลียร์กับชุดไหน (เลขเอกสารเคลียร์)
  clear_date     date,                    -- วันที่เคลียร์
  status         text default 'open',     -- open | partial | cleared
  note           text,
  created_at     timestamptz default now(),
  created_by     uuid,
  updated_at     timestamptz default now(),
  updated_by     uuid,
  deleted_at     timestamptz,
  deleted_by     uuid
);
-- เผื่อ clone เก่าที่ตารางมีอยู่แต่คอลัมน์ไม่ครบ
alter table public.advances add column if not exists category       text;
alter table public.advances add column if not exists cleared_amount numeric default 0;
alter table public.advances add column if not exists clear_no       text;
alter table public.advances add column if not exists clear_date     date;
alter table public.advances add column if not exists status         text default 'open';

create index if not exists idx_advances_co  on public.advances(company_id) where deleted_at is null;
create index if not exists idx_advances_emp on public.advances(company_id, employee_name) where deleted_at is null;

alter table public.advances disable row level security;
grant all on public.advances to authenticated, service_role;

notify pgrst, 'reload schema';
select 'advances table ready' as result;
