-- SKU master (สินค้า/สต็อก/ทุน/ราคา/รูป) จากไฟล์ BigSeller — ใช้ใน Sales Dashboard
-- ★ idempotent · RLS ปิด (แอปกรอง company_id เอง) · อัปครั้งเดียว ทุกคนเห็นชุดเดียวกัน
create table if not exists public.sku_master (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null,
  sku           text not null,
  name          text,
  brand         text,
  category      text,
  cost          numeric,
  price         numeric,
  stock         numeric,
  image_url     text,
  updated_at    timestamptz default now(),
  updated_email text
);
-- กัน clone/ตารางเก่าที่มีอยู่แต่คอลัมน์ไม่ครบ (CREATE IF NOT EXISTS จะข้ามการสร้างคอลัมน์)
alter table public.sku_master add column if not exists name       text;
alter table public.sku_master add column if not exists brand      text;
alter table public.sku_master add column if not exists category   text;
alter table public.sku_master add column if not exists cost       numeric;
alter table public.sku_master add column if not exists price      numeric;
alter table public.sku_master add column if not exists stock      numeric;
alter table public.sku_master add column if not exists image_url  text;
alter table public.sku_master add column if not exists updated_at timestamptz default now();
alter table public.sku_master add column if not exists updated_email text;

create unique index if not exists uq_sku_master on public.sku_master(company_id, sku);
create index if not exists idx_sku_master_co on public.sku_master(company_id);

alter table public.sku_master disable row level security;
notify pgrst, 'reload schema';
