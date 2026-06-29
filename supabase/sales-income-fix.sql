-- Fix: เพิ่ม unique CONSTRAINT (ไม่ใช่แค่ partial index) บน sales_income_rows
-- เพื่อให้ Supabase upsert onConflict:"company_id,order_id,channel_group" ทำงานได้
-- (partial index ที่สร้างใน sales-income.sql ไม่เพียงพอสำหรับ onConflict resolution)
DO $$
BEGIN
  -- drop partial index เก่า (ถ้ามี)
  BEGIN
    DROP INDEX IF EXISTS uq_sales_income_co_order;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  -- สร้าง constraint จริง (non-partial) แทน
  BEGIN
    ALTER TABLE sales_income_rows
      ADD CONSTRAINT uq_sales_income_co_order_ch
      UNIQUE (company_id, order_id, channel_group);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

NOTIFY pgrst, 'reload schema';
