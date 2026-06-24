# Order Pipeline — แผนปรับระบบงานขายให้ครบ flow จริง

> เอกสารออกแบบ (review ก่อนลงมือ) · ยังไม่แตะ `index.html` · SQL ในโฟลเดอร์นี้ **ยังไม่ auto-run** (อยู่นอก `supabase/`)
> ไฟล์ในชุดนี้: `PLAN.md` · `schema-draft.sql` · `recon-mockup.html` · **`channel-field-map.md`** (คอลัมน์จริงต่อช่องทาง)
> ตัดสินใจที่ล็อกไว้แล้ว: (1) **ยึด BigSeller `orders` เป็น order master เดียว** (2) **recon เทียบครบ: มีครบ + ยอด + SKU×จำนวน**

---

## 0. ภาพรวม pipeline เป้าหมาย

```
[BigSeller report]  ──ingest──►  orders + order_items   (★ MASTER เดียว · รวม FB/LINE คีย์มือ)
       ▲                              │
       │  เทียบรายวัน                  ├─► (1) RECON  ◄── [Backend: Shopee/TikTok/Lazada]
[ฝ่ายขายคีย์]                          │       └ ต้องตรวจ / ตรงแล้ว · รายงานออเดอร์คีย์ไม่ครบ
                                       │
                                       ├─► (2) Export CSV → AutoKey  (เลือกวัน/ทั้งหมด)   [มีแล้ว]
                                       │
                          [723-5] ───► (3) คีย์ IV + ตรวจถูก/ผิด + loop แก้
                                       │
                       [รับชำระ AR] ──► (4) map order→IV · คงค้าง · หักค่าธรรมเนียม · net เข้ากระเป๋า
                                       │
                    [รายงานถอน+STM] ──► (5) BQ/เช็ค/ค่าธรรมเนียม/เงินเข้าแบงค์   [มีแล้ว brec_mp_*]
                                       │
                                       └─► (6) order_events log → timeline จริง · แท็กกลับ IV/RE/BQ
```

ทุก stage เกาะ **ออเดอร์เดียวกัน** (`orders.id = "{company}|{order_no}"`)

### Cardinality (เจ้าของยืนยัน 2026-06-24) — สำคัญต่อ data model
- **1 Order = 1 IV = 1 RE เป๊ะ** (1:1:1) → เก็บ `iv_no`/`re_no` เป็น **flat column บน `orders`** พอ **ไม่ต้อง** ตาราง invoices/settlement แบบ many-to-many
- **มีแค่ตอนฝากเช็ค (ถอนกระเป๋าแพลตฟอร์ม→บัญชี): 1 BQ : หลายเลขที่เช็ค** → **ของเดิมรองรับแล้ว** (`brec_mp_withdrawals` 1 ถอน/BQ : `brec_mp_orders` หลายออเดอร์/เช็ค) · แต่ละออเดอร์ได้ `bq_no` ร่วม + วันเข้าแบงค์ (ผ่าน `ordTagBankFromWithdrawals`)

### เคสซับซ้อนที่ต้องรองรับ (ข้อ 13 — เฉพาะที่ยังจริงหลังแก้ cardinality)
| เคส | วิธีรองรับ |
|---|---|
| 1 Order หลายสินค้า | เก็บ **Header (`orders`) + Line (`order_items`)** อยู่แล้ว — recon/ยอดคำนวณจาก line ไม่ใช่ยอดรวม |
| คืนบางสินค้า (partial return) | เพิ่ม line-level `returned_qty`/`refund_amount`/`return_date`/`net_qty` + `orders.return_status` |
| ยอดขาย ≠ เงินเข้า wallet | แยกชั้นเงินชัด: `gross_sales` (Σ price×qty) · `net_sales` (หลังลด+คืน) · `receipt_fee` (platform fee) · `receipt_net` (เข้ากระเป๋า) — ทั้งหมดต่อ order (1:1) |
| platform ปรับยอดย้อนหลัง | **Adjustment module** ตาราง `order_adjustments` (refund/penalty/affiliate_fee/fee_adjustment) append-only ผูก order/iv 1:1 ไม่แก้ยอดเดิม |
| FB/LINE ไม่มีข้อมูล platform เทียบ | **workflow อนุมัติคีย์มือ:** `source_type='manual'` + `approval_status` (draft→submitted→sales_reviewed→accounting_accepted) · ผู้ขายคีย์ → หัวหน้าขายตรวจ → บัญชีรับไปออก IV · log ใน `order_events` (stage=approval) · gate ด้วย role |

