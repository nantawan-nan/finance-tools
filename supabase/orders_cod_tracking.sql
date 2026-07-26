-- COD link phase 2: เก็บเลขพัสดุ + ชื่อผู้รับ ใน order_ledger
-- ใช้ลิงก์ "พัสดุ COD (iShip) → ออเดอร์ในระบบ" ในแท็บ COD ขนส่ง
-- idempotent · ต้อง push ให้ migration รัน + re-import BigSeller (ที่มีคอลัมน์เลขพัสดุ) ให้ backfill
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='order_ledger') then
    alter table public.order_ledger add column if not exists tracking_no text;
    alter table public.order_ledger add column if not exists recipient   text;
    -- index ช่วยค้นเลขพัสดุตอนลิงก์ COD (partial · เฉพาะที่มีค่า)
    create index if not exists idx_order_ledger_tracking
      on public.order_ledger (company_id, tracking_no)
      where tracking_no is not null and deleted_at is null;
  end if;
exception when others then
  raise notice 'orders_cod_tracking: %', sqlerrm;
end $$;
notify pgrst, 'reload schema';
