-- =====================================================================
-- zzz-audit-phase0-indexes.sql  (Pre-production audit · Phase 0)
--   C3: unique key กันออเดอร์ซ้ำใน order_ledger (เชิงโครงสร้าง แทนพลาสเตอร์ dedup-map ฝั่ง client)
--   H5: index ที่ขาดบน hot path (ap_payments trigger seq-scan, order_ledger sort/re lookup)
-- ★ idempotent · EXCEPTION-wrapped · ตั้งชื่อ zzz- ให้รัน "หลังสุด" (หลัง zz-orders-dedup-cleanup)
-- ★ ไม่ใช้ CONCURRENTLY (Management API อาจ wrap txn) — plain CREATE INDEX IF NOT EXISTS พอที่ scale ปัจจุบัน
-- ★ client insert (ordIngestChannelOrders) ข้าม row ที่ error อยู่แล้ว → unique index reject ตัวซ้ำได้โดยไม่พังการอัป
-- =====================================================================

-- 0) กันซ้ำค้างก่อนสร้าง unique index (idempotent · เก็บแถวข้อมูลครบสุดต่อ company_id+order_id)
DO $$
BEGIN
  WITH ranked AS (
    SELECT id,
      ROW_NUMBER() OVER (
        PARTITION BY company_id, order_id
        ORDER BY (iv_no IS NOT NULL) DESC, (re_no IS NOT NULL) DESC,
                 (bq_no IS NOT NULL) DESC, (sale_amount IS NOT NULL) DESC,
                 created_at ASC, id ASC
      ) AS rn
    FROM order_ledger
    WHERE deleted_at IS NULL AND order_id IS NOT NULL
  )
  UPDATE order_ledger o SET deleted_at = now()
  FROM ranked r WHERE o.id = r.id AND r.rn > 1;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'phase0 dedup skipped: %', SQLERRM;
END $$;

-- 1) C3 — unique index กันออเดอร์ซ้ำ (partial: เฉพาะ active + มี order_id)
DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS uq_order_ledger_co_order
    ON order_ledger (company_id, order_id)
    WHERE order_id IS NOT NULL AND deleted_at IS NULL;
EXCEPTION WHEN OTHERS THEN
  -- ถ้ายังมีซ้ำค้าง (edge) → ไม่ทำ CI แดง แต่เตือนชัดให้ไปเคลียร์ก่อน
  RAISE NOTICE 'uq_order_ledger_co_order NOT created (ยังมีออเดอร์ซ้ำค้าง?): %', SQLERRM;
END $$;

-- 2) order_ledger — hot sort/lookup paths (ordLoad order by order_date DESC · tag-back by re_no)
DO $$
BEGIN
  CREATE INDEX IF NOT EXISTS idx_order_ledger_co_orderdate
    ON order_ledger (company_id, order_date DESC) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_order_ledger_co_re
    ON order_ledger (company_id, re_no) WHERE re_no IS NOT NULL AND deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_order_ledger_co_iv
    ON order_ledger (company_id, iv_no) WHERE iv_no IS NOT NULL AND deleted_at IS NULL;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'order_ledger idx skipped: %', SQLERRM;
END $$;

-- 3) H5 — ap_payments: trigger fn_ap_recompute ทำ SUM WHERE ap_invoice_id ทุกครั้งที่จ่าย (เดิม seq-scan)
DO $$
BEGIN
  CREATE INDEX IF NOT EXISTS idx_ap_payments_invoice
    ON ap_payments (ap_invoice_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_ap_payments_voucher
    ON ap_payments (voucher_id) WHERE deleted_at IS NULL AND voucher_id IS NOT NULL;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ap_payments idx skipped: %', SQLERRM;
END $$;

-- 4) sales_income_rows — join order_ledger by order_id (incReconData) + filter paid_date
DO $$
BEGIN
  CREATE INDEX IF NOT EXISTS idx_sales_income_co_order
    ON sales_income_rows (company_id, order_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_sales_income_co_paid
    ON sales_income_rows (company_id, paid_date) WHERE deleted_at IS NULL;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'sales_income idx skipped: %', SQLERRM;
END $$;

NOTIFY pgrst, 'reload schema';