> manual orders (FB/LINE) **ข้าม recon** (ไม่มีฝั่ง backend เทียบ) แต่ต้องผ่าน approval ก่อนถึงสเตปคีย์ IV แทน

---

## 1. สิ่งที่มีอยู่ vs ต้องทำ (สรุป)

| Stage | ของเดิม | ต้องทำ |
|---|---|---|
| 0 ออเดอร์เข้า | `orders`/`order_items` (BigSeller import) | คงไว้ |
| 1 **Recon** | ❌ (order_ledger แค่ ingest ไม่เทียบ) | **ตารางใหม่ + engine + แท็บ UI** |
| 2 Export AutoKey | `exkExport` (filter วัน, เลือก) | ปรับให้อ่าน lifecycle ใหม่ |
| 3 คีย์ IV | `ordIngestFromSales` แท็ก iv_no | + ตรวจถูก/ผิด + สถานะรอแก้ + export รายการแก้ |
| 4 รับชำระ | `ordTagReceipts` แท็ก RE/net/fee | + คอลัมน์คงค้าง + หน้ารายงาน AR |
| 5 ถอน/แบงค์ | `brec_mp_*` + `ordTagBank...` | ต่อ STM (ขัดเงาทีหลัง) |
| 6 timeline | `ordTimeline` อ่านคอลัมน์ | **เขียน `order_events` จริง** |

**หนี้ทางเทคนิคที่ต้องเก็บกวาด:** `order_ledger` (โมดูล "ทะเบียนคำสั่งซื้อ") เป็นระบบออเดอร์ชุดที่ 2 ที่ซ้อนกับ `orders` — แผนนี้ย้าย lifecycle มาไว้บน `orders` แล้ว **deprecate `order_ledger`** (ดูข้อ 6)

---

## 2. การเปลี่ยน schema

### 2.1 ขยาย `orders` (เพิ่มคอลัมน์ lifecycle — nullable ทั้งหมด, idempotent)

> `orders` ปัจจุบันใช้คีย์ `company` (text 'mbark'/'benya') + `order_no`, `id="{company}|{order_no}"`, ไม่มี soft-delete/uuid — **คงรูปแบบเดิมไว้** เพื่อไม่ให้ bsImport/exkLoad/Dashboard พัง เพิ่มเฉพาะคอลัมน์ใหม่

```
-- คีย์ IV (จาก 723-5)
iv_date date · iv_amount numeric(18,2) · iv_status text · iv_keyed_at timestamptz · iv_src text
   iv_status ∈ no_iv | keyed_ok | amount_mismatch | needs_fix | voided

-- รับชำระ (RE)
re_no text · cheque_no text · receipt_gross numeric · receipt_net numeric · receipt_fee numeric
received_at timestamptz · ar_outstanding numeric   -- = iv_amount − receipt_net

-- ฝากเช็ค / เข้าแบงค์ (BQ)
bq_no text · deposit_date date · bank_in_date date · bank_amount numeric · bank_matched boolean

-- recon (สรุปผลล่าสุดมาแปะที่ออเดอร์ เพื่อ filter/แสดงเร็ว)
recon_status text · recon_checked_at timestamptz
   recon_status ∈ not_checked | matched | needs_review | resolved
```

### 2.2 ตารางใหม่ `order_recon_runs` — header การตรวจแต่ละครั้ง (เก็บเป็น DATA กู้คืนได้)

```
id uuid · company text · run_at timestamptz · sale_date_from/to date
channels text[]            -- ช่องทางที่ตรวจรอบนี้
bs_file text · be_files text[]
n_total · n_matched · n_needs_review · n_only_bs · n_only_be · n_amount_diff · n_sku_diff
created_by uuid
```

### 2.3 ตารางใหม่ `order_recon` — ผลเทียบรายออเดอร์ (snapshot แช่แข็งทั้ง 2 ฝั่ง)

