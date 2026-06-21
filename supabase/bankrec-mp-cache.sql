-- ================================================================
-- BANK RECONCILIATION — MP: cache ข้อมูล Express (sales/รับชำระ/เช็ครับ)
-- ให้ครั้งต่อไปอัปแค่ Shopee balance พอ — ไม่ต้องอัป Express ซ้ำทุกครั้ง
-- 1 row ต่อ company (upsert) · เก็บเป็น jsonb
-- Idempotent
-- ================================================================
CREATE TABLE IF NOT EXISTS brec_mp_express_cache (
  company_id   uuid PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
  sales_json   jsonb,        -- { ivs: [...] }  จากรายงานขาย 723-5
  ar_json      jsonb,        -- { cheques: [...], ivToCheque: [[iv,chq],...] } จากรับชำระ
  cheque_json  jsonb,        -- { deposits: [...] } จากเช็ครับ
  sales_files  text,
  ar_files     text,
  cheque_files text,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   uuid
);

GRANT ALL ON brec_mp_express_cache TO authenticated;
GRANT ALL ON brec_mp_express_cache TO service_role;
GRANT ALL ON brec_mp_express_cache TO supabase_auth_admin;

ALTER TABLE brec_mp_express_cache ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_brec_mp_cache_read   ON brec_mp_express_cache;
DROP POLICY IF EXISTS p_brec_mp_cache_write  ON brec_mp_express_cache;
DROP POLICY IF EXISTS p_brec_mp_cache_update ON brec_mp_express_cache;

CREATE POLICY p_brec_mp_cache_read ON brec_mp_express_cache FOR SELECT TO authenticated
  USING (company_id IN (SELECT fn_my_companies()));
CREATE POLICY p_brec_mp_cache_write ON brec_mp_express_cache FOR INSERT TO authenticated
  WITH CHECK (company_id IN (SELECT fn_my_companies())
             AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
CREATE POLICY p_brec_mp_cache_update ON brec_mp_express_cache FOR UPDATE TO authenticated
  USING (company_id IN (SELECT fn_my_companies())
         AND fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'))
  WITH CHECK (fn_my_role(company_id) IN ('admin','finance_mgr','accountant','treasury'));
