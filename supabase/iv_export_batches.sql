-- ================================================================
-- IV EXPORT BATCHES — ประวัติการส่งออกคีย์ IV (AutoKey JSON/CSV)
-- หน้า "บันทึกขายเชื่อในระบบบัญชี (IV)" — ทุกครั้งที่บัญชีกดส่งออก
-- บันทึก metadata 1 row (ช่วงวัน/ช่องทาง/จำนวน/start_iv/order_ids[])
-- ★ ไม่เก็บเลข IV ลง order_ledger ตอน export — รอ 141.RWT มา verify ก่อน
-- ทุก statement EXCEPTION-wrapped · idempotent
-- ================================================================
CREATE TABLE IF NOT EXISTS iv_export_batches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL,
  batch_no        text NOT NULL,
  date_from       date,
  date_to         date,
  channels        text[],
  start_iv        text,
  end_iv          text,
  order_count     int NOT NULL DEFAULT 0,
  order_ids       jsonb,
  file_name       text,
  exported_by     uuid,
  exported_email  text,
  exported_at     timestamptz NOT NULL DEFAULT now(),
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

-- ALTER ครบทุก column — กันตารางถูกสร้างด้วยเวอร์ชันเก่าที่ column ไม่ครบ
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS company_id uuid;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS batch_no text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS date_from date;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS date_to date;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS channels text[];
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS start_iv text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS end_iv text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS order_count int NOT NULL DEFAULT 0;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS order_ids jsonb;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS file_name text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS exported_by uuid;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS exported_email text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS exported_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

DO $$
BEGIN
  BEGIN EXECUTE 'GRANT ALL ON iv_export_batches TO authenticated'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON iv_export_batches TO service_role'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON iv_export_batches TO supabase_auth_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- ปิด RLS — แอป query กรอง company_id เอง (consistent กับ order_ledger)
  BEGIN EXECUTE 'ALTER TABLE iv_export_batches DISABLE ROW LEVEL SECURITY'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- indexes
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_iv_export_batches_co_at ON iv_export_batches (company_id, exported_at DESC) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_iv_export_batches_no ON iv_export_batches (company_id, batch_no) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