```
id uuid · company text · run_id uuid · sale_date date · channel text · order_no text
-- ฝั่ง BigSeller (copy ณ เวลาตรวจ → กู้คืนได้)
bs_present bool · bs_amount numeric · bs_item_count int · bs_sku_sig text · bs_raw jsonb
-- ฝั่งหลังบ้าน (จากไฟล์ backend)
be_present bool · be_amount numeric · be_item_count int · be_sku_sig text · be_raw jsonb
-- ผล
status text          -- matched | only_in_bigseller | only_in_backend | amount_diff | sku_diff
diff_amount numeric · diff_detail jsonb
-- resolve
resolved bool · resolve_action text · resolve_note text · resolved_by uuid · resolved_at timestamptz
```
- `sku_sig` = รายการ `SKU×qty` เรียง a→z ต่อด้วย `|` (เทียบตรงตัว) · `diff_detail` เก็บ SKU ที่ขาด/เกิน/จำนวนต่าง
- เก็บทั้ง `bs_raw`/`be_raw` (jsonb) → **กู้คืน/audit ย้อนหลังได้** ตามโจทย์ "เก็บเป็น DATA ไฟล์"

### 2.4 ใช้ `order_events` (มีอยู่แล้วใน `supabase/orders.sql` — เริ่มเขียนจริง)

อ้างออเดอร์ด้วย `order_id`(=order_no) + `company` · `stage ∈ sale_ingest | recon | iv_keyed | iv_fixed | receipt | deposit_bq | bank_in` · `detail jsonb` · `src_file`
> หมายเหตุ: `order_events` เดิมมี `company_id uuid` — เพิ่ม `company text` + `order_no text` (idempotent) เพื่อให้เกาะ `orders` ได้โดยไม่ต้อง map uuid

---

## 3. Logic แต่ละ engine

### Stage 1 — Recon (ใหม่)
1. **อัป 2 ฝั่ง:** BigSeller report (ถ้ายังไม่ ingest) + ไฟล์ backend Shopee/TikTok/Lazada
2. ฝั่ง BigSeller ดึงสดจาก `orders`+`order_items` ตาม `sale_date` → `gross=Σ(price×qty)`, `ship`, `discount`, `sku_sig`
3. ฝั่ง backend parse ด้วย `ordParseSalesFile` (ต้องเพิ่ม mapping gross — ดูข้อ 7) → `gross`, `ship`, `discount`, `sku_sig`
4. **join ด้วย `order_no` (ตรงเป๊ะ)** แล้วตัดสถานะ **strict 0 tolerance**:
   - มีฝั่งเดียว → `only_in_backend` (= ฝ่ายขายคีย์ไม่ครบ) / `only_in_bigseller`
   - `gross`/`ship`/`discount` ต่างแม้บาทเดียว → `amount_diff` (diff_detail ชี้ว่าต่างที่ค่าไหน) · SKU×qty ต่าง → `sku_diff` · ตรงครบทุกค่า → `matched`
5. เขียน `order_recon_runs` + `order_recon` (แช่ทั้ง 2 ฝั่ง) → อัปเดต `orders.recon_status`
6. เขียน `order_events` (stage=`recon`) เฉพาะตัวที่ needs_review
7. **Export 2 แบบ:** (ก) "ออเดอร์คีย์ไม่ครบ (ส่งฝ่ายขาย)" = only_in_backend · (ข) **"รายงานขายรายวันตาม order_no"** = matched+ยอด

### Stage 3 — IV validation (ต่อยอด `ordIngestFromSales`)
- อัป 723-5 → แท็ก `iv_no/iv_date/iv_amount` ตาม `ref_order_id`→`order_no`
- เทียบ `iv_amount` กับ **ยอดที่ควรเป็น** (`orders.net_amount`/recon) → ต่าง ⇒ `iv_status=amount_mismatch`, ตรง ⇒ `keyed_ok`
- รายงาน: มี IV / รอคีย์ / **คีย์ผิดรอแก้** + ปุ่ม export "รายการรอแก้ IV" → แก้แล้วอัป 723-5 ใหม่ flip เป็น `keyed_ok`
- เขียน `order_events` stage=`iv_keyed`/`iv_fixed`

