-- ================================================================
-- ORDER LEDGER — Phase A (แก้): รับรู้ออเดอร์ตั้งแต่ยังไม่มี IV
-- source หลัก = รายงานขายหลังบ้าน 4 ช่องทาง (Shopee/TikTok/Lazada/BigSeller)
-- key = (company_id, order_id)  · IV เติมทีหลังจาก 723-5
-- Idempotent
-- ================================================================

-- iv_no ไม่ต้อง NOT NULL อีกต่อไป (ออเดอร์เกิดก่อน IV)
ALTER TABLE orders ALTER COLUMN iv_no DROP NOT NULL;

-- order-level fields จากรายงานขายหลังบ้าน
ALTER TABLE orders ADD COLUMN IF NOT EXISTS products        text;      -- รายชื่อสินค้า (สรุป)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS item_count      int;       -- จำนวนชิ้นรวม
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_total     numeric(18,2);  -- ยอดขาย (ก่อนหัก platform)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_fee    numeric(18,2);  -- ค่าส่งที่ผู้ซื้อจ่าย
ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_discount numeric(18,2);  -- ส่วนลดจากผู้ขาย
ALTER TABLE orders ADD COLUMN IF NOT EXISTS returned_qty    int;       -- จำนวนที่ส่งคืน
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_returned     boolean NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS sale_status_raw text;      -- สถานะดิบจากแพลตฟอร์ม
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_src       text;      -- ไฟล์ที่ป้อนออเดอร์
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_ingested_at timestamptz;

-- ★ key ใหม่: 1 order = 1 row ต่อบริษัท (ตาม order_id) — iv เติมทีหลัง
CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_company_orderid
  ON orders (company_id, order_id) WHERE deleted_at IS NULL AND order_id IS NOT NULL;
-- index ค้นด้วย iv (ตอน 723-5 จับ IV) + ออเดอร์ที่ยังไม่มี IV
CREATE INDEX IF NOT EXISTS idx_orders_no_iv
  ON orders (company_id, channel_group, order_date) WHERE deleted_at IS NULL AND iv_no IS NULL;
