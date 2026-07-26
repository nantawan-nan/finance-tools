-- ถอน Marketplace: ติ๊ก "ดำเนินการแล้ว" (คีย์ BQ เสร็จ) → แยกแท็บรอ/เสร็จ
-- idempotent
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='brec_mp_withdrawals') then
    alter table public.brec_mp_withdrawals add column if not exists done boolean not null default false;
    alter table public.brec_mp_withdrawals add column if not exists done_at timestamptz;
  end if;
exception when others then
  raise notice 'zz-bankrec-mp-done: %', sqlerrm;
end $$;
notify pgrst, 'reload schema';