### Stage 2.5 — Manual order approval (FB/LINE เท่านั้น)
- ออเดอร์ `source_type='manual'` (ผู้ขายคีย์ใน BigSeller เอง) → ไม่มีฝั่ง backend เทียบ recon
- workflow: **ผู้ขายคีย์ (`draft→submitted`) → หัวหน้าขายตรวจ (`sales_reviewed`) → บัญชีรับ (`accounting_accepted` → ออก IV ได้)**
- gate ด้วย role · แต่ละ transition เขียน `order_events` (stage=`approval`) · ออเดอร์ที่ยังไม่ `accounting_accepted` **ไม่โผล่ในรายการ export AutoKey** (กันคีย์ของที่ยังไม่อนุมัติ)

### Stage 4 — AR / รับชำระ (ต่อยอด `ordTagReceipts`)
- แท็ก `re_no/cheque_no/receipt_gross/receipt_net/receipt_fee` ผ่าน iv_no (มีแล้ว) → คำนวณ `ar_outstanding`
- หน้า/รายงานใหม่ bucket: **คีย์ IV แล้วยังไม่รับชำระ** · รับบางส่วน · ครบ · RE ออกแล้ว/ยัง · แสดงค่าธรรมเนียม + net เข้ากระเป๋าแพลตฟอร์ม
- **Adjustment:** รวมรายการจาก `order_adjustments` (refund/penalty/affiliate/fee adj ที่มาทีหลัง) → `net เข้าจริง = receipt_net + Σ adjustments` · timeline โชว์เป็น event แยก (ไม่ทับยอดเดิม)

### Stage 6 — order_events ทุกจุด → `ordTimeline` อ่าน event จริง (มีเวลา + ไฟล์ที่มา)

### Stage 1.5 — Header mapping ทนการขยับคอลัมน์ (เรียนรู้จากชื่อคอลัมน์)
> ความต้องการ: ไฟล์ SH/TT/LZ คอลัมน์ราคาขายอาจขยับ (เคยอยู่ AB เดือนหน้าไป AZ) — ระบบต้อง **จับจากชื่อหัวคอลัมน์ ไม่ล็อกตำแหน่ง Excel**

- ✅ **ของเดิมทำถูกอยู่แล้วระดับหนึ่ง** — `ordParseSalesFile` ใช้ `headers.indexOf(ชื่อคอลัมน์)` (อ้างชื่อ ไม่ใช่ตำแหน่ง) → คอลัมน์ขยับ AB→AZ **ไม่พัง** ตราบใดที่ "ชื่อหัวคอลัมน์เหมือนเดิม"
- ความเสี่ยงจริง = **ชื่อหัวคอลัมน์เปลี่ยน/มีหลายแบบ** (เว้นวรรค, วงเล็บ, เปลี่ยนคำ, ไฟล์ EN/TH) → เสริม 3 ชั้น:
  1. **alias list ต่อ field** — `ORD_CH` เปลี่ยน field จาก string เดี่ยว เป็น **array ชื่อที่เป็นไปได้** เช่น `gross:["ราคาขาย","ราคาต่อหน่วย","Original Price","Unit Price"]`
  2. **normalize ก่อนจับคู่** — `normHeader()` = lower + ตัดช่องว่าง/zero-width/วงเล็บ/`*` → จับคู่แม้พิมพ์ต่างเล็กน้อย + fallback `contains`
  3. **เรียนรู้+จำ (learned mapping)** — ถ้าจับ field ไหนไม่ได้ → เด้ง UI ให้ผู้ใช้ชี้คอลัมน์เอง → **บันทึก** mapping (channel + field → header ที่เลือก) ลงตาราง `import_column_map` → เดือนหน้าหัวคอลัมน์แบบนี้จับได้เอง
- เก็บ `header signature` (รายชื่อหัวคอลัมน์ทั้งแถว) ใน import log → debug ย้อนหลังได้ว่าไฟล์เดือนไหนหัวเป็นแบบใด
- ใช้กับ **ทั้ง recon parser และ 723-5 parser** (ป้องกัน Express ขยับด้วย — ของเดิม AP มี "column shift +1" hardcode อยู่แล้ว ควรย้ายมาใช้กลไกเดียวกัน)

ตารางใหม่ `import_column_map`: `company · channel · field · header_text · created_by` (ดู schema-draft.sql)

