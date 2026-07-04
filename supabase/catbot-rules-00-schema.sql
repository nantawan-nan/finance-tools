-- ================================================================
-- CATBOT RULES (schema) — สมองจัดหมวดเงินรับ-เงินจ่ายอัตโนมัติ
-- หน้า Bank Reconciliation แท็บ "จัดหมวด (AI)" · helper catbot*
--   match_type 'exact' = ประโยคหมายเหตุ normalize แล้ว · 'vendor' = ชื่อผู้ขาย
-- ทุก confirm ของผู้ใช้ = upsert (weight++) → ฉลาดขึ้นทุกเดือน
-- seed 857 rules แยกเป็นไฟล์ catbot-rules-0N-seed.sql (payload เล็ก กัน API limit)
-- idempotent · EXCEPTION-wrapped
-- ================================================================
CREATE TABLE IF NOT EXISTS catbot_rules (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  uuid NOT NULL,
  dir         text NOT NULL,
  match_type  text NOT NULL,
  pattern     text NOT NULL,
  category    text NOT NULL,
  activity    text NOT NULL,
  weight      int  NOT NULL DEFAULT 1,
  source      text NOT NULL DEFAULT 'user',
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS company_id uuid;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS dir text;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS match_type text;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS pattern text;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS activity text;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS weight int NOT NULL DEFAULT 1;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'user';
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE catbot_rules ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
DO $$
BEGIN
  BEGIN EXECUTE 'GRANT ALL ON catbot_rules TO authenticated'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON catbot_rules TO service_role'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'GRANT ALL ON catbot_rules TO supabase_auth_admin'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE catbot_rules DISABLE ROW LEVEL SECURITY'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_catbot_rules ON catbot_rules (company_id, dir, match_type, pattern, category)'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_catbot_rules_lookup ON catbot_rules (company_id, dir, match_type)'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
NOTIFY pgrst, 'reload schema';
