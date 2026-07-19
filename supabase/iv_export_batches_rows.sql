-- ★ เก็บ "รหัสลูกค้าที่ส่งออกจริง" รายใบลง batch ถาวร (snapshot ตอนส่งออก)
-- idempotent · รันซ้ำได้ · ต้องรันหลัง iv_export_batches.sql (guard table exists)
--   ('_rows' sort หลัง '.' ของ iv_export_batches.sql → รันหลังตารางถูกสร้าง)
DO $$
BEGIN
  IF EXISTS (select 1 from information_schema.tables
             where table_schema='public' and table_name='iv_export_batches') THEN
    -- export_rows jsonb: [{iv, order_id, channel, shop, brand, cust, vat}] ตามลำดับส่งออก
    ALTER TABLE public.iv_export_batches ADD COLUMN IF NOT EXISTS export_rows jsonb;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- reload PostgREST schema cache (กัน PGRST204 column not in schema cache หลัง DDL)
NOTIFY pgrst, 'reload schema';