### Stage 0.5 — แยกบริษัทอัตโนมัติตอนนำเข้า (shop → company)
> ปัญหา: ไฟล์ BigSeller export ออกมา **ปน 2 บริษัท** (เบญญา + เอ็มบาร์ค) ฝ่ายขายต้องติ๊กแยกมือ และบางทีลืมแยก → ของเดิม `bsImport` ยัดทุกออเดอร์เข้า `state.company` ที่เลือกอยู่ (ไม่กรอง) → เข้าผิดบริษัท

**ตัวแยก = ชื่อร้าน (`ร้านค้าเพลตฟอร์ม`)** — แต่ละร้านสังกัดบริษัทเดียวตายตัว (เบญญา: benya_official/betra_brand · เอ็มบาร์ค: mommam/MommamOfficialTH/…)

- **ยกระดับ map ร้าน→บริษัท เป็นตาราง Supabase `shop_registry`** (เดิมอยู่ localStorage per-browser → ฝ่ายขายคนละเครื่องไม่เห็น map เดียวกัน) · seed จาก `bsSeedShopBrand` + `BMP_SHOP_ROUTING` ที่มีอยู่
- **ตอน import จำแนกทุกออเดอร์ตามร้าน → บริษัท:**
  1. ร้าน → บริษัท = บริษัทปัจจุบัน → **นำเข้า**
  2. ร้าน → อีกบริษัท → **ข้าม + นับ** (ไม่เข้าผิด) · มีปุ่ม "นำเข้าทั้ง 2 บริษัทเลย" (เขียน `orders` ตาม company ของแต่ละร้านในรอบเดียว — ทำได้เพราะ `orders.company` เป็น text ต่อแถว)
  3. ร้านที่ยังไม่รู้จัก → **การ์ด "ร้านนี้ของบริษัทไหน?"** เลือกบริษัท+แบรนด์ → บันทึกลง `shop_registry` → จำแนกใหม่อัตโนมัติ (ครั้งเดียว เดือนหน้ารู้เอง)
- **สรุปก่อน commit:** "ไฟล์นี้มี เบญญา X · เอ็มบาร์ค Y · ไม่รู้จัก Z — จะนำเข้าเฉพาะ [บริษัทปัจจุบัน] X ออเดอร์" → กันเข้าผิดเงียบ ๆ
- ใช้กลไกเดียวกันกับ **recon backend import** ด้วย (ไฟล์หลังบ้านก็อาจปนร้าน/บริษัท)
- fallback ถ้าชื่อร้านไม่ชัด: ดู brand/SKU prefix เป็นตัวช่วย (รอง)

ตารางใหม่ `shop_registry`: `shop_name · company · brand · channel` (ดู schema-draft.sql)

---

## 4. UI ที่ต้องเพิ่ม (รวมในโมดูล `orders`)

แท็บในหน้า "ทะเบียนคำสั่งซื้อ":
0. **🚦 สรุปสถานะงาน** ← ใหม่ (default · ดูข้อ 4.0)
1. **📋 ทะเบียน** (เดิม) — เพิ่มคอลัมน์ recon_status + iv_status
2. **🔍 ตรวจรายวัน (Recon)** ← ใหม่ · ดู `recon-mockup.html`
3. **🧾 สถานะ IV** ← ใหม่ (มี IV/รอคีย์/รอแก้ + export)
4. **💰 รับชำระ/ลูกหนี้** ← ใหม่ (bucket AR)
5. **📊 สรุปรายเดือน** ← ใหม่ (ดูข้อ 4.1)
6. timeline drawer ต่อแถว (เดิม แต่ดึงจาก order_events)

### 4.0 แท็บ "สรุปสถานะงาน" (status board — default)
> เจ้าของขอ: เห็นชัด ๆ ว่าแต่ละสถานะมีกี่ออเดอร์ กี่บาท · 1 ออเดอร์อยู่ **สถานะเดียว** = สเตปแรกที่ยังไม่เสร็จ (`ordCurrentStatus(o)`)

