-- ============================================================
-- User-Company Access: page_permissions — กำหนดสิทธิดูหน้าทีละหน้า
-- ============================================================
-- ปัญหาเดิม: role (admin/finance_mgr/viewer/...) กำหนดสิทธิเป็นชุด — ไม่ flex
-- ปัญหาใหม่: ผู้ใช้บางคนต้องดู "บาง" หน้าได้ "บาง" หน้าไม่ได้
--
-- Solution: เพิ่ม page_permissions jsonb
--   - null  → ใช้ role เดิม (default — backward compat)
--   - []    → ปิดทุกหน้า
--   - ["home","ap_outstanding","cashflow"]  → ดูได้เฉพาะ tool id ที่ระบุ
--
-- Idempotent + NOTIFY pgrst
-- ============================================================

ALTER TABLE user_company_access
  ADD COLUMN IF NOT EXISTS page_permissions jsonb;

COMMENT ON COLUMN user_company_access.page_permissions IS
  'Array of allowed tool IDs. NULL = use role default. Example: ["home","cashflow","ap_outstanding"]';

NOTIFY pgrst, 'reload schema';
