-- ================================================================
-- BANK RECON — รองรับ M-to-N matching (1 ex × N bk / M ex × 1 bk / M ex × N bk)
-- เคสจริง: ลูกค้าโอนขาด แล้วโอนซ้ำ → Express 1 รายการ vs Bank 2 รายการ
-- เดิม unique index ห้าม row เดียวกันมี match >1 → ทำ M-to-N ไม่ได้
-- ใหม่: drop single-side unique → เปลี่ยนเป็น pair-unique (ex,bk) + เพิ่ม match_group_id
-- ★ Idempotent · EXCEPTION-wrapped · NOTIFY pgrst
-- ================================================================

DO $$
BEGIN
  -- 1) drop old single-column unique (Phase 1)
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_brec_match_express'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_brec_match_bank'; EXCEPTION WHEN OTHERS THEN NULL; END;
  -- 2) create new pair-based unique (allow many-to-many · กันแค่คู่เดียวกันซ้ำ)
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_match_pair ON brec_matches (express_row_id, bank_row_id) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- 3) เพิ่ม match_group_id — tag matches ในกลุ่มเดียวกัน (ex/bk cross product)
ALTER TABLE brec_matches ADD COLUMN IF NOT EXISTS match_group_id text;

-- 4) index สำหรับ query group
DO $$
BEGIN
  BEGIN EXECUTE 'CREATE INDEX IF NOT EXISTS idx_brec_match_group ON brec_matches (match_group_id) WHERE match_group_id IS NOT NULL AND deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
