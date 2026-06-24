-- ================================================================
-- SALES RECONCILIATION REPORT — ใบกระทบยอด BigSeller ↔ Platform (snapshot ล็อก)
-- เก็บ snapshot ณ เวลาตรวจ → ไม่เปลี่ยนแม้ข้อมูลต้นทางอัปเดตภายหลัง
-- idempotent · ปิด RLS (แอปกรอง company เอง ตามแนว orders.sql)
-- ================================================================
CREATE TABLE IF NOT EXISTS recon_reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company       text NOT NULL,
  report_no     text NOT NULL,            -- SRR-SHOPEE-20260601-001
  platform      text,                     -- shopee/tiktok/lazada
  date_from     date,
  date_to       date,
  generated_at  timestamptz NOT NULL DEFAULT now(),
  generated_by  uuid,
  generated_by_name text,
  status        text NOT NULL DEFAULT 'closed',  -- draft|reviewed|approved|closed
  version       int NOT NULL DEFAULT 1,
  note          text,
  summary       jsonb,                    -- counts + totals (frozen)
  snapshot      jsonb,                    -- รายการ matched/only_be/only_bs/diff (frozen)
  deleted_at    timestamptz
);
CREATE INDEX IF NOT EXISTS idx_recon_reports_co
  ON recon_reports (company, generated_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_recon_reports_plat
  ON recon_reports (company, platform, date_to) WHERE deleted_at IS NULL;

DO $$ BEGIN
  BEGIN EXECUTE 'GRANT ALL ON recon_reports TO authenticated'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON recon_reports TO service_role'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON recon_reports TO supabase_auth_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE recon_reports DISABLE ROW LEVEL SECURITY'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
