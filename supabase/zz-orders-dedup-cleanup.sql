-- =====================================================================
-- zz-orders-dedup-cleanup.sql
-- ล้างออเดอร์ซ้ำใน order_ledger (เกิดจากอัปไฟล์ซ้ำ + ตัวกันซ้ำเดิมติด cap 1000 แถว)
-- เก็บ 1 แถวที่ข้อมูลครบสุดต่อ (company_id, order_id) · soft-delete ที่เหลือ
-- ลำดับเก็บ: มี iv_no > มี re_no > มี bq_no > มี sale_amount > เก่าสุด (created_at)
--
-- ★ idempotent — รันซ้ำได้: รอบถัดไปไม่มีซ้ำแล้ว → UPDATE 0 แถว (no-op)
-- ★ EXCEPTION-wrapped + ตั้งชื่อ zz- ให้รันหลังสุด (order_ledger ถูกสร้างครบก่อน)
-- ★ ต้นเหตุแก้แล้วในแอป (ordFetchAllRows แบ่งหน้า) → จะไม่เกิดซ้ำใหม่
-- =====================================================================
DO $$
BEGIN
  WITH ranked AS (
    SELECT id,
      ROW_NUMBER() OVER (
        PARTITION BY company_id, order_id
        ORDER BY
          (iv_no       IS NOT NULL) DESC,
          (re_no       IS NOT NULL) DESC,
          (bq_no       IS NOT NULL) DESC,
          (sale_amount IS NOT NULL) DESC,
          created_at ASC,
          id ASC
      ) AS rn
    FROM order_ledger
    WHERE deleted_at IS NULL AND order_id IS NOT NULL
  )
  UPDATE order_ledger o
  SET deleted_at = now()
  FROM ranked r
  WHERE o.id = r.id
    AND r.rn > 1;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'zz-orders-dedup-cleanup skipped: %', SQLERRM;
END $$;

NOTIFY pgrst, 'reload schema';
