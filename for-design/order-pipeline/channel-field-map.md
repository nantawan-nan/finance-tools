# Channel Field Map — คอลัมน์ที่ต้องจับต่อช่องทาง (จากไฟล์จริง 2026-06-24)

ดึงจากไฟล์ตัวอย่างจริง: BigSeller (Order-Goods), หลังบ้าน Shopee/TikTok/Lazada (Be/Qi/MM × 3 ช่อง)

## สรุปจำนวนคอลัมน์ + ภาษา
| แหล่ง | คอลัมน์ | หัวข้อ | order id | หมายเหตุ |
|---|---|---|---|---|
| **BigSeller** (master) | 14 | ไทย | `หมายเลขคำสั่งซื้อ` | 1 ไฟล์ปนหลาย platform + หลายบริษัท (Mommam=mbark, Betra/Qi=benya) |
| **Shopee** หลังบ้าน | 60 | ไทย | `หมายเลขคำสั่งซื้อ` | order id เดียวกับ BigSeller |
| **TikTok** หลังบ้าน | 63 | อังกฤษ | `Order ID` | ไฟล์ Be เป็น .csv (utf-8-sig), Qi/MM เป็น .xlsx |
| **Lazada** หลังบ้าน | 77 | อังกฤษ | `orderNumber` | **1 แถว = 1 ชิ้น** (ไม่มีคอลัมน์จำนวน → นับแถว) · `orderItemId` = line id |

> ⚠️ **xlsx หลังบ้านมี dimension เพี้ยน** (read_only อ่านได้ 1 คอลัมน์) — ตอน parse จริงใน browser ใช้ `XLSX.read` + `sheet_to_json({header:1})` ปกติได้ครบ (เป็นปัญหาเฉพาะ openpyxl read_only)

---

## ★ ตารางจับคอลัมน์ (สำหรับ Recon — เทียบ gross/ship/discount/SKU strict 0)

| field (ใช้เทียบ) | BigSeller (master) | Shopee | TikTok | Lazada |
|---|---|---|---|---|
| **order_no** | `หมายเลขคำสั่งซื้อ` | `หมายเลขคำสั่งซื้อ` | `Order ID` | `orderNumber` |
| platform | `แพลตฟอร์ม` | (ทั้งไฟล์=Shopee) | (=TikTok) | (=Lazada) |
| **ร้าน → บริษัท** | `ร้านค้าเพลตฟอร์ม` | (จากชื่อไฟล์/ร้าน) | — | — |
| sale_date | `เวลาสั่งซื้อ` | `วันที่ทำการสั่งซื้อ` | `Created Time` | `createTime` |
| status | `สถานะคำสั่งซื้อ` | `สถานะการสั่งซื้อ` | `Order Status` (+`Order Substatus`) | `status` |
| cancel | `เวลายกเลิก` (มีค่า=ยกเลิก) | สถานะ=`ยกเลิกแล้ว` | `Cancelled Time`/status | `status`=canceled |
| **SKU** | `SKU Merchant` | `เลขอ้างอิง SKU (SKU Reference No.)` | `Seller SKU` | `sellerSku` |
| **qty** | `จำนวน` | `จำนวน` | `Quantity` | **นับแถวต่อ orderNumber+sku** (ไม่มี qty) |
| returned qty | — | `จำนวนที่ส่งคืน` | `Sku Quantity of return` | `refundAmount`/status |
| **gross (ราคาขาย×qty ก่อนลด)** ⚠️ | **`ราคาสินค้าเดิม` ?? `ราคา`** × `จำนวน` (ดูกฎ ↓) | `ราคาขายสุทธิ` | `SKU Subtotal Before Discount` | `unitPrice` × แถว |
| **seller discount** | `ส่วนลดผู้ขาย` | `โค้ดส่วนลดชำระโดยผู้ขาย` | `SKU Seller Discount` | `sellerDiscountTotal` |
| **ค่าส่ง (เก็บจากลูกค้า)** ⚠️ | `ค่าจัดส่ง` | `ค่าจัดส่งที่ชำระโดยผู้ซื้อ` | `Shipping Fee After Discount` | `shippingFee` |
| net/ชำระจริง | `ราคา` | `ราคาสินค้าที่ชำระโดยผู้ซื้อ (THB)` | `SKU Subtotal After Discount` | `paidPrice` |
| refund | — | `สถานะการคืนเงินหรือคืนสินค้า` | `Order Refund Amount` | `refundAmount` |