| สถานะปัจจุบัน | เงื่อนไข (จาก orders) |
|---|---|
| รออนุมัติ (คีย์มือ) | `source_type=manual` AND `approval_status≠accounting_accepted` |
| **รอเทียบยอดขาย** | auto AND `recon_status` ∈ (null, not_checked) |
| **ยอดขายไม่ตรง** | `recon_status=needs_review` |
| **รอคีย์ IV** | recon ผ่าน (matched/resolved หรือ manual approved) AND `iv_no` ว่าง |
| คีย์ IV ผิด รอแก้ | `iv_status=amount_mismatch` |
| **คีย์ IV แล้ว รอรับชำระ** | `iv_no` มี AND `received_at` ว่าง |
| **รับชำระแล้ว รอออก RE** | `received_at` มี AND `re_no` ว่าง |
| ออก RE แล้ว รอฝากเช็ค | `re_no` มี AND `bq_no` ว่าง |
| **ถอนเงินแล้ว รอเงินเข้าธนาคาร** | `bq_no` มี AND `bank_in_date` ว่าง |
| **ปิดงานแล้ว** | `bank_in_date` มี (AND `bank_matched`) |
| (ยกเลิก) | `status=cancelled` — แยกออก ไม่นับใน pipeline |

- การ์ด/ตาราง: **สถานะ · จำนวนออเดอร์ · ยอดเงิน** (ยอด = Σ `gross_sales`) + คลิกสถานะ → กรองไปแท็บทะเบียน
- เป็น **funnel เห็นคอขวด** ว่าค้างเยอะที่สเตปไหน · ทุกแถวมีปุ่ม export (เช่น "รอแก้ IV" โหลดไปแก้)

### 4.05 ค้นหา / เปิดดูออเดอร์ (global order lookup) — แถบบนสุด เห็นทุกแท็บ
> เจ้าของขอ: พิมพ์เลขออเดอร์ → เด้งการ์ดสรุปทันทีว่า "ถึงไหนแล้ว"
- ช่องค้นหา **ครอบคลุมทุกเลข**: `order_no` · `iv_no` · `re_no` · `bq_no` · `cheque_no` · ชื่อลูกค้า · SKU/สินค้า
- เจอ → แสดง **การ์ดรายละเอียด** ทันที (ไม่ต้องเลื่อนหาในตาราง):
  - หัวการ์ด: order_no · ช่องทาง · ร้าน · บริษัท · **chip สถานะปัจจุบัน** (จาก `ordCurrentStatus`)
  - แถวสรุป: ยอดขาย (gross/net) · IV no+วันที่ · RE no+เช็ค · BQ no · เงินเข้าแบงค์วันไหน · คงค้าง
  - **timeline เต็ม** (เหมือน drawer ในตาราง — ดึงจาก `order_events` มีเวลา+ไฟล์ที่มา)
  - adjustment (ถ้ามี) · ปุ่มไปแก้/ดูที่เกี่ยวข้อง
- พิมพ์เลข BQ/เช็ค → โชว์ **ทุกออเดอร์ในเช็ค/รอบถอนนั้น** (1 BQ : หลายเช็ค) เป็นลิสต์การ์ด
- search ผ่าน Supabase (index `order_no`/`iv_no`/`bq_no` ที่เพิ่มไว้) → เร็วแม้ข้อมูลเยอะ

### 4.1 แท็บ "สรุปรายเดือน" (กราฟแท่งต่อแพลตฟอร์ม)
- **เลือกเดือน** (dropdown) + **as-of date** ("ณ วันที่") → สรุปสะสมในเดือนถึงวันนั้น
- **กราฟแท่ง stacked ต่อแพลตฟอร์ม** (Shopee/TikTok/Lazada/หน้าร้าน) — ใช้ Chart.js ที่มีอยู่
  - **เต็มแท่ง = ยอดออเดอร์ (บาท)** แบ่งเป็น 2 ส่วนซ้อน: **คีย์ IV แล้ว** (Σ iv_amount) + **คงค้างคีย์ IV** (ยอดออเดอร์ − คีย์ IV)
  - เช่น Shopee: ออเดอร์ 100 = คีย์ IV 89 + คงค้าง 11 (ตามตัวอย่างเจ้าของ)
  - การ์ด KPI บน: รวมทุกแพลตฟอร์ม — ยอดออเดอร์ / คีย์ IV แล้ว / คงค้างคีย์ IV / จำนวนใบ
  - ตารางใต้กราฟ: แพลตฟอร์ม × (ออเดอร์ใบ · **ยอดออเดอร์** · **คีย์ IV แล้ว** · **คงค้างคีย์ IV** · ยกเลิก)
  - สลับมุมมองเป็น "จำนวนใบ" ได้ (count แทนบาท)
