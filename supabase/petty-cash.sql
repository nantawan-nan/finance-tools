-- ทะเบียนคุมเงินสดย่อย (Petty Cash Control Register) — ต่อบริษัท ต่อรอบ
-- ★ idempotent · RLS ปิด (แอปกรอง company_id เอง)
create table if not exists public.petty_cash (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null,
  round_label    text,                 -- รอบ (เช่น "2026-06")
  doc_date       date,                 -- วันที่ตรวจเอกสาร
  pay_date       date,                 -- วันที่จ่ายเงิน
  doc_no         text,                 -- เลขที่เอกสาร
  requester      text,                 -- ผู้เบิก
  description    text,                 -- รายการ
  amount_in      numeric default 0,    -- รับ/เติมเงินสดย่อย
  amount_out     numeric default 0,    -- จ่าย (เบิก)
  reimburse_round text,                -- เบิกคืนเข้ารอบ
  note           text,
  seq            int default 0,        -- ลำดับในรอบ
  created_at     timestamptz default now(),
  created_by     uuid,
  updated_at     timestamptz default now(),
  deleted_at     timestamptz
);
alter table public.petty_cash add column if not exists reimburse_round text;
alter table public.petty_cash add column if not exists seq int default 0;
create index if not exists idx_petty_cash_co on public.petty_cash(company_id, round_label) where deleted_at is null;

-- ยอดยกมาต้นรอบ + หมายเหตุรอบ
create table if not exists public.petty_cash_rounds (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null,
  round_label     text not null,
  opening_balance numeric default 0,
  note            text,
  updated_at      timestamptz default now()
);
create unique index if not exists uq_petty_cash_rounds on public.petty_cash_rounds(company_id, round_label);

alter table public.petty_cash        disable row level security;
alter table public.petty_cash_rounds disable row level security;
notify pgrst, 'reload schema';