---

## ตรวจสอบความหมาย "gross" จากตัวอย่างจริง

- **BigSeller** (Shopee Mommam): `ราคาสินค้าเดิม`=780 · `ราคา`=523 · `ส่วนลดผู้ขาย`=257 → **780−257=523** ✓ (gross−discount=net)
- **Shopee หลังบ้าน** (Qi): `ราคาตั้งต้น`=750/หน่วย · `ราคาขาย`=380/หน่วย · `จำนวน`=4 · `ราคาขายสุทธิ`=1520 (=380×4)
- **TikTok**: `SKU Unit Original Price` (ต่อหน่วย) · `SKU Subtotal Before Discount` (= ×qty) · `SKU Seller Discount` · `SKU Subtotal After Discount`
- **Lazada** (Qi): `unitPrice`=380 · `sellerDiscountTotal`=−38 · `platformDiscountTotal`=−91.20 · `paidPrice`=250.80

### ★ กฎ gross ของ BigSeller (เจ้าของยืนยัน 2026-06-24)
**`gross_unit = ราคาสินค้าเดิม ถ้ามีค่า, ไม่งั้นใช้ ราคา`** แล้ว × `จำนวน`
- **ผ่านแพลตฟอร์ม (SP/TT/LZ):** มี `ราคาสินค้าเดิม` → ใช้ตัวนี้ (gross ก่อนลด) · `ราคา` = หลังลด
- **คีย์มือ (FACE/LINE/Dealer):** `ราคาสินค้าเดิม` **ว่าง** → ราคาขายไปอยู่ที่ `ราคา` แทน → ใช้ `ราคา` เป็น gross
- detection: `source_type=manual` เมื่อ `แพลตฟอร์ม` ∉ {Shopee,TikTok,Lazada} หรือ `ราคาสินค้าเดิม` ว่าง (สอดคล้อง order_no prefix FB/OD → FACE เดิม)
- **manual orders ข้าม recon** (ไม่มี backend เทียบ) แต่ยังคีย์ IV ตาม gross=`ราคา` + ผ่าน approval workflow

### ✅ ค่าส่ง TikTok = `Shipping Fee After Discount` (ยืนยันจากเลขจริง 2026-06-24)
พิสูจน์: **`Order Amount` = `SKU Subtotal After Discount` + `Shipping Fee After Discount`** (ทุกแถวลงตัว)
- เช่น 149+29=178 · 199+69=268 · 148.07+38=186.07 · เมื่อ platform ออกค่าส่งให้ (`SF Platform Discount`=`Original SF`) → `SF After Discount`=0 = ผู้ซื้อจ่าย 0 พอดี
- → `Shipping Fee After Discount` = ค่าส่งที่ผู้ซื้อจ่ายจริง = ที่เก็บจากลูกค้า ใช้ยื่นภาษีขาย ✓
- ค่าส่งทั้ง 3 ช่อง (recon): Shopee=`ค่าจัดส่งที่ชำระโดยผู้ซื้อ` · TikTok=`Shipping Fee After Discount` · Lazada=`shippingFee`

> **ทุกข้อยืนยันครบแล้ว — design พร้อม implement**

---

## ผลต่อ `ORD_CH` config (ของเดิมใน index.html ต้องแก้)
- **bigseller**: `sig` เดิม `["หมายเลขคำสั่งซื้อ","ร้านค้า BigSeller"]` → ไฟล์จริงใช้ **`ร้านค้าเพลตฟอร์ม`** ไม่ใช่ "ร้านค้า BigSeller" → **detection พังกับไฟล์จริง** ต้องแก้ + เพิ่ม gross `ราคาสินค้าเดิม`, shop `ร้านค้าเพลตฟอร์ม`
- **shopee**: เพิ่ม gross=`ราคาขายสุทธิ` (เดิมใช้เป็น net) · SKU ใช้ `เลขอ้างอิง SKU (SKU Reference No.)`
- **tiktok**: gross=`SKU Subtotal Before Discount` (เดิม net=After Discount)
- **lazada**: gross=`unitPrice` (เดิม net=`paidPrice`) · qty=นับแถว
- ทั้งหมดผ่านชั้น **alias + normalize + learned mapping** (Stage 1.5) เพื่อทนคอลัมน์ขยับ/เปลี่ยนชื่อ