- **คำนวณฝั่ง client จาก `orders`** (ที่ dedup แล้ว) ตาม `sale_date`/`iv_date` ในเดือน → ไม่ต้องมีตารางใหม่
- export กราฟ/ตารางเป็น PNG/Excel (ใช้ html2canvas + XLSX ที่มีอยู่)

> ฐานข้อมูลพร้อมอยู่แล้ว (orders + iv_no + iv_amount + platform) → ทำได้ทันทีหลังมี lifecycle column

---

## 5. ลำดับลงมือ (หลัง approve mockup)
1. SQL: ขยาย `orders` + สร้าง `order_recon*` + เพิ่มคอลัมน์ `order_events` → ย้ายไป `supabase/order-pipeline.sql` (auto-run)
2. order_events helper + เขียนทุก ingest เดิม
3. Recon engine + แท็บ "ตรวจรายวัน" + 2 export
4. IV validation + แท็บสถานะ IV
5. หน้า AR
6. Deprecate `order_ledger` (ดูข้อ 6)

## 6. แผน deprecate `order_ledger`
- ปิดปุ่มอัปใน order_ledger / redirect โมดูลไปใช้ `orders`
- one-time migrate: เติม lifecycle (iv/re/bq/bank) จาก `order_ledger` → `orders` ผ่าน `order_no`
- เก็บตารางไว้ (ไม่ DROP) อ้างอิงย้อนหลัง

## 7. กฎ recon (ตัดสินแล้ว — เจ้าของยืนยัน 2026-06-24)

> **strict 100% — ต้องตรง 0 เป๊ะทุกค่า** (แนวเดียวกับ bank recon / marketplace recon)

1. **เทียบบน "ราคาขาย" (gross ก่อนหักส่วนลด) — ไม่ใช่ net**
   - บัญชีคีย์ **ราคาขายเต็ม** แล้ว **คีย์ส่วนลดแยกอีกบรรทัด** → recon ต้องเทียบ gross + ส่วนลด **แยกกัน**
   - BigSeller side: `gross_unit = ราคาสินค้าเดิม ?? ราคา` (★ แพลตฟอร์มใช้ `ราคาสินค้าเดิม` · คีย์มือ FACE/LINE/Dealer `ราคาสินค้าเดิม` ว่าง → ใช้ `ราคา`) แล้ว × `จำนวน` · ดู `channel-field-map.md`
   - manual orders (FACE/LINE/Dealer) **ข้าม recon** — gross ใช้ `ราคา`, คีย์ IV ผ่าน approval แทน
   - ⚠️ **ต้องปรับ `ORD_CH` config:** field `net` ปัจจุบันชี้คอลัมน์ *หลังหักส่วนลด* (Shopee "ราคาขายสุทธิ", TikTok "SKU Subtotal After Discount", Lazada "paidPrice") — ต้องเพิ่ม mapping คอลัมน์ **ราคาขายก่อนลด (gross)** ต่อช่องทาง เพื่อเทียบให้ถูกฐาน
2. **ค่าส่ง (shipping_fee) ต้องตรงด้วย — tolerance 0** เพราะเป็นค่าส่งที่เรียกเก็บจากลูกค้า **ใช้ยื่นภาษีขาย** ผิดไม่ได้
3. **4 ค่าที่ต้องตรงเป๊ะทุกตัว:** `gross (Σ price×qty)` · `shipping_fee` · `seller_discount` · `SKU×qty set` → ต่างแม้บาทเดียว = `needs_review`
4. **order_no ตรงกันเป๊ะทั้ง 2 ฝั่ง** → join ตรงๆ ไม่ต้อง normalize prefix/suffix

**ผลต่อ schema:** `order_recon` ควรแยกคอลัมน์เทียบเป็น `bs_gross/be_gross`, `bs_ship/be_ship`, `bs_discount/be_discount`, `bs_sku_sig/be_sku_sig` (แทน `bs_amount` รวม) เพื่อชี้ได้ว่า "ต่างที่ค่าส่ง" vs "ต่างที่ส่วนลด" vs "ต่างที่ราคา" — ดู schema-draft.sql ปรับตาม
