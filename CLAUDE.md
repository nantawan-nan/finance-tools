# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is
**Finance Tools** — Finance Operations Platform สำหรับ 2 บริษัท:
1. **Benya Medical Innovations Co., Ltd.** (code `BENYA`, theme teal `#0d9488`)
2. **M Bark Co., Ltd.** (code `MBARC`, theme navy `#1e3a8a`)

แอปภาษาไทยเป็นหลัก — รวมเครื่องมือการเงิน 10+ โมดูล (Bank Balance, AP/AR, Cash Flow Forecast, Executive Dashboard, BigSeller import, Sales Dashboard ฯลฯ) โดยมี **Supabase** เป็น single source of truth + Auth + RLS

## No build step — single-file SPA (read this first)
ไม่มี bundler, ไม่มี package.json, ไม่มี npm, ไม่มี framework, ไม่มี tests, ไม่มี lint.

**`index.html` ไฟล์เดียว** (~7000 บรรทัด, ~300KB) มี HTML + CSS + JavaScript รวมหมด. โหลด library จาก CDN เท่านั้น:
- React-like? **ไม่ใช้** — vanilla JS รัน `renderToolXxx()` แล้ว assign `main.innerHTML`
- `XLSX` (SheetJS), `supabase-js`, `Chart.js`, `chartjs-chart-treemap`, `lucide` (icons), `html2canvas`, `jsPDF`, Google Fonts IBM Plex

Consequences:
- ทุก function เป็น **global** — ไม่มี imports/exports
- เรียก style state ผ่าน `state.xxx` (global object ที่ persist ระหว่าง re-render)
- **edit แล้ว push = deploy เลย** (no build, no CI gate beyond migrate workflow)

## Run / preview locally
ต้อง serve ผ่าน HTTP (ไม่ใช่ `file://`):
- `python -m http.server 8000` → เปิด `http://localhost:8000` (entry = `index.html`)
- Login ต้องมี user ใน Supabase + role assigned (`user_company_access`)

## Deploy = `git push` → GitHub Pages
Live: **https://nantawan-nan.github.io/finance-tools/**

**Push checklist:**
1. commit + push → GitHub Pages auto-deploy (~30 วินาที)
2. ถ้ามีไฟล์ `supabase/*.sql` → workflow `db-migrate` รัน **อัตโนมัติ** บน Supabase (ดูส่วน "Database migrations")
3. แจ้ง user ให้ **Hard refresh** (Ctrl+Shift+R) เพราะ browser cache index.html นาน

## Database migrations (auto-run on push)
ไฟล์ `.github/workflows/migrate.yml` รัน SQL ทุกไฟล์ใน `supabase/` ทุกครั้งที่ push (ตามลำดับ alphabetical). ใช้ Management API + secret `SUPABASE_ACCESS_TOKEN`.

**สำคัญ:**
- ไฟล์ทุกตัวต้อง **idempotent** — `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `DROP POLICY IF EXISTS ... CREATE POLICY` (run ซ้ำได้ไม่เสีย)
- ลำดับ "h" > "f" — ไฟล์ที่ขึ้นต้น `hotfix-*` รันหลัง `fix-*` (เคยทำให้ trigger ฟื้นกลับมาเป็น bug)
- ❌ **อย่าใส่ `DROP FUNCTION ... CASCADE` ในไฟล์ที่ run บ่อย** — เคย break dependencies ของ RLS policies
- หลัง push รอ ~1 นาที (gh actions) + ดู conclusion success

## Database backups (auto-run ตี 2 ICT)
ไฟล์ `.github/workflows/backup.yml` (workflow ชื่อ `db-backup`) รันทุกคืน 02:00 ICT (`cron 0 19 * * *`) + กด Run เองได้:
- ใช้ `pg_dump --schema=public` → **`.sql`** (ทุกตาราง + function + RLS) **และ** `\copy` ต่อตาราง → **`.csv`** (เปิดใน Excel)
- gzip → เข้ารหัส **AES-256** (`BACKUP_PASSPHRASE`) → commit เข้า `backups/` → เก็บ 30 ไฟล์ล่าสุดต่อชนิด
- ต้องมี secret **`SUPABASE_DB_URL`** (Supabase → Database → Connection string → **Session pooler URI** + รหัส DB) — Session pooler เพราะ GitHub Actions เป็น IPv4
- วิธี restore: `backups/RESTORE.md` (decrypt → gunzip → `psql -f` / `\copy` CSV)
- ⚠️ ของเดิมเคย backup ผ่าน REST API เป็น JSON + ลิสต์ตารางแบบ hardcode (ตกหล่นตาราง FinOps ทั้งหมด) — เปลี่ยนมา pg_dump แล้วครอบทุกตารางอัตโนมัติ

## Architecture
- **`index.html`** — entry + ทุก code (~7000 lines)
  - lines 1-300: `<head>` (CDN scripts, Google fonts) + `<style>` (CSS หลัก ~280 lines)
  - lines 300+: `<style>` ส่วน Executive Dashboard เพิ่มเติม
  - lines 300+: `<body>` + `<script>` ทั้งหมด:
    - `AUTH`, `sb` (Supabase client), `COMPANIES`, `TOOLS` arrays
    - `state` global object (per-tool sub-states)
    - `renderLogin`, `renderApp`, `buildShell`, `renderSidebar`, `renderTool` (dispatcher)
    - `renderToolXxx` ต่อหน้า (one function per tool)
    - helpers per module: `bb*` (bank balance), `apo*` (AP), `rec*` (recurring), `cff*` (cash flow), `ed*` (executive dashboard), `usr*` (users), `ar*` (AR), `bs*` (BigSeller), `armap*`, `exk*`, etc.
- **`supabase/*.sql`** — DDL/migrations (run auto via workflow)
- **`logos/`** — โลโก้บริษัท (`benya.png`, `mbark.png`) — ใช้ใน sidebar + PDF print header
- **`logos bank/`** — โลโก้ธนาคารไทย (ชื่อไฟล์ภาษาไทย เช่น `กรุงเทพ.png`, `ไทยพาณิช.png`)
- **`design-handoff/`, `design-handoff-v2/`** — Claude Design exports (HTML/CSS reference)
- **`for-design/`** — code snippets แยกหน้า สำหรับส่งให้ Claude.ai redesign
- **`tools/`** — utility HTMLs (backup, auth setup) — ไม่ใช่ส่วนของ live app
- **`README.md`** — สาธารณะ, สั้น

## Data model (Supabase tables)

ทุก table มี: `id, company_id, created_at/by, updated_at/by, deleted_at/by` (soft delete) + RLS

### Phase 0 (foundation — `supabase/phase0-foundation.sql`)
- `companies` — `code` (`BENYA`/`MBARC`), `name`, etc.
- `users_profile` — mirrors auth.users (1:1)
- `user_company_access` — `(user_id, company_id, role)` — role ∈ `admin|finance_mgr|accountant|treasury|sales_ops|approver|executive|viewer`
- `audit_log_v2` — append-only ผ่าน trigger
- helpers: `fn_my_companies()`, `fn_my_role(p_co)`, `fn_set_updated_at()`, `fn_audit_trigger()`, `fn_block_hard_delete()`

### Phase 1 (FinOps — `supabase/finops-phase1.sql` + `-fix1.sql` + `-fix2.sql`)
- `bank_accounts` (master) + `bank_balances` (append-only history)
  - `fn_balance_as_of(p_company, p_as_of)` — ยอดล่าสุดต่อบัญชี ณ วันที่
- `vendors`
- `ap_invoices` — UNIQUE `(company_id, invoice_no)` กันคีย์ซ้ำจาก CSV/XML import
  - Fields: `due_date`, **`planned_payment_date`** (จนท. กรอกเอง), **`internal_note`** (หมายเหตุเพิ่ม), `category`
- `ap_payments` + trigger `fn_ap_recompute` (auto-update `amount_paid` + `status`) · +`voucher_id`/`receipt_no`(RR/RW/AC)/`cheque_no` (จากนำเข้ารายงานจ่าย)
- `ap_payment_vouchers` (PS) — 1 PS จ่ายได้หลาย RR · `ps_no` unique · gross/net/discount/bank_label/bank_account_id/cheque/note · seed จากนำเข้ารายงานจ่ายชำระหนี้ (`supabase/ap-payment-settlement.sql`)
- `vendors` +ทะเบียนบัญชีผู้รับเงิน: `bank_code/bank_name/bank_account_no/account_name/account_type/notify_email/bank_note_raw` (seed จากไฟล์ "รายละเอียดผู้จำหน่าย" · parse ช่องหมายเหตุ)
- `recurring_expenses` + `recurring_occurrences` + `fn_materialise_recurring()`
- `csv_imports` (audit trail)
- RLS: read = ทุก user ของ company, write = admin/finance_mgr/accountant/treasury

### Other tables
- `exec_cashflow` — `(company_id PK, data jsonb)` — Executive Dashboard data per company (`supabase/exec-cashflow.sql`)
- `financial_statements` — `(company_id, kind ['pnl'|'balance'], data jsonb)` unique `(company_id, kind)` — งบกำไรขาดทุน + งบแสดงฐานะการเงิน per company (`supabase/financial-statements.sql`) · seed MBark อยู่ใน client `window.FIN_SEED` (โชว์ก่อนถ้า cloud ว่าง)
- `ar_receipts` — Phase 0 AR module (`supabase/ar-module.sql`)
- (อนาคต: ar_invoices, marketplace_settlements, forecast_items)

## Modules (TOOLS array — render dispatcher in `renderTool()`)

| id | function | สถานะ | หมายเหตุ |
|---|---|---|---|
| `home` | `renderToolHome` | live | Hub grid + greeting "สวัสดี <user>" — auto-fill toolcard |
| `execdash` | `renderToolExecDash` | live (admin only) | **★ ห้ามแก้ — นิ่งแล้ว** ใช้เป็น reference สี/สไตล์ |
| `orders` | `renderToolOrders` | live | **ทะเบียนคำสั่งซื้อ** (Order Ledger) — รับรู้ออเดอร์ 4 ช่องทางก่อนมี IV · timeline ขาย→IV→รับชำระ→แบงค์ · ord* helpers |
| `prodcost` | `renderToolProdCost` | live | **ต้นทุนผลิตภัณฑ์** (การขาย บนสุด) — การ์ดสินค้า: รูป (repo `product-cost/`) + ต้นทุน/หน่วยแยก 6 หมวด + ราคาขายแก้ได้ (`product_prices`) · `prod*` · data ใน `window.PRODUCT_COST` |
| `dashboard` | `renderToolDashboard` | live | Sales Dashboard |
| `bigseller` | `renderToolBigSeller` | live | **บันทึกขายเชื่อ (IV)** — เกาะ order_ledger · ส่งออก AutoKey + ตรวจการคีย์ด้วย 141.RWT · ivr* helpers (รื้อใหม่ 2026-06-27) |
| `expressmatch` | (retired) | redirect | ★ ลบจาก sidebar 2026-06-27 · `state.tool='expressmatch'` → redirect ไป `bigseller` · function ยังอยู่ (dead) |
| `exportkey` | (retired) | redirect | ★ ลบจาก sidebar 2026-06-27 · `state.tool='exportkey'` → redirect ไป `bigseller` · function ยังอยู่ (dead) |
| `ar` | `renderToolAr` | live | AR Outstanding |
| `armap` | `renderToolArmap` | live | Map ลูกหนี้ → เงินเข้า |
| `settle` | (none — generic) | live | จับยอด Settlement |
| `bankrec` | `renderToolBankRec` | live | **Full Bank Reconciliation** (Phase 1) — Express XML ↔ Statement (SCB XLSX / BBL XLS) · strict same-date · brec* helpers · **แท็บ "🏷️ จัดหมวด (AI)"** เดาหมวดเงินรับ-จ่ายอัตโนมัติ (catbot* · self-learning · `catbot_rules`) |
| `withdraw` | (none) | soon | กระทบยอดถอนเงิน |
| `ap` | (replaced) | soon (เก่า) | — — |
| `ap_outstanding` | `renderToolApOutstanding` | live | **AP จริง** (finops phase 1) · 4 แท็บ: คงค้าง · **จ่ายแล้ว** (กลุ่มตาม PS) · **ตั้งโอน** (ส่งออกให้การเงินโอน) · **ทะเบียนบัญชีผู้รับเงิน** · นำเข้ารายงานจ่ายชำระหนี้ → mark จ่าย+สร้างบิล (`apst*`) |
| `bank_balance` | `renderToolBankBalance` | live | **ตารางกรอกยอดรายวัน** (chip เลือกวัน + "พรุ่งนี้" คาดการณ์ carry-forward) — bb* helpers |
| `recurring` | `renderToolRecurring` | live | ค่าใช้จ่ายประจำ |
| `cashflow` | `renderToolCashflowForecast` | live | **Cash Flow Forecast** — มี 2 view: 📋 พนักงาน (daily LINE) + 📊 ผู้บริหาร (30d) |
| `finstmt` | (group) | live | **งบการเงินทางบัญชี** — nav-group ใต้ Cash Flow · อัปไฟล์ "งบการเงิน" (xlsx) → 2 เมนูย่อย · fin* helpers |
| `finpnl` | `renderToolFinPnl` | live | **งบกำไรขาดทุน** (P&L) รายเดือน (สะสมต้นปี) · KPI + ตารางรายบัญชี (toggle ย่อ/รายบัญชี) |
| `finbalance` | `renderToolFinBalance` | live | **งบแสดงฐานะการเงิน** (Balance Sheet) เทียบปีก่อน · คลิกดูบัญชีย่อย · สินทรัพย์=หนี้สิน+ส่วนของผู้ถือหุ้น |
| `tasks` | (none) | soon | — |
| `docs` | `renderToolDocs` | live | **Document Center** — คลังเอกสาร PDF (STM/เมมโม่/อนุมัติจ่าย/สัญญา) · เก็บบน Supabase Storage bucket `documents` · อัป/ค้นหา/เปิด/โหลด/ลบ + ดาวน์โหลดทั้งหมด ZIP · doc* helpers |
| `users` | `renderToolUsers` | live (admin only) | จัดการผู้ใช้ |
| `audit` | (none) | soon | — |

## Companies + Theme + Logos
- **COMPANIES** array ที่ index.html: `[{ id:'mbark', code:'MBARC', ... }, { id:'benya', code:'BENYA', ... }]`
- Switch ผ่าน sidebar — `setCompany(id)` → `state.company` → re-render → CSS `body[data-co="..."]` swaps brand color vars
- Benya: teal/green `#0d9488`
- MBark: navy `#1e3a8a`
- Consolidated (future): purple

**Logos:**
- บริษัท: `logos/benya.png`, `logos/mbark.png` — ใช้ใน sidebar + PDF header
- ธนาคาร: `logos bank/{ชื่อไทย}.png` (ใช้ `encodeURI` เพราะชื่อไทย) — ปัจจุบันมี `กรุงเทพ.png` (BBL), `ไทยพาณิช.png` (SCB). fallback ไป Clearbit (`https://logo.clearbit.com/{domain}`) ถ้าไฟล์ไม่มี — `cffBankLogo()` ใน Cash Flow page

## Auth (Supabase Auth + RLS)
- Email/password ผ่าน `sb.auth.signInWithPassword()`
- Role อยู่ใน `auth.users.app_metadata.role` (admin/finance_mgr/...) — ตั้งผ่านหน้าจัดการผู้ใช้
- `user_company_access` — กำหนดสิทธิ์เข้าบริษัท + role ต่อบริษัท
- **`fn_my_companies()`** + **`fn_my_role(p_co)`** → SECURITY DEFINER, ใช้ใน RLS policies
- ปุ่ม "ออกจากระบบ" → `sb.auth.signOut()`

**⚠️ Auth trigger gotcha:** `phase0-foundation.sql` มี `trg_sync_user_profile ON auth.users AFTER INSERT only` (อย่าเปลี่ยนเป็น `INSERT OR UPDATE` — เคยทำให้ login fail "Database error granting user" เพราะ Supabase update `last_sign_in_at` ทุก login → trigger fire → error → blocked). มี exception handler + search_path ครบใน function แล้ว ห้ามแตะ.

## Conventions & Gotchas

### CSS / UI
- ฟอนต์: **IBM Plex Sans Thai** (ไทย) + **IBM Plex Sans** (อังกฤษ)
- Icon: **Lucide** ผ่าน `<i data-lucide="name">` + เรียก `lucide.createIcons()` หลัง `innerHTML`
- Palette: `--brand` (per company), `--in` (teal #14B8A6), `--out` (pink #E18AAA), `--warn` (amber)
- Glassmorphism: `background: var(--glass)` + `backdrop-filter: blur(10px)` + `border: var(--glass-border)`
- Layout: `.main { max-width: none }` (ใช้พื้นที่จอเต็ม)

### State
- `state.company` — current company id (mbark/benya)
- `state.tool` — current tool id
- Per-tool state: `state.{tool_short}[company_id]` (e.g. `state.apo[co]`, `state.cff[co]`, `state.bb[co]`)
- ⚠️ ห้าม share state ข้าม company — แต่ละ company มี container แยก

### Data persistence
- **Supabase = single source of truth** ทุกหน้า
- localStorage = cache อ่านอย่างเดียวเพื่อโหลดเร็ว (sidebar collapse, user preferences)
- Executive Dashboard ใช้ **cloud-first sync** — ถ้า `exec_cashflow` row มี → ใช้เสมอ (ignore local timestamp), ถ้าว่าง + local มี → auto push (recovery)

### Auth role โค้ดต้องเช็ค
- write actions: `fopCanWrite()` หรือ `AUTH.role && ['admin','finance_mgr','accountant','treasury'].includes(AUTH.role)`
- admin only: `t.adminOnly && AUTH.role !== 'admin'` → ซ่อนจาก sidebar + filter ที่ home

### Number formatting
- ค่าติดลบ ⇒ `()` ทั่ว Executive Dashboard — `edFmt()` ทำให้อัตโนมัติ (ส่ง negative number)
- AP/Cash Flow ใช้ `fopFmt()` — เหมือนกัน
- ใช้ `apoNum()` ในการ parse CSV/XML ที่มี comma (`500,000.00` → 500000)

### Critical "ห้ามแตะ"
- **Executive Cash Flow Dashboard** (`renderToolExecDash` + ทุก `ed*` function + `edRender*`) — นิ่งแล้ว ใช้เป็น reference เท่านั้น
- `phase0-foundation.sql` trigger `trg_sync_user_profile` ต้องเป็น `AFTER INSERT only` (ไม่ใช่ `INSERT OR UPDATE`)

## Recent changes (chronological)

### 2026-07-22 (3) — ★ รับชำระ: เลือกดูตามเดือน / ช่วงวันรับเงิน (ทะเบียนรับชำระ + จับคู่ IV↔Income)
- **เจ้าของขอ:** ดูสถานะรายการรับชำระของเดือนนั้น ๆ ว่าขาดอะไร — เดิมรวมทุกเดือน (5-6-7 ที่ยังขึ้นระบบไม่เต็ม) ปนกัน
- **`incDateBarHtml`:** chip เดือน (auto จาก `incAvailableMonths` = วันรับเงินที่มีจริง · `incMonthLabel` เดือนไทย) + ช่วงวันที่ from/to + ล้าง · `incIsoInRange`/`incRowInRange` · setters `incSetIncMonth`/`incSetIncDate`/`incClearIncDate` · state `d.incMonth`/`incFrom`/`incTo` (ISO · from/to override เดือน)
- **แสดงเฉพาะแท็บ list + recon** (renderToolSalesIncome) · กรอง incRows ตาม `paid_date`
- **`incReconData`:** กลุ่มฝั่ง income (ready/received/noIv/noOrder/cancel/creditNote) กรองตามเดือน · **noIncome กรองตาม `iv_date`** (ไม่มีวันรับเงิน) · **"มี income" (incByOrder) เช็คจาก `allInc` ทั้งหมด** (ไม่ผูกเดือน) — กัน noIncome หลอกเมื่อ income คนละเดือนกับ IV
- **`incRenderList`:** empty state เช็ค `allRows` (ไม่มีข้อมูลเลย) · ที่เหลือใช้ `rows` (กรองเดือน) · verified date logic (เดือน/ช่วง/ทั้งหมด) · syntax OK · กระทบหน้าอื่น = 0 · ไม่ต้อง migration
- **หมายเหตุ:** แท็บ fees มี month filter ของตัวเอง (`feeMonth`) แยกกัน · export tab มี from/to แยก — ไม่ชนกับ `incMonth`

### 2026-07-22 (2) — ★ รับชำระ: แยกออเดอร์ net≤0 (มี IV) เป็นกลุ่ม "ต้องออกใบลดหนี้ (CN)"
- **เจ้าของแจ้ง:** ออเดอร์ที่เงินเข้าสุทธิ **≤ 0** บัญชี**ไม่รับชำระ** → ออก**ใบลดหนี้ (CN)** แทน · (net ติดลบมักจากค่าขนส่งถูกหักจากกระเป๋าแพลตฟอร์ม บันทึกตอนฝากเช็ค)
- **`incReconData`:** มี IV + `net≤0` + ยังไม่รับชำระ → กลุ่มใหม่ `creditNote` (เดิมอยู่ `ready`) → **`ready` เหลือเฉพาะ net>0** (ตรงกับหน้าส่งออก RE ที่ `probOf` บล็อก net≤0 อยู่แล้ว = สองหน้า consistent) · `cancelledRefund` = เฉพาะที่**ยังไม่มี IV** (net≤0/ยกเลิก) แยกจาก creditNote (มี IV)
- **UI (`incRenderRecon`):** banner ส้ม "ต้องออกใบลดหนี้ (CN)" คลิกกางดู (grp `creditNote`) + ส่งออก Excel/CSV ไปทำ CN · lastCell "เลข IV · ออกลดหนี้" · card ready sub = "มี IV · เงินเข้า > 0" · export map +creditNote
- **verified (harness routing):** IV+net-2/0→creditNote · IV+net568→ready · IV+รับแล้ว→received · ไม่มี IV+net-5→cancel · syntax OK · กระทบหน้าอื่น = 0 · ไม่ต้อง migration

### 2026-07-22 — ★ เงินสดย่อย: เลขที่การเบิก (คุมของเรา) รันอัตโนมัติ + ค้นหาหน้ารับชำระ + SQ=Qi
- **เลขที่การเบิก:** เจ้าของขอเลขคุมการเบิก **แยกจาก "เลขที่เอกสาร"** (แต่ละแผนกรันเอง อาจซ้ำ) — เบญญา `BY2607001..` · เอ็มบาร์ค `MB2607001..` (`{BY|MB}{YYMM}{NNN}`) · เปลี่ยนเดือน=รันใหม่ · **ย้ายผิดบริษัท(`pcMoveCompany`)/ลบออก → เลขเลื่อนเต็มเอง** (เบอร์ว่างถูกรายการใหม่ใช้ต่อ — ตรงที่เจ้าของอธิบาย)
  - `pcAssignWno(rows,round,company)` **คำนวณตามลำดับที่คีย์** (created_at→seq · จาก `pcCompute`) เฉพาะรายการจ่าย(`amount_out>0`) · **ไม่เก็บค่าตายตัว** (computed) → ย้าย/ลบ recompute อัตโนมัติ · `pcWnoPrefix`/`pcWnoYYMM`
  - คอลัมน์ "เลขที่การเบิก" (คอลัมน์แรก) ในตาราง + ฟอร์มโชว์เลขถัดไป/ปัจจุบัน (read-only) + Excel export + PDF · colspan 14→15 (จอ) · 9→10 (PDF) · **ไม่ต้อง migration**
- **ค้นหาหน้ารับชำระ:** `incSetIncSearch` + ช่องค้นหาในแท็บทะเบียนรับชำระ (เลขออเดอร์/เลข IV/ช่องทาง · re-focus กัน cursor หลุด) · join `order_ledger` → ค้นด้วยเลข IV ได้ + เพิ่มคอลัมน์เลข IV
- **`benyaSkuBrand` +`SQ`→QI:** แพ็ค Qi Care (SQHD02/SQI152/SQI1G1) เดิมเดาแบรนด์ไม่ออก (ขึ้นต้น S ไม่ใช่ Q) → 156 ใบไม่ถูกตรวจ Vat · verified 14111.CSV: เดาไม่ออก 156→3 · ต้องแก้คงที่ 175 (SQ คีย์ถูกทั้งหมด · ไม่ชน SBR/STR/BTR/SDO)

### 2026-07-21 (5) — ★ ตรวจ IV: ปุ่ม "ส่งออกคีย์ใหม่ (เลข IV เดิม)" แก้รหัสลูกค้า/Vat ที่คีย์ผิด (Benya)
- **เจ้าของขอ:** เคส Benya คีย์ Qi เป็น Betra — ระบบฟ้องแล้ว (แบนเนอร์แดง 175 ใบ · `ordIvBrandCheck`) แต่อยากส่งออกไปคีย์แก้ **เลข IV เดิม แต่รหัสลูกค้า/Vat ที่ถูกต้อง**
- **`ivrBuildExportAoA(orders, startIv, ivMap)`** +param `ivMap` (order_id → เลข IV เดิม) — ถ้ามี ใช้เลขเดิม (`String(iv).replace(/\D/g,'').padStart(10)`) แทนเลขรัน · ไม่มี = พฤติกรรมเดิมเป๊ะ (backward-compat)
- **`ordIvExportRekey()`:** กรอง `brandBad` (custMismatch/vatMismatch · ไม่ voided) → หาออเดอร์จาก `orderRowId`/`ref_order_id` ในทะเบียน → build AutoKey ด้วยเลข IV เดิม + รหัสลูกค้า/Vat จาก `ivrOrderExportMeta`→`incBrandOf` (SKU-authoritative → ตรงกับที่แบนเนอร์บอก "ควรเป็น" เป๊ะ) · ข้าม orphan (ไม่มีออเดอร์) · format 17 คอลัมน์ + `forceTextCells([1,2,3,6,11,12])` เหมือนส่งออก IV ปกติ
- **UI:** ปุ่มแดง "ส่งออกคีย์ใหม่ (เลข IV เดิม)" ในแบนเนอร์ตรวจแบรนด์ + footer อธิบาย 2 ทางแก้ (ส่งออกไฟล์ / แก้มือใน Express)
- **เฉพาะ Benya** (brand check ไม่ทำ mbark) · syntax OK · **กระทบหน้าอื่น = 0** (reuse ivrBuildExportAoA · param optional) · ไม่ต้อง migration

### 2026-07-21 (4) — ★★ ตรวจการคีย์ 1.9.1: parser บล็อก RE ไม่คงที่ 3 แถว → ข้ามใบ/ได้ IV ผิด (false ตกหล่น)
- **อาการ (191.CSV):** batch verify บอก RE2606000974/976/1008 "ยังไม่พบใน 1.9.1" ทั้งที่อยู่ในไฟล์จริง (เจ้าของเช็คด้วย Find ใน Excel)
- **ต้นเหตุ:** `salIncomeParseReceiptReport191` สมมติทุกบล็อก RE = **3 แถวเป๊ะ** แล้ว `i+=2` (กระโดด 3 แถว/บล็อก) · แต่ไฟล์จริงบล็อก **1/2/3 แถวปนกัน** (บางใบไม่มีเช็ค/ไม่มี IV row แยก) → พอเจอบล็อกสั้น การจับแถวเลื่อน → **ข้ามหัว RE ใบถัดไป** + บางใบได้ `iv_no` ผิด (จับ r3 ที่เลื่อนไปโดนบล็อกอื่น) · ผล: parse ได้แค่ **1527 แถว (จริง 1638)** · iv_no ว่างเกินจริง 109 ใบ → `vByIv`/`incMatchVerifyRow` จับไม่เจอ → ขึ้นตกหล่นหลอก
- **แก้:** เปลี่ยนจากกระโดด `i+=2` ตายตัว → **สแกน detail rows ในบล็อกจนถึงหัว RE ใบถัดไป** (`isRE(rows[j])` = break) · IV row = ช่อง[5] มีเลข · cheque/net row = ช่อง[14] มีเลขเช็ค + สุทธิช่อง[17] · รองรับบล็อกกี่แถวก็ได้ · เอา `i+=2` ออก (ปล่อย loop re-sync ที่หัว RE เอง)
- **verified 191.CSV:** 1638 แถว · iv_no ว่างเหลือ 13 (บล็อกไม่มี IV จริง) · RE974/976/1008 จับ IV เจอครบ (IV2606001068/992/1049) · **กระทบเฉพาะแท็บตรวจ 1.9.1** (parser ใช้ที่เดียว = `incVerifyUpload`) · syntax OK · ไม่ต้อง migration
- **★ ผลข้างเคียงที่ดีขึ้น:** ทุกฟีเจอร์ที่พึ่ง verify.rows แม่นขึ้น (coverage/RE↔IV mismatch/tag-back) — เดิม ~111 RE ถูกข้าม/IV ผิดเงียบ ๆ

### 2026-07-21 (3) — ★ ส่งออก RE: checkbox เลือก/ติ๊กออก + ตรวจกับรายงานลูกหนี้คงค้าง (ตัดที่รับชำระ/คีย์มือแล้ว)
- **เจ้าของขอ:** (1) ส่งออก RE ให้เลือกทั้งหมดแล้วติ๊กเอาตัวที่ไม่ต้องการออก (บางตัวบัญชีคีย์รับชำระมือไปแล้ว) (2) ตรวจกับรายงานลูกหนี้คงค้าง ณ วันนั้น ว่า IV ใบนั้นยังค้างอยู่ไหม
- **checkbox เลือกส่งออก:** คอลัมน์ติ๊กหน้าตาราง + master (`incReSelectAll` เลือกทั้งหมด/ไม่เลือกเลย · `incReResetSel` คืนค่าติ๊กอัตโนมัติ) · `incReIsSelected(d,r)` = user override (`d.reSel[orderNo]`) ก่อน ไม่งั้น default เลือกทุกใบยกเว้นที่รับชำระแล้ว · **เลข RE รันต่อเฉพาะที่ติ๊ก** (reIdx display = index ใน `selected`) · `incExportRE` ใช้ `selected` (ไม่ใช่ `view` ทั้งหมด) · KPI/seed preview/ปุ่มส่งออกใช้ `selected.length`
- **รายงานลูกหนี้คงค้าง (Express CSV cp874):** `incParseArOutstanding` อ่าน col[7]=IV/RE · col[11]=ยอดค้าง · หัว "ณ วันที่ DD <เดือนย่อ> YYYY" → `incThaiAbbrevDate` (ม.ค.–ธ.ค. · พ.ศ.→ค.ศ.) · เก็บ `d.arReport={asOf, ivsFull:Set, ivsDig:Set, count, sum}` (in-memory ต่อบริษัท · ไม่ persist) · **verified 1A4.CSV: asOf 2026-07-21 · 227 ใบ · ค้างรวม 107,678.06 (ตรงยอดรวมท้ายรายงาน)**
- **`incArStatus(d,r)`:** IV อยู่ในลูกหนี้คงค้าง = `outstanding` (ยังค้าง · คีย์ได้) · **ไม่อยู่ + iv_date ≤ วันที่รายงาน = `settled` (รับชำระ/คีย์มือแล้ว → ติ๊กออกอัตโนมัติ)** · ใหม่กว่ารายงาน = `unknown` (คงไว้ · รายงานยังไม่ครอบ) · null = ไม่ได้อัปรายงาน
- **UI:** แถบอัปรายงาน (เหลือง=ยังไม่อัป · เขียว=อัปแล้วโชว์ asOf/count/sum + จำนวนตัดออก) · แถวแดง=รับชำระแล้ว · badge สถานะในคอลัมน์หมายเหตุ · match IV ทน format (`incNormKey` + digits-only `incIvDigits`)
- **กระทบหน้าอื่น = 0** (เพิ่มฟังก์ชัน `incParseArOutstanding`/`incArStatus`/`incReIsSelected`/`incRe*`/`incUploadArReport` · reuse `incNormKey`/`incIvDigits`/`bmpDecodeCp874`/`bmpParseCsvText`) · syntax OK · ไม่ต้อง migration

### 2026-07-21 (2) — ★ เงินสดย่อย: ปุ่มติ๊ก "จ่ายแล้ว/ยังไม่จ่าย" + เรียงตามลำดับที่คีย์ (ไม่ออโต้ตามวันที่)
- **เจ้าของขอ:** (1) บางรายการส่งมาแล้วแต่ยังไม่เรียบร้อย/ยังไม่โอน อยากคุมในทะเบียนไว้ก่อน แล้วค่อยติ๊กเมื่อจ่ายจริง (2) เรียงตามที่แนนคีย์ ไม่เรียงออโต้ตามวันที่
- **Migration `petty-cash-extras.sql`** +`is_paid boolean not null default true` (ของเก่า/นำเข้า = จ่ายแล้ว) · idempotent · **ต้อง push ให้ migration รันก่อน** ถึงบันทึก/ติ๊กได้
- **ปุ่มติ๊ก:** ฟอร์ม +checkbox "จ่าย/โอนแล้ว" (`#pcPaid` · ใหม่ default ติ๊ก · แก้ = `is_paid!==false`) · `pcSaveForm` เก็บ `is_paid` · ตาราง +คอลัมน์ "สถานะจ่าย" (`pcTogglePaid` คลิกสลับ · local update ไม่ reload) · **แถวยังไม่จ่าย = พื้นเหลือง** (`#fffbeb`) · Excel export +คอลัมน์ "สถานะ"
- **เรียงตามที่คีย์:** `pcCompute` sort เปลี่ยนจาก `pay_date→seq→created_at` เป็น **`created_at→seq`** (เวลาบันทึก = ลำดับคีย์) · **carry-forward ไม่กระทบ** (`pcChainClosings` ใช้ `R.closing` = total order-independent)
- **หมายเหตุ:** ยอดคงเหลือวิ่งยังนับรวมรายการที่ยังไม่จ่าย (คุมในทะเบียน — ถ้าอยากให้ยังไม่จ่ายไม่หักยอด ค่อยแก้) · colspan ตาราง 13→14, opening/total row trailing 4→5 · **กระทบหน้าอื่น = 0** (โมดูล pc* · reuse select `*`)

### 2026-07-21 — ★ AP นำเข้ารายงานจ่ายชำระหนี้: บรรทัดใบรับ (RR) ที่ใส่เลข PS ซ้ำ ถูกนับเป็น PS ซ้ำ (net 0)
- **อาการ (ไฟล์ 2912.CSV):** นำเข้ารายงานจ่ายชำระหนี้ → 1 PS แตกเป็น 2 การ์ด: อันจริง (net + SCB-4889) + อันซ้ำ (net 0.00 · ไม่รู้บัญชี · ไม่มีใบรับ)
- **ต้นเหตุ:** Express export บางแบบใส่เลข PS ในช่อง[3] ของ**บรรทัดใบรับ (RR/RW/AC)** ด้วย · `apstParsePaymentReport` เช็คแค่ `/^PS/i.test(c3)` แล้วนับเป็นหัว PS ใหม่ → บรรทัด RR ถูกนับเป็น PS ก้อนที่ 2 (net จากช่อง[13] ว่าง = 0 · แบงค์ช่อง[21] ว่าง)
- **แก้:** คำนวณ `isDetail = c5 มีเลข RR/RW/AC` (`/^[A-Zก-๙]{1,3}\d{4,}/`) ก่อน → เงื่อนไขหัว PS เป็น `/^PS/i.test(c3) && !isDetail` · บรรทัด RR ที่ซ้ำเลข PS ตกไปเข้า detail branch (แนบใต้ PS เดิม) ถูกต้อง
- **behavior-preserving:** ไฟล์เดิมบรรทัด RR ปล่อยช่อง[3] ว่างอยู่แล้ว → ผลเท่าเดิม · verified: 2912.CSV 12 บรรทัด → 6 PS (แต่ละอันมี 1 RR) · **กระทบหน้าอื่น = 0** · ไม่ต้อง migration

### 2026-07-20 (6) — ★ AP: การจ่ายเอง (ไม่ผ่าน PS) โผล่ในแท็บ "จ่ายแล้ว" (เคสเงินมัดจำรหัส A)
- **เจ้าของขอ:** AP รหัส A = เงินมัดจำ ดึงรายงานจ่ายชำระหนี้ไม่ออก → กดจ่ายเองในหน้าคงค้าง แต่ไม่โผล่ในแท็บ "จ่ายแล้ว" (แท็บนั้นอิง PS voucher ล้วน)
- **แก้ `apstLoadVouchers`:** โหลด `ap_payments` ที่ `voucher_id` ว่าง (จ่ายเอง จาก `apoBulkPay`/`apoOpenPay`) → สร้าง **pseudo-voucher ต่อบิล** (`id='manual-'+invId` · `_manual:true` · ps_no=invoice_no · net=Σamount · _cat จาก invoice) push เข้า `vouchers`+`byVoucher` → ไหลเข้า list/table/filter ปกติ · badge "จ่ายเอง" (ฟ้า) ในคอลัมน์ PS
- **`apstRenderTransfer` ตัด `_manual`** (จ่ายแล้ว ไม่ต้องตั้งโอน) — filter + dates chip
- **กระทบหน้าอื่น = 0** · ไม่ต้อง migration (reuse ap_payments/ap_invoices) · syntax OK

### 2026-07-20 (5) — ★ เงินสดย่อย: ยอดยกมา carry-forward + เจ้าของวงเงิน (สรุปคงเหลือรายคน) + เต็มหน้า
- **เจ้าของขอ:** (1) ยอดยกมา ดึงยอดยกไปเดือนก่อนอัตโนมัติ (2) สรุปให้พี่ป้อมว่าวงเงินเหลือกี่บาท (โอนคืนบริษัท) → ต้องกรอก "วงเงินของใคร" (3) ตารางเต็มหน้า (ตอนนี้เหลือพื้นที่)
- **(1) carry-forward:** `pcChainClosings(d)` คำนวณทุกเดือนเรียงเวลา · opening = ตั้งเอง (petty_cash_rounds) ถ้ามี > ยอดยกไปเดือนก่อน · `pcOpeningOf(d,round)` ใช้ใน render/pcSetOpening · โชว์ "(ยกมาจากเดือนก่อน)" · verify: มิ.ย. closing 2596 → ก.ค. opening 2596
- **(2) เจ้าของวงเงิน:** migration `petty-cash-extras.sql` +`fund_holder text` · ฟอร์ม input+datalist "เจ้าของวงเงิน" · คอลัมน์ในตาราง · **`pcFundSummary(d)`** รวมทุกเดือน group by fund_holder → การ์ด "💰 วงเงินคงเหลือรายเจ้าของ" (เติมเข้า−จ่ายไป=คงเหลือให้โอนคืน) · verify: พี่ป้อม in5000 out2722 remain2278
- **(3) เต็มหน้า:** `.pc-wrap max-width:1200px→none`
- **ตาราง 12→13 คอลัมน์** (เพิ่มเจ้าของวงเงิน) · export Excel +คอลัมน์ · **ต้อง push ให้ migration รัน** (fund_holder) · **กระทบหน้าอื่น = 0**

### 2026-07-20 (4) — ★ จับคู่ยอดถอน Marketplace (bmp): อ่าน IV/RE จากทะเบียน (order_ledger) แทน 723-5 ที่อัปล่าสุด
- **เจ้าของขอ:** อัป Shopee Balance เดือน 7 มาจับคู่ยอดถอน แต่ระบบไปอ่าน "รายงานขาย 723-5" ที่เก็บล่าสุด (19/6) → ออเดอร์เดือน 7 หา IV ไม่เจอ → flag "ยังไม่ออก IV" หมด · อยากให้อ่านจากทะเบียน IV/RE ของเรา
- **ต้นเหตุ:** `bmpGroupWithdrawals` ผูก order→IV จาก `salesData.ivs` (723-5 cache) อย่างเดียว → 723-5 เก่า = ตันหมด
- **แก้:** โหลด `order_ledger` (order_id→iv_no/re_no/sale_amount/cheque_no · paginate) ก่อน loop → ส่งเป็น param `ledgerByOrder` เข้า `bmpGroupWithdrawals` · resolution order→IV/gross/receipt: **723-5 ก่อน → fallback ทะเบียน** (ivNo = iv.doc_no||led.iv_no · gross = chq.amount??iv.total??led.sale_amount · hasReceipt = chq||led.re_no||led.cheque_no) · mismatch reason ใหม่ ("ยังไม่คีย์ IV" / "ยังไม่ออกใบเสร็จ RE")
- **coverage check รื้อ:** เลิกเทียบช่วงวัน 723-5 vs Shopee → เปลี่ยนเป็นนับ Shopee order (จาก `shopeeByName.txns` type="รายรับจากคำสั่งซื้อ") ที่ **ยังไม่คีย์ IV ในทะเบียน+723-5** · เตือนเฉพาะที่ค้างจริง + บอกว่าใช้ทะเบียนเป็นหลัก (ไม่ต้องอัป 723-5 ใหม่)
- **behavior-preserving:** path 723-5 เดิม (iv เจอ) = ผลเท่าเดิม · เพิ่ม fallback ทะเบียนเมื่อ 723-5 ไม่มี · **กระทบหน้าอื่น = 0** (reuse order_ledger · ไม่ต้อง migration) · syntax OK
- **หมายเหตุ:** gross ผ่านทะเบียน = `sale_amount` (IV) → fee_diff = gross−net = ค่าธรรมเนียมเต็ม (ต่างจากผ่านเช็คที่ gross≈net) · IV เดือน 7 ต้องคีย์ที่ "ตรวจการคีย์ 141.RWT" ก่อนถึงจะอยู่ในทะเบียน

### 2026-07-20 (3) — ★ ตรวจการคีย์ IV (141.RWT): เพิ่มตรวจ "รหัสลูกค้า + ประเภท Vat" ที่คีย์ vs ที่ควรเป็น
- **เจ้าของถาม (ต่อจากเคส QHD201→Betra):** ตรวจ 141 ควรตรวจถึงรหัสลูกค้าที่คีย์ด้วยไหม — ใช่ · การเทียบยอดเดิมจับไม่ได้ (Qi/Betra ยอดเท่ากัน ต่างแค่แบรนด์/Vat)
- **141.RWT มีข้อมูลอยู่แล้ว:** `r.customer` (รหัสลูกค้าที่คีย์ · เช่น "ลูกค้าทั่วไป-Shopee Betra") + `r.ivVat` (ยอด VAT) + `r.ivLines[].sku`
- **`ordIvKeyedBrand(customer)`** อ่านแบรนด์ที่คีย์จริงจากช่องลูกค้า (betra/be→BT · qi→QI) · **`ordIvBrandCheck(r, ord)`** เทียบ: keyed vs expect (`incBrandOf(ord)` = SKU-authoritative · orphan→เดาจาก ivLines SKU) → `custMismatch` · Vat: Qi ต้องมี VAT(>0)=type1 · Betra=0 → `vatMismatch` · เฉพาะ Benya
- **เสียบใน `ordIvAnalyze`** (matched + orphan) · **แบนเนอร์แดง** ใน `ordRenderIv` (toggle `ordIvToggleBrand`/`ic.brandOpen`): "พบ IV คีย์รหัสลูกค้า/Vat ไม่ตรงสินค้า N ใบ" + ตาราง (IV/ออเดอร์/SKU/ลูกค้าที่คีย์/ควรเป็น/Vat คีย์ vs ควร) + วิธีแก้ที่ Express · export Excel +5 คอลัมน์ (รหัสลูกค้าควรเป็น/ตรวจ · Vat คีย์/ควร/ตรวจ)
- **verify (harness):** QHD201 คีย์ Betra+Vat0 → custMis+vatMis true · คีย์ Qi ถูก → false · SDO101 Betra→false · mbark→ข้าม · syntax OK · **กระทบหน้าอื่น = 0** (reuse benyaSkuBrand/incBrandOf · ไม่ต้อง migration)

### 2026-07-20 (2) — ★★ แก้รากปัญหาแบรนด์เพี้ยน: ฝังตาราง SKU→แบรนด์ Benya ลงโค้ด (ชนะร้าน+localStorage)
- **อาการ (เจ้าของสืบจากไฟล์จริง):** QHD201 (Qi Care) ส่งออกเป็น SHOPEE **BE + Vat 0** ทุกใบ (163/163) แต่ QIC101 → QI ถูก · **เครื่องแนนเดา QI ถูก แต่เครื่องบัญชีเดา Betra ผิด** ออเดอร์เดียวกัน
- **ต้นตอ (ยืนยัน 100%):** `incBrandOf` เดาจาก localStorage **`inc-sku-brand-{co}` (per-browser · ไม่แชร์)** — เครื่องบัญชีตั้ง **QHD→Betra ผิด** → ทุก QHD ออก BE · เครื่องแนนไม่มี map → ตกไปเดาชื่อ "Qi Care" → QI · **แบรนด์เก็บแยกแต่ละเครื่อง = ต่างคนต่างได้ผล**
- **`benyaSkuBrand(sku)` (ใหม่ · authoritative):** `Q…`=QI · `SBR/STR/BTR/SDO…`=BT (เจ้าของยืนยัน) · เสียบเป็น **step 0 ใน `incBrandOf`** (ก่อนร้าน + ก่อน localStorage user-map) — แบรนด์อิงสินค้า/VAT ไม่ใช่ร้าน → SKU ควรชนะ · เฉพาะ Benya (`state.company!=='mbark'`)
- **ผล:** QHD201 → QI + Vat 1 **ทุกเครื่อง** (แม้ localStorage ตั้งผิด/ขายในร้าน Betra) · SDO เดิมว่าง→BT ด้วย · กระทบทั้ง IV export (`ivrBuildExportAoA`) + RE export (`incReCandidates`) พร้อมกัน (ใช้ incBrandOf ร่วม)
- **verify (harness):** QHD201+map QHD→BT→QI · QHD201 in betra shop→QI · SDO/SBR/STR/BTR→BT · QIC101→QI · SKU ไม่รู้จักในร้าน Betra→BT(ผ่านร้าน) · syntax OK · **ไม่ต้อง migration** (code-only)
- **หมายเหตุ:** ของที่คีย์ผิดไปแล้ว (14 RE + IV เก่า) ยังต้องแก้ใน Express เอง · ตั้งแต่นี้ส่งออกถูกทุกเครื่อง · **UI เสริม:** หัวออเดอร์ในหน้าค้นหาโชว์ 🏪 ร้าน + แบรนด์ที่เดา (Benya) เพื่อ debug

### 2026-07-20 — ★ เงินสดย่อย: แนบเอกสาร + dropdown พนักงาน/แผนก + คอลัมน์เบิกคืนวันที่ + ฟิลเตอร์เดือน
- **เจ้าของขอ:** แนบเอกสารไว้เปิดดูภายหลัง · dropdown ชื่อพนักงานที่เคยเบิก + แผนก (ไม่ต้องคีย์ซ้ำ) · ฟิลเตอร์เดือน (สรุป+แสดงเฉพาะเดือนนั้น) · คอลัมน์ "ได้รับเงินคืนรอบวันที่"
- **Migration `supabase/petty-cash-extras.sql`** (idempotent): `petty_cash` +`department text` +`attachments jsonb` (`[{name,path,size,type}]`) · `reimburse_round` มีอยู่แล้ว
- **แนบไฟล์:** reuse Storage bucket `documents` (path ASCII `petty-cash/{CODE}/{stamp}.{ext}` กัน URL ไทยพัง) · `pcUploadAttachments` (อัปหลายไฟล์ในฟอร์ม) · `pcOpenAtt` (createSignedUrl เปิด) · `pcRemoveAtt` (ลบ + storage.remove) · คอลัมน์ "เอกสาร" 📎 คลิกเปิด · ฟอร์มโชว์ไฟล์แนบเดิม (แก้ไข) + ปุ่มลบ
- **dropdown:** `<input list>` + `<datalist>` — พนักงาน (`pcReqList`) + แผนก (`pcDeptList`) สร้างจาก distinct ทุกเดือน (ยังพิมพ์ใหม่ได้)
- **ฟิลเตอร์เดือน:** "รอบ" = เดือน (YYYY-MM) อยู่แล้ว → relabel chips เป็น "เลือกเดือน" · KPI/ตาราง/รวม คำนวณเฉพาะเดือนที่เลือก (มีอยู่แล้ว)
- **คอลัมน์ "เบิกคืนวันที่"** (`pcReimbLabel` · ISO→วันที่ · ฟอร์ม date input เขียน `reimburse_round`) · ตาราง 9→12 คอลัมน์ (แผนก/เบิกคืนวันที่/เอกสาร) · export Excel +แผนก/ไฟล์แนบ(นับ)
- **กระทบหน้าอื่น = 0** (โมดูล pc* · reuse bucket documents + policy เดิม) · **ต้อง push ให้ migration รันก่อน** ถึงเก็บ department/attachments ได้
- **★ fix (ตามมา):** เพิ่มรายการเดือน 7 ตอนเลือกเดือน 6 ค้าง → `round_label` ติดเดือน 6 → ไม่โผล่เป็นเดือนใหม่ · แก้ `pcRoundOf` อิง **วันที่จ่าย/เอกสารก่อน** (fallback round_label) → จัดเดือนตามวันจริง + แก้ย้อนหลังของที่ใส่ไปแล้ว (ไม่ต้อง migration) · `pcSaveForm` เก็บ round_label ตามวันที่กรอก + เด้งไปเดือนนั้นหลังบันทึก

### 2026-07-19 (3) — ★ ประวัติส่งออก IV: ดาวน์โหลด Excel/CSV + เก็บ "รหัสลูกค้าที่ส่งออกจริง" ลง batch ถาวร (จับเคสแบรนด์ผิด SHOPEE QI↔BE)
- **เจ้าของขอ:** เจอออเดอร์ QHD201 (Qi) แต่บัญชีส่งออกไปคีย์เป็น SHOPEE BETRA (ควรเป็น SHOPEE QI) → รับชำระ RE ผูกผิด 14 ใบ · อยากดาวน์โหลดประวัติส่งออก IV มาเช็ค + **เก็บรหัสลูกค้าที่ส่งจริงลง batch ถาวร**
- **★ snapshot ถาวร:** migration `supabase/iv_export_batches_rows.sql` (idempotent · guard table exists · `ADD COLUMN IF NOT EXISTS export_rows jsonb` + NOTIFY pgrst) — เก็บ `[{iv, order_id, channel, shop, brand, cust, vat}]` ตอนส่งออก · `ivrDoExport` insert `export_rows` (เลข IV = start_iv + index · reuse helper)
- **`ivrOrderExportMeta(o)` (helper กลางใหม่):** ดึงสูตร รหัสลูกค้า/แบรนด์/Vat ออกจาก `ivrBuildExportAoA` → ใช้ร่วมทั้ง build AoA + snapshot (กัน drift) · behavior-preserving (verify harness: SP QI→SHOPEE QI vat1 · SP BT→SHOPEE BE vat0 · เดาไม่ออก→cust ว่าง+warn · direct→Dealer · MBark SP→SHOPEE)
- **`ivrExportHistory(fmt)`** + ปุ่ม "ดาวน์โหลด (Excel)" / "CSV รายใบ" ในโมดอลประวัติส่งออก IV:
  - **ชีต 1 "ภาพรวม batch"** · **ชีต 2 "รายใบ (รหัสลูกค้า)":** ★ ใช้ **`export_rows` snapshot ก่อน** (ค่าจริงตอนส่งออก · แม่นย้อนหลัง 100%) → batch เก่าไม่มี → fallback reconstruct เลข IV + recompute จากทะเบียนปัจจุบัน · คอลัมน์ "ที่มารหัสลูกค้า" บอก ค่าจริงตอนส่งออก / คำนวณใหม่(batch เก่า) · `forceTextCells([2,3])` กันเลขยาว
- **ต้อง push ให้ migration รันก่อน** batch ที่ส่งออกหลัง deploy ถึงจะมี snapshot · batch เก่า = fallback recompute · **กระทบหน้าอื่น = 0** (helper เป็น refactor · เพิ่มปุ่ม/คอลัมน์)
- **`iv_export_batches` +`export_rows jsonb`** (snapshot รหัสลูกค้ารายใบ)

### 2026-07-19 (2) — ★ ตรวจ RE (batch): เพิ่มเช็ค "RE↔IV จับคู่ถูกใบไหม" (จับเคส AutoKey ตัด IV ผิดใบ · ยอดเท่ากันเลยไม่ฟ้อง)
- **อาการ (เจ้าของ):** คีย์ออโต้ (AutoKey) รับชำระ RE ไป **ตัดกับ IV คนละใบที่ยอดเท่ากันพอดี** → ระบบตรวจเดิมเช็คแค่ "ออเดอร์มี RE ในไฟล์ไหม" ยอดตรงเลยไม่ฟ้อง · เจ้าของต้องไล่เช็คมือ
- **`incReBatchCoverage` +`mismatched`:** ดัชนีไฟล์ 1.9.1 by re_no (`vByRe`) → วนทุกออเดอร์ใน batch: RE เดิม (`incReBatchOrigReMap`) ควรตัด IV ของ order_ledger (`expIv`) vs IV ที่ไฟล์บอกว่า RE นั้นตัดจริง (`vr.iv_no`) · ไม่ตรง (ทน format · normalize + เลข IV ล้วน) → flag + หา `hitOrder` (IV ที่คีย์ผิดเป็นของออเดอร์ไหน จาก idx.byIv)
- **UI banner:** chip แดง "RE↔IV ผิดใบ (N)" + accent/bg แดงเมื่อมี mismatch + **ตารางแดง** (เลข RE · ออเดอร์ · IV ที่ควรตัด(เขียว) · IV ที่คีย์จริง(แดง) · ยอด `= กัน` ถ้ายอดชนกัน · IV ผิดเป็นของออเดอร์ไหน) + footer แนะไปแก้รับชำระใน Express · `incReSaveBatchVerify` เก็บ mismatched + status=partial ถ้ามี
- **verify (harness):** RE001 ควรตัด IV_A(500) แต่ไฟล์ตัด IV_B(500) → flag 2 ใบ + ชี้ hitOrder ถูก · เคสคีย์ถูก → 0 (ไม่ฟ้องมั่ว) · syntax OK · **กระทบหน้าอื่น = 0** (เพิ่ม field ใน coverage + reuse ตัวจับคู่ทนรูปแบบ)

### 2026-07-19 — ★ ตรวจ RE ตกหล่น: จับคู่ 1.9.1↔ทะเบียน "ทนรูปแบบ" (แก้อัปไฟล์ครอบแล้วยังตกหล่น)
- **อาการ (เจ้าของ):** อัปไฟล์ 1.9.1 ที่ครอบวันคีย์แล้ว 5 ใบยังขึ้น "ตกหล่น" — ไม่ใช่ไฟล์ไม่ครอบ แต่ **จับคู่ไม่ติด** (เลข IV/ออเดอร์ในไฟล์ vs ทะเบียนต่างรูปแบบเล็กน้อย: มี-ไม่มี "IV" นำหน้า / เว้นวรรคต่อท้าย → exact-match พลาด)
- **`incNormKey`/`incIvDigits`/`incBuildOrdIndex`/`incMatchVerifyRow` (ใหม่):** matcher ทนรูปแบบ — normalize (uppercase + ตัดช่องว่าง) + **เทียบเลข IV ล้วน** (`\d{6,}`) เป็น fallback + normalize order_ref · เป็น superset ของ exact (ที่เคยตรงยังตรง)
- **ใช้ร่วมทุกจุด:** `incReBatchCoverage` (batch coverage) · `incRenderVerify` matchOf (KPI/ตาราง) · `incVerifyTagAll` matchOf (Tag RE) · ดัชนี "ในไฟล์ 1.9.1?" ใน `incReBatchMissingDetailHtml` (vByIv/vByIvDig/vByOrder ทนรูปแบบ · เจอผ่าน loose → โชว์ "IV ในไฟล์" ให้เทียบ)
- **verify (harness):** ไฟล์ iv "2606000666" (ไม่มี IV) → เลขล้วนจับ ledger "IV2606000666" ✓ · iv "IV2606001107 " (เว้นวรรค) → normalize จับ ✓ · order_ref เว้นวรรคท้าย → จับ ✓ · ใบไม่มีในไฟล์จริง → ยังขึ้น "ยังไม่พบในไฟล์" ถูก · syntax OK · **กระทบหน้าอื่น = 0** (matcher เป็น superset · reuse)

### 2026-07-18 (2) — ★ ตรวจการคีย์ RE (batch): คลิกดูใบตกหล่น + ส่งออก "รอบตกหล่น" ★★ ใช้เลข RE เดิมของ batch
- **เจ้าของขอ:** batch verify RE โชว์ "ยังไม่พบใน 1.9.1 — 5 ใบ" เป็น chip เฉย ๆ → อยากคลิกดูว่าใบไหนบ้าง + ส่งออกไปคีย์รอบตกหล่นได้เลย
- **★★ เจ้าของท้วง (ถูก):** "ตกหล่นจริงต้องใช้เลข RE เดิมที่ batch นี้เคยรันให้สิ" — รอบแรกผมทำ prompt รันเลขใหม่ (ผิด · จะได้เลข RE ไม่ตรงกับที่ export/expected ไว้ → คีย์ซ้ำเลขชนกัน)
- **`incReBatchOrigReMap(b)` (ใหม่):** กู้เลข RE เดิมรายใบ = `armapRunRE(b.start_re, index ใน b.order_ids)` — batch เก็บ `start_re` + `order_ids` (เรียงตาม paidISO ตอน export) ไว้แล้ว → order_ids[i] ↔ RE ที่ i · **verify:** start_re 2607000001 → O3=…003, O5=…005 · legacy batch ไม่มี start_re → map ว่าง
- **`incReBatchBannerHtml` missHtml รื้อ:** ปุ่ม toggle (`incToggleReMiss` · `d.reMissOpen`) กาง **ตารางรายละเอียดใบตกหล่น** (`incReBatchMissingDetailHtml`) — คอลัมน์ **เลข RE (เดิม)** เด่นสุด + ออเดอร์/ช่อง/เลข IV/ลูกค้า/ยอด IV/เงินเข้าสุทธิ + **สาเหตุรายใบ** (`incReCandidates`+`ordGet().rows` join): พร้อมคีย์รอบตกหล่น (เลข RE เดิม · ฟ้า) · ยังไม่คีย์ IV → ออก RE ไม่ได้ · ไม่พบออเดอร์ (แดง) · ไม่มี Income · คีย์ RE แล้ว (คนละรายงาน?) เขียว · toggle เปิดแล้ว auto-`incLoadRows` (แท็บ verify ไม่ auto-load income → กันสาเหตุเพี้ยน)
- **`incExportReMissing(fmt)`** — ปุ่ม "ส่งออกรอบตกหล่น (Excel/CSV)" · กรอง candidate = `missing ∩ !re_no ∩ มี income` (กันคีย์ซ้ำ) · **แนบเลข RE เดิม (`_origRe`) แล้วเรียงตามเลข RE** · doc_no = `_origRe` (ไม่รันใหม่) · confirm โชว์ช่วง RE เดิม · ส่งออก AutoKey 19 คอลัมน์ (`incReRow` override doc_no) ชื่อไฟล์ `RE_AutoKey_ตกหล่น_*` · **ไม่สร้าง batch ใหม่** — คีย์เสร็จอัป 1.9.1 แล้วตรวจ batch เดิมซ้ำได้เลย · **fallback:** batch เก่าไม่มี start_re → prompt กรอกเลขเริ่มต้นเอง
- **verify (node harness):** origReMap ถูก (index→RE เดิม) · syntax OK · **กระทบหน้าอื่น = 0** (แบนเนอร์ batch RE + ฟังก์ชันใหม่ · reuse incReCandidates/incReRow/armapRunRE)
- **★★★ ตามมา (เจ้าของท้วง "5 IV นี้คีย์แล้วในบัญชี"):** ตัวตรวจดูจาก **ไฟล์ 1.9.1 ที่อัปเท่านั้น** → คีย์ RE แล้วใน Express แต่ไฟล์ 1.9.1 ที่อัปไม่ครอบวันคี้ = ขึ้น "ตกหล่น" หลอก · เพิ่มคอลัมน์ **"ในไฟล์ 1.9.1?"** ในตารางรายละเอียด + วินิจฉัยรายใบ (ดัชนีย้อนกลับ `vByIv`/`vByOrder` จาก `d.verify.rows`): (1) **ยังไม่พบในไฟล์** (ปกติ · เพราะถ้า iv_no ตรง coverage จับได้แล้วไม่ตกหล่น) → footer แนะ "คีย์แล้ว? กด **อัปไฟล์เพิ่ม** เลือก 1.9.1 ที่ครอบวันคีย์ แล้วตรวจใหม่" (2) **✓ อยู่ในไฟล์แต่จับคู่ไม่ติด** (เคส iv_no ซ้ำในทะเบียน → ivMap last-writer ชนออเดอร์อื่น · ม่วง) · **verify (harness 2 เคส):** not-in-file + collision(RE ซ้ำ) ถูกทั้งคู่ · เลข RE เดิมยังโชว์ครบ

### 2026-07-18 — ★ รับชำระ: แท็บใหม่ "จับคู่ IV ↔ Income" + ★★ แก้ 2 บั๊กจากข้อมูลจริง (income cap 1000 + แยกกลุ่ม)
- **เจ้าของถาม:** จะรู้ได้ไงว่าออเดอร์ไหน "มี Income แล้วยังไม่มี IV" / "มี IV แล้วแต่ยังไม่มี Income" — เดิมระบบ **เงียบทั้งคู่** (`incReCandidates` ข้ามออเดอร์ที่ไม่มี IV เงียบ ๆ · KPI "พร้อมออก RE" นับเฉพาะที่มีครบทั้งคู่ · ทะเบียนรับชำระไม่มีคอลัมน์ IV)
- **แท็บใหม่ `recon` "จับคู่ IV ↔ Income"** (ระหว่าง "ทะเบียนรับชำระ" กับ "ส่งออก RE") · `incReconData(d)` + `incRenderRecon(d)` · จับคู่ด้วย **order_id** (income ↔ order_ledger)
- **★★ ต้นเหตุจริงจากข้อมูล MBark (ส่องหน้าจริง):** เจ้าของถามต่อ "ทำไม 618 ยังไม่มี IV ทั้งที่คีย์ IV ไปแล้ว 600 กว่า" → เจอ **2 บั๊ก:**
  1. **`incLoadRows` ติด cap 1000** (`limit(2000)` ไม่ช่วย · Supabase PostgREST max-rows 1000) — income จริง 1569 โหลดมาแค่ 1000 → เดือนก่อนหาย · **แก้: paginate `.range(from,from+PAGE-1)` วน** (เหมือนบั๊ก ordLoad เดิม)
  2. **กลุ่ม "ยังไม่มี IV" รวม 2 เคสคนละเรื่อง** → เข้าใจผิดว่าคีย์ IV ไม่ครบ · แยกเป็น: **noIv** (มีออเดอร์ในทะเบียนแต่ `iv_no` ว่าง = คีย์ IV ได้เลย) vs **noOrder** (income มีแต่ `order_id` ไม่เจอในทะเบียนเลย)
- **★ ต้นตอที่แท้:** `order_ledger` ของ MBark มีแค่ **เดือน 7 (order_date 2026-07-01..15 · 651 แถว) · เดือน 6 = 0 แถว** → income เดือน 6 (IV เดือน 6 รับชำระเดือน 7) จับ order ไม่เจอ → **1165 ใบเข้ากลุ่ม noOrder** (ไม่ใช่ "ยังไม่คีย์ IV" · ระบบยังไม่รู้ด้วยซ้ำว่ามี IV ไหมเพราะไม่มีออเดอร์) · **วิธีแก้ของ user = นำเข้า BigSeller เดือน 6 เข้าทะเบียนคำสั่งซื้อก่อน** (ออเดอร์เดือน 6 ต้องมี iv_no ด้วย = ต้อง verify 141.RWT เดือน 6)
- **4 กลุ่ม (การ์ด auto-fit คลิกกาง · `d.reconGroup`):** ✅ พร้อมออก RE · ⚠️ มีออเดอร์ยังไม่คีย์ IV (ปุ่มไปขั้นตอน 1) · ❓ ไม่เจอออเดอร์ในทะเบียน (แดง · hint "นำเข้าออเดอร์ก่อน" + เดา "เดือนออเดอร์" จาก prefix `YYMMDD` ของ order_id) · 🔵 มี IV ยังไม่มี Income
- **★ noOrder ไม่โชว์ "ยังไม่คีย์ IV"** (คอลัมน์สุดท้าย = "✕ ไม่อยู่ในทะเบียน" ไม่ใช่ "⚠ ยังไม่คีย์ IV") — กันเข้าใจผิดว่าออเดอร์ยังไม่คีย์ IV
- **★ กลุ่ม "มี IV ยังไม่มี Income" = ทุกช่องทาง** (เจ้าของเลือก) · ตัด `cancelled` + ตัดที่มี `re_no` แล้ว · ช่องทางจาก `ordChannelDetail` · ชิปกรองช่องทาง (`d.reconCh`)
- **★ ข้ามเดือนทำงานถูก (เมื่อออเดอร์อยู่ในทะเบียน):** จับด้วย order_id ไม่ผูกเดือน → IV เดือน 6 รับชำระเดือน 7 เข้า "พร้อมออก RE" · **แต่ถ้าออเดอร์เดือน 6 ไม่อยู่ในทะเบียน = เข้า noOrder** (ต้อง import ออเดอร์ก่อน)
- **verify (node harness 4 กลุ่ม + หน้าจริง browser · ข้อมูลจริง MBark):** income 1569 · ready 382 · noIv 22 · noOrder 1165 · noIncome 206 · การ์ด 4 ใบ + hint เดือนออเดอร์ + noOrder ไม่โชว์ "ยังไม่คีย์ IV" · boot 0 error · **กระทบหน้าอื่น = 0** (แท็บ+ฟังก์ชันใหม่ · แก้ incLoadRows paginate กระทบเฉพาะหน้ารับชำระ · ไม่ต้อง migration)
- **★ ตามมา (เจ้าของถามต่อ · commit 3c57b3a + 0b06711):** (1) **แยกออเดอร์ยกเลิกที่มีเงินเข้า** (คืนเงิน/ปรับ · net ติดลบ) เป็นกลุ่ม `cancelledRefund` — เดิมปนใน noIv/ready ทำ noIv บวม 50→75 · โชว์เป็น note คลิกดู · (2) **แยก `received` (มี IV + `re_no`/พบ 1.9.1) ออกจาก `ready`** — เดิม recon "พร้อมออก RE" นับรวมที่รับชำระแล้ว = 1349 → **งงกับหน้าส่งออก RE ที่โชว์ 676** (676 ยังไม่รับชำระ + 673 รับแล้ว = 1349) · แก้ให้ recon ready = **676 ตรงหน้าส่งออกเป๊ะ** · received โชว์เป็น note คลิกดู ("✓ RE {เลข}") · `isReceived(o)` = `re_no || keyedIv/keyedOrder จาก verify.rows` (mirror incReCandidates) · **6 กลุ่ม:** ready/received/noIv/noOrder/noIncome/cancel
- **★ ต้นเหตุที่ noOrder เยอะตอนแรก (1165):** order_ledger MBark มีแค่เดือน 7 · เจ้าของ **อัป BigSeller เดือน 6 + 141.RWT เดือน 6** เข้าไปเอง → order_ledger เดือน 6 = 1267 (มี IV 1135) → ready พุ่ง 382→1349 · noOrder ลด 1165→145 (เหลือ TikTok เก่า/ออเดอร์ที่ยังไม่ import)
- **★ ทำไมหน้าส่งออก "กำลังจะส่งออก" 595 < "พร้อมออก RE" 676:** 676 ตัดที่ติดปัญหา (78 ไม่มียอด IV ในระบบ + 2 เงินเข้า≤0 + 1 เงินเข้า>ยอด IV) = 595 · เป็น filter ของหน้าส่งออก ไม่ใช่บั๊ก
- **★ ตามมา (commit 203055e · เจ้าของขอส่องกลุ่ม noIv/noOrder):** (ก) **กางกลุ่มไหนโชว์ block "แยกเดือน / แยกช่อง"** (นับ+ยอดเงินเข้า) · `incReconMonth(rec)` = order_date ถ้ามีออเดอร์ · noOrder อ่าน order_id (Shopee/Lazada = YYMMDD → 20YY-MM · **TikTok เลขล้วน 18 หลัก อ่านเดือนไม่ได้ → ใช้เดือนเงินเข้า**) · `incReconBreakdown(arr)` · (ข) **income net≤0 (คืนเงิน/ปรับ) ที่ยังไม่มี IV → ย้ายเข้ากลุ่ม cancelledRefund** (ไม่แตะ ready/received เพื่อคง 676) · rename "ยกเลิก/คืนเงิน/ปรับ"
- **★ bug ที่เจอ+แก้:** เขียน `Number(r.net)` แต่ `r` = income row (มี `net_received` ไม่มี `net`) → `NaN<=0=false` ไม่ทำงาน · **แก้เป็น `rec.net`** (rec.net = Number(r.net_received))
- **★ ผลข้อมูลจริง MBark:** noIv 50→**34 (เดือน 6 ล้วน เงินเข้าบวก = ตัวที่ต้องคีย์ IV จริง · 141.RWT มิ.ย. ที่อัปไม่ครอบ 28-29 มิ.ย.)** · noOrder 126 (Shopee 67 = **เดือน 5 ยังไม่ import** · TikTok/Lazada ยอดเล็ก) · cancel 60 (รวม net≤0 returns)

### 2026-07-17 (7) — แดชบอร์ดตรวจการคีย์: การ์ด "รอคีย์ IV" คลิกกางรายการ + บอกสาเหตุที่ยังคีย์ไม่ได้
- **เจ้าของขอ:** "รอคีย์ IV ต้องคลิกได้ด้วยสิ" (เดิมคลิกได้แค่การ์ด "คีย์ IV แล้ว")
- **`s.dashIvOpen` (bool) → `s.dashList` ('' | 'keyed' | 'wait')** + `salesToggleDashList(kind)` (toggle ตัวเดิม = ปิด · กางได้ทีละรายการ · scroll ไปที่ `#salDashList`)
- **★ รายการ "รอคีย์ IV" ไม่ใช่แค่ลิสต์ — บอกสาเหตุรายใบ:** reuse **`ivrCanExport(o, rmap, false, includeCsr)`** (gate ตัวเดียวกับหน้าส่งออก) → badge "✓ พร้อมส่งออก" หรือ "⚠ {เหตุผล}" (ยอดไม่ตรง / ยังไม่ตรวจกระทบยอด / CSR ปิดอยู่ / หลังบ้านขาด) · สีตาม `g.sev`
- **เรียงใบที่ติดปัญหาขึ้นก่อน** (actionable) · หัวการ์ดสรุป "พร้อมส่งออก N · ติดกระทบยอด M" · ปุ่ม **"ไปหน้าส่งออก IV"** (`salesSetSubtab('export')`) · คอลัมน์: ออเดอร์/ช่องทาง/วันที่/สินค้า(ellipsis+tooltip)/ยอด/ภาษี/สถานะ · table-layout:fixed · cap 200
- **verify (หน้าจริง · 6 ออเดอร์):** KPI มี onclick · สรุป "5 ใบ · 2,430.00 · พร้อมส่งออก 2 · ติดกระทบยอด 3" · เหตุผลถูกรายใบ (diff→"ยอดไม่ตรง" · ไม่มี recon→"ยังไม่ตรวจ" · CSR→"เปิดชิปรวม CSR" · FACE ขายตรง→พร้อม) · กาง keyed/wait สลับกันทีละอัน · ปิดแล้วไม่มีการ์ด · กรอง face→เหลือ 1 ใบ · เซลล์ทับกัน 0 · boot 0 error

### 2026-07-17 (6) — ★★ ตรวจการคีย์: แดชบอร์ดสรุปการตรวจ + ★ จับ "IV ที่ต้องออกใบลดหนี้"
- **เจ้าของขอ:** หน้าตรวจการคีย์ "อัปไฟล์แล้วจบ" → อยากได้**แดชบอร์ดสรุป** โฟกัส **IV / ยอด IV / มูลค่าภาษี**: ออเดอร์ในระบบกี่ใบ · คีย์แล้วกี่ใบกี่บาท **ประกอบด้วย IV อะไรบ้าง** · รอคีย์กี่บาท · คีย์แล้วไม่ตรงกี่บาท · **กรองช่องทางได้/ดูทุกช่องได้** · **★ IV ที่คีย์ไปแล้วมี "ยกเลิกภายหลัง" ไหม → ต้องคีย์ลดหนี้ไหม**
- **`salesIvDashData(d, mrows, ch)` + `salesRenderIvDash(d, s, mrows)`** (ใหม่ · วาง**เหนือ** `ordRenderIv` ในแท็บ verify ของ `sales_orders` — **ไม่แตะ `ordRenderIv`** ที่ใช้ร่วมกับหน้าอื่น) · state `s.dashCh` (default all) + `s.dashIvOpen`
- **KPI 5 ใบ:** ออเดอร์ในระบบ · **คีย์ IV แล้ว** (ยอด + **ภาษี 7/107** · คลิกกางรายการ IV) · **รอคีย์** (ยอด + ภาษีที่ยังไม่ยื่น) · **คีย์แล้วไม่ตรง** (Σ|diffAmount| จาก 141.RWT · ไม่มีไฟล์→ "—" + แถบบอกให้อัป) · **★ ต้องออกใบลดหนี้** (ยอด + ภาษีที่ต้องลด)
- **★ ใบลดหนี้ (CN) = `o.iv_no && o.status==='cancelled'`** — IV ออกไปแล้วแต่ออเดอร์ยกเลิกภายหลัง → ยอดขาย/ภาษีขายเกินจริง · **ยกเลิกที่ไม่เคยคีย์ IV ไม่นับ** (ไม่ต้องลดหนี้) · กล่องแดงโชว์เลข IV คลิกเปิดออเดอร์ได้ (cap 24) · ไม่มี → กล่องเขียว
- **รายการ IV** (`s.dashIvOpen` · cap 200 · table-layout:fixed): เลข IV / ออเดอร์ / ช่องทาง / วันที่ / **ยอด IV** / **ภาษี 7/107** / สถานะ — badge 4 แบบ: ✓ ตรวจแล้วตรง · ⚠ ยอดไม่ตรง · **⚠ ยกเลิก → ลดหนี้** · • ยังไม่ตรวจ (ไม่อยู่ในไฟล์ 141.RWT)
- **ชิปช่องทาง** = ทุกช่องทาง + 7 ช่อง (ใช้ `salesChOf`) · กรองทั้งแดชบอร์ด (KPI/CN/รายการ IV) · scope = เดือนปัจจุบัน (เท่าหน้าทะเบียน)
- **verify (หน้าจริง · 7 ออเดอร์ครบทุกเคส):** ทุกช่อง keyed 3 ใบ 2,400 ภาษี 157.01 · รอคีย์ 700 · ไม่ตรง 50 · **CN 2 ใบ 700 ภาษี 45.79 (IV003+IV005)** · **ยกเลิกที่ไม่เคยคีย์ IV ไม่ถูกนับ ✓** · กรอง shopee→CN เหลือ IV003 · face→IV005 · รายการ IV badge ถูกทั้ง 4 แบบ · VAT รายใบ 1000→65.42 ✓ · ไม่มี 141.RWT → "—" + แถบเตือน · ไม่มี CN → กล่องเขียว · เซลล์ทับกัน 0 · boot 0 error

### 2026-07-17 (5) — ★ หน้า "1. คำสั่งซื้อ" + ตรวจการคีย์: เพิ่มช่องทางขายตรง (FACE/LINE/Dealer/CSR)
- **เจ้าของแจ้ง:** หน้า `sales_orders` มีแต่ชิป Shopee/TikTok/Lazada — "ตรวจการคีย์ ต้องมีทะเบียนของ เฟส ไลน์ ดีลเลอร์ อื่นๆ CSR ด้วยสิ"
- **ต้นเหตุ:** `SALES_CH` มี 3 marketplace · `salesKpis` กรองด้วย `channel_group === ch` ตรง ๆ → ขายตรง (channel_group = `offline`/`other`) **ไม่มีชิป ไม่มีทะเบียน เข้าไม่ถึงเลย**
- **`SALES_CH` +4 ช่องขายตรง** (face/line/dealer/csr · `direct:true` · icon facebook/message-circle/store/gift) · **`salesChOf(o)`** (ใหม่) = marketplace→`channel_group` · ขายตรง→`ordChannelDetail` (FB→face · LMS→line · CSR/ยอด 0→csr · อื่น→dealer) · ใช้ทั้ง `salesKpis` + chip count
- **★ ปุ่มอัปไฟล์ต่อช่อง:** ขายตรง **ไม่มีรายงานหลังบ้าน** → ปุ่มเป็น "นำเข้า BigSeller" → `setTool('orders')` + แถบอธิบาย · **ห้าม ingest ไฟล์ BigSeller ที่หน้านี้** — `salesUpload` ไม่มีตัวแยกบริษัท (`ordSplitByCompany`) ที่ `ordUploadFiles` มี → **ออเดอร์ M Bark จะหลุดเข้า Benya** · (เรียก `ordUploadFiles()` ตรง ๆ ก็ไม่ได้ — มันจบด้วย `renderToolOrders()` = เด้งออกจากหน้านี้)
- **ตรวจการคีย์ (141.RWT) แยกช่องด้วย:** `ordIvPlatform(ord, iv)` (ใหม่) แทน `ordChannelGroup` → มีออเดอร์ใช้ `ordChannelDetail(ord)` · orphan → ประกอบใบจำลองจาก iv (channel/ref_order_id/total) · **ชิปสร้างจากค่าที่มีจริงใน results** (`pCount`) + label map + ลำดับคงที่ → **ผลเก่าที่ persist ไว้เป็น `offline`/`other` ยังได้ชิปของตัวเอง ไม่หายเงียบ**
- **verify (หน้าจริง):** `salesChOf` 8 เคสถูก (FB→face · LMS→line · CSR/ยอด0→csr · other→dealer) · KPI แยกช่องถูก (Shopee 2 ใบ net 290 = ตัดยกเลิก) · ชิปครบ 7 · ขายตรง→ปุ่ม "นำเข้า BigSeller" + note · marketplace→"อัปไฟล์ Shopee" เหมือนเดิม · `ordIvAnalyze` platform = shopee/face/line/dealer/csr + orphan FB9999→face · ชิปตรวจการคีย์ "SHOPEE(1) FACE(2) LINE(1) Dealer(1) CSR(1)" · ใส่ผลเก่า offline → ชิป "ออฟไลน์(1)" โผล่ · boot 0 error

### 2026-07-17 (4) — แท็บยกเลิก: จัดฟอร์แมตตาราง (เบียด/ทับกัน) + banner บอกทิศทางจริง
- **เจ้าของแจ้ง:** ตารางเบียด — ชื่อสินค้าไทยยาวล้นไปทับคอลัมน์ยอด · คอลัมน์รายละเอียดยาวเกิน
- **ต้นเหตุ:** `max-width:280px` บน `<td>` **ไม่มีผล** ถ้าตารางไม่ได้ `table-layout:fixed` → เนื้อหาดันคอลัมน์/ล้นทับกัน
- **แก้ตาราง:** `table-layout:fixed` + `<colgroup>` (96/108/172/auto/104/186) + `min-width:940px` ในกล่อง `overflow:auto` (จอแคบ = เลื่อนในกล่อง ไม่ดันทั้งหน้า) · เซลล์ยาว = `overflow:hidden;text-overflow:ellipsis;white-space:nowrap` + `title` tooltip (ชื่อสินค้าเต็ม)
- **ยุบ 7 คอลัมน์ → 6** (รวม "สถานะ"+"รายละเอียด") · คำอธิบายย้ายไป tooltip → **แถวสูง 109px → 45px** (เดิม hint ซ้ำทุกแถวทั้งที่ banner บอกไปแล้ว) · `.ord-table td` มี `white-space:nowrap` → เคยทำ hint ล้นออกนอกคอลัมน์
- **`ORD_CXL_META` เพิ่ม `hint`** · `l`/`short` สั้นลง (`cxl_bs` เดิมยาวเป็นประโยค)
- **★ banner บอกทิศทางจริง** (เดิมเขียนรวม "หลังบ้านยกเลิกแล้ว แต่ BigSeller ยังขายสำเร็จ (หรือกลับกัน)" — **สลับด้านกับของจริง**): แยกนับ `cxl_open` ("BigSeller ยังไม่ยกเลิก → ต้องไปยกเลิกใน BigSeller" แดง) vs `cxl_bs` ("รอหลังบ้านยืนยัน → อัปรายงานหลังบ้านใหม่" เหลือง) · 2 เคสนี้ต้องทำคนละอย่าง
- **`cxl_bs` เปลี่ยนสี แดง→เหลือง** (รอยืนยัน ไม่ใช่ผิด) · ยังเป็น `ok:false` = เข้าผลต่าง (ตามที่เจ้าของเลือก)
- **verify (วัดเรขาคณิตจริงในหน้า · ข้อมูลตามภาพผู้ใช้):** เซลล์ทับกัน 0 · เนื้อหาล้น 0 · แถว 45px · tableScrollsInsideBox=true / pageScrollsHoriz=false ที่ 768px · banner "3 ใบ รอหลังบ้านยืนยัน" + แถว ✓ ยกเลิกตรง อยู่ด้วยกันถูก · boot 0 error

### 2026-07-17 (3) — ★★ Orders: เก็บใบยกเลิก (เลิกทิ้ง) + แท็บยกเลิก 2 แบบ + มุมมองกระดาน 3 สถานะ
- **เจ้าของสั่ง:** ใบยกเลิก "อยากให้เก็บไว้" · แยก 2 แบบ: ① **ยกเลิกแบบไม่นำเข้า** (สั่งปุ๊ปยกเลิกปั๊บ · BigSeller ไม่มีเลย · มีแค่หลังบ้าน) → ไม่ต้องตรวจ เก็บรายละเอียดไว้ดู ② **ยกเลิกภายหลัง** (BigSeller มีแล้วค่อยยกเลิก) → **ตรวจสถานะ: หลังบ้านยกเลิก → BigSeller ต้องยกเลิกด้วย = ข้อมูลตรง** · กระดานเลือกดูได้ 3 สถานะ
- **★ ต้นเหตุที่ไม่มีข้อมูลใบยกเลิกเลย:** `ordReconUpload` **ทิ้งใบยกเลิกตั้งแต่ก่อนตรวจ** (`filter(o=>o.status!=='cancelled')`) + `ordRunRecon` `continue` ทิ้งอีกชั้น + `bsScoped` ตัด cancelled → **ไม่เคยเก็บสักใบ** · แก้: upload เก็บทุกใบ (ตัดแค่ `ordIsLabelOrder`) · bsScoped รวม cancelled
- **`ORD_CXL_META` (taxonomy กลาง · 5 สถานะ):** `cxl_nobs` (ไม่นำเข้า · ปกติ) · `cxl_ok` (ยกเลิกภายหลัง · 2 ระบบตรง ✓) · `cxl_open` (หลังบ้านยกเลิก · BigSeller ยังขาย ⚠) · `cxl_bs` (BigSeller ยกเลิก · ผลตรวจหลังบ้านยังขาย ⚠) · `cxl_nobe` · helper `ordIsCxl/ordIsCxlStatus/ordIsCxlLate/ordIsCxlProblem` · `order_recon.status` เป็น text ไม่มี CHECK → **ไม่ต้อง migration**
- **★ `ordReconEffStatus(r, liveBs)` — สถานะยกเลิกอ่านจากทะเบียนสดก่อน** (snapshot แช่ตอนตรวจ ไม่รู้ว่ายกเลิกทีหลัง) → **อัป BigSeller อย่างเดียวก็เห็นทันที ไม่ต้องอัปหลังบ้านซ้ำ** · ★ ใช้เฉพาะเช็คยกเลิก — **เทียบยอดยังใช้ snapshot** (กันผล recon เดิมเพี้ยน) · caller ที่ไม่ส่ง liveBs = พฤติกรรมเดิม
- **`ordReconView(d)` (ใหม่ · จุดเดียวที่คำนวณสถานะ):** recon + สถานะสด + กรองช่วงวัน + แนบ `_live` → ใช้ร่วม board/detail/แท็บยกเลิก/matchStats/gap (เดิมต่างคนต่าง `.map(ordReconEffStatus)`)
- **กระดาน — มุมมอง 3 สถานะ** (`d.boardScope` · `ordBoardSetScope`): **ยังมีผลอยู่** (default = เดิมเป๊ะ) · **ทั้งหมด** (ก่อนหักยกเลิกภายหลัง · **ไม่รวมไม่นำเข้า** — เจ้าของเลือก) · **ที่ยกเลิก** · `bsPick`/`bePick` คุมประชากรทั้ง 2 แถวต่อ scope → **live/all 2 แถวลบกันลงตัว** · **แถวใหม่ "ยกเลิกภายหลัง"** (คลิก→แท็บยกเลิก) · ผลต่างรวม `cxlProb` (cxl_open/cxl_bs — เจ้าของเลือก "ผลต่าง ต้องแก้")
- **แท็บใหม่ "✕ ยกเลิก"** (`ordRenderCxl` · sub-tab late/nobs · `ordCxlRows`/`ordCxlCounts`/`ordCxlGo`): ตาราง วันที่/ช่องทาง/เลขออเดอร์(คลิกเปิด)/สินค้า/ยอด/สถานะ/รายละเอียด · late = banner เตือนถ้าสถานะไม่ตรง · nobs = banner "ไม่ต้องกระทบยอด"
- **อัตราแมท** = `(matched+cxl_ok)/denom` · **cxl_nobs/cxl_nobe ไม่เข้าสูตร** (ไม่ต้องตรวจ · กันปั่น %)
- **`ordBoardGap` เหลือ 2 เหตุผล** (ยกเลิกมีแถวของตัวเองแล้ว): ไม่มีในทะเบียนแล้ว · วันที่คนละช่วง
- **★ ต้องอัปรายงานหลังบ้านใหม่ 1 รอบ** เพื่อดึงใบยกเลิกย้อนหลัง (ของเก่าถูกทิ้งไปแล้ว ไม่มีใน DB)
- **verify (หน้าจริง):** `ordRunRecon` 5 เคส → matched/cxl_ok/cxl_open/cxl_bs/cxl_nobs ถูกครบ · ยกเลิกทีหลังโดยไม่อัปหลังบ้าน → `cxl_bs` + gap=0 · board live 2/200=2/200 · all 3/419=3/419 · cxl BigSeller 1 vs หลังบ้าน 2 (NOBS ไม่เคยเข้า BigSeller = ถูก) · แท็บ late 2 ใบ (✓ตรง + ⚠ไม่ตรง) · nobs 1 ใบ · cxl_open เข้าผลต่าง TikTok 1/88 · boot 0 error

### 2026-07-17 (2) — ★ Orders board: อธิบายช่องว่าง "หลังบ้าน > BigSeller ทั้งที่ผลต่าง = 0"
- **เจ้าของถาม (ถูกต้อง):** Shopee BigSeller 773 · หลังบ้าน 775 · **ผลต่าง 0** · แมท 100% — ทำไมจำนวนไม่เท่ากันแต่ผลต่างเป็น 0
- **สาเหตุ (by design · 2 แถวคนละแหล่ง):** แถว **หลังบ้าน** = `d.recon.results` (**snapshot `order_recon` แช่ตอนตรวจ** · กรองด้วย `r.date` = `sale_date` = **วันของแพลตฟอร์ม**) · แถว **BigSeller** = `d.rows` (**ทะเบียนสด order_ledger** · กรองด้วย `o.order_date` = **วันของ BigSeller** · ตัด `status==='cancelled'`) → ใบที่ตอนตรวจ `matched` แต่ภายหลัง **ยกเลิก / ถูกลบจากทะเบียน / ลงวันคนละช่วง** จะหายจากแถว BigSeller แต่ยังอยู่แถวหลังบ้าน · **`ผลต่าง` = only_be+only_bs+diff+unrecon (สถานะ recon) ไม่ใช่ผลลบของ 2 แถว** → gap นี้มองไม่เห็นมาก่อน
- **`ordBoardGap(d)` (ใหม่):** recon row ที่ `ordReconEffStatus` = matched/diff (มี 2 ฝั่งใน snapshot) แต่ `order_no` ไม่อยู่ใน active set → คืนรายใบ + เหตุผล 3 แบบ: **ยกเลิกภายหลัง** (`o.status==='cancelled'`) · **วันที่คนละช่วง** (มีใน rows · order_date นอกช่วง · tip โชว์ 2 วัน) · **ไม่มีในทะเบียนแล้ว** (ไม่มีใน rows)
- **UI:** กล่องเหลืองใต้ matrix (`gapHtml` · โชว์เฉพาะเมื่อ gap>0 · เงียบสนิทเมื่อสะอาด) — พาดหัว "ทำไม 'ระบบหลังบ้าน' มากกว่า 'BigSeller' N ใบ ทั้งที่ผลต่าง = 0" + จัดกลุ่ม ช่องทาง×เหตุผล + **เลขออเดอร์คลิกได้** (`ordSet('q',order_no)` → เด้งไปหน้าค้นหา) cap 8 ใบ/กลุ่ม
- **display-only** — ไม่แตะ `ordRunRecon`/`ordReconSave`/สถานะที่ save แล้ว · **verify (หน้าจริง · stub 3 เคสครบ):** BigSeller 1 vs หลังบ้าน 4 · ผลต่าง 0 · แมท 100% → กล่องขึ้น "3 ใบ" + เหตุผลถูกทั้ง 3 (ยกเลิกภายหลัง/วันที่คนละช่วง/ไม่มีในทะเบียนแล้ว) + code คลิกได้ · เคสสะอาด gap=0 ไม่โชว์ · boot 0 error · **กระทบหน้าอื่น = 0**

### 2026-07-17 — ★ ส่งออก IV: คอลัมน์ "ประเภท Vat" (C014) + ชิป "รวม CSR (ยอด 0)"
- **เจ้าของขอ:** (1) เพิ่มช่อง **ประเภท Vat** — M Bark = 1 · Benya: Betra (ขายข้าว) = **0** · Qi care = **1** (2) ออเดอร์ **CSR ยอด 0** ให้เลือกส่งออกมาคีย์แพทเทิร์นเดียวกับ IV ได้ (หน้างานขอ)
- **(1) Vat = ต่อท้าย C014** (เจ้าของเลือก · หลัง "ค่าส่ง (AutoKey)" ก่อน ร้าน/หมายเหตุ) → **ไม่เลื่อน mapping ของสูตร AutoKey เดิม** แค่เพิ่ม mapping ช่องใหม่ · `BS_HEAD` ไม่แตะ (dead path bs*/exportkey ใช้ร่วม) — ต่อใน `ivrBuildExportAoA` concat เท่านั้น
- **`ivrVatType(o, brand)`** (ใหม่): mbark→'1' · benya อิง `incBrandOf` (BT→'0' · QI→'1') · **เดาแบรนด์ไม่ออก → '' + หมายเหตุเตือน** (ไม่เดามั่ว · Vat ผิด = ภาษีผิด) · **Vat = ระดับบิล → ใส่บรรทัดแรกของออเดอร์** (`isFirst?vat:''` เหมือน IV/order_id)
- **★ อุด `incBrandOf` (บั๊กเดิม):** step 1 ดู **`bsSeedShopBrand()` map ก่อน** แล้วค่อย fallback `bsBrandFromShop` (regex) — `benya_official` (= Qi care) regex จับไม่ได้ (`/qi/i` ไม่ match · `be\b` ก็ไม่ match "benya") → **รหัสลูกค้า "SHOPEE QI" เคยว่างมาตลอด** ทั้งที่ตารางร้านรู้แบรนด์อยู่แล้ว · แก้แล้วได้ทั้ง cust + Vat (กระทบ RE export ด้วย = ดีขึ้นทั้งคู่)
- **panel "กำหนดแบรนด์ตาม SKU" ขยายสโคป:** เดิมเก็บเฉพาะ marketplace ที่เดาแบรนด์ไม่ออก → ตอนนี้ **ทุกออเดอร์ Benya** (ขายตรงก็ต้องรู้แบรนด์เพื่อกำหนด Vat) · ปุ่มบอก Vat ("Betra (BE) · Vat 0" / "Qi (QI) · Vat 1") · กดครั้งเดียวเติมทั้ง cust + Vat
- **(2) CSR = ชิปเลือกเอง ปิดไว้ก่อน** (เจ้าของเลือก · คงเจตนาเดิม "CSR ไม่ยื่นภาษีขาย"): `exp.includeCsr` + `ivrToggleIncludeCsr` · `ivrCanExport(o, rmap, includeKeyed, **includeCsr**)` param 4 (default false = พฤติกรรมเดิมเป๊ะ · caller 2-arg ที่ board/KPI ไม่กระทบ) · ชิปโชว์จำนวน CSR ในช่วง + เตือน "กินเลข IV ต่อเนื่อง" ตอนเปิด · confirm ตอนส่งออกบอกจำนวน CSR
- **preview index เลื่อน:** `NOTE_COL 15→16` · `VAT_COL 14` ไฮไลต์ + เตือน "ประเภท Vat ว่าง N ใบ" (นับเฉพาะบรรทัดแรก = ระดับบิล) · `!cols` xlsx 16→17 ช่อง
- **verify (หน้าจริง · stub state + render จริง):** header 17 ช่อง Vat=idx14 · MBark tiktok 2 สินค้า → Vat '1' บรรทัดแรกเท่านั้น · Benya betra_brand→0 · benya_official→**1 (ได้แล้วหลังอุด shop map)** · CSR จาก benya_official→Vat 1 + cust CSR · SDO101 เดาไม่ออก→ว่าง+เตือน · ชิป default "ไม่รวม CSR" (eligible 1 / blocked 2) → เปิด → eligible 3 · CSV ไม่มี `="` · boot 0 error · **กระทบหน้าอื่น = 0**

### 2026-07-16 (2) — ★ ส่งออก IV: CSV = ข้อความล้วน (ถอด Excel text-lock `="..."` ที่ AutoKey คีย์ตามไปด้วย)
- **เจ้าของแจ้ง:** ไฟล์ CSV ส่งออกไปคีย์ AutoKey มี `="` และ `"` นำหน้าทุกข้อความ (เช่น `="2607000001"` · `="260701GCDXV0AV"` · `="01/07/69"`)
- **ต้นเหตุ:** `aoaToLockedCsv` (commit `9111ea0` · 29 มิ.ย.) ห่อ 5 คอลัมน์เสี่ยง (1=เลข IV · 2=เลขคำสั่งซื้อ · 3=วันที่ · 6=SKU · 11=ผัง SKU ค่าส่ง) ด้วย **Excel formula syntax `="value"`** กัน Excel แปลง order_id TikTok ยาว → scientific (5.8433E+17) + วันที่ `01/07/69`→`01/07/2569` · ได้ผลเฉพาะตอนเปิดใน Excel (decode formula → text) · **AutoKey อ่าน CSV ดิบ ไม่ strip → คีย์เครื่องหมายไปด้วย** (commit เดิมเขียนหมายเหตุเตือนเคสนี้ไว้แล้ว)
- **แก้:** `aoaToLockedCsv` → **`aoaToCsv(aoa)`** (plain · quote เฉพาะค่าที่มี comma/quote/newline ตามมาตรฐาน CSV · CRLF · BOM เหมือนเดิม) · `ivrDoExport` fmt='csv' เรียกตัวใหม่ · **xlsx ไม่แตะ** (`forceTextCells` ล็อก cell type ในตัวไฟล์อยู่แล้ว ไม่ต้องพึ่งสูตร)
- **★ ห้ามเอา `="..."` กลับมาใส่ CSV อีก** (คอมเมนต์เตือนไว้ทั้ง 2 จุด) — CSV = ให้ AutoKey อ่าน · อยากเปิดดู/แก้ใน Excel โดยเลข/วันที่ไม่เพี้ยน → **ใช้ปุ่มส่งออก .xlsx** · เปิด CSV ใน Excel แล้ว order_id เพี้ยน = ธรรมชาติของ CSV (trade-off ที่ยอมรับ)
- **verify (หน้าจริง):** `aoaToCsv` output ไม่มี `="` · escape ถูก (`"ของ, มีคอมม่า"` · `"เขา ""อ้าง"" ว่า"`) · `aoaToLockedCsv` ไม่เหลือใน repo · syntax OK · boot 0 error · **กระทบหน้าอื่น = 0** (helper ใช้ที่เดียว = ivrDoExport)

### 2026-07-16 — ★ AP นำเข้า: identity = เลขเอกสารตั้งหนี้ (doc_no/RR) แทน "เลขที่บิล" + เตือนยอด/ผู้ขายเปลี่ยน
- **บั๊กจริง (ผู้ใช้แจ้ง):** เลขที่บิลซ้ำได้ (เช่น `MEMO.2026-07-01` คนละ RR คนละคน) แต่ upsert คีย์ `company_id,invoice_no` → ทับกัน (อารียา 1000 → นันทวรรณ 5000)
- **แก้ identity → doc_no (RR):** migration `supabase/zz-ap-docno-identity.sql` — เพิ่มคอลัมน์ `doc_no` + backfill จาก `remark` (`Express:xxx`) + **drop `ap_invoices_company_id_invoice_no_key`** + unique partial `(company_id,doc_no) WHERE doc_no NOT NULL` (ห่อ EXCEPTION)
- **นำเข้า XML (`apoHandleXml`):** dedup ในไฟล์ด้วย `doc_no||invoice_no` · จับคู่ DB ด้วย `doc_no` ก่อน (ไม่มี doc_no → invoice_no) · tag: `new`/`update`/`same` · **`update` = ยอดเปลี่ยน หรือ ผู้ขายเปลี่ยน** (`apstNormName` เทียบชื่อ · RR เดิมคนละคน = เตือนแดง ⚠) · preview โชว์ doc_no เด่น + เลขบิลรอง + "⚠ เดิม: {ผู้ขาย}"
- **commit เลิก upsert-invoice_no:** มี `_exId` → update by id (คง planned/note/pay_from เดิม) · ไม่มี → insert (เลขบิลซ้ำได้) · CSV import จับด้วย invoice_no (doc_no ว่าง) แทน upsert
- **apoEnrich `_docno`** อ่านจาก `r.doc_no` ก่อน (fallback remark) · apoLoad `select("*")` ได้ doc_no
- **apst ไม่ตั้ง doc_no** (invoice ที่สร้างจากรายงานจ่าย · RR ซ้ำข้าม PS ได้ · ถ้าตั้งจะชน unique) · idempotency ยังใช้ existKeys
- **verify browser:** อารียา≠นันทวรรณ (เตือน) · นาย อดิศร=อดิศร (ไม่เตือนผิด) · _docno column-first · syntax OK · boot 0 error · **ต้อง push ให้ migration รันก่อนใช้**

### 2026-07-15 (4) — ★ AP Outstanding: redesign ตาม handoff (filter drawer + KPI แถบสี)
- **เจ้าของส่ง handoff จาก Claude Design** (`for-design` ref) — เอาตามนี้เป๊ะ โดยเฉพาะ "สไลเซอร์แบบ drawer"
- **เลิกสไลเซอร์ inline → filter drawer แผงเลื่อนขวา** (`apoFilterDrawerHtml` · ปุ่ม `⛭ ตัวกรอง` + badge นับ): 4 กลุ่ม (ประเภทค่าใช้จ่าย/อายุหนี้/ผู้ขาย/รอบจ่าย) · checkbox **3 สถานะ** (เลือกทั้งหมด ✓ / บางส่วน – / ไม่เลือก) ต่อกลุ่ม + master "(เลือกทั้งหมด)" + count · ปุ่ม "ล้างตัวกรอง"/"ดูผลลัพธ์"
- **โมเดลตาม handoff:** `colFilters[col]` = array ค่าที่เลือก · `undefined`=เลือกทั้งหมด · `[]`=ไม่เลือกเลย (0 แถว) → **เลิกลบ empty array ใน apoGet** · `apoDrawerToggle` (undefined→เริ่มจาก allVals แล้ว toggle = deselect ทีละตัว) · `apoDrawerToggleAll` (all↔none) · `apoActiveFilters` (กลุ่มที่ไม่ได้เลือกครบ = active → pill + badge)
- **KPI การ์ดแถบสีซ้าย** (`.apo-kpi` · คงค้าง #e11d48 · เกินกำหนด #d97706 · บิลเกิน #ea580c · ครบ30 #0d7c74) · **แปรตามตัวกรอง** (`apoKpis(inv)` recompute ใน apoApplyChanges + pill/badge/drawer re-render)
- **filter bar:** ⛭ ตัวกรอง + ค้นหา + เฉพาะเกินกำหนด/แสดงที่จ่ายแล้ว + pills (× ลบ) + ล้างทั้งหมด + นับ · **สไลเซอร์นับจาก slicerBase (ตัด paid)**
- **palette handoff** (teal #0d7c74 · #0f2e2b · #5c807a ...) scoped ใน apstInjectStyle · **verify browser:** drawer logic ครบ (toggle/all-none/filter/tri-state/active) · syntax OK · boot 0 error
- **ยังไม่ทำ:** drawer สำหรับแท็บจ่ายแล้ว (handoff มี paidGroups) · header col-filter ▼ เดิมยังอยู่ (ไม่ขัดกับ drawer · เขียน colFilters ตัวเดียวกัน)

### 2026-07-15 (3) — AP settlement: fix หน้าจ่ายแล้วว่าง (self-heal voucher) + วันที่/เลขบิลชน + ชิปประเภทเจ้าหนี้
- **บั๊กจ่ายแล้วว่าง (ต่อ):** ล้างการนำเข้า soft-delete voucher → นำเข้าใหม่ที่ทุกรายการถูกข้าม (existKeys) → ปุ่มยืนยันขึ้น (0) กดไม่ได้ → voucher ไม่ถูกคืนชีพ → จ่ายแล้วว่างตลอด
  - **`apstLoadVouchers` self-heal:** query payment active → หา voucher ที่ soft-delete แต่มี payment → `deleted_at=null` (ซ่อมเองตอนเปิดแท็บจ่ายแล้ว/ตั้งโอน · ไม่ต้องนำเข้าซ้ำ)
  - ปุ่มยืนยัน preview: enable เมื่อมี voucher (`active.length`) ไม่ใช่แค่ payCount · label "ยืนยัน / ซ่อมข้อมูล" เมื่อ payCount=0
  - `apstCommit` voucher upsert +`deleted_at:null` (คืนชีพ) · สร้างบิลชนตัว soft-delete → คืนชีพบิลเดิมแทนเติม -2 (`allByNo` incl deleted)
- **วันที่ detail ถูกตัดหลักหน้า** (`0/06/2569`→`2026-06-00`) → `apstValidDate`/`apstThai` คืน null ถ้าไม่ valid · สร้างบิลใช้ payDate (วันจ่าย PS)
- **UI หน้า AP Outstanding:** ประเภทเจ้าหนี้ = **ชิปด้านบน** (`apoCatChipsHtml` · multi-select toggle + "ทั้งหมด"=ล้าง + count) แทน dropdown หัวตาราง · `apoApplyChanges` re-render ชิป (`#apoCatChipsWrap`) · filter bar คุมความกว้าง (search max 400 · select 160 · nowrap) · CSS `.apo-catchip` ใน apstInjectStyle
- **verify:** syntax OK · boot 0 error · apoCatChipsHtml render ถูก (count/on-state/หมวดนอก list) · ฟังก์ชันโหลดครบ

### 2026-07-15 (2) — ★ แก้ db-migrate แดงค้างตั้งแต่ 29 มิ.ย. (index จับคู่ 1:1 เก่า ขัดกับ M-to-N)
- **อาการ:** `db-migrate` workflow แดงทุก push ตั้งแต่ commit `8780e49` (29 มิ.ย.) → บดบังว่า migration ใหม่ลงจริงไหม (เขียวมาก่อน 28 ครั้ง · run เขียวสุดท้าย `f4b0911`)
- **หา culprit:** annotations API ให้แค่ "exit code 1" · เพิ่ม `echo "::error title=... ::$ERRMSG"` ต่อไฟล์ที่ fail ใน `migrate.yml` → อ่านผ่าน check-runs annotations API (public) ได้ชื่อไฟล์+error จริง (เก็บ diagnostic นี้ไว้ถาวร)
- **error จริง:** `bankrec-phase1.sql` → `could not create unique index uq_brec_match_express DETAIL: Key (express_row_id)=(...) is duplicated` (23505)
- **root:** `uq_brec_match_express`/`uq_brec_match_bank` (UNIQUE บน express_row_id/bank_row_id เดี่ยว = จับคู่ 1:1) **ขัดกับฟีเจอร์ M-to-N matching** (2026-06-28 · 1 Express ↔ หลาย Bank group match ใส่ brec_matches หลายแถว/express) → พอ user เริ่มใช้ group match ~29 มิ.ย. → express_row_id ซ้ำ → CREATE UNIQUE INDEX fail ทุก run
- **แก้:** `bankrec-phase1.sql` เปลี่ยน CREATE 2 ตัวนั้นเป็น **`DROP INDEX IF EXISTS`** (index เดี่ยวล้าสมัย · ความถูกต้องคู่คุมด้วย `uq_brec_match_pair (express_row_id,bank_row_id)` จาก `zz-bankrec-multi-match.sql` อยู่แล้ว) · เสริม `bankrec-phase-a-stable-key.sql` mark dup ค้างเป็น ambiguous + ห่อ CREATE UNIQUE INDEX ด้วย EXCEPTION (กันเคส edge)
- **ผล:** migrate เขียวแล้ว (commit `ba79c06`) → ยืนยัน `zz-ap-payment-settlement.sql` (ฟีเจอร์ AP ข้างล่าง) ลงจริงครบ
- **บทเรียน:** เพิ่มฟีเจอร์ M:N อย่าลืมถอด unique 1:1 เก่า · unique index บนตาราง user-data ควรห่อ `EXCEPTION` เหมือนไฟล์อื่นทั้ง repo (กัน migrate ทั้ง run แดงเพราะ data)

### 2026-07-15 — ★ AP: นำเข้ารายงานจ่ายชำระหนี้ → mark จ่ายแล้ว + แท็บ "จ่ายแล้ว/ตั้งโอน/ทะเบียนบัญชี" (โมดูล `apst*`)
- **เจ้าของขอ:** การเงินอัปรายงานจ่ายชำระหนี้ (Express CSV) → ระบบอ่านว่า AP ตัวไหนจ่ายแล้ว (วันไหน/แบงค์ไหน/PS ไหน/RR ไหน) → ยืนยัน → ย้ายไปแท็บ "จ่ายแล้ว" (เห็นว่า 1 PS จ่ายกี่ RR) + ฟังก์ชัน **ตั้งโอน** (ดึงเลขบัญชีผู้รับ + ยอด + หมายเหตุ → ส่งออก/ก๊อปให้การเงินตั้งโอน)
- **หน้า AP เป็น 4 แท็บ** (`apstTabBarHtml` · `apoSetTab` · `apoGet().tab`): เจ้าหนี้คงค้าง (เดิม) · **จ่ายแล้ว** (`apstRenderPaid`) · **ตั้งโอน** (`apstRenderTransfer`) · **ทะเบียนบัญชีผู้รับเงิน** (`apstRenderRegistry`) · แท็บใหม่โหลดข้อมูลเอง (`apstRenderTab` dispatch · renderToolApOutstanding = แท็บคงค้างล้วน · ตั้ง `d.tab='outstanding'`)
- **Migration `supabase/ap-payment-settlement.sql`** (idempotent): (1) `vendors` +`bank_code/bank_name/bank_account_no/account_name/account_type/notify_email/bank_note_raw` (2) ตาราง **`ap_payment_vouchers`** (PS · unique `company_id,ps_no` · gross/net/discount/bank_label/bank_account_id/cheque/note · RLS ปิด) (3) `ap_payments` +`voucher_id/receipt_no/cheque_no`
- **นำเข้า (ปุ่ม "⬆ รายงานจ่ายชำระ" ในแท็บคงค้าง):** `apoHandlePaymentReport` decode cp874 → `apstParsePaymentReport` (PS header cols: [1]วันจ่าย [2]`*`=ยกเลิก [3]PS [4]ผู้ขาย [10]gross [13]net [16]ส่วนลด+ภาษี [18]หมายเหตุ [19]เช็ค [21]แบงค์ [22]สถานะ · detail: [5]RR/RW/AC [6]วัน [7]ref [8]ยอด [11]note · เช็ค/แบงค์อาจมาบรรทัดถัดไป = continuation) → **preview modal** (จับคู่ AP `apstMatchDoc` ผ่าน invoice_no หรือ `Express:xxx` ใน remark · จับคู่ได้/สร้างใหม่/ข้ามซ้ำ/ยกเลิก) → `apstCommit`
- **★ ทุกบรรทัดในรายงาน = บิลจ่ายแล้ว** (เจ้าของสั่ง): จับคู่ AP ไม่เจอ → **สร้าง ap_invoice ใหม่ + ทำจ่าย** (invoice_no=doc · collision→`-2`) · เจอ → insert ap_payment เต็มยอด detail (=gross clear บิล) · **idempotent** ด้วย existKeys `pv_no|receipt_no` (re-import ไม่ซ้ำ) · voucher upsert by ps_no · trigger `fn_ap_recompute` mark paid
- **จ่ายแล้ว** = จัดกลุ่มตาม voucher (PS) · คลิกการ์ดดู RR ในแต่ละ PS · badge "หลายใบใน PS เดียว" · KPI PS/จ่ายสุทธิรวม/PS หลายใบ
- **ตั้งโอน** = vouchers ต่อรอบ (chip วันจ่าย) → ตาราง ลำดับ/ชื่อ/จำนวนเงิน(net)/ธนาคาร/เลขบัญชี/ชื่อบัญชี/หมายเหตุ(`PSxxx - note`)/อีเมล · เลขบัญชีดึงจากทะเบียน vendors (match vendor_id หรือชื่อ) · แถวไม่มีเลขบัญชี=ส้ม · ส่งออก xlsx (`apstExportTransfer`) + ก๊อป TSV (`apstCopyTransfer`)
- **ทะเบียนบัญชีผู้รับเงิน** = ตาราง vendors แก้ inline (ธนาคาร/เลขบัญชี/ชื่อบัญชี/อีเมล · `apstSaveVendorRow`) + **นำเข้าไฟล์ "รายละเอียดผู้จำหน่าย" (CSV)** (`apstImportVendorMaster`): parse เลขบัญชีจากช่อง "หมายเหตุ" (`apstParseBankNote` · รูปแบบ `ธนาคาร/เลขบัญชี[/ประเภท]` + กลับด้าน/เว้นวรรค/บัตรเครดิต) → upsert by external_code (**คงอีเมลเดิมไว้** ไม่อยู่ในไฟล์) · รายใหม่เว้นเลขบัญชีให้การเงินกรอก
- **ธนาคาร:** `APST_BANK_ALIAS/TH/CODE3` (SCB→014 · KBANK→004 · ฯลฯ) · resolve บัญชีบริษัทจ่ายจาก `SCB-4889`→bank_accounts เลขลงท้ายตรง (`apstResolveBankAcct`)
- **verify (Node harness กับไฟล์จริง 2 ไฟล์):** รายงานจ่าย 46 PS (ยกเลิก 2) · gross 1,431,511.70 + net 1,424,450.88 = ยอดรวมในรายงานเป๊ะ · PS จ่าย 2 RR ✓ · multiline PS ดึงเช็ค/แบงค์จาก continuation ✓ · 6 AC ✓ · ส่วนลด ✓ · ผู้จำหน่าย 376 ราย parse บัญชี 252/269 · syntax OK · boot 0 error · ฟังก์ชันโหลดครบในหน้าจริง · **กระทบหน้าอื่น = 0** (แท็บ+โมดูลใหม่ · แท็บคงค้างเดิมไม่แตะ logic)
- **ยังไม่ทำ/หมายเหตุ:** ต้อง **push เพื่อรัน migration** ก่อนใช้ · การจ่ายจริง (ตัดเงินสด) source = ap_payments (net เก็บใน voucher สำหรับตั้งโอน) · โอนต่างประเทศ (PT Benya note block) ยังไม่ handle · รอเจ้าของ seed ทะเบียน + ทดสอบกับข้อมูลจริงหลัง deploy

### 2026-07-14 (4) — ★ หน้าใหม่: ทะเบียนคุมเงินทดรองจ่าย (advance) — คุมเบิกทดรองรายพนักงาน · เคลียร์ · คงค้าง
- **เจ้าของขอ:** หน้าใกล้ ๆ เงินสดย่อย · คุมว่าพนักงานแต่ละคน (คลิกดูรายคน) เบิกเงินทดรองค่าอะไร (คลิกดูรายค่าใช้จ่าย) · เบิกแล้วเคลียร์ยัง · เคลียร์กับชุดไหน · คนนี้มีกี่วง คงค้างเท่าไหร่
- **Migration `supabase/advance-register.sql`** (idempotent · RLS ปิด เหมือน petty_cash): ตาราง `advances`(company_id/employee_name/advance_no[ชุดเบิก]/advance_date/purpose[ค่าอะไร]/category/amount/cleared_amount/clear_no[ชุดเคลียร์]/clear_date/status/note/soft-delete) + index co/emp
- **โมดูล `adv*`** (`renderToolAdvance` · dispatch `t.id==="advance"` · TOOLS หลัง `tasks`/เงินสดย่อย · icon receipt-text): **2 view** — (1) สรุปรายคน (`advByPerson`: ชื่อ · จำนวนวง · เบิกรวม · เคลียร์แล้ว · คงค้าง · คลิกชื่อ→ (2) รายคน) · (2) person view = วงของคนนั้น (ชุดเบิก · ค่าอะไร · ยอด · เคลียร์แล้ว · คงค้าง · สถานะ badge · เคลียร์กับชุด) + filter chip ทั้งหมด/ยังค้าง/เคลียร์แล้ว · form เพิ่ม/แก้ (`advSave`/`advDelete` · prefill ชื่อเมื่อเพิ่มจาก person view)
- **สถานะ** `advStatusOf`: cleared=0→ยังไม่เคลียร์(แดง) · <amount→เคลียร์บางส่วน(ส้ม) · =amount→เคลียร์แล้ว(เขียว) · `advOutstanding`=amount−cleared · KPI: เบิกทั้งหมด/เคลียร์แล้ว/คงค้าง/จำนวนคน
- **กระทบหน้าอื่น = 0** · reuse `pcNum`/`fopCompanyId`/`fopCanWrite`/`fopDate`/`esc` · verify (mock): KPI เบิก 16,000·เคลียร์ 6,200·คงค้าง 9,800 · person สมชาย 2 วง (AV-001 เคลียร์แล้ว·AV-004 บางส่วน คงค้าง 1,800·CL-014) · form prefill ชื่อ
- **guard company-switch:** `if((!d.loaded || d._co!==state.company) && !d.busy)` (บทเรียนจาก docs)

### 2026-07-14 (3) — งบกำไรขาดทุน: เอา banner seed ออก + กราฟรายเดือนใหญ่+เลขบนแท่ง + การ์ดจุดคุ้มทุน
- **เจ้าของขอ 3 อย่าง:** (1) เอา banner เหลือง "แสดงข้อมูลตัวอย่าง" ออก (2) กราฟ "รายได้·ค่าใช้จ่าย·กำไรสุทธิ รายเดือน" ขยาย + ใส่เลขบนหัวแท่ง (เช่น +788K) (3) เพิ่มบทวิเคราะห์จุดคุ้มทุน (ต้องขายกี่บาทถึงไม่ขาดทุน)
- **(1)** ลบ `.fin-seednote` ทั้ง P&L + งบฐานะ (replace_all)
- **(2)** กราฟรายเดือน = การ์ดเต็มความกว้าง (`.fin-chart-box.tall` 420px · เดิม 280 ครึ่งจอ) · plugin `finValLabels` (afterDatasetsDraw) วาดเลขย่อ `finKfmt` บนแท่งรายได้(น้ำเงิน)/ค่าใช้จ่าย(เทา) + จุดเส้นกำไรสุทธิมีเครื่องหมาย +/- (เขียว/แดง) · `layout.padding.top:22` กันเลขล้น
- **(3) `finBreakEven(C)` + `finBreakEvenHtml(C)`:** จุดคุ้มทุน = ต้นทุนคงที่ (opex+fin) ÷ อัตรากำไรขั้นต้น (gross÷rev · ถือ COGS=ผันแปร) · การ์ดข้างกราฟแนวโน้ม (fin-grid2) โชว์ จุดคุ้มทุนทั้งงวด + เฉลี่ย/เดือน + รายได้จริง + ต้องขายเพิ่มอีก (แดง) / เกินแล้ว (เขียว) + สูตร
- **verify (seed MBark):** จุดคุ้มทุน ฿3,887,312 (fixed 2,879,120 ÷ 74.1%) · ต้องขายเพิ่ม ฿1,215,724 · /เดือน 647,885 (ตอนนี้ 445,265) · seednote หาย · chart tall · กระทบหน้าอื่น = 0

### 2026-07-14 (2) — ★ Document Center: แก้บั๊กจริง — เอกสารไม่ได้หาย (renderToolDocs ไม่โหลดใหม่ตอนสลับบริษัท)
- **อาการ:** Benya โชว์ 0 ไฟล์ · แต่ปุ่มกู้คืนรายงาน "ที่เก็บมี 2 ไฟล์ · ตรงกับทะเบียนครบแล้ว" → **ข้อมูลอยู่ครบ ไม่ได้หาย** · เป็นบั๊กแสดงผล
- **ต้นเหตุ:** `state.docs` เป็น object เดียวใช้ร่วมทุกบริษัท (`docGet` ไม่ได้ key ต่อบริษัท) · `renderToolDocs` โหลดใหม่เฉพาะ `if(!d.loaded && !d.busy)` → เปิด Docs ตอนอยู่ M Bark (0 ไฟล์ · loaded=true, _co=mbark) แล้วสลับมา Benya → `d.loaded` ยังค้าง true → **ข้ามการโหลด** → โชว์ rows ว่างของ M Bark · (การ reset ตอนสลับบริษัทอยู่ใน `docLoad` แต่ไม่เคยถูกเรียก) · ปุ่มกู้คืน `await docLoad()` เข้าไปข้างในเลย reset+query ถูก → เจอ 2 ไฟล์
- **แก้ (1 บรรทัด):** guard เป็น `if((!d.loaded || d._co!==state.company) && !d.busy)` → สลับบริษัทแล้วโหลดใหม่เสมอ · verify (stub): สถานะค้าง mbark→สลับ benya→docLoad ถูกเรียก·rows=2·โชว์ครบ·KPI 2
- **กระทบหน้าอื่น = 0** (โมดูลอื่น key state ต่อบริษัทอยู่แล้ว · docs เป็นเคสเดียวที่ใช้ object ร่วม)

### 2026-07-14 — Document Center: ปุ่ม "🛟 กู้คืนจากที่เก็บ" (สแกน Storage → เติมทะเบียนที่หาย · safety net)
- **เจ้าของแจ้ง:** เคยอัปเอกสารใน Document Center แต่ตอนนี้หาย (โชว์ 0 ไฟล์ · หน้า Benya) — ภายหลังพบว่าเป็นบั๊กแสดงผล (ดูข้อ (2) ด้านบน) · ปุ่มกู้คืนยังเก็บไว้เป็น safety net
- **วินิจฉัย:** repo/migration ไม่มี DELETE/soft-delete `documents` เลย · insert+load ใช้ `fopCompanyId()` เหมือนกัน (ไม่ mismatch) · หน้าอื่นของ Benya (AP/orders) โหลดได้ = RLS/access ปกติ → ไฟล์น่าจะยังอยู่ใน Supabase Storage แต่ **แถวตารางหาย** หรือ **อัปไว้คนละบริษัท**
- **`docScanStorage()` (ใหม่):** list bucket `documents` ใต้ `{CODE}/` (โฟลเดอร์ปี → ไฟล์ · โฟลเดอร์ = `id===null`) → เทียบกับ `storage_path` ในตาราง → ไฟล์ที่ขาด (orphan) = re-insert แถว `documents` (title/file_name = ชื่อในที่เก็บ · category=other · note="กู้คืนจากที่เก็บ") · ถ้าที่เก็บว่าง → แจ้ง "อาจอยู่บริษัทอื่น สลับบริษัท" · gate เขียนด้วย `docCanWrite`
- **UI:** ปุ่มส้ม "🛟 กู้คืนจากที่เก็บ" ข้าง ZIP · empty state ใบ้ให้กดกู้คืน/สลับบริษัท · ข้อความสถานะที่ `#docZipMsg`
- **หมายเหตุ:** ชื่อไฟล์เดิม (ภาษาไทย) อยู่ในแถวตารางที่หาย — กู้จากที่เก็บได้แค่ชื่อ ASCII `{stamp}.{ext}` (ไฟล์เปิด/โหลดได้ปกติ · เปลี่ยนชื่อ/จัดหมวดภายหลัง) · **กระทบหน้าอื่น = 0**

### 2026-07-13 (13) — หน้าแรก: KPI ทะเบียนคำสั่งซื้อ (ยอดขาย/ยกเลิก) + งานที่ต้องทำ = รอบจ่ายใกล้สุด + เตือนอัป STM
- **เจ้าของขอ (จากข้อมูลจริง):** (1) KPI ใบแรก "การคีย์ IV" → **ทะเบียนคำสั่งซื้อ** (อัพข้อมูลถึงวันที่ · ขายทั้งหมดกี่ออเดอร์กี่บาท · ยกเลิกกี่ออเดอร์กี่บาท) · รอรับชำระ/เงินเข้าแบงค์คงไว้ (2) แทน "งานวันนี้ + Progress" ด้วย **ค่าใช้จ่ายถึงกำหนดชำระรอบใกล้สุด** (รายการ+ยอดรวม) + **เตือนฝ่ายการเงินอัปยอด STM**
- **`homeLoadStats` เพิ่ม:** `cancelledSum` · `maxOrderDate` (max order_date ทุกออเดอร์ = ความสดข้อมูล) · **`payRound`** (query `ap_invoices` ที่มี `planned_payment_date` · group ตามวัน · เลือกวันใกล้สุด ≥ วันนี้ ไม่งั้นวันเลยกำหนดล่าสุด · {date,total,count,items,overdue}) · **`lastBalDate`** (max `bank_balances.balance_date`)
- **KPI ใบ 1:** icon clipboard-list · value = saleSum เดือนนี้ · sub "ขายทั้งหมด N ออเดอร์" + "ยกเลิก M ออเดอร์ · ฿Y" (แดง) · tag "อัพถึง {maxOrderDate}" · ลิงก์ tool `orders`
- **แถว 2 (แทน tasks/progress):** ซ้าย = การ์ด "ค่าใช้จ่ายที่ถึงกำหนดชำระ · รอบใกล้ที่สุด" (ยอดรวม + list 7 + "อีก N" + ลิงก์ cashflow · ว่าง→ชวนไปกรอกวันชำระที่ AP) · ขวา = การ์ดเตือน **อัปยอด STM** (แดงถ้า lastBalDate<วันนี้ · ลิงก์ bank_balance) + การ์ดอัปสเตทเมนต์ (bankrec)
- **★ แก้ทันที (เจ้าของท้วง "รอบ 15 มีเต็ม แต่การ์ดว่าง"):** payRound เดิมดึงแค่ `ap_invoices.planned_payment_date` → พลาดค่าใช้จ่ายประจำ (recurring) · เปลี่ยนเป็น **reuse `cffLoad()` + `cffStaffPayments(cd.data,cd)`** (ตัวเดียวกับหน้า Cash Flow Forecast) → group by due_date · เลือกวันใกล้สุด ≥ วันนี้ · aggregate ตาม vendor · = รอบจ่ายตรงกับ CFF เป๊ะ (รวม recurring: วอเทอร์ป๊อก/ปกส/สรรพากร/Google/กยศ) · recurring amount = `expected_amount`
- **ลบ dead code:** `tasks`/`taskCounts`/`tf`/`visTasks`/`progress` (ของ mockup) · เก็บ `activity`/quick access/cash flow chart เดิม (เจ้าของไม่แตะ) · **กระทบหน้าอื่น = 0** · verify (mock): KPI ฿1,875,400 · payRound ฿214,000 7 แถว · STM stale แดง · งานเดิมหาย

### 2026-07-13 (12) — งบฐานะ: คะแนนสุขภาพคิดจาก "อัตราส่วนงบฐานะ" ล้วน (ไม่ใช่ก๊อป P&L)
- **เจ้าของท้วง:** คะแนนหน้างบฐานะเอา finHealth ของ P&L มาวาง (มีทำกำไร/เติบโตจากงบกำไรขาดทุน) — ต้องคิดจาก 5 อัตราส่วนที่แสดงในตารางด้านบนของหน้านั้นเอง
- **`finBalHealth(T)` (ใหม่):** คะแนน 5 มิติ = 5 ratio ของ `finBalRatios` เป๊ะ — สภาพคล่อง (Current Ratio · 25%) · เงินทุนหมุนเวียนสุทธิ (WC÷CL · 10%) · หนี้สินต่อสินทรัพย์ (Debt Ratio · 25% · desc) · หนี้สินต่อทุน (D/E · 20% · desc · ทุนติดลบ→5) · ส่วนของผู้ถือหุ้น (Equity Ratio · 20%) · แต่ละตัว `finScoreLinear` pts ตาม band ที่โชว์ + scale/raw/unit/desc/cap ครบ (drilldown finScaleHtml ได้)
- **refactor:** แยก renderer กลาง `finRenderHealth(H,caption)` · `finHealthBlock` (P&L) + `finBalHealthBlock` (งบฐานะ) เป็น wrapper บาง ๆ · งบฐานะเรียก finBalHealthBlock แทน finHealthBlock
- **verify (seed MBark):** สภาพคล่อง 1.36→70 · WC 74 · Debt 5.15→6 · D/E ทุนติดลบ→5 · Equity -415%→3 · **overall 28** (P&L ยัง 34 คนละชุด · มิติตรงกับตาราง ratio) · กระทบหน้าอื่น = 0

### 2026-07-13 (11) — งบฐานะ: เพิ่มคะแนนสุขภาพการเงิน + Exec period picker = การ์ดเดียวสะอาด
- **เจ้าของขอ 2 อย่าง:** (1) หัว Exec ยังรก (3 แถวเลือกช่วงเวลาลอย ๆ) (2) เพิ่มคะแนนสุขภาพการเงินในหน้างบแสดงฐานะการเงินด้วย
- **(1) `edPeriodPicker` = การ์ดเดียว** (bg ขาว + border + radius 12 + shadow) · 3 ส่วนเรียงข้างกัน **ช่วงเวลา | ไตรมาส·ปี | เดือน·ปี** คั่นด้วยเส้นตั้ง (แทน 3 แถว full-width ลอยบนพื้น) · flex-wrap เมื่อจอแคบ · แต่ละ section = label เล็ก + chips
- **(2) `finHealthBlock(d)` (ใหม่ · reusable):** แยกบล็อกคะแนนสุขภาพ (gauge + 5 มิติ + drilldown finScaleHtml) ออกจาก finAnalyticsHtml → เรียกทั้ง **P&L** (`finAnalyticsHtml`) และ **งบฐานะ** (`finBalAnalyticsHtml` · วางหลังการ์ดอัตราส่วน ก่อน insight) · guard `d.pnl && d.balance` (ไม่มี pnl → ไม่โชว์) · finToggleHScore/hOpen ใช้ร่วม (drilldown ทำงานทั้ง 2 หน้า)
- **กระทบหน้าอื่น = 0** · P&L gauge เท่าเดิม (34) · verify: balance มี .fin-health + 5 มิติ · period = การ์ด radius 12 · refactor ลบ subBars/gcol/gstat ซ้ำใน finAnalyticsHtml

### 2026-07-13 (10) — Executive Cash Flow: ปุ่ม toolbar คลีน (ghost ขาว+ไอคอน แทน gradient สีจัด · ป้ายสั้น)
- **เจ้าของขอ (ต่อจากข้อ 9):** ให้หน้า Exec (`edRenderDashboard`) คลีนตาแบบภาพอ้างอิงด้วย — ปุ่มเดิมเป็น gradient สีจัด (ส้ม/ฟ้า/คราม) รก
- **แก้:** นำเสนอ/พิมพ์ PDF/ทั้งรายงาน/ล้าง&เริ่มใหม่ → `btn ghost btn sm` (ขาวโปร่ง) + `<i data-lucide>` (monitor/printer/file-text/rotate-ccw) · **อัปโหลดเพิ่ม เก็บสีเขียว (CTA หลัก)** + icon plus · ป้ายสั้นลง ("พิมพ์ทั้งรายงาน"→"ทั้งรายงาน" · "อัปไฟล์เพิ่ม (รวมปี)"→"อัปโหลดเพิ่ม") · onclick/ฟังก์ชันเดิมไม่แตะ (edTogglePresent/edPrint/edExportFullPDF/edAddFile/edReset)
- **กระทบหน้าอื่น = 0** · render logic/ตัวเลข Exec ไม่แตะ (แค่ปุ่ม presentation) · verify: 4 ปุ่ม ghost + 1 เขียว ทุกปุ่มมีไอคอน

### 2026-07-13 (9) — Cash Flow Forecast: หัวเพจคลีนแบบ Exec (โลโก้ + toolbar) + คืนปุ่ม "รายละเอียดเพิ่มเติม"
- **เจ้าของขอ:** หัวหน้า `renderToolCashflowStaff` ให้คลีนตาแบบหน้างบกระแสเงินสด (Exec) · เดิม page-head ธรรมดา (h1+badge + sub ยาว "ประมาณการ · period · ยอดธนาคาร ณ · หน่วย" + ปุ่ม Snapshot เดี่ยว)
- **แก้:** mirror header ของ edRenderDashboard — `<img co.logo>` 40px + h1+badge + sub เหลือ "หน่วย: บาท" · toolbar ขวา 2 ปุ่ม ghost+icon: **รายละเอียดเพิ่มเติม** (`cffToggleStaffDetail` · เดิม def ไว้แต่ไม่มีปุ่มเรียก = dead → คืนชีวิต · toggle KPI/ไฮไลต์/timeline) + **Snapshot** · ตัด period/ยอดธนาคารออกจาก sub (ยังโชว์ในตัวรายงาน)
- **กระทบหน้าอื่น = 0** · `periodLabel` const เหลือ unused ใน func (ไม่ error) · verify: logo 40px + "Cash Flow Forecast" M Bark + sub หน่วย:บาท + 2 ปุ่มมีไอคอน

### 2026-07-13 (8) — คะแนนสุขภาพการเงิน: โชว์ "สเกลคะแนน" ในป๊อปอัพ (ตอบ "ทำไม Current Ratio >2 ได้ 93 ไม่ใช่ 100")
- **หัวหน้าถาม:** สภาพคล่อง 93 มายังไง · ถ้า >2 = ดี ทำไมไม่ 100 · ป๊อปอัพเดิมโชว์แค่ "เกณฑ์ป้ายสถานะ" (`≥2=ดี`) ไม่โชว์สเกลตัวเลข → ดูเหมือนคะแนนโผล่ลอย ๆ
- **คำตอบ:** คะแนนเป็นสเกลไล่ระดับ 0–100 (จุดยึด `finScoreLinear` pts) ไม่ใช่ผ่าน/ไม่ผ่าน · Current Ratio: 0.5→12 · 1→45 · 1.5→70 · **2→85 (เข้าเขตดี)** · 3→95 (เพดาน · สภาพคล่องสูงเกิน=เงินจม ไม่ให้เต็ม) · 93 = ratio 2.79 (Benya) interp ระหว่าง 2(85)–3(95)
- **`finScaleHtml(dt,score)`** (ใหม่ · หลัง finScoreLinear) แสดงใน `finToggleHScore` popup: chip จุดยึดทุกจุด (`ratio→score` · ไฮไลต์ `.hot` จุดที่ค่าเราตกอยู่) + ประโยคอธิบาย interp ("ค่าเรา X อยู่ระหว่าง … → = N คะแนน") + note ทิศทาง (asc/desc `dt.desc`) + cap note (ความเสี่ยง+ทุนติดลบ → ≤12)
- **refactor:** pts 5 มิติเป็น const (ptsLiq/Prof/Grow/Eff/Risk) reuse ทั้ง finScoreLinear + detail · เพิ่ม `scale`/`raw`/`unit['x'|'%']`/`desc`/`cap` ใน detail แต่ละมิติ · เปลี่ยน label popup "เกณฑ์ให้คะแนน" → "เกณฑ์ (ป้ายสถานะ)" + เพิ่มแถว "สเกลคะแนน"
- **กระทบหน้าอื่น = 0** · verify (seed MBark): สภาพคล่อง 1.36→63 (interp 1(45)–1.5(70)) · ความเสี่ยง 5.15→8 + cap ≤12 · overall 34 (เท่าเดิม)

### 2026-07-13 (7) — งบแสดงฐานะการเงิน: hero = การ์ดสินทรัพย์ (ซ้าย) + กลุ่มหนี้สิน&ส่วนของผู้ถือหุ้น (ขวา แตก 2 การ์ด)
- **เจ้าของ iterate 4 รอบ:** (1) KPI เดิมงง (2) แถบสมการ `=`/`+` → "แปลก" (3) gradient 2 การ์ด + net → ยัง (4) เจ้าของแปะภาพ layout ที่ชอบ (การ์ดขาว icon-square) → **เอาแบบนี้ · ตัวเลขใหญ่ ๆ · สีตามแบรนด์**
- **`.fin-cfhero` (final):** `.cfh-eq2` grid `0.82fr 1.45fr` → **ซ้าย** การ์ด `.cfh-asset` (รวมสินทรัพย์ · icon `landmark` square สีแบรนด์ · เลข **46px สีแบรนด์** `var(--brand)`) · **ขวา** `.cfh-src` header "หนี้สินและส่วนของผู้ถือหุ้น · แหล่งเงินทุน = รวมสินทรัพย์ {LE=A}" + 2 การ์ดย่อย: **รวมหนี้สิน** (icon `lock` ส้ม · 36px) + **ส่วนของผู้ถือหุ้น** (icon `user` เขียว/แดง · 36px · การ์ดชมพู `.neg` เมื่อ E<0) · ทุกการ์ดมี "ณ {asOf}"
- **การ์ดขาวแบน** (ไม่ gradient แล้ว) · icon square = `color-mix(brand 15%,#fff)` (asset) / soft ส้ม (liab) / soft เขียว-แดง (equity) · เลขสินทรัพย์สีแบรนด์ (mbark navy · benya teal) · เลขหนี้=`var(--fg)` · ทุน=เขียว/แดง · responsive stack ≤860/560px · ต้อง `lucide.createIcons()` (render path เรียกให้อยู่แล้ว)
- **กระทบหน้าอื่น = 0** · P&L ยังใช้ 4 KPI เดิม · verify preview (seed MBark): สินทรัพย์ 1,053,211.11 (navy 46px) · หนี้ 5,423,191.17 · ทุน (4,369,980.06) แดงการ์ดชมพู · header = 1,053,211.11

### 2026-07-13 (6) — งบกำไรขาดทุน + งบฐานะ: สัดส่วน Pareto (TOP 80%) แบบนำเสนอ ต่อท้ายงบ
- **เจ้าของขอ:** เห็นสัดส่วนรายได้/ค่าใช้จ่ายชัด ๆ แบบสไลด์นำเสนอ (อ้างภาพ PresentX · TOP 80%)
- **`finParetoBlock(items, accent)`** — sort desc · ไฮไลต์ TOP 80% (cumulative<0.8=แถบสีเข้ม · ที่เหลือ=เทา) · badge "TOP X% · N รายการหลัก" + divider + **ไอคอน (`finItemIcon` match ชื่อ→lucide)** + แถบ + %ของทั้งหมด · CSS `.fin-par-*` grid [ไอคอน|ชื่อ|แถบ|ยอด|%] · ไอคอนสีตามหมวด(top)/เทา(other)
- **P&L** (ต้นสุดของ analytics · หลังตาราง): แหล่งรายได้ (`C.acc.revenue` positive) + สัดส่วนค่าใช้จ่าย (`finExpenseCats` 6 หมวด) · **เอาโดนัท "โครงสร้างค่าใช้จ่าย" + "ค่าใช้จ่ายสูงสุด" ออก (ซ้ำกับ Pareto)** → เหลือ 2 กราฟ (monthly combo + net trend) คู่กัน · ลบ `finChartDonut`
- **Balance:** สัดส่วนสินทรัพย์ (`finBalAssetComp`) + แหล่งเงินทุน (liabeq lines cur>0 = หนี้สิน+ทุนบวก)
- **verify preview:** P&L รายได้ TOP 97% (รายได้จากการขาย 96.9%) · ค่าใช้จ่าย TOP 92% (ค่าโฆษณา 30/เงินเดือน 24/ต้นทุน 19/ค่าธรรมเนียม 19) · Balance สินทรัพย์ TOP 81% · เงินทุน TOP 89% · **กระทบหน้าอื่น = 0**

### 2026-07-13 (5) — งบกำไรขาดทุน: คลิกยอดรวมย่อย → popup แยกรายบัญชี (drill-down)
- **เจ้าของขอ:** ตอนยุบกลุ่ม คลิกยอดในช่องเดือน → เห็นว่าประกอบด้วยบัญชีอะไรบ้าง · คลิกช่องรวม → เห็นทุกเดือน
- **`subP` เพิ่ม param `secKey`** → cells มี `onclick="finDrillPnl(secKey, monthKey|'all')"` + class `.fin-drill` (hover ไฮไลต์) · 6 บรรทัดรวม (รายได้/ต้นทุนขาย/รวมขาย/รวมบริหาร/ขายและบริหาร/ต้นทุนการเงิน) · gross/ebit/net (คำนวณ) ไม่ผูก
- **`finDrillPnl(secKey,periodKey)`:** ใช้ periodized pnl เดียวกับตาราง (month/quarter) · `opex`=selling+admin · gap สินค้าคงเหลือ (subtotal−ผลรวมบัญชีมีรหัส) โชว์เป็นบรรทัด "การเปลี่ยนแปลงสินค้าคงเหลือ" (reconcile ยอด) · periodKey='all'→ตารางบัญชี×ทุกเดือน+รวม · เดือนเดียว→ลิสต์เรียงยอดมาก→น้อย · `finModal`/`finCloseModal`/`finModalKey` (Esc/click-outside · z-index 100000 อยู่บนโหมดนำเสนอ)
- **verify preview:** 42 cells คลิกได้ · COGS ม.ค.=7 บัญชี รวม 365,131.81 (ตรง cell) · admin all=27 บัญชี · **กระทบหน้าอื่น = 0** (subP + fin* ใหม่)

### 2026-07-13 (4) — งบกำไรขาดทุน + งบฐานะ: ขยายฟอนต์ + กรอบสี KPI ล้อ Exec Cash Flow + ตัวเลขวิ่ง
- **เจ้าของขอ:** ตัวอักษรใหญ่/ชัดขึ้น · สีกรอบการ์ดล้อกับหน้า Exec Cash Flow · ตัวเลข count-up ตอนเปลี่ยนหน้า
- **ฟอนต์ใหญ่ขึ้น:** KPI k-val 22→29px · ตาราง P&L 12.5→14px · Balance 13→14.5px · หัวข้อ 16→19px · padding เพิ่ม
- **KPI กรอบสี (accent):** `finKpi` เปลี่ยน param `variant`→`accent` (hex) + `accVal` · `--acc` → `border-top:4px` + ไอคอนสี + badge สี · รายได้/สินทรัพย์=teal · ต้นทุน/หนี้สิน=ส้ม · กำไรขั้นต้น/สุทธิ/ทุน=เขียว(บวก)/แดง(ลบ) (ล้อ in/out ของ Exec)
- **ตัวเลขวิ่ง:** reuse `edAnimMoney(main)` ท้าย `renderToolFinPage` (edFmt==fopFmt) · guard `_finAnimKey=which+company` → วิ่งเฉพาะเข้าหน้า/สลับบริษัท ไม่วิ่งซ้ำตอน toggle · **กระทบหน้าอื่น = 0** (แก้ fin CSS + finKpi + 8 callers)

### 2026-07-13 (3) — ต้นทุนผลิตภัณฑ์: ราคาขายจากยอดขายจริง + %ต้นทุน/%กำไร + hero รวยขึ้น + รูปข้าวเบายอดม่วง
- **เจ้าของขอ:** (1) ราคาขายดึงจากยอดขายล่าสุด (ทะเบียนคำสั่งซื้อ) "ค่าที่ขายมากสุดใช้ค่านั้น" (2) hero ต้นทุนเฉลี่ยจืดไป + เพิ่ม %ต้นทุน/%กำไรต่อการ์ด จากราคาขายล่าสุด (3) ลบกล่องเหลือง (4) เพิ่มรูปข้าวเบายอดม่วง Benya
- **`prodLoadSales`** โหลด `order_ledger.items` (paginate · ข้าม cancelled) → ต่อ SKU เก็บ `{price:qty}` → **qty-weighted mode** (ราคาที่ขายจำนวนชิ้นมากสุด) · `prodEffPrice(p,d)` = กรอกเอง(override) > จากยอดขาย(match `p.sku` upper) > ไม่มี · badge "จากยอดขาย · N ชิ้น"/"กรอกเอง"
- **%ต้นทุน/%กำไร** (`prod-split`): costPct=ต้นทุน/ราคาขาย · profitPct=1−costPct · แถบ ต้นทุน(ส้ม)+กำไร(เขียว) + กำไร ฿/ชิ้น · ไม่มีราคา→placeholder
- **hero รวยขึ้น:** 4 tiles กระจก (จำนวนสินค้า/ต้นทุนเฉลี่ย/ราคาขายเฉลี่ย/มาร์จินเฉลี่ย · จาก effPrice) · ลบ `.prod-noteline` (กล่องเหลือง)
- **รูป benya-5:** ไฟล์ Benya ชีตข้าวเบายอดม่วงไม่มีรูป → เจ้าของแปะรูป (Downloads `196982_*.jpg`) → resize→`product-cost/benya-5.png` · แก้ `"img":null`→path ใน PRODUCT_COST
- **★ ข้อจำกัด:** ราคาจากยอดขายต้อง **SKU ในทะเบียนคำสั่งซื้อ = SKU ในไฟล์ต้นทุน** (M Bark มี 4/6 SKU · **Benya ไม่มี SKU ในไฟล์ต้นทุน → auto-price ไม่ทำงาน ต้องกรอกเอง**) · verify preview: TS1001 180฿ (1,240 ชิ้น) ต้นทุน 46%/กำไร 54% · manual override ได้ · กระทบหน้าอื่น = 0

### 2026-07-13 (2) — งบกำไรขาดทุน + งบแสดงฐานะการเงิน: เพิ่มโหมดนำเสนอ (reuse edTogglePresent)
- **เจ้าของขอ:** เพิ่มโหมดนำเสนอในหน้า P&L + งบฐานะ
- **reuse `edTogglePresent`** (เต็มจอ + `sb-hidden` + ปุ่มออกลอย `#edPresentBar` + Esc + ไฮไลต์ตามเมาส์ · generic ไม่ผูก ed DOM) — ปุ่ม "นำเสนอ" (`.fin-btn-present`) ใน `finHeroHtml` (pnl+balance ที่มีข้อมูล)
- **ขยาย selector ไฮไลต์เมาส์** ใน `edEnterPresent` เพิ่ม `.fin-card, .fin-kpi` (tr/canvas/h1-3 จับได้อยู่แล้ว)
- **CSS ใน `finInjectStyle`:** `body.ed-present` → ซ่อน `.fin-acts` · กระจกฝ้า (`backdrop-filter blur`) ให้ `.fin-kpi/.fin-sheet/.fin-card/.fin-hscore/.fin-hsubs/.fin-insight` · `.fin-hscore` คงพื้นเข้ม
- **verify preview:** ปุ่มโผล่ · กดเข้า→ ed-present + sb-hidden + fin-acts none + kpi backdrop blur + exit bar · กดออกคืนปกติ · **กระทบหน้าอื่น = 0** (แตะ 1 บรรทัดใน edEnterPresent selector · ที่เหลือเพิ่มใน fin)

### 2026-07-13 — งบแสดงฐานะการเงิน: เอาคอลัมน์ปีก่อน (2567) ออก (เจ้าของแจ้งเป็นข้อมูลบริษัทอื่นในไฟล์)
- **เจ้าของเช็คแล้ว:** เลขคอลัมน์ 2567 ในไฟล์เป็นข้อมูลบริษัทอื่นที่ลอกมาผิด → เอาออกจากการแสดงผลทั้งหมด
- **แก้ (display only · parser ยังอ่าน prev ไว้):** (1) `finBalanceHtml` ตารางเหลือคอลัมน์เดียว (curYear · colspan 3→2 · ตัด `cur(l.prev)` + empty acc td) (2) `finRenderBalCharts` ลบกราฟ `finChartBalYoY` (เหลือโดนัทโครงสร้างสินทรัพย์) (3) `finBalAnalyticsHtml` การ์ดอัตราส่วนเต็มความกว้างแทนแถว YoY (4) `finBalInsight` ตัด bullet/summary ที่อ้างปีก่อน (T.taP/T.eqP) → เพิ่ม working capital + equity ติดลบ bullet แทน
- **ถ้าไฟล์แก้ prev-year ถูกต้องแล้วอยากได้ comparison กลับ = ใส่ display กลับ (parser ยังมี prev)** · verify preview: header "2569 (บาท)" เดียว · ไม่มี YoY chart · ratios 5 · insight ไม่มี "ปีก่อน" · **กระทบหน้าอื่น = 0**

### 2026-07-12 — ★ หน้าใหม่: ต้นทุนผลิตภัณฑ์ (prodcost) — การ์ดสินค้า + รูป + ต้นทุนแยกรายการ (การขาย บนสุด)
- **เจ้าของขอ:** อัปไฟล์ "Product Cost" (Benya + M Bark) → การ์ดผลิตภัณฑ์แนวตั้ง: ชื่อ → รูป → ราคาขาย → ต้นทุนแยกตามรายการ · วางบนสุดของกลุ่ม "การขาย"
- **โครงไฟล์:** 1 ชีต = 1 สินค้า (ชื่อ row1 · ขนาด/MOQ row8 · รายการต้นทุน desc+price · Total) + **รูปฝังในชีต** · **★ ไม่มีราคาขายในไฟล์** (มีแต่ต้นทุน)
- **Pre-parse + commit** (client แกะรูปจาก xlsx ไม่ได้): `scratchpad/gen_prodcost.py` (openpyxl `data_only=True` · แกะรูปใหญ่สุด/ชีต → resize 560px → `product-cost/{co}-{n}.png` · categorize รายการ 6 หมวด: วัตถุดิบ/บรรจุภัณฑ์/ค่าแรง/ขนส่ง/VAT/อื่นๆ · match SKU จากชีตสรุป M Bark ด้วย total) → embed `window.PRODUCT_COST` (ก่อน `applyCompanyTheme`) · **รันซ้ำเมื่อได้ไฟล์ใหม่**
- **ราคาขาย = แก้ไขได้ → cloud** (`product_prices` · migration `product-pricing.sql`): คลิกช่องราคาขาย กรอกเอง → upsert → คำนวณกำไร/มาร์จิน (ไฟล์ไม่มีราคา จึงให้กรอก) · `prodLoad`/`prodSavePrice`/`prodCommitPrice` · gate `fopCanWrite`
- **โมดูล `prod*`** (`renderToolProdCost`): การ์ดต่อสินค้า — ชื่อ+SKU chip+ขนาด · รูป (object-fit contain · null→placeholder) · ราคาขาย(แก้ได้)+ต้นทุน/หน่วย · กำไร/มาร์จิน · **แถบสัดส่วนต้นทุน 6 หมวด** + legend · ปุ่มกางดูรายการต้นทุนทั้งหมด · grid `auto-fill minmax(268px)` · CSS `.prod-*` · hero gradient ตามบริษัท
- **ทดสอบ preview:** 11 สินค้า (Benya 5 · M Bark 6) · Tear Stain ต้นทุน 83.11 = ผลรวมหมวด · ราคา 180→มาร์จิน 53.8% · รูปโหลด 200 · benya-5 ไม่มีรูป→placeholder (ชีตนั้นไม่มีรูป) · **กระทบหน้าอื่น = 0**
- **ยังไม่ทำ:** อัปไฟล์ในแอป (ตอนนี้ pre-parse) · ดึงราคาขายอัตโนมัติจาก sku_master

### 2026-07-11 (2) — งบแสดงฐานะการเงิน: แดชบอร์ดวิเคราะห์ใต้ตาราง (โครงสร้าง/YoY/อัตราส่วน/สรุป)
- **เจ้าของขอ:** หน้างบแสดงฐานะการเงินอยากได้วิเคราะห์ด้วย (แบบ P&L)
- **`finBalAnalyticsHtml`+`finRenderBalCharts`** เรียกท้าย `renderToolFinPage` (which==balance+hasData) · reuse CSS `.fin-*` เดิม:
  - **โครงสร้างสินทรัพย์** (โดนัท `finBalAssetComp` — asset lines type=line · top 7 + อื่นๆ) + legend
  - **แหล่งเงินทุน** (`finBalFunding` — หนี้หมุนเวียน/ไม่หมุนเวียน/ส่วนของผู้ถือหุ้น · bar scale ต่อ max · ติดลบ=แดง)
  - **เทียบปีก่อน YoY** (grouped bar `finChartBalYoY` — สินทรัพย์/หนี้สิน/ทุน × 2569 vs 2567)
  - **อัตราส่วนทางการเงิน** (`finBalRatios` — Current Ratio/Working Capital/Debt Ratio/D-E/Equity Ratio · แต่ละตัวคลิกกางดูสูตร+ตัวเลข+ที่มา `finToggleBRatio`·`d.rOpen` · status good/warn/bad)
  - **วิเคราะห์ฐานะการเงิน** (`finBalInsight` — สรุป+bullets+ข้อเสนอแนะ · เน้นส่วนของผู้ถือหุ้นติดลบ/YoY)
- **★ เคสส่วนของผู้ถือหุ้นติดลบ (ทั้ง 2 บริษัท):** D/E โชว์ "ทุนติดลบ · คำนวณไม่ได้" · Equity Ratio ติดลบ = "ขาดทุนเกินทุน" · funding bar ติดลบ=แดง · ทดสอบไฟล์จริง: MBark สภาพคล่อง 1.36 · Benya 2.79 · Benya asset comp ลูกหนี้ 53% · YoY เห็นสินทรัพย์ Benya 66.6M→3.5M · **กระทบหน้าอื่น = 0**
- **Balance ยังไม่มี toggle เดือน/ไตรมาส** (snapshot ณ วันที่ · ต้อง parse TB sheets เพิ่มถ้าจะทำ)

### 2026-07-11 — ★ งบการเงิน: ย้าย Exec Cash Flow เข้ากลุ่ม + P&L toggle เดือน/ไตรมาส + แดชบอร์ดวิเคราะห์ใต้ตาราง
- **เจ้าของขอ (3 อย่าง):** (1) P&L+Balance คลิกดูรายเดือน/รายไตรมาส (2) เปลี่ยนชื่อ "Executive Cash Flow" → "งบกระแสเงินสด" ย้ายเข้ากลุ่ม "งบการเงิน" **บนสุด** (ก่อน กำไรขาดทุน/ฐานะ) (3) ใต้ตาราง P&L เพิ่มกราฟแท่ง รายได้/ค่าใช้จ่าย/กำไร + โครงสร้างค่าใช้จ่าย + วิเคราะห์ธุรกิจ (ตามภาพ mockup)
- **ย้ายเมนู:** `execdash` เปลี่ยน `name:"งบกระแสเงินสด"` + `parent:"finstmt"` วางเป็น child แรกของ group (ก่อน finpnl/finbalance) · icon `banknote` · **render logic ห้ามแตะ = ไม่แตะ** (แค่ย้าย TOOLS entry) · **PRESENT_TOOLS เพิ่ม finstmt/finpnl/finbalance** (กันโหมดพรีเซนต์พังเพราะ execdash กลายเป็น child ใต้ group ที่ present filter ตัดออก)
- **P&L toggle เดือน/ไตรมาส** (`d.pnlPeriod` · `finSetPnlPeriod` · `finQuarterize`): รวม mv รายเดือน→ไตรมาส (Q1=ม.ค.-มี.ค. ฯลฯ) ทั้ง accounts+subs · ปุ่มใน sheet header · KPI/analytics ยังอิงรายเดือนเสมอ · **Balance = snapshot ณ วันที่ (ไม่มี toggle)** — อธิบายเจ้าของว่าเป็น point-in-time + เทียบปีก่อนอยู่แล้ว (ข้อมูลรายเดือนต้อง parse TB sheets เพิ่ม)
- **แดชบอร์ดวิเคราะห์ใต้ตาราง P&L** (`finAnalyticsHtml`+`finRenderPnlCharts` · Chart.js เดิม) เรียกท้าย `renderToolFinPage` (เฉพาะ pnl+hasData):
  - กราฟ **รายได้·ค่าใช้จ่าย·กำไรสุทธิ** (bar×2 + line) · **โดนัทโครงสร้างค่าใช้จ่าย** + legend · **ค่าใช้จ่ายสูงสุด** (bar list) · **แนวโน้มกำไรสุทธิ** (area line) — 3 canvas (`_finCharts`/`finMakeChart`)
  - **จัดหมวดค่าใช้จ่าย** `finExpenseCats` (6 หมวด: ค่าโฆษณา/ต้นทุนขาย/เงินเดือน&บุคลากร/ค่าธรรมเนียม&ขายอื่นๆ/ดอกเบี้ยจ่าย/บริหารอื่นๆ · `finExpCatKey` match ชื่อ · cogs/interest ใช้ยอด authoritative)
  - **คะแนนสุขภาพการเงิน** `finHealth` (gauge 0-100 + 5 มิติ: สภาพคล่อง/ทำกำไร/เติบโต/ประสิทธิภาพ/ความเสี่ยง · `finScoreLinear` map จาก netMargin/currentRatio/growth/opexRatio/debtRatio · ใช้ทั้ง P&L+Balance) · **แต่ละมิติมี `detail`** (metric/formula/inputs/result/bands/src/weight) — คลิกกางดูที่มา (`finToggleHScore` · `d.hOpen` · โชว์ตัวเลขจริง+งบต้นทาง+น้ำหนัก)
  - **CFO Insight** `finInsight` (rule-based · สรุป+bullets+ข้อเสนอแนะ จากตัวเลขจริง)
- **ทดสอบ (preview + seed MBark):** หมวดค่าใช้จ่าย = mockup เป๊ะ (ค่าโฆษณา 30%/เงินเดือน 24%/ต้นทุนขาย 19%...) · health 34 (mockup 33) · ไตรมาส Q1 รวมรายได้ 1,233,253.91 (=ม.ค.+ก.พ.+มี.ค.) · 3 Chart.js instance สร้างครบ · **กระทบหน้าอื่น = 0** (เพิ่ม fin* + ย้าย menu · execdash render เดิม)

### 2026-07-10 (3) — งบกำไรขาดทุน: %ของรายได้บนบรรทัดรวม + คลิกกลุ่มกางรายบัญชี (accordion)
- **เจ้าของขอ:** (1) บรรทัดรวมอยากได้ % (ค่าบริหารคิดเป็นกี่ %ของยอดขาย) (2) กดดูแบบกลุ่มแล้วไม่เห็นรายบัญชี · "รวม" เยอะไป
- **%ของรายได้** (`subP` · `pctOfRev`=total/รายได้รวม): chip ข้างชื่อ + %เล็กใต้ช่องรวมทั้งปี บนบรรทัด ต้นทุนขาย/รวมขาย/รวมบริหาร/ขายและบริหาร/ต้นทุนการเงิน (รวมรายได้ไม่ใส่=100% · gross/net มี margin row อยู่แล้ว)
- **accordion ต่อกลุ่ม:** หัวข้อกลุ่ม (รายได้/ต้นทุนขาย/ค่าใช้จ่ายขายและบริหาร/ต้นทุนการเงิน) คลิกได้ (`finTogglePnlSection` · `d.pnlOpen[key]` · chevron ▸/▾) → กางรายบัญชี+gap เฉพาะกลุ่มนั้น · ปุ่มหัว `finTogglePnlDetail` = กาง/ย่อ**ทุกกลุ่ม** (`finPnlAllOpen`) · default ย่อหมด (สะอาด · เลิกใช้ `d.pnlDetail`)
- **กระทบหน้าอื่น = 0** — เฉพาะ `finPnlHtml`+toggle+CSS (`.fin-sec-click/.fin-chev/.fin-pctlbl/.fin-totpct`) · ทดสอบ preview: chip 34.1% ค่าบริหาร · คลิก opex → 36 บัญชี · ย่อ=15 บรรทัด

### 2026-07-10 (2) — ★ งบการเงิน parser = generic รองรับทุกบริษัท (แก้ให้อัป Benya ได้)
- **เจ้าของถาม:** อัปงบเบญญา (`.xls`) ได้เลยไหม ข้อมูลตรงกับเอ็มบาร์คทุกช่องไหม → **ตรวจแล้วไม่ตรง** ต้องแก้ parser ก่อน
- **ปัญหาที่เจอ (เทียบไฟล์จริง 2 บริษัท):** (1) **balance parser เดิม hardcode โครงเอ็มบาร์ค** (line names + attach index) → เบญญ่ามีรายการต่าง (เงินลงทุนชั่วคราว/เงินให้กู้ยืมระยะสั้น/สินทรัพย์ไม่มีตัวตน/เงินฝากค้ำประกัน/หนี้สินตามสัญญาเช่า/ประมาณการหนี้สินพนักงาน) → โชว์ผิด (2) **P&L COGS ขาด 174,066** เพราะเบญญามีบรรทัดสินค้าคงเหลือ (สินค้าสำเร็จรูป-ต้นงวด/ปลายงวด) **ไม่มีรหัสบัญชี** → parser ข้าม
- **แก้ P&L:** เลิก recompute subtotal จากรายบัญชีอย่างเดียว → **อ่าน "ยอดรวมย่อยที่พิมพ์ไว้" ในชีตตรง ๆ** (`finParsePnl` subs: รวมรายได้/ต้นทุนขาย/ขั้นต้น/รวมขาย/รวมบริหาร/ขายและบริหาร/ก่อนต้นทุนการเงิน/สุทธิ · match ด้วยชื่อ) เป็น authoritative (รวมปรับปรุงสินค้าคงเหลือให้แล้ว) · `finPnlCompute` ใช้ subs ก่อน fallback รายบัญชี · `fin = EBIT − net` (identity) · **gap line** "การเปลี่ยนแปลงสินค้าคงเหลือ" ในโหมดรายบัญชี = subtotal − ผลรวมบัญชีมีรหัส (ให้ detail กระทบยอด) · **★ SheetJS จัด subtotal ตรงคอลัมน์เดือน (ไม่ shift)** — อ่านที่ `mcActive` index ได้เลย
- **แก้ Balance = generic** (`finParseBalance` เขียนใหม่ + `finBalDetGroups`): สร้างจากโครง "ชีตสรุป" เอง — จำแนก type จากชื่อ (group `สินทรัพย์`/`หนี้สินและส่วนฯ` · total `รวมสินทรัพย์/รวมหนี้สิน/...` · subtotal `รวม*` · line=มีเลข · subheader=ไม่มีเลข) · แนบบัญชีย่อยจาก detail ด้วย **name-match** (exact/contains) · **★ อ่าน cur/prev ตามคอลัมน์ปี (จับจากแถวหัว 2569/2567)** ไม่ใช่ลำดับตัวเลข — กันเคส cur ว่างแต่ prev มีค่า (เช่น เงินฝากค้ำประกัน 139,500 = ปีก่อน) ไปโผล่ช่อง cur
- **ทดสอบ 2 ไฟล์จริง (browser + ground-truth ชีตสรุป):** Benya net **(5,810,983.16)** · COGS 918,316.22 (gap 174,066) · สินทรัพย์ 3,486,424.68 = หนี้สิน+ทุน · โครง 16+20 บรรทัดตามจริง · MBark ยังเป๊ะ (net (900,420.02) · gap 0 · ไม่ regression)
- **หมายเหตุ:** รองรับ `.xls` เก่า (SheetJS อ่านได้) · ชื่อชีต detect ด้วย `indexOf` (มี trailing space ก็ผ่าน) · seed ในข้อ (1) ข้างล่างยังใช้ได้ (โครง shape เดิม + subs เพิ่ม optional)

### 2026-07-10 — ★ งบการเงินทางบัญชี (P&L + งบแสดงฐานะการเงิน) — เมนูใหม่ใต้ Cash Flow Forecast
- **เจ้าของขอ:** เพิ่มหน้างบกำไรขาดทุน + งบแสดงฐานะการเงิน (จากไฟล์ "งบการเงิน เอ็มบาร์ค เดือน1-6.xlsx") ไว้ใต้ Cash Flow Forecast
- **nav-group `finstmt` "งบการเงิน"** (stage ภาพรวม · หลัง cashflow) มี 2 เมนูย่อย: `finpnl` (งบกำไรขาดทุน) + `finbalance` (งบแสดงฐานะการเงิน) · helper prefix **`fin*`** (ก่อน `renderToolCashflowForecast`)
- **Upload-based + cloud** (เหมือน Executive Dashboard): อัปไฟล์งบการเงิน xlsx → `finParse(wb)` → เก็บ `financial_statements` (upsert `company_id,kind`) · `finLoad` cloud-first · **seed MBark ใน `window.FIN_SEED`** (insert ก่อน `applyCompanyTheme` · ~15KB) โชว์ทันทีถ้า cloud ว่าง (company='mbark') · `finSaveCloud`/`finHandleFile`/`finUpload` (เฉพาะ `fopCanWrite`)
- **Parser** (`finParsePnl`/`finParseBalance`/`finParse`): detect ชีตด้วยชื่อ (กำไร→P&L รายเดือน · ฐานะ+รวม→งบแสดงฯ summary YoY · ฐานะ→detail รายบัญชี) · **P&L**: track section จาก marker row (รายได้/ต้นทุนขายสุทธิ/ค่าใช้จ่ายในการขาย/บริหาร/ก่อนต้นทุนทางการเงิน) → เก็บ**รายบัญชี** (code+mv รายเดือน+total) · subtotal ทั้งหมด**คำนวณจากรายบัญชีตอน render** (`finPnlCompute` — รวมรายได้/ต้นทุนขาย/กำไรขั้นต้น/ขาย/บริหาร/opex/EBIT/ดอกเบี้ย/สุทธิ + margin) · **Balance**: ใช้ summary เป็นโครง (YoY 2569 vs 2567) + แนบบัญชีย่อยจาก detail
- **★ gotcha SheetJS (แก้แล้ว):** (1) `cellDates` แปลง serial คลาด ~4 วิ (`2026-01-01`→`Dec 31 2025 23:59:56`) → เดือนเพี้ยน -1 · แก้ด้วย `finCellYM` snap เป็นเที่ยงคืน local ที่ใกล้สุด (2) SheetJS **ตัดคอลัมน์ว่างซ้ายทิ้ง** → index เลื่อนจาก openpyxl · summary parse ต้อง **scan** (name=text แรก · cur/prev=ตัวเลข 2 ตัวแรก) ไม่ hardcode index · P&L ใช้ month column ที่ detect จาก header Date (dynamic อยู่แล้ว)
- **UI** (สไตล์ mockup Water POG · CSS scoped `.fin-*`): hero gradient ตามบริษัท + watermark โลโก้ · KPI 4 ใบ (P&L: รายได้/ต้นทุน/กำไรขั้นต้น+margin/สุทธิ+net margin · Balance: สินทรัพย์/หนี้สิน/ส่วนของผู้ถือหุ้น/เงินสด) · ตัวเลขติดลบ `()` แดง (`fopFmt`) · ตาราง P&L รายเดือน + toggle "แสดงรายบัญชี" (`finTogglePnlDetail`) · ตาราง Balance คลิกบรรทัดดูบัญชีย่อย (`finToggleBLine`) · ปุ่ม "พิมพ์/PDF" เปิดหน้าต่างใหม่ (`finPrint`)
- **ทดสอบ (preview + parser roundtrip):** P&L net = **(900,420.02)** เป๊ะ · Balance สินทรัพย์ = หนี้สิน+ทุน = **1,053,211.11** · `finParse(ไฟล์จริง)` = seed ทุกบัญชี (54 บัญชี · 6 เดือน ม.ค.–มิ.ย.) · **กระทบหน้าอื่น = 0** (โค้ด+ตาราง+migration ใหม่ล้วน)
- **หมายเหตุ:** MBark seed อยู่ใน client (โชว์ก่อน) — อัปไฟล์ทับ = บันทึกขึ้น cloud (ทับ seed) · Benya ยังไม่มีข้อมูล (อัปไฟล์เอง) · migration `financial-statements.sql` สร้างตารางเปล่า (ไม่ seed ผ่าน SQL)
### 2026-07-09 — ★ หน้าใหม่: Document Center (docs) — คลังเอกสาร PDF บน Supabase Storage
- **เจ้าของขอ:** อยากเริ่มใช้ Document Center เก็บ PDF (STM · เมมโม่ · รายงานอนุมัติจ่าย · สัญญา) · ไม่อยากให้ไฟล์หาย → เก็บ + สำรอง
- **สถาปัตยกรรม (ตัดสินใจร่วมกับเจ้าของ):** ไฟล์จริงเก็บใน **Supabase Storage** (ไม่ยัดลง DB · ไม่ต่อ Google Drive สดเพราะไม่มี backend) · meta เก็บตาราง `documents` · ตาข่ายสำรอง = มิเรอร์เข้า backup ทุกคืน + ปุ่ม ZIP โหลดเข้า Drive เอง
- **Migration `supabase/documents.sql`** (idempotent): ตาราง `documents`(company_id/title/category/file_name/**storage_path**/mime_type/size_bytes/doc_date/note/uploaded_by/soft-delete · RLS ปิด) + `INSERT storage.buckets 'documents'` (private · limit 50MB) + **storage policies** `p_docs_read/insert/update/delete` ให้ role `authenticated` บน bucket 'documents' (storage.objects RLS ปิดไม่ได้ ต้องมี policy)
- **โมดูล `doc*`** (`renderToolDocs` · dispatch `t.id==="docs"` · tool `soon`→`live`): อัปหลายไฟล์ (modal เลือกหมวด/วันที่/หมายเหตุ) · **storage key = ASCII ล้วน** `{CODE}/{ปี}/{stamp}.{ext}` (ชื่อจริงเก็บ file_name/title — กัน URL ภาษาไทยพังตอน mirror) · เปิด/โหลดผ่าน `createSignedUrl(path,3600,{download})` · ลบ = soft-delete + `storage.remove` · ค้นหา + chip หมวด · KPI จำนวน/พื้นที่ · audit ผ่าน `docAudit`
- **6 หมวด** (`DOC_CATS`): STM/เมมโม่/อนุมัติจ่าย/สัญญา/ใบกำกับ/อื่นๆ
- **ปุ่ม "ดาวน์โหลดทั้งหมด (ZIP)"** (`docDownloadAllZip`): fetch ทุกไฟล์ตามตัวกรอง → **JSZip** (เพิ่ม CDN ใน head) จัดโฟลเดอร์ตามหมวด → โหลด zip (redundancy เข้า Google Drive เอง)
- **มิเรอร์อัตโนมัติเข้า backup** (`.github/workflows/backup.yml` เพิ่ม step): list ชื่อไฟล์จาก `storage.objects` ผ่าน psql (`SUPABASE_DB_URL`) → curl ดาวน์โหลดแต่ละไฟล์ด้วย **`SUPABASE_SERVICE_KEY`** (secret ใหม่ · ⚠️ **ต้องเพิ่มเอง** ที่ Settings→API→service_role) → tar+gzip+AES → `backups/docs_{DATE}.tar.gz.enc` · **skip เงียบถ้าไม่มี secret** (meta ยังอยู่ใน SQL/CSV) · prune เก็บ 30 ไฟล์ล่าสุด
- **เพิ่ม `documents` ใน `BKP_TABLES`** (หน้า Backup/Restore สำรอง meta ด้วย)
- **กระทบหน้าอื่น = 0** — โมดูล+ตาราง+bucket ใหม่ล้วน · syntax OK · unit test (fmtSize/filter/search/code/safeName) + render sim ผ่าน
- **ข้อจำกัด/ยังไม่ทำ:** Storage ฟรี 1GB (เตือนใกล้เต็มได้ภายหลัง) · storage policy ยังกว้าง (authenticated ทุกคนเห็นทุกบริษัท — app กรอง company_id ที่ query · ถ้าต้องเข้มค่อยทำ path-based RLS) · service key mirror ต้องรอเจ้าของเพิ่ม secret

### 2026-07-09 — ซ่อนกลุ่ม "ลูกหนี้ (AR)" (ar/armap/settle) — ซ้ำกับระบบงานขาย
- **เจ้าของขอ:** 3 หน้าใน AR (AR Outstanding · Map ลูกหนี้→เงินเข้า · จับยอด Settlement) ซ้ำกับ "ระบบงานขาย" → เอาออก/ซ่อน
- **วิธี:** เติม `hidden:true` บน tool `ar`/`armap`/`settle` + guard บรรทัดแรกใน `appToolVisible` (`if(t.hidden) return false`) → หายจาก sidebar + home quick modules + home task cards (ผ่าน `appToolVisible`) · `renderTool()` guard เดิม (บรรทัด 1024-1030) เด้ง `state.tool` ที่ hidden → หน้าแรกที่เห็น
- **function ยังอยู่ครบ** (`renderToolAr`/`renderToolArmap` + dispatch) — เปิดคืนได้แค่ลบ `hidden:true`
- **repoint demo task cards** ใน `renderToolHome`: `tool:"ar"`→`sales_income` · `tool:"settle"`→`sales_recon` (กันคลิกแล้วเด้ง)
- **กระทบหน้าอื่น = 0** — flag + 1 guard line · syntax OK

### 2026-07-09 — จัดการผู้ใช้: ปุ่ม "รีเซ็ตรหัส" ต่อผู้ใช้ (admin ตั้งรหัสใหม่ให้)
- **เจ้าของขอ:** ต้องมีปุ่มกดรีเซ็ตรหัสในตารางผู้ใช้ (เหมือนระบบตัวอย่าง Water POG)
- **`usrResetPwd(uid)`** (หลัง `usrGenPwd`) — gate admin · หา email จาก `state.users.list` · `prompt` รหัสใหม่ (default = `usrGenPwd()` สุ่ม 14 ตัว · แก้เองได้ · บังคับ ≥6 ตัว) → **PUT `SUPABASE_URL/auth/v1/admin/users/{uid}` `{password}`** (service_role key ผ่าน `usrSrKey()` เหมือน `usrToggleBan`) → `usrAuditLog("reset_password", email)` → alert โชว์รหัสใหม่ให้คัดลอกไปแจ้งผู้ใช้
- **ปุ่ม "รีเซ็ตรหัส"** (สีน้ำเงิน) ในแถว action ตารางผู้ใช้ ระหว่าง "แก้ไข" กับปุ่ม ban · `onclick="usrResetPwd('${u.id}')"`
- **กระทบหน้าอื่น = 0** — ฟังก์ชัน+ปุ่มใหม่ · reuse `usrGenPwd`/`usrSrKey`/`usrAuditLog` (audit ผ่าน policy `p_audit_insert` ที่เพิ่มไว้แล้ว) · syntax OK · boot 0 non-env errors

### 2026-07-08 — จัดการผู้ใช้: สถานะออนไลน์ (heartbeat) + บังคับออกจากระบบ (kick) + audit
- **เจ้าของขอ:** อยากได้ online presence + force logout เหมือนระบบตัวอย่าง + ลง audit
- **Migration `supabase/user-presence.sql`** (idempotent · RLS ปิด): ตาราง `user_presence(user_id PK, email, display_name, role, last_seen, current_tool, kick_at)` + **policy `p_audit_insert`** ให้ client บันทึก audit ได้ (เดิม audit_log_v2 มีแค่ SELECT policy)
- **heartbeat (`presence*`):** `presenceStart()` เรียกท้าย `renderApp` (guard `_prsTimer`) → upsert `user_presence` ทุก 60 วิ + ตอน focus · `state._sessionStart` = เวลา login · `presenceBeat` เช็ค `kick_at > sessionStart` → signOut+reload · `authSignOut` เรียก `presenceStop`+`presenceLeave` (ลบ row)
- **force logout:** `usrKick(id)` (set `kick_at=now` ต่อคน) · `usrKickAll()` (`.neq(user_id, me)`) — client เด้งออกภายใน ~1 นาที · ปุ่ม "⏻ บังคับออกทุกคน" บนหัว + ✕ บน chip ออนไลน์ · `usrAuditLog` insert audit_log_v2 (action UPDATE · table 'auth' · changed_fields ['force_logout'])
- **UI:** panel "🟢 กำลังออนไลน์ (N คน)" chips (เขียว<5นาที/เทา + relative time `usrAgo`) · `usrLoadPresence` โหลดใน `usrLoadAll`
- **กระทบหน้าอื่น = 0** — heartbeat try/catch (เงียบถ้ายังไม่ deploy) · presence เขียนโดยทุก user ที่ login · syntax OK · boot 0 non-env errors

### 2026-07-08 — จัดการผู้ใช้: redesign (KPI ตาม role + filter tab + ค้นหา + Excel)
- **`renderToolUsers` รื้อเฉพาะ render block** (handlers `usrOpenAdd`/`usrOpenEdit`/`usrToggleBan`/`usrConfirmDelete`/`usrClearKey` ไม่แตะ) — KPI การ์ดต่อ role (นับจาก app_metadata.role · สีต่อ role) · filter tab (ทั้งหมด+role ที่มี) · ค้นหา อีเมล/ชื่อ · badge role สี · ปุ่ม Excel (`usrExportXlsx`)/พิมพ์ · `usrSetFilter` · state `users.filter/q`
- **กระทบหน้าอื่น = 0** — service_role gate + modal + ban/delete เดิมทำงานเหมือนเดิม · syntax OK · boot 0 non-env errors

### 2026-07-08 — หน้าใหม่: สำรอง/กู้คืนข้อมูล (backup) + Audit Log (audit) — กลุ่มตั้งค่า (admin only)
- **เจ้าของขอ:** อยากได้หน้า backup/restore แบบแอปอื่น + ปรับ Audit/Users ให้สวย
- **`backup` (ใหม่ · `bkp*` · `renderToolBackup`):** ดาวน์โหลดทุกตาราง (`BKP_TABLES` ~30 ตาราง · paginate) เป็น JSON ไฟล์เดียว · กู้คืน = อ่าน JSON → **upsert ตาม id** (ไม่ลบของเดิม · chunk 200) · banner เตือน · log สถานะ
- **`audit` (soon→live · `aud*` · `renderToolAudit`):** ดึง `audit_log_v2` (occurred_at/user_email/table_name/row_id/action/changed_fields) · KPI (ทั้งหมด/แก้ไข/เพิ่ม/ลบ) · filter tab + dropdown ตาราง + ค้นหา + limit (200–2000) · export Excel
- dispatch เพิ่มที่ `renderTool()` · tool ทั้งคู่ `adminOnly` · **กระทบหน้าอื่น = 0** — โมดูลใหม่ล้วน · syntax OK · boot 0 non-env errors (fns defined)

### 2026-07-08 — ทะเบียนคุมเงินสดย่อย (Petty Cash) — แทนหน้า Task Management
- **เจ้าของขอ:** เปลี่ยนหน้า `tasks` (Task Management · placeholder "กำลังพัฒนา") เป็น **ทะเบียนคุมเงินสดย่อย** (มีไฟล์ STM ตัวอย่าง 2 ชีต Benya/M Bark)
- **Migration `supabase/petty-cash.sql`** (idempotent · RLS ปิด): `petty_cash`(company_id,round_label,doc_date,pay_date,doc_no,requester,description,amount_in,amount_out,reimburse_round,note,seq,soft-delete) + `petty_cash_rounds`(company_id,round_label,opening_balance · unique) เก็บยอดยกมาต้นรอบ
- **โมดูล `pc*`** (`renderToolPettyCash` · dispatch ที่ `t.id==="tasks"` · tool เปลี่ยนชื่อ+status live): เลือกรอบ (chip · YYYY-MM) · ยอดยกมา · ตารางเบิกจ่าย/เติมเงิน + **ยอดคงเหลือวิ่ง** (`pcCompute` sort pay_date→seq) · เพิ่ม/แก้/ลบ (Supabase) · KPI (ยกมา/รับ/จ่าย/คงเหลือ)
- **นำเข้า Excel** (`pcImport`): auto เลือกชีตตามบริษัท (regex เบญญา/บาร์ค · fallback index) · หา header "วันที่ตรวจเอกสาร" · แปลง Excel serial→ISO (`pcExcelDate` · 46177→2026-06-04) · เอาเฉพาะ HP…(จ่าย)/RR…(รับ) · ยอด = คอลัมน์ที่มีค่า · **ส่งออก** xlsx ฟอร์แมตทะเบียน
- **กระทบหน้าอื่น = 0** — โมดูลใหม่ล้วน (CSS `.pc-*`) · **unit test:** running balance (1000−107+3000=3893) · pcExcelDate serial/ISO/พ.ศ. · render sim ผ่าน · syntax OK · boot 0 non-env errors
- **ยังไม่ทำ:** ผูก "เบิกคืนเข้ารอบ" อัตโนมัติ · แนบใบเสร็จ · approval · import ของแถวสรุป/top-up ที่ไฟล์ตัวอย่างกรอกไม่สม่ำเสมอ (เลือก HP/RR เท่านั้น)

### 2026-07-08 — Sales Dashboard: SKU master เก็บบน Supabase (ทุกคนเห็นชุดเดียวกัน) + รูปจาก repo
- **เจ้าของขอ:** อยากให้ทุกคนเห็นสต็อกชุดเดียวกัน (เดิม localStorage ต่อเครื่อง) + รูปสินค้าไม่ขึ้น
- **Migration `supabase/sku-master.sql`** (idempotent · RLS ปิด): ตาราง `sku_master(company_id,sku,name,brand,category,cost,price,stock,image_url,...)` + unique `(company_id,sku)`
- **`sdashUploadSku`** อัป xlsx → **upsert ขึ้น Supabase** (chunk 500 · onConflict company_id,sku) + cache localStorage · **`sdashSyncSku(co)`** โหลดจาก DB ครั้งเดียวต่อบริษัท (fallback cache) · `renderToolDashboard` เรียก sync แล้ว re-render
- **รูปสินค้า:** commit 69 รูปเข้า repo **`sku_images/{SKU}.jpeg`** · `sdashImgTag(sku,url)` = ลอง repo (same-origin ชัวร์) → fallback Image URL → ซ่อน · แก้อาการรูปไม่ขึ้น + ยอด 0 (skuMap ว่างเพราะยังไม่ sync)
- **กระทบหน้าอื่น = 0** — เพิ่ม state `state.sdashSku` (cache) · **verify:** imgTag repo+fallback+hide · render sim (ชื่อจริง/ยอด≠0/repo path) · syntax OK · boot 0 non-env errors

### 2026-07-08 — ★ Sales Dashboard รื้อใหม่ (วิเคราะห์ยอดขาย + สินค้าคงเหลือ ใน 1 หน้า · แทนของเดิม)
- **เจ้าของขอ:** แดชบอร์ดพรีเซนต์ — เดือนที่เลือกขายช่องทางไหนกี่บาท · สินค้าตัวไหนของแต่ละช่องทางขายดี · รายงานสินค้าคงเหลือ · กราฟล้ำๆ ดูง่าย เน้นวิเคราะห์ · มีรูปสินค้า · แทน Seller Dashboard เดิม
- **ดีไซน์:** ทำจาก Claude Design handoff (`for-design` ref) · ฟอนต์ **Noto Sans Thai** (เพิ่มใน `<head>` · weight 400–900 · ตัวเลข/หัวข้อ 800–900 หนาเด่น) · theme light/dark ต่อบริษัท (Benya teal · M Bark navy)
- **`renderToolDashboard` เขียนใหม่ทั้งหมด** (เดิม `dashLoad`/`state.dash` = dead) · helper prefix **`sdash*`** · `state.sdash={mode,month}`
- **ข้อมูล:** ยอดขาย/ช่องทาง/สินค้าขายดี = `order_ledger` (ผ่าน `ordGet()`/`ordLoad`) · สต็อก/ทุน/ราคา/รูป = **อัปไฟล์ SKU Merchant (BigSeller) client-side** → เก็บ localStorage `sdash-sku-{co}` (`sdashUploadSku` parse xlsx: match header เลข SKU/ชื่อ/หมวด/ต้นทุน/ราคาขาย/สต็อก/Image URL) · รูปดึงจาก Image URL ในไฟล์
- **section:** Header (เลือกเดือน+สลับบริษัท+โหมด+อัปสินค้า+พิมพ์) · KPI 5 ใบ (ยอดขาย/ออเดอร์/เฉลี่ย/กำไรขั้นต้น/มูลค่าสต็อก · sparkline + MoM) · โดนัทช่องทาง + แยกแบรนด์ · แท่งเทียบเดือนก่อน · การ์ดสินค้าขายดีต่อช่องทาง (Top 3 + รูป) · ตารางสินค้าคงเหลือ (เสี่ยงขาด/ควรเติม/ค้างสต็อก · พอขาย = สต็อก÷ขายเฉลี่ย/วัน) · Insight วิเคราะห์
- **channel = `ordChannelDetail`** (shopee/tiktok/lazada/face/line/dealer/csr) · การ์ดขายดีโชว์ 5 ช่อง (SP/TT/LZ/FACE/Dealer)
- **graceful ไม่มีไฟล์ SKU:** KPI ยอดขาย/ออเดอร์/เฉลี่ย + โดนัท + MoM + สินค้าขายดี ยังทำงานจาก order_ledger · กำไร/มูลค่าสต็อก/คงเหลือ = ปุ่ม "อัปไฟล์สินค้า"
- **กระทบหน้าอื่น = 0** — CSS scoped `.sdash` · **unit test:** total/orders/profit/stockValue/donut/top/inventory ถูก · render simulation (fake DOM) ผ่าน · boot 0 non-env errors
- **ยังไม่ทำ:** เก็บ SKU master ลง Supabase (ตอนนี้อัปไฟล์ client-side) · sparkline มูลค่าสต็อกเป็น snapshot (ไม่มี history)

### 2026-07-08 — ส่งออก IV: รหัสลูกค้าขายตรง = FACE/LINE/Dealer (อะไรที่ไม่ใช่ marketplace/FB/LMS = Dealer)
- **เจ้าของขอ:** ออเดอร์ที่ไม่ใช่ Shopee/TikTok/Lazada/FACE/LINE → รหัสลูกค้า = "Dealer" (เดิม MANUAL ที่ไม่ใช่ FB/LMS ขึ้น "— ว่าง —")
- **`ivrBuildExportAoA`:** ขายตรง (channel ว่าง) → `directCust = {face:FACE, line:LINE, dealer:Dealer, csr:CSR}[ordChannelDetail(o)] || 'Dealer'` (ใช้การจัดกลุ่มเดียวกับบอร์ด/register) · Benya = directCust · M Bark = `customer||directCust` · marketplace เดิมไม่เปลี่ยน (Benya ช่องทาง×แบรนด์ · M Bark ช่องทาง)
- **ผล:** พรีวิว "รหัสลูกค้าว่าง N บรรทัด" เหลือเฉพาะ Benya marketplace ที่เดาแบรนด์ไม่ออก (ตรงกับ panel SKU→brand) · ขายตรงไม่ว่างแล้ว
- **กระทบหน้าอื่น = 0** — เลิกใช้ `isManual`(FB|OD) หันมา `ordChannelDetail` (FB→FACE/LMS→LINE/อื่น→Dealer) · **unit test:** BY→Dealer · FB→FACE · LMS→LINE · SP Betra→SHOPEE BE · MBark direct มีชื่อ→ชื่อ · ไม่มี→Dealer

### 2026-07-08 — ส่งออก IV: เติมรหัสลูกค้าว่าง (Benya) ด้วยแบรนด์ตาม SKU — จำครั้งเดียว
- **เจ้าของขอ:** รหัสลูกค้าว่างเต็มไปหมด (Benya marketplace ที่เดาแบรนด์ BT/QI ไม่ออกจากชื่อสินค้า เช่น SKU `SDO101`) — อยากได้ที่แก้ง่ายๆ
- **`incBrandOf` รื้อลำดับความแม่น:** (1) **ชื่อร้าน** `bsBrandFromShop(shop)` (betra→BT/qi→QI · ถ้าเก็บ `shop` ไว้) (2) **map ผู้ใช้กำหนดตาม SKU prefix** (localStorage `inc-sku-brand-{co}`) (3) เดาจากข้อความ+SKU (SBR/STR/BTR=Betra) · helper ใหม่ `incSkuPrefix`/`incSkuBrandMap`/`incSetSkuBrand`/`incOrderSkus`
- **UI แก้ง่ายในแท็บ "ส่งออก IV"** (Benya เท่านั้น): panel รวม SKU prefix ที่ยังเดาแบรนด์ไม่ออก (จาก eligible marketplace) → ปุ่ม **Betra (BE) / Qi (QI)** ต่อ prefix · กดครั้งเดียว → เติม "รหัสลูกค้า" (SHOPEE BE/QI) ให้ทุกออเดอร์ SKU กลุ่มนั้นทันที (พรีวิว+ไฟล์) · โชว์ mapping ที่ตั้งไว้ + ปุ่มลบ (✕)
- **กระทบหน้าอื่น:** `incBrandOf` ใช้ร่วม RE export ด้วย → IV↔RE แบรนด์ตรงกัน (ดีขึ้นทั้งคู่) · signature เดิม · **unit test:** shop betra→BT · SDO ไม่รู้→ว่าง · map SDO→QI แล้ว SDO101/SDO999→QI · ลบ map→ว่าง

### 2026-07-08 — ส่งออก IV: พรีวิว = เนื้อไฟล์ CSV จริง (helper `ivrBuildExportAoA` ใช้ร่วม)
- **เจ้าของขอ:** พรีวิวในหน้าส่งออกไม่โชว์ "รหัสลูกค้า" (อ่าน `o.customer` ว่าง) ต้องโหลดไฟล์มาเช็ค — ส่งออก 9 รอบยังไม่ได้คีย์ · อยากให้พรีวิว = ไฟล์จริงที่จะดาวน์โหลด ตรวจครบไหมได้เลย
- **ต้นเหตุ:** พรีวิว (`ivrRenderExport`) กับไฟล์จริง (`ivrDoExport`) สร้างแยกกัน → รหัสลูกค้า/วันที่ พ.ศ./SKU ไม่ตรงกัน
- **แก้ = helper กลาง `ivrBuildExportAoA(orders, startIv)`** — สร้าง AoA (header + รายบรรทัด item) ครบ 16 คอลัมน์ · `ivrDoExport` เรียกใช้แทน inline (ลบโค้ดซ้ำ ~45 บรรทัด) · **พรีวิว render AoA เดียวกันเป๊ะ** (ทุกคอลัมน์: เลข IV/วันที่ 01/07/69/ช่องทาง/**รหัสลูกค้า**/SKU/จำนวน/ราคา/ส่วนลด/ค่าส่ง/หมายเหตุ)
- **UX พรีวิว:** ไฮไลต์คอลัมน์ "รหัสลูกค้า" (เขียว) · ว่าง = แดง "— ว่าง —" · banner นับ "รหัสลูกค้าว่าง N บรรทัด" / "เดาแบรนด์ BT/QI ไม่ออก N" หรือ "✓ ครบทุกบรรทัด" · โชว์สูงสุด 150 บรรทัด · scroll แนวนอน
- **กระทบหน้าอื่น = 0** — `ivrDoExport` ผลลัพธ์เท่าเดิม (unit test: MBark shopee→SHOPEE, Benya Betra→SHOPEE BE, date→01/07/69, IV รันต่อเนื่อง, brand ว่าง→note) · shared ทั้ง sales_orders + (bigseller dead)

### 2026-07-08 — ยุบ "บันทึกขายเชื่อ (IV)" (bigseller) เข้า "ระบบงานขาย · 1. คำสั่งซื้อ" (sales_orders)
- **เจ้าของขอ:** หน้า "ส่งออก IV + ตรวจการคีย์ 141.RWT" ซ้ำกัน 2 ที่ (sales_orders กับ bigseller) → เก็บ **1. คำสั่งซื้อ (sales_orders)** ที่เดียว
- **ลบ TOOLS entry `bigseller` ออกจาก sidebar** · redirect ใน `renderTool()`: `state.tool` = expressmatch/exportkey/**bigseller** → `sales_orders` (เดิม 2 ตัวแรก redirect ไป bigseller) · `renderToolBigSeller` ยังอยู่ในไฟล์ (dead · เปิดคืนได้)
- **อัป nav links** ที่ชี้ tool เก่า → sales_orders: home task card (`tool:"bigseller"`) · ปุ่ม "ไปหน้าส่งออกคีย์ AutoKey" (`setTool('exportkey')`→`sales_orders`)
- **guard เดิมใน `renderToolOrders`** (`state.tool==='bigseller'`→renderToolBigSeller) เป็น dead แต่ไม่เสียหาย (redirect จับก่อน) · **กระทบหน้าอื่น = 0** — sales_orders มีครบ ทะเบียน+ส่งออก+ตรวจ (reuse `ivrRenderExport`/`ordRenderIv`)

### 2026-07-08 — ส่งออก IV: รหัสลูกค้า M Bark = ช่องทาง + วันที่ DD/MM/YY (พ.ศ.)
- **เจ้าของจับได้:** ไฟล์ส่งออก AutoKey IV ของ M Bark คอลัมน์ "รหัสลูกค้า" ยังว่าง (fix ก่อนหน้าใช้ `o.customer` ซึ่ง marketplace ว่าง) + วันที่เป็น ISO `2026-07-01` ทั้งที่ต้องเป็น `01/07/69` (DD/MM/YY ปีพุทธ)
- **`ivrDoExport` รหัสลูกค้า M Bark** — M Bark แบรนด์เดียว (mommam) → marketplace ใช้ **ช่องทาง** (SHOPEE/TIKTOK/LAZADA = `platLabel`) · ขายตรง = `o.customer||FACE` · ตรงกับที่ `mbarkBankDownByCust`/`mbarkCheckCode` parse (SHOPEE→SH ฯลฯ) · Benya ยังเป็น channel×brand เหมือนเดิม
- **วันที่ = `fmtDateDDMMYYBE(o.order_date)`** (helper ใหม่ · `(ปี+543)%100` → 2026=69) → คอลัมน์วันที่ขายเป็น `01/07/69` · เพิ่ม col 3 ใน `forceTextCells` (xlsx) กัน Excel แปลง
- **กระทบหน้าอื่น = 0** — แก้ใน `ivrDoExport` (shared bigseller+sales_orders) · **unit test:** date 2026-07-01→01/07/69, 2025→68 · M Bark shopee→SHOPEE · offline→customer

### 2026-07-08 — Register "ออเดอร์ที่แมพแล้ว": แยกชิปขายตรง FACE/LINE/Dealer/CSR (เลิกกรุ๊ป "หน้าร้าน/อื่น")
- **เจ้าของขอ:** ชิปช่องทางในแท็บ register กรุ๊ปขายตรงรวมเป็น "หน้าร้าน/อื่น 35" — อยากให้แยกแบบหน้าแรก (board): FACE/LINE/Dealer/CSR แยกชิป
- **`ordRenderRegister`:** `detOf(o)= isMp?channel_group:ordChannelDetail(o)` → chip filter/count ใช้ detOf (marketplace=channel_group · ขายตรง=face/line/dealer/csr) · ชิปใหม่ 8 อัน (all/shopee/tiktok/lazada/face/line/dealer/csr) · sub-label "(ขายตรง — ไม่ต้องกระทบยอด)" เมื่อเลือกช่องขายตรง
- **`ordPlatLogo`** เพิ่ม key face/line/dealer/csr (สี board + โลโก้จริงจาก `logo platfrom/` · csr = badge ตัว C ม่วง)
- **`ordFiltered`** fCh รองรับ sub-channel ด้วย (`mpCh?channel_group:ordChannelDetail`) → ปุ่มส่งออก "ยังไม่คีย์ IV" กรองตามช่องขายตรงได้ถูก
- **กระทบหน้าอื่น = 0** — `ordPlatGo`/`ordReconGoReg` ยังตั้ง fCh เป็น marketplace key/all เหมือนเดิม · **unit test:** FACE29/CSR6/Dealer1/LINE1 · shopee matched1 (diff ซ่อน)

### 2026-07-08 — ส่งออก IV: รหัสลูกค้า Benya = ช่องทาง×แบรนด์ (BT/QI) + CSR ไม่ยื่นภาษีขาย
- **เจ้าของจับได้ 2 จุดในไฟล์ส่งออก AutoKey IV:** (1) คอลัมน์ "รหัสลูกค้า" ของ SHOPEE/TIKTOK ว่างเปล่า — Benya ต้องแยกช่องทาง×แบรนด์ (Betra=BE / Qi=QI) (2) ออเดอร์ CSR (แจก/เคลม/ตัวอย่าง) โผล่มามียอดให้ยื่นภาษีขาย ทั้งที่ปกติต้องยอด 0
- **`ivrDoExport` รหัสลูกค้า** — เดิม `isManual?'FACE':''` (marketplace ว่างเสมอ) → เปลี่ยนเป็น **mirror RE export (`incReCandidates`):** `custCodeBenya(channel,brand)` = `{SP:SHOPEE,TT:TIKTOK,LZ:LAZADA}` × `{BT:BE,QI:QI}` → "SHOPEE BE"/"TIKTOK QI"/... · brand จาก `incBrandOf(o)` (products) · fallback ขายตรง=FACE · M Bark=`o.customer` · คอลัมน์หมายเหตุเตือน "⚠ เดาแบรนด์ BT/QI ไม่ออก" เมื่อ marketplace แต่ brand ว่าง
- **CSR = ไม่ยื่นภาษีขาย** — `ordChannelDetail` เพิ่มจับ **prefix "CSR"** (ไม่ใช่แค่ยอด 0) · `ivrCanExport` block CSR (non-marketplace + `ordChannelDetail==='csr'`) → reason "CSR (แจก/เคลม/ตัวอย่าง) · ไม่ยื่นภาษีขาย" · หลุดจาก eligible/KPI ready อัตโนมัติ
- **กระทบหน้าอื่น = 0** — `custCodeBenya` reuse สูตรเดียวกับ RE (IV↔RE รหัสตรงกัน) · `ordChannelDetail` เพิ่มเงื่อนไข CSR เดิม (face/line/dealer ไม่เปลี่ยน) · **unit test:** custCode SP/BT→"SHOPEE BE" · CSR prefix→csr · CSR export blocked · FACE export ok · SP matched ok/diff blocked

### 2026-07-08 — Orders: แก้ "แมท 100% หลอก" + ช่องที่ยังไม่อัปหลังบ้านหายจากรายงาน (unrecon)
- **อาการ:** Lazada มี 1 ออเดอร์ใน BigSeller แต่ยังไม่อัปรายงานหลังบ้าน Lazada → `ordRunRecon` scope เฉพาะช่องที่อัป → Lazada ไม่เคยเข้า recon results → (1) hero โชว์ "อัตราแมท 100%" (คิดจากเฉพาะที่ตรวจ SP+TT) (2) ผลต่าง Lazada = 0 (3) ใบกระทบยอดไม่มี Lazada
- **helper กลาง** `ordUnreconBs(d)` — ออเดอร์ marketplace (SP/TT/LZ) active ในช่วง ที่ `order_id` ไม่อยู่ใน recon results = "ยังไม่ตรวจ" · `ordMatchStats(d)` — `rate = matched / (matched+only_be+only_bs+diff+unrecon)` → 100% เฉพาะตรวจครบจริง · **unit test:** เคสจริง SP155+TT59 matched + LZ1 unrecon → matched 214/denom 215 = 99.53%
- **board:** `M[ch].unrecon`/`unreconSum` (นับจาก `ordUnreconBs`) · `diffN` รวม unrecon → ผลต่าง Lazada = 1 · cell amount รวม unreconSum
- **detail/export:** `ordBoardDetailRows` เพิ่มแถว `_type:'unrecon'` · typeMeta/chip "ยังไม่ตรวจ" (ฟ้า #0284c7) · cntType/cntCh นับ unrecon · det บอก "ยังไม่อัปรายงานหลังบ้าน <ช่อง>" · `ordBoardExportXlsx` ได้ unrecon อัตโนมัติ
- **hero:** `mrate = ordMatchStats(d).rate` (เดิมนับจาก reconRes อย่างเดียว = 100% หลอก)
- **ใบกระทบยอด** (`ordReconGenReports`): concat `ordUnreconBs` เป็น `only_bs` (มีใน BigSeller · ไม่พบแพลตฟอร์ม) เข้า res → Lazada โผล่ในรายงาน · reuse category เดิม ไม่แก้ layout
- **กระทบหน้าอื่น = 0** — helper+display layer ล้วน · ไม่แตะ `ordRunRecon`/recon ที่ save แล้ว · **แนะนำ user:** อัปรายงานหลังบ้าน Lazada เพื่อกระทบยอดจริง (unrecon = ตัวเตือนว่ายังไม่อัป)
- **(ตามมา) ตารางผลต่างอ่านง่ายขึ้น** — det ของ `_type:'diff'` เดิมโชว์แค่ "ฐานภาษีขาย: 670 vs 680" (ไม่รู้ฝั่งไหน/ต่างตรงไหน) → เปลี่ยนเป็น "คีย์ขาย (BigSeller) X ↔ หลังบ้าน Y · ต่าง ±Δ" + **`ordDiffBreakdown(bs,be)`** แยก ยอดสินค้า/ส่วนลดร้าน(voucher vs discount)/ค่าส่ง 2 ฝั่ง ไฮไลต์ม่วง "◀ ต่าง" จุดที่ไม่ตรง + บรรทัด SKU/จำนวนถ้าต่าง · **unit test:** shopee 670/680 → ไฮไลต์ ส่วนลดร้าน 20≠10

### 2026-07-07 — Orders board: เลือก "ดูเฉพาะเดือน" (กัน report ปนเดือนก่อน)
- **เจ้าของขอ:** เริ่มใช้จริงเดือน 7 → หน้าทะเบียนต้องเลือกเดือนได้ · "ทั้งหมด" ปนเดือน 6 ที่ผ่านมาแล้ว ไม่ควรเอามาออก report
- **`ordRangeBounds` รองรับ `"m:YYYY-MM"`** → from=วันที่ 1, to=สิ้นเดือน (เต็มเดือน · `new Date(y,m,0)` หาวันสุดท้าย) · **unit test:** ก.ค.→01-31, ก.พ.→28
- **`ordMonthsAvailable(d)`** (distinct YYYY-MM จาก order_date active + recon date · ใหม่→เก่า) · **`ordMonthLabel`** (ไทย+พ.ศ. เช่น "ก.ค. 2569") · **`ordSetMonth(ym)`** ตั้ง `d.dateRange='m:'+ym`
- **UI:** `<select>` "เลือกเดือน…" ในกล่องช่วงวันที่ (แท็บ board · โชว์เมื่อมีข้อมูล) — ไฮไลต์สีแบรนด์เมื่อเลือกเดือน · chip all/today/7d/month เดิมยังอยู่
- **ทุก downstream respect อัตโนมัติ** (ใช้ `d.dateRange` ผ่าน `ordRangeBounds`): board matrix/KPI (`ordRenderBoard` inRange) · detail rows/export (`ordBoardDetailRows`) · **เพิ่ม filter เดือนใน `ordReconExport` (ใบส่งกลับฝ่ายขาย)** ให้ไม่ปนเดือนอื่น
- **กระทบหน้าอื่น = 0** — เพิ่ม case ใน `ordRangeBounds` (ค่าเดิม all/today/7d/month ไม่เปลี่ยน) + helper/UI ใหม่
- **(ตามมา) default ช่วงวันที่ = "เดือนนี้"** — `ordGet()` init `dateRange:"month"` (เดิม fallback 'all') · เจ้าของขอให้เปิดหน้ามาเห็นเฉพาะเดือนปัจจุบัน (เริ่มใช้รายเดือน)
- **(ตามมา) badge/register/export respect ช่วงที่เลือกด้วย** — เดิม `ordKpis` totN + `ordRenderRegister` + `ordFiltered` นับ/โชว์ทั้ง `d.rows` (badge "ออเดอร์ที่แมพแล้ว" ค้าง 1241 แม้ดูเดือนเดียว) · helper กลาง **`ordDateFilter(d)`** (จาก `ordRangeBounds(d.dateRange)`) ใช้ร่วมทั้ง 3 จุด + onlyBe count · **unit test:** ก.ค. totN=2 · มิ.ย.=1 (ตัดยกเลิก) · ทั้งหมด=3

### 2026-07-05 — ★ 3. กระเป๋าเงิน (sales_wallet): จับกลุ่มถอน = ออเดอร์ − ค่าธรรมเนียมในกระเป๋า
- **เจ้าของขอ:** จับคู่ยอดที่เข้ากระเป๋า (ออเดอร์วันที่ 1-7) กับการถอน (วันที่ 8) · แต่ละยอดถอนประกอบด้วยออเดอร์กี่ใบ + ค่าธรรมเนียมที่หัก**ในกระเป๋า** (ค่าโฆษณา ฯลฯ ที่ไม่ได้หักตอนออเดอร์) · บางค่าธรรมเนียมออเดอร์อาจถูกยกเลิก → รายงานต้องบอกด้วย
- **เปิด `sales_wallet` `soon`→`live`** · `renderToolSalesWallet` เดิมเป็น placeholder → เขียนจริง · **reuse `bmpParseShopeeBalance`** (Shopee Balance/Transaction report · stream txn: รายรับจากคำสั่งซื้อ/การถอนเงิน/รายการปรับปรุง)
- **`walGroupWithdrawals(txns, ordByOrder)`** — buffer txn ตั้งแต่ถอนครั้งก่อน → เจอ "การถอนเงิน" ปิดกลุ่ม · กลุ่ม = ออเดอร์ (Σnet) + ค่าธรรมเนียม (Σ ติดลบ) ≈ ยอดถอน · `diff = Σorders+Σfees − withdraw` (ยกไป/ขาด) · flag ออเดอร์ยกเลิกในกลุ่ม (`ordByOrder[order_id].status==='cancelled'`) · leftover = `pending` (ยังไม่ถอน) · **unit test:** 3 ออเดอร์ 11,000 − ค่าโฆษณา 1,000 = ถอน 10,000 diff 0 · byCat ถูก · cancelledN ถูก
- **`walAdjCat(tx)`** จัดหมวดค่าธรรมเนียมในกระเป๋า (ค่าโฆษณา/คืนเงิน/ภาษี/ค่าธรรมเนียม/ชดเชย/อื่นๆ) จาก desc+type
- **UI:** hero + KPI (กลุ่มถอน/ยอดถอนรวม/ค่าธรรมเนียมในกระเป๋า/ออเดอร์) + **การ์ดต่อยอดถอน** (`walGroupCardHtml`: "N ออเดอร์ = X − ค่าธรรมเนียม Y = Z" + chip หมวด + badge ✓ตรง/ยกไป-ขาด + ⚠ยกเลิก + กางดูรายการออเดอร์/ค่าธรรมเนียม) + การ์ด pending · `walExport` xlsx 2 sheet (สรุปกลุ่ม + รายละเอียด)
- **กระทบหน้าอื่น = 0** — โมดูลใหม่ (`wal*` + `state.wallet[co]`) · reuse `bmpParseShopeeBalance`/`ordLoad`/`salesFmt`

### 2026-07-05 — ★ กระเป๋าเงิน "ครบวง": BQ ต่อกลุ่มถอน + จับกับสเตทเมนต์แบงค์ + tag กลับ order_ledger
- **เจ้าของขอ:** เชื่อมกระเป๋าเงิน → BQ → เข้าแบงค์ ให้ครบวง (timeline ออเดอร์ติดด่านสุดท้าย)
- **BQ ต่อกลุ่มถอน** — `walNextBq(seqByDay, iso)` = `YYMMDD+seq` (รันต่อในไฟล์) · ใส่ `g.bq` ใน `walGroupWithdrawals` · **unit test:** 2607080001/2
- **จับกับแบงค์** — `walLoadBank` โหลด `brec_bank_rows` (deposit>0 · company_id uuid · best-effort) → `walMatchBank(d,g)` จับ deposit ยอดตรง (±0.5) วันตรง→เผื่อ 3 วัน (`walAddDays` via cffISO) · badge "🏦 เข้าแบงค์ <วัน>" / "ยังไม่พบในสเตทเมนต์" · note รวม matchedN/N · **unit test:** พบในกรอบ / นอกกรอบ / ไม่มีสเตทเมนต์
- **tag กลับ order_ledger** — `walTagBank` map กลุ่ม→`{orders,bq_number,withdraw_date}` แล้วเรียก **`ordTagBankFromWithdrawals(state.company, wds)`** (reuse · เขียน `bq_no/deposit_date/bank_in_date/bank_matched` เฉพาะออเดอร์ที่ยังไม่มี bq_no) → timeline ออเดอร์ติดด่าน "เงินเข้าแบงค์"
- **การ์ด/Export** เพิ่ม BQ chip + สถานะแบงค์ · `walExport` s1 เพิ่มคอลัมน์ BQ + เข้าแบงค์(วันที่)
- **กระทบหน้าอื่น = 0** — reuse `ordTagBankFromWithdrawals` (path เขียน bank เดิม) · `walMatchBank` mirror `bmpMatchBank` · **ยังไม่ทำ:** persist กลุ่มถอนลง DB (ตาราง `brec_mp_withdrawals` มีอยู่แต่ผูกกับ bmp) · TikTok/Lazada wallet · account routing (ตอนนี้ bank_account_no=null ตอน tag)

### 2026-07-05 — ★ รับชำระ: แท็บใหม่ "รายงานค่าธรรมเนียม" (รายเดือน · แยกหมวด) — ให้บัญชีบันทึกล้าง
- **เจ้าของขอ:** การเงินรับชำระ IV 150 เงินเข้า 100 → ตั้ง "ค่าธรรมเนียมจ่ายล่วงหน้า 50" · สิ้นเดือนบัญชีต้องดึงรายงานรวมค่าธรรมเนียมทั้งเดือน **แยกหมวด** ไปบันทึกล้างเข้าบัญชีค่าใช้จ่ายจริงตามใบกำกับแพลตฟอร์ม
- **design ที่ตกลง:** เก็บ**ที่เดียว** (`sales_income_rows` มี `channel_group` อยู่แล้ว · fee ต่างแพลตฟอร์มถูกดูดด้วย `fee_breakdown` jsonb + `incFeeCategory`→7 หมวด) · อิง**วันเงินเข้า (`paid_date`)** · กระทบใบกำกับแพลตฟอร์ม = เฟสหน้า
- **แท็บใหม่ `fees`** ใน `renderToolSalesIncome` (subtab list/export/verify/**fees**) — **ไม่ต้อง migration** (ดึงจากข้อมูลที่มี):
  - `incFeeReportData(d)` — กรอง incRows ตามเดือน(paid_date)+แพลตฟอร์ม → aggregate `byCatPlat`/`catTotals`/`platTotals`/`grand` ผ่าน `incRowFeeCats` · join `order_ledger` เอา `iv_no` · **unit test:** grand/หมวด/byPlatform/join IV/filter ถูกครบ
  - `incRenderFeeReport` — เลือกเดือน(dropdown จาก `incFeeReportMonths`)+ชิปแพลตฟอร์ม · **ตาราง ① สรุป 7 หมวด × แพลตฟอร์ม** (บัญชีบันทึก) + **ตาราง ② รายละเอียดต่อออเดอร์** (order/IV/วันเงินเข้า/ฐานภาษี/สุทธิ/ค่าธรรมเนียมจ่ายล่วงหน้า/แยกหมวด)
  - `incFeeExport` — xlsx 2 sheet (สรุปหมวด + รายละเอียด) · auto-load incRows เมื่อเข้าแท็บ fees
- **ค่าธรรมเนียมจ่ายล่วงหน้า/ออเดอร์ = `fee_total` = ฐานภาษี − เงินเข้าสุทธิ** (มีในตารางอยู่แล้ว)
- **กระทบหน้าอื่น = 0** — subtab + ฟังก์ชันใหม่ล้วน · reuse `incRowFeeCats`/`incFeeCategory`/`INC_FEE_CATS`/`incTaxBaseOf`

### 2026-07-05 — ★ ตรวจ RE: วงจร Batch (mirror IV) — ส่งออก RE → ตรวจกลับด้วย 1.9.1 ว่าคีย์ครบไหม
- **เจ้าของขอ:** ส่งออก RE ต้องมีวงจรตรวจเหมือน IV (ดึงรายงานกลับมาเทียบครบไหม) · แก้หน้ารับชำระเดิมได้เลย (ไม่ต้องมีหน้าใหม่)
- **Migration `supabase/re_export_batches.sql`** (idempotent · RLS ปิด · mirror `iv_export_batches`): ตาราง `re_export_batches` (batch_no/date_from-to/channels/start_re/end_re/order_count/order_ids jsonb/exported_email + verify_status/verified_at/verified_email/verify_result) + unique `(company_id,batch_no)` + index exported_at
- **Engine (`inc*` ก่อน `incRenderVerify`) — gated ด้วย `d.reBatchId`:**
  - `incCreateReBatch(company, ready)` — `incExportRE` เรียกหลังส่งออก (fire-and-forget) · batch_no `RE-{CO}-YYYYMMDD-NNN` (query max seq) · order_ids = ready.map(orderNo) · start/end_re จาก `armapRunRE(seed,0/len-1)` · alert batch_no
  - `incReBatchCoverage(d)` — join batch.order_ids กับ `d.verify.rows` ผ่าน iv_no/order_ref→order → `{expectedN,keyedN,missing[],extra[]}` · **unit test:** ส่ง 3 เจอ 2 → missing=[O3] · extra แยก "นอก batch"(เจอออเดอร์) vs "ไม่พบออเดอร์"(ไม่มีในทะเบียน)
  - `incReSaveBatchVerify` — update `re_export_batches` verify_status/verify_result · `incReBatchBannerHtml` การ์ด coverage · `incLoadReBatches`/`incEnsureReBatches`/`incSetReBatch`
- **UI (`incRenderVerify`):** `<select>` "ตรวจเทียบใบส่งออก" ใน action bar + banner หลัง kpiHtml · gated (ไม่มี/ไม่เลือก batch = ตรวจทั้งทะเบียนเหมือนเดิม) · tag-back เดิม (`incVerifyTagAll` เขียน re_no) ไม่แตะ
- **กระทบหน้าอื่น = 0** — ฟังก์ชันใหม่ล้วน + gated · `incExportRE` เพิ่มแค่ 1 บรรทัดท้าย (สร้าง batch)

### 2026-07-05 — ★ ตรวจ IV: ผูก "วงจร Batch" — ตรวจการคีย์เทียบใบส่งออก (ไม่ใช่ทั้งทะเบียน) + เก็บผลลง DB
- **เจ้าของขอ (workflow):** แก้อาการหน้าตรวจ IV "refresh แล้วเด้งให้อัปใหม่/สะสมมั่ว มองไม่ออกว่าครบจากอะไร" · ครบต้องวัดจาก **ใบส่งออก (batch)** — ส่งไป 120 ต้องคีย์กลับ 120 · เรียก 141.RWT เกิน (150) → ตรวจแค่ 120 อีก 30 = "นอกสโคป"
- **Migration `supabase/iv_export_batches_verify.sql`** (idempotent · guard table exists · sort หลัง `iv_export_batches.sql` เพราะ '.'<'_'): `ALTER TABLE iv_export_batches ADD COLUMN IF NOT EXISTS verify_status/verified_at/verified_email/verify_result(jsonb)` + NOTIFY pgrst
- **Engine (`ordIv*` ก่อน `ordRenderIv`) — ทั้งหมด gated ด้วย `d.ivCheck.batchId` (ไม่เลือก batch = พฤติกรรมเดิมเป๊ะ):**
  - `ordIvEnsureBatches` โหลด `d.ivrec.batches` (reuse `ivrLoadBatches`) แบบ idempotent — guard `d._ivBatchesLoading` + เช็ค array กันลูป (ivrLoadBatches set เป็น [] เสมอแม้ error)
  - `ordIvBatchCoverage(d)` — join batch.order_ids (order_id หลังบ้าน · เก็บตอน export) กับ `ic.results` ผ่าน `orderRowId→d.rows→order_id` → คืน `{expectedN, keyedN, missing[], extra[]}` · orphan/voided/นอก batch = extra · **verified ด้วย unit test:** ส่ง 3 เจอ 2 → missing=[O3], extra=[orphan, นอก batch]
  - `ordIvSaveBatchVerify` — update `iv_export_batches` (`verify_status` = verified ถ้า missing=0 ไม่งั้น partial · `verify_result` jsonb เก็บ missing/extra) → refresh batches + flash
  - `ordIvBatchBannerHtml` — การ์ด coverage (ส่งออก/พบใน 141.RWT/ยังไม่คีย์/นอกสโคป) + list เลขที่ขาด/เกิน + ปุ่ม "บันทึกผลตรวจ batch นี้" + badge สถานะ
- **UI (`ordRenderIv`):** เพิ่ม `<select>` "ตรวจเทียบใบส่งออก" ใน action bar (โชว์เมื่อมี batch) + banner หลัง coverageWarn · ทั้งคู่ hidden/no-op ถ้าไม่มี/ไม่เลือก batch
- **tag-back = ของเดิม** (`ordIvApply('tagSelected')` เขียน iv_no/iv_date/sale_amount กลับ order_ledger) — batch cycle แค่ track ครบ/ขาด/เกิน + persist สถานะ ไม่แตะ path เขียนกลับ
- **กระทบหน้าอื่น = 0** — `ordRenderIv` shared กับ BigSeller (`ivrRenderVerify`) · ทุกฟังก์ชันใหม่ + gated · `renderToolOrders()` มี guard redirect ตาม state.tool อยู่แล้ว

### 2026-07-05 — Orders เสิร์ช "เห็นครบ": join เงินเข้าจริง (sales_income_rows) เข้า timeline
- **เจ้าของขอ:** เสิร์ชออเดอร์แล้วเห็นทุกด้านในที่เดียว — BigSeller↔แพลตฟอร์ม (เน็ตต้องตรง · มีอยู่แล้วใน `ordReconDetailHtml`) + **เงินเข้าสุทธิกี่บาท เข้าวันไหน ค่าใช้จ่ายเท่าไหร่** + เลข IV/RE
- **`ordEnsureIncome`/`ordLoadIncomeMap`** (lazy · idempotent · `d.incomeByOid` Map by order_id · แบ่งหน้า `.range()`): โหลด `sales_income_rows` (`net_received/paid_date/fee_total/tax_base/gross/seller_discount/buyer_shipping`) ต่อบริษัท (`fopCompanyId` uuid · `deleted_at` null) — guard กันยิงซ้ำเหมือน `ordIvEnsureBatches`
- **`ordTimeline(o, inc)`** เพิ่ม param `inc` (optional · เรียกที่เดียวใน `ordRenderSearch`) — step "รับชำระ" → "รับชำระ / เงินเข้ากระเป๋า" โชว์ทั้ง RE (เอกสาร) + `💰 เงินเข้าสุทธิ X เข้า <วัน> · ค่าใช้จ่าย Y · ฐานภาษี Z` (จาก income) · `on` เปิดเมื่อมี re_no **หรือ** income
- **`ordRenderSearch`** เรียก `ordEnsureIncome()` + ส่ง `incMap.get(order_id)` เข้า timeline · เน็ตต้องตรงดูจาก `ordReconDetailHtml` เดิม
- **กระทบหน้าอื่น = 0** — `ordTimeline` param optional (caller อื่นไม่มี) · loader ใหม่ล้วน · verify: timeline โชว์ income ถูก / ไม่มี income → "ยังไม่รับชำระ"

### 2026-07-05 — Orders recon: "ใบส่งกลับฝ่ายขาย" (แทนปุ่ม export "คีย์ไม่ครบ" ดิบ)
- **เจ้าของขอ (workflow):** เวลา recon เจอไม่ตรง ให้ส่งกลับฝ่ายขายเป็นเอกสารที่อ่านง่ายว่า "ออเดอร์วันไหนบ้างไม่ตรง · ต้องแก้อะไร · นัดตรวจซ้ำวันไหน" — ไม่ใช่ใบกระทบยอดเทคนิค (เซลงง)
- **`ordReconExport` รื้อใหม่** (ปุ่ม "ใบส่งกลับฝ่ายขาย" ในแท็บ recon · เดิมชื่อ "ส่งออก คีย์ไม่ครบ" export only_be ดิบ): ใช้ `ordReconEffStatus` คำนวณสถานะสด แล้วแยก xlsx เป็น **3 หมวด** — ① ยังไม่คีย์ (`only_be`) ② ยอดไม่ตรง (`diff` · โชว์ยอดหลังบ้าน/ยอดที่คีย์/ผลต่าง/จุดที่ต่างจาก `ordReconDiffs`) ③ ต้องเช็คซ้ำ (`only_bs`) · หัวเอกสารมี วันที่ตรวจ + ช่วงข้อมูล + **นัดตรวจซ้ำ** (`prompt` default พรุ่งนี้ via `cffISO`) · ยอดใช้ `ordTaxBase(o,'be'/'bs')` ให้ตรงสูตร recon
- **cancelled = handled อยู่แล้ว** (ยืนยัน · ไม่แก้): `ordRunRecon` ข้าม `be.status==='cancelled'` (l.20241) + `ordReconUpload` กรอง cancelled ออกก่อน recon (l.20265) → ใบยกเลิกไม่เคยกลายเป็น only_be หลอก
- **กระทบหน้าอื่น = 0** — แก้เฉพาะ leaf function `ordReconExport` + label ปุ่ม · ไม่มี migration · reuse helper เดิมล้วน
- **ยังไม่ทำ (คุยไว้):** วงจร batch ตรวจการคีย์ — ผูก `iv_export_batches` เข้าหน้าตรวจ IV (141.RWT เทียบ batch ที่ส่งออก ไม่ใช่ทั้งทะเบียน) + persist ผลตรวจลง DB (แก้อาการ refresh แล้ว state หาย/สะสมมั่ว)

### 2026-07-04 — ★ Bank Recon: auto-match "กลุ่มยอดรวม" (same-date equal-sum N:M) — แตกยอด/รวมยอด COD
- **เจ้าของขอ:** ให้ auto-match จับเคสที่ **วันเดียวกัน ยอดรวมเท่ากัน แต่แตกเป็นหลายรายการ** (เดิม 1:1 จับไม่ได้ ต้องกดจับเอง): (1) **1 Express = หลาย Bank** (ลูกค้าโอนแตกหลายครั้ง เช่น 390 = 290+100) · (2) **หลาย Express = 1 Bank** (aggregator รวมยอด เช่น FLASH PAY COD: 450+900 = 1,350)
- **Tier 3 อัลกอริทึม** (`brec*` หลัง `brecAutoMatch`): `brecAutoMatchGroups(ex,bk,existingPairs)` — วนต่อวัน×ทิศทาง(sign) · anchor 1 ฝั่ง หา subset อีกฝั่งที่ผลรวมตรง (`brecSubsetsToTarget` DFS ขนาด 2..4 · cents integer กัน float) · **เสนอเฉพาะที่จับได้ทางเดียว (unique)** — กำกวม(หลาย subset)/ข้ามวัน = ข้าม ให้จับเอง · `brecCents`/`MAXPOOL=18`/`MAXK=4`
- **เก็บเป็น group match:** `brecGroupInserts` สร้าง brec_matches (cartesian ex×bk) ผูก `match_group_id` · status `suggested` confidence `group` (reuse schema เดิมที่ `brecManualLink` ใช้)
- **ผูกเข้า auto-match ทั้ง 2 จุด:** `brecRunAutoMatch` (ปุ่ม ⚡) + `brecTryAutoMatch` (silent ตอนโหลด) — insert คู่ 1:1 + กลุ่ม พร้อมกัน · นับ `proposed.length + groups.length`
- **UI แท็บ "รอยืนยัน":** `brecSplitPending` แยกกลุ่ม(match_group_id)/เดี่ยว · กลุ่มโชว์เป็น**การ์ด** (`brecGroupCardHTML` · `.brec-group`/`.bg-*`) — Express stack ซ้าย ↔ Bank stack ขวา + ยอดรวม + ✓ตรง + ปุ่ม "ยืนยันกลุ่ม"/"นำออก" (`brecConfirmGroup`/`brecUnmatchGroup` update by match_group_id) · คู่เดี่ยวยังเป็นตารางเดิม · กลุ่มไม่ผ่าน row-filter (กันยอดรวมเพี้ยน)
- **คงกฎเดิม:** strict same-date (ยืนยันแล้ว cross-date ไม่จับ · [[feedback_bankrec_date_strict]]) · `brecConfirmAllPending` ยืนยันกลุ่มพร้อมกันได้ (ทุก row เป็น pending)
- **ทดสอบ:** 4 เคสจากภาพจริงจับครบ (390=290+100 · 661.27=283.79+377.48 · 450+900=1350 · 4360+315=4675) · แถวโดดเดี่ยวไม่จับ · ความกำกวม(3ทาง)ข้าม · ถอนเงินแตกยอดได้ · ข้ามวันไม่จับ · **กระทบหน้าอื่น = 0**

### 2026-07-04 — ★ Bank Recon แท็บใหม่ "🏷️ จัดหมวด (AI)" — เดาหมวดเงินรับ-จ่ายอัตโนมัติ (self-learning)
- **เป้าหมาย (เจ้าของขอ):** อัปงบกระทบยอด (Express XML) ดิบ ๆ → ระบบเดา "หมวดเงินรับ-เงินจ่าย" ให้เอง (อ้างอิง 40 หมวดตายตัวจากไฟล์ "รายละเอียดเงินรับเงินจ่าย" · **ห้ามสร้างหมวดใหม่**) → มีให้รีวิว/แก้ก่อนกดยืนยัน → รอบถัดไปฉลาดขึ้น (จำประโยค+ผู้ขาย)
- **ค้นพบ:** ไฟล์ "รายละเอียดเงินรับเงินจ่าย" = งบกระทบยอด layout เดียวกันเป๊ะ + เติม 2 คอลัมน์ (col8 `หมวดเงินรับ-เงินจ่าย` · col9 `ประเภทกิจกรรมทางการเงิน`) — ตรงกับที่ `edParse` (Executive Dashboard) อ่านอยู่แล้ว
- **พิสูจน์ความแม่น (train 2025 → test 2026 held-out):** รวม 74% · กลุ่มมั่นใจสูง (exact/keyword/vendor≥0.8) = **94%** · exact-phrase = 100% · ~45% flag รีวิว (ลดลงเร็วเมื่อยืนยันสะสม)
- **สมองตั้งต้น** (idempotent · seed ON CONFLICT DO NOTHING · ปิด RLS): `supabase/catbot-rules-00-schema.sql` = ตาราง `catbot_rules(company_id,dir,match_type['exact'|'vendor'],pattern,category,activity,weight,source)` + unique `(company_id,dir,match_type,pattern,category)` (non-partial → ON CONFLICT infer ได้) · **seed 857 rules** (616 exact + 241 vendor) แยก `catbot-rules-01..07-seed.sql` (~40KB/ไฟล์ · **แยกเป็นชิ้นกัน payload เกินลิมิต Supabase Management API** — ไฟล์เดียว 248KB เสี่ยง fail · schema sort ก่อน seed) · เรียนจากไฟล์จริง Benya 1,580 รายการ 2 ปี · company via `(SELECT id FROM companies WHERE code='BENYA')`
- **Engine (`catbot*` ใน index.html ก่อน `renderToolBankRec`):**
  - `catbotNorm` (ตัด "ด.05/69"+วันที่ · **ต้องตรงกับ normalize ใน seed SQL เป๊ะ**) · `catbotVendor` (ส่วนหลัง `/`)
  - `catbotKeyword(remark,dir)` — กฎคำสำคัญเฉพาะทาง 13 กฎ (โอนระหว่างบัญชี/ค่าธรรมเนียม/ภาษี/ปกส/กยศ/ดอกเบี้ย/เน็ต/IT/อินฟลู/เช่า/เงินเดือน/สดย่อย/ช่องทางรายรับ SP-TT-LZ-Dealer) · **transfer ต้องมี token ธนาคาร** กัน "รับเงินโอนจาก-Lazada" หลุดไป transfer
  - `catbotPredict` ลำดับ: exact memory (0.99) → keyword → vendor memory (share) → none · `catbotTier` = ok(มั่นใจ)/review/none
  - `catbotLoadModel` โหลด rules ต่อบริษัท (แบ่งหน้า cap 1000) → `{exact,vendor,cid}` map
- **UI:** แท็บ `autocat` ในหน้า bankrec (ทำงานได้แม้ยังไม่มี bank_accounts — guard `if(tab==='autocat')` ก่อน noAcct) · อัปหลายไฟล์/หลายบัญชีพร้อมกัน · ตารางรีวิว: วันที่·ทิศทาง·ยอด·หมายเหตุ·**dropdown 40 หมวด**·badge มั่นใจ/ควรตรวจ/เดาไม่ได้ · chip filter (ทั้งหมด/มั่นใจ/ต้องรีวิว) · CSS prefix `.cb-*`
- **ยืนยัน (`catbotConfirm`) ทำ 3 อย่าง:** (1) `catbotLearn` upsert exact+vendor rules (weight = ของเดิม+จำนวนรอบนี้ · source='user' · อัป model ในหน่วยความจำด้วย) (2) `catbotExportExcel` — ส่งออก xlsx format "รายละเอียดเงินรับเงินจ่าย" (sheet=YYYY.MM · reuse `catbotBuildBook`) (3) `catbotPushExec` — `edSyncFromCloud()` (กันเดือนอื่นหาย) → `edParse(catbotBuildBook())` → `edMergeData` → `edSave`+`edSaveCloud`
- **reuse ล้วน:** `brecParseExpressXml` (parser) · `edParse`/`edMergeData`/`edSaveCloud`/`edCompanyId` (Exec Dashboard ingest — ไม่แตะ render logic) · **กระทบหน้าอื่น = 0** (เพิ่มแท็บ+ฟังก์ชันใหม่ล้วน)
- **gotcha:** normalize ใน JS (`catbotNorm`) กับ Python seed generator ต้องเหมือนกัน (regex ตัด ด.MM/YY + dd/mm/yy) · MBark ยังไม่มี seed (เรียนจาก 0) — หมวดอาจต่างจาก Benya · ยืนยันไฟล์เดิมซ้ำ = exec merge แทนที่ month key (ไม่ double) แต่ weight เพิ่ม (ไม่กระทบ share มาก)

### 2026-07-03 — ★ Bank Recon: แก้บั๊กข้อมูลหาย — รายการซ้ำจริง (740 เข้า 2 ยอดวันเดียว) ถูกลบทุก push
- **อาการ:** เงินเข้ายอดเท่ากันวันเดียวกัน 2 รายการจริง (คนละคนโอน · sender อยู่ใน `description` ไม่อยู่ใน stable key) → นำเข้าครบตอนแรก แต่หายไป 1 ยอด
- **ต้นเหตุ (ร้ายแรง):** `supabase/bankrec-phase-a-stable-key.sql` มี DO block cleanup ที่ soft-delete แถว stable-key ซ้ำ (rn>1) **โดยไม่ยกเว้น `ambiguous`** — migrate workflow รัน SQL ทุกไฟล์**ทุก push** → cleanup รันซ้ำทุกครั้ง → ลบ 1 ใน 2 รายการ ambiguous ที่ถูกต้องทิ้ง (unique index ยกเว้น ambiguous แต่ cleanup ไม่ยกเว้น)
- **แก้ 1 (หยุดลบ):** เพิ่ม `AND ambiguous = false` ใน ranked CTE ทั้ง 4 จุดของ cleanup (ex/bk × migrate-match/soft-delete) → cleanup แตะเฉพาะ non-ambiguous (ตรงกับเงื่อนไข unique index)
- **แก้ 2 (คืนที่หาย + กัน re-upload ซ้ำ):** `brecUpload` เปลี่ยน dedup ของ ambiguous เป็น **นับจำนวน** — query active rows ทั้งหมด (รวม ambiguous) นับต่อ key (`dbCountByKey`) → insert เฉพาะส่วนขาด `need = fileCount − dbActiveCount` (เดิม insert ทุกแถว ambiguous ทุกครั้ง → re-upload บวมซ้ำ) · fresh=insert ครบ · re-upload(ครบ)=0 · recovery(ขาด1)=insert 1
- **วิธีกู้คืนของ user:** หลัง deploy → **อัป statement ไฟล์เดิมซ้ำ** → รายการ 740 ที่หายจะกลับมา (นับจำนวนเติมส่วนที่ขาด ไม่บวมเกิน)
- **gotcha:** `existSig` (dup check ของ non-ambiguous) เปลี่ยนมา filter จาก query เดียว (เดิม query `.eq('ambiguous',false)`) · ambiguous rows ไม่เคยอยู่ใน existSig — คุมด้วย count แทน

### 2026-07-03 — Bank Recon: ปุ่มแก้ไขแถว Express (แก้ยอด/วันที่ inline แล้วจับคู่ใหม่)
- **เคส:** Express ยอดพิมพ์ผิด (เช่น 1,105.**81** ควรเป็น 1,105.**82** ตาม Bank) → ต่าง 0.01 ไม่ auto-match · เดิมต้องไปแก้บัญชี+อัป XML ใหม่ → เกิดแถวเก่าค้าง (orphan)
- **`brecOpenEditRow(side,id)` + `brecSaveEditRow(side,id)`** — modal แก้ วันที่/ทิศทาง(เข้า-ออก)/จำนวนเงิน/เลขเอกสาร(doc_no)/หมายเหตุ(remark) · update `brec_express_rows` แล้ว `brecLoad()`+`brecRefresh()` → auto-match รันใหม่ตอนโหลด (ถ้าตรงเด้งไป "รอยืนยัน")
- ปุ่ม ✏️ (pencil สีแบรนด์) เพิ่มใน `.brec-acts` ของแถว Express (unex) ในแท็บ "รอกระทบยอด" · ข้าง 🔗 จับคู่เอง + 🗑 ลบ · เฉพาะ `brecCanWrite()`
- ฟังก์ชัน generic รับ side (`ex`/`bk`) — ตอนนี้ wire เฉพาะ Express (Bank = statement ต้นทาง ไม่ควรแก้) · เปิด Bank ได้ภายหลังถ้าต้องการ
- gotcha: แก้ยอดชน stable-key unique index (date+withdrawal+deposit+doc_no) กับแถวอื่นได้ (rare) → catch แจ้ง error

### 2026-07-03 — แบ่งจ่าย: ติ๊กจ่ายรายงวด (แก้บั๊กติ๊กจ่ายทั้งใบทั้งที่ยังจ่ายไม่ครบ)
- **ปัญหา:** บิลแบ่งจ่าย (planned_splits) เช่น 214k = 100k(จ่ายแล้ว 30/06) + 114k(รอ) · ติ๊กจ่ายในตาราง AP = จ่ายเต็ม 214k (ต้นเหตุ: `planned_splits` เป็นแค่ "แผน" ไม่มี paid flag · `apoBulkPay` จ่าย `amount_outstanding` เต็ม)
- **แก้ = ติ๊กจ่ายรายงวดใน pay card (`cffOpenPayCard`):** เพิ่มคอลัมน์ checkbox "จ่ายแล้ว" ต่องวด · `cffToggleSplitPaid(apId,i)` — ติ๊ก → insert `ap_payments` (amount+date ของงวด · pv_no "แบ่งจ่ายงวด N" · bank = pay_from_account_id) → เซฟ `paid`/`payment_id` ลงใน split object (planned_splits jsonb) → trigger `fn_ap_recompute` อัป amount_paid/outstanding/status · ติ๊กออก → soft-delete payment คืนสถานะ
- งวดที่จ่ายแล้ว = แถวเขียว ล็อกแก้ไข (โชว์วันที่/ยอดเป็น text) · summary ใหม่: "ยอดบิล X · จ่ายแล้ว Y · ยังต้องจ่าย Z" (`window._apoPayCardTotal/ApId/PayAcct`)
- **`cffStaffPayments`** ข้าม split ที่ `sp.paid` (ไม่เอาเข้าประมาณการ) · **`cffSaveSplits`** เก็บ `paid`/`payment_id` + ตั้ง planned_payment_date = งวดแรกที่ยังไม่จ่าย
- gotcha: source of truth ของ "จ่ายจริง" = `ap_payments` · `planned_splits.paid` เป็น mirror ไว้โชว์ · ถ้า bulk-pay ยอดคงเหลือของบิล split (จ่ายส่วนที่เหลือ) จะไม่อัป flag ในงวด แต่ invoice paid+ซ่อนอยู่ดี

### 2026-07-03 — Cash Flow view-only สำหรับผู้บริหาร + Exec period picker แถวของตัวเอง
- **ผู้บริหาร (view-only) ไม่เห็นดินสอ/แก้ไขในหน้า Cash Flow:** `cffStaffReportInner` รับ `opts.canEdit` (default true) · `renderToolCashflowStaff` ส่ง `canEdit:canWrite` (`fopCanWrite()` — exec/viewer = false) · ดินสอ ✏ + คลิกแก้ AP (`cffOpenPayCard`) + คลิกซ่อน recurring (`cffOpenRecurCard`) gate ด้วย `interactive && canEdit` (เดิม `interactive` อย่างเดียว) · **view interactivity ยังอยู่** (ย่อ/ขยายหมวด `cffToggleCat`/`cffToggleVendor`, chips ระดับการดู, drill pivot) — gate ด้วย `interactive` เหมือนเดิม
- **Exec Dashboard period picker = แถวของตัวเอง:** ย้าย `edPeriodPicker` ออกจาก flex row เดียวกับปุ่มนำเสนอ/พิมพ์ → ใส่ `<div>` แถวแยกใต้ title (กันแถวเดือนโผล่แล้วดันปุ่มกระโดดไปมา) · ไม่ใส่ `.ed-hide-present` (โชว์ตอนนำเสนอด้วย)

### 2026-07-03 — Cash Flow: ปิดมุมมองผู้บริหาร (ชั่วคราว) + Exec Dashboard เลือกเดือนได้
- **ย้าย Cash Flow Forecast → กลุ่ม "ภาพรวม" อันดับ 3** (หลัง Executive Cash Flow) — เปลี่ยน `stage` ของ tool `cashflow` เป็น `"ภาพรวม"` · 2 หน้าที่ผู้บริหารดู (execdash+cashflow) อยู่กลุ่มเดียวกัน · `PRESENT_TOOLS`/`page_permissions` คุมด้วย tool id ไม่กระทบ
- **ปิดมุมมอง "ผู้บริหาร" ในหน้า Cash Flow Forecast (ชั่วคราว):** `renderToolCashflowForecast` บังคับ `return renderToolCashflowStaff()` เสมอ (เดิม dispatch ตาม `d.viewMode`) · ถอดปุ่มสลับ 📋 พนักงาน / 📊 ผู้บริหาร ออกจาก toolbar หน้าพนักงาน · **`renderToolCashflowExec` + `cffSetView` ยังอยู่ในไฟล์ (dead) เปิดคืนได้ภายหลัง**
- **Exec Cash Flow — เลือกเดือนได้:** `edPeriodPicker` เพิ่ม "แถวเดือน" (โผล่เมื่อเลือกปีแล้ว · ต่อจากแถวไตรมาส) — ปุ่มเดือนไทยย่อ (ม.ค.–ธ.ค.) เฉพาะเดือนที่มีข้อมูลในปีนั้น → `edSetMonth("YYYY.MM")` (backend `edScopeMonthKeys`/`edTxsInScope` รองรับ single-month อยู่แล้ว · เดิมมีแค่ปี→ไตรมาส)

### 2026-07-03 — AP Outstanding: ซ่อนบิลที่จ่ายแล้ว + ยกเลิกจ่ายหลายรายการ
- **ซ่อนบิล `status='paid'` เป็นค่าเริ่มต้น** (`apoFilterAndSort`: `if(!f.showPaid && !colFilters.status) filter(status!=='paid')`) — เดิมโชว์ทุกสถานะ เจ้าหนี้คงค้างเลยรก · partial (ค้างบางส่วน) ยังโชว์
- **toggle "แสดงที่จ่ายแล้ว"** (`f.showPaid`) ข้าง "เฉพาะเกินกำหนด" → เปิดเพื่อดู/จัดการบิลที่จ่ายแล้ว
- **ยกเลิกจ่ายหลายรายการ:** checkbox โผล่บนแถว paid ด้วย (`selectable = outstanding>0 || paid` · `data-paid`) · `apoUpdateBulkBar` แยก unpaidIds/paidIds → โชว์ปุ่ม "จ่ายชำระแล้ว" (ค้าง) + "↩ ยกเลิกการจ่าย" (paid) พร้อมกันได้ · `apoBulkUnpay` soft-delete `ap_payments` ของ id ที่เลือก → trigger `fn_ap_recompute` คืนสถานะ · **prune ใน bulkbar เปลี่ยนเป็นเก็บทั้ง payable+paid** (เดิมตัด paid ออกจาก selection)

### 2026-07-03 — AP Outstanding: จ่ายชำระหลายรายการพร้อมกัน (bulk pay) + วันที่จ่ายจริง
- **เจ้าของขอ:** จ่ายเจ้าหนี้ทีละหลายบิลได้ — ติ๊กเลือกหลายรายการ (หรือติ๊กทั้งหมดในตัวกรอง) → ใส่ "วันที่จ่ายจริง" → กด "จ่ายชำระแล้ว"
- **คอลัมน์ checkbox ใหม่** ใน `apoBuildTable` (คอลัมน์แรก · เฉพาะ `canWrite`): master checkbox หัวตาราง (`apoToggleSelectAll` — เลือกทุกบิลที่ค้างจ่ายในตัวกรองปัจจุบัน · indeterminate เมื่อเลือกบางส่วน) + checkbox รายแถว (เฉพาะบิล `amount_outstanding>0 && status!=='paid'`)
- **State ใหม่ใน `apoGet()`:** `selected` (Set ของ invoice id · แยกต่อบริษัท · backward-compat guard) + `payActualDate` (string) · เก็บ selection ข้ามการ filter ได้
- **แถบสรุป `#apoBulkBar`** (ระหว่าง filter bar กับตาราง · โผล่เมื่อเลือก ≥1): "เลือกไว้ N รายการ · รวมคงค้าง X บาท" + input วันที่จ่ายจริง (`apoSetPayActualDate` — ไม่ re-render กัน focus หลุด) + ปุ่ม "✓ จ่ายชำระแล้ว" + "ยกเลิกการเลือก" · `apoUpdateBulkBar()` วาดแถบ + ตั้งสถานะ master checkbox + prune id ที่จ่ายครบแล้วออกจาก set · เรียกท้าย `renderToolApOutstanding` + `apoApplyChanges`
- **`apoBulkPay()`** — insert `ap_payments` ทีเดียว (array) ต่อบิล: `amount = amount_outstanding` (จ่ายเต็มคงค้าง) · `paid_date = วันที่จ่ายจริง` · `bank_account_id = pay_from_account_id||null` · method transfer · confirm ก่อน (โชว์จำนวน+ยอดรวม+วันที่) → trigger `fn_ap_recompute` อัปเดต `amount_paid`+`status='paid'` อัตโนมัติต่อบิล · สำเร็จ → clear selection + reload
- **กระทบหน้าอื่น = 0** — reuse `apoEnrich`/`apoFilterAndSort`/`fopFmt`/`fopDate` เดิม · ปุ่ม "จ่าย" รายตัว (`apoOpenPay`) + แบ่งจ่าย ยังทำงานเหมือนเดิม · ไม่มี migration (ใช้ schema `ap_payments` เดิม)

### 2026-07-02 — User self-service password + เปิด/ปิด user (ban)
- **User เปลี่ยนรหัสเอง** (`changeOwnPassword`/`doChangeOwnPassword`): ปุ่ม "เปลี่ยนรหัส" บน topbar (ข้างออกจากระบบ) → modal รหัสใหม่+ยืนยัน → `sb.auth.updateUser({password})` (session ตัวเอง ไม่ต้อง service key) · **ซ่อนสำหรับบัญชี present** (บัญชีแชร์)
- **เปิด/ปิดใช้งาน user** (`usrToggleBan`): ปุ่ม "ปิดใช้/เปิดใช้" ในตารางผู้ใช้ → admin API `ban_duration` (`876000h` = แบน ~100ปี / `none` = ปลดแบน) — บล็อก login โดยไม่ลบข้อมูล · badge "ปิดใช้งาน" + row จางเมื่อ `banned_until` > now
- **Exec Dashboard ซ่อนปุ่มนำเข้า/ลบ สำหรับ non-admin** (`canEditExec = AUTH.role==='admin'`): ผู้บริหารที่เข้าผ่าน `page_permissions` (execdash) เห็นแค่ ดู/พิมพ์/นำเสนอ — ไม่เห็น "+ อัปไฟล์เพิ่ม" / "ล้าง & เริ่มใหม่"
- **หมายเหตุ:** สิทธิ์ view-only ของผู้บริหารใช้ระบบ `page_permissions` เดิม (admin ติ๊ก execdash ให้ user) — ไม่ได้เพิ่ม path role=executive แยก (กันชนกับระบบ permission ที่มีอยู่)

### 2026-07-02 — Bank Recon: auto-match รันเองตอนโหลดหน้า + เด้ง error ตอนอัป (แก้ "ไม่ยอมจับคู่ให้")
- **อาการ:** แถวที่ วัน+ยอดตรงเป๊ะ (Tier 2) ค้างในแท็บ "รอกระทบยอด" ไม่ยอมจับคู่ — เพราะ auto-match เดิมรันแค่ 2 จังหวะ: ตอนอัปไฟล์เสร็จ + กดปุ่ม ⚡ เอง · **เปิดหน้าเฉย ๆ ไม่ trigger** · ซ้ำ: insert `brec_matches` ล้มเหลวตอนอัปถูกกลืนเงียบ (`if(!me){...}` ไม่มี else)
- **แก้ 1 — silent auto-match ตอนโหลด:** helper ใหม่ `brecTryAutoMatch(d)` (จับเฉพาะ non-ambiguous · วัน+ยอด(+ref)ตรง · error ไม่ throw แค่ log · คืนจำนวนคู่) · เรียกใน `renderToolBankRec` ก่อน `brecBuildBuckets` · **gate ด้วย signature** `accountId|express.len|bank.len|matches.len` (`d._autoSig`) กันรันซ้ำตอน re-render จาก toggle · ตั้ง sig เป็นสถานะ**หลัง** match กันเข้าลูป · คู่ใหม่ไป pending (status suggested) รอยืนยัน
- **แก้ 2 — banner แจ้ง:** `d._autoNote` = จำนวนคู่ที่จับได้ → banner เขียวเหนือ brec-sum "จับคู่อัตโนมัติเพิ่ม N คู่..." + ปุ่ม ✕ (`brecDismissAutoNote`)
- **แก้ 3 — error ตอนอัปเด้งเตือน:** `brecUpload` เพิ่ม else — insert match fail → `matchedMsg` เตือน "⚠ จับคู่อัตโนมัติไม่สำเร็จ: {error}" + console.warn (เดิมเงียบ → คู่หายโดยไม่รู้ตัว)
- **กระทบหน้าอื่น = 0** — เฉพาะ bankrec · upload flow เดิม (explicit auto-match ที่ 15269) ยังทำงาน · gate หลัง upload จะเจอ 0 คู่ใหม่ (จับไปแล้ว) ไม่ double-match
- **หมายเหตุ diagnostic:** ถ้ายังไม่จับ ให้เช็ค (1) Express/Bank อยู่คนละ `bank_account_id` (auto-match เทียบเฉพาะบัญชีเดียว+siblings เลขเดียวกัน) (2) แถวติด flag `ambiguous` (วัน+ยอด+doc ซ้ำในไฟล์เดียว — ปุ่ม ⚡ รวมให้ แต่ silent ตอนโหลดข้าม)
- **แก้ 4 (ตามมา) — ปุ่มลบแถวค้างรายตัว:** โหมด "เพิ่มเข้าของเดิม" ตอนอัปซ้ำใช้ลายเซ็น `วัน|ถอน|ฝาก|เลขเอกสาร` → **แก้ยอดแล้วอัปใหม่ = ลายเซ็นเปลี่ยน → เพิ่มแถวใหม่แต่แถวยอดเก่าค้างเป็น orphan** (เช่น 14,232 ค้างหลังแก้เป็น 14,273) · เพิ่ม `brecDeleteRow(side,id)` (soft-delete `brec_express_rows`/`brec_bank_rows` + match ที่อ้างถึง) + ปุ่มถังขยะแดงข้าง "จับคู่เอง" ในแท็บ "รอกระทบยอด" ทั้งฝั่ง ex/bk · unique index เป็น partial (`WHERE deleted_at IS NULL`) → อัปแถวเดิมซ้ำภายหลังได้
- **แก้ 6 (ตามมา) — compact + ช่องหมายเหตุ + ตัวเลือกเดือนแบบเลื่อน (ตามที่เจ้าของขอ · อิงตัวอย่าง recon อีกทีมที่ชอบ):**
  - **compact แถวตาราง**: `.brec-row` padding 5→3px · `.brec-side` height 30→27 · แท็บ "รอกระทบยอด" ตัดบรรทัด hint (`.w` "ยังไม่ขึ้นเงิน?/ค่าธรรมเนียมยังไม่บันทึก?") ออก + ปุ่ม "จับคู่เอง" เป็น icon-only + acts `nowrap` → แถวเตี้ยลงจาก ~60px เหลือ ~34px (เดิมยืดเพราะปุ่ม+hint ดันสูง)
  - **ช่องหมายเหตุท้ายบรรทัด** (`user_note`): คอลัมน์ใหม่ในแท็บ "รอกระทบยอด" (แทนคอลัมน์ผู้รับผิดชอบในตัวอย่าง) · `<input>` บันทึกตอน blur ผ่าน `brecSetRowNote(side,id,val)` (อัป local ก่อนกัน re-render ทับ · ไม่ re-render กัน focus หลุด) · **migration `supabase/bankrec-row-note.sql`** เพิ่ม `user_note` ทั้ง `brec_express_rows`/`brec_bank_rows` (แยกจาก remark/ref_note ที่ parse จากไฟล์ → ไม่ถูกทับตอนอัปซ้ำ) · `brecLoadRows` ใช้ `select("*")` โหลดมาเอง · grid แท็บนี้เป็น 7 คอลัมน์ผ่านคลาส `.brec-table.wnote` (แท็บอื่นยัง 6 คอลัมน์ ไม่กระทบ) · **ค้นหาได้ด้วย**: เพิ่ม `user_note` เข้า search text ทั้ง `brecStmFilterRows` (ช่องใน statement bar) + `brecFilterRow` (filter หลัก)
  - **ตัวเลือกเดือนแบบเลื่อน** `‹ มิ.ย. 2026 ›`: แทน `<input type=month>` · `brecMonthStep(±1)` (ปรับ d.period.month แล้ว reload) + `brecMonthLabel(ym)` (เดือนไทยย่อ `BREC_TH_MON` + ปี ค.ศ.) · CSS `.brec-mstep`
- **แก้ 5 (ตามมา) — งบสรุปงวด Statement แบบ bridge:** เดิมแท็บ "รอกระทบยอด" โชว์แค่ ยอดยกมา/เงินเข้า/เงินออก วางเรียงกันใน `.brec-stmbar` · เปลี่ยนเป็น **bridge 4 กล่อง**: ยอดยกมาต้นงวด → **+** รับในงวด (เขียว) → **−** จ่ายในงวด (แดง) → **=** คงเหลือยกไป (สีแบรนด์) · `brecStmStats` เพิ่ม `closing` (ยอดคงเหลือแถวสุดท้าย · fallback = opening+in−out ถ้าไฟล์ไม่มี balance) + `net`/`hasBal` · CSS `.brec-stmwrap`/`.brec-bridge` (responsive: จอ ≤820px เรียงลง) · **เตือนงวดไม่ต่อเนื่อง**: ถ้า closing ≠ opening+รับ−จ่าย (>0.01) โชว์แถบเหลือง "อาจมีรายการขาด"

### 2026-06-30 — Orders: แก้บั๊กออเดอร์ซ้ำ (อัปไฟล์ BigSeller ซ้ำ → นับเกิน ~2 เท่า)
- **อาการ:** กระดานสรุปภาพรวมโชว์ฝั่ง BigSeller (หน้าบ้าน) เด้งเกือบ 2 เท่า (เช่น Shopee 2,754 ทั้งที่ของจริง ~1,377) แต่ฝั่ง "ระบบหลังบ้าน" (จาก `order_recon`) ปกติ — เพราะ recon สร้างใหม่ทุกรอบ ไม่สะสมซ้ำ
- **ต้นเหตุ:** `ordIngestChannelOrders` ดึงออเดอร์เดิมมาทำ map กันซ้ำ (`byOid` keyed `order_id`) **แต่ query ไม่แบ่งหน้า** → Supabase/PostgREST คืนสูงสุด 1000 แถว → ตัวกันซ้ำรู้จักแค่ 1000 ใบแรก · ออเดอร์ใบที่เกิน 1000 ตอนอัปไฟล์ซ้ำ → `byOid.get()` ไม่เจอ → **insert ซ้ำ** · ซ้ำร้าย index `(company_id, order_id)` เป็น **non-unique** (orders.sql:117) → DB ไม่บล็อก insert ซ้ำ
- **แก้โค้ด (ต้นเหตุ):** เพิ่ม helper **`ordFetchAllRows(co, cols, applyFilters)`** ดึง `order_ledger` แบบแบ่งหน้า (`.range()` loop เหมือน `ordLoad`) · เปลี่ยน 4 จุดที่ดึง existing แบบติด cap มาใช้ helper นี้: `ordIngestChannelOrders` (insert/dedup — ตัวก่อบั๊ก) · `ordIngestFromSales` · `ordTagReceipts` · `ordTagBankFromWithdrawals`
- **แก้ข้อมูลที่ซ้ำไปแล้ว:** `supabase/zz-orders-dedup-cleanup.sql` (idempotent · EXCEPTION-wrapped · prefix `zz-` รันหลังสุด) — soft-delete แถวซ้ำ เก็บ 1 แถว/`order_id` ที่ข้อมูลครบสุด (ลำดับ: มี iv_no > re_no > bq_no > sale_amount > เก่าสุด) · รันซ้ำได้ (รอบถัดไปไม่มีซ้ำ → no-op)
- **กระทบหน้าอื่น = 0** — `ordLoad`/`homeLoadStats` (display) แบ่งหน้าถูกอยู่แล้ว · แก้เฉพาะ path ที่ดึง existing มากันซ้ำ/แท็ก

### 2026-06-30 — รับชำระเงิน: GROSS = ฐานภาษี + รายจ่าย reconcile + จัดหมวดค่าใช้จ่าย + Lazada
- **เจ้าของขอ:** ทะเบียนรับชำระต้องโชว์ **GROSS = ฐานภาษี** (= มูลค่าที่จะคีย์ IV) · รายจ่ายแทร็คได้ว่ามาจากไหน · **ฐานภาษี − รายจ่าย = เงินเข้าสุทธิจริง** · คอลัมน์: ลำดับ/แพลตฟอร์ม/เลขออเดอร์/GROSS/รายจ่าย(toggle ดีเทล)/สุทธิ
- **ฐานภาษีต่อช่อง** (ตรวจกับไฟล์จริง MM): Shopee=`สินค้าราคาปกติ[11] + ส่วนลดผู้ขาย[12](ติดลบ) + ค่าส่งผู้ซื้อ[19]` · TikTok=`รายได้รวม[6](หลังหักส่วนลดผู้ขายแล้ว) + ค่าส่งผู้ซื้อ` · Lazada=`Σยอดรวมค่าสินค้า − คูปองผู้ขาย + ค่าส่ง` · **ส่วนลดผู้ขาย/ค่าส่งผู้ซื้อ = เข้าฐานภาษี ไม่ใช่รายจ่าย** (แก้บั๊กเดิมที่ Shopee เอา gross−net เป็นค่าธรรมเนียม → ปนส่วนลด เช่นส่วนลด 1058 โชว์ fee 1158 แทนที่จะเป็น 100)
- **รายจ่าย = `tax_base − net_received`** (reconcile เสมอ ไม่ว่า fee breakdown ครบไหม) · เก็บคอลัมน์ใหม่ `tax_base`/`buyer_shipping` (`supabase/sales-income-taxbase.sql`) — **ต้องอัป Income ใหม่** หลัง deploy
- **จัดหมวดค่าใช้จ่าย** `incFeeCategory(name)` รวมชื่อต่างกันของแต่ละช่อง → 7 หมวด (คอมมิชชั่น/ธุรกรรม/บริการ/ขนส่ง/โฆษณา/ภาษี/อื่นๆ) · `incRowFeeCats` balance ผลรวมหมวด = รายจ่าย (ใส่ส่วนต่างใน "อื่นๆ") · ปุ่ม **"แสดง/ซ่อนดีเทลรายจ่าย"** (`incShowFeeDetail`) แทรกคอลัมน์หมวด (เฉพาะหมวดที่มียอด)
- **เพิ่ม Lazada income parser** (`parseLazadaIncome` — บัญชีรายการธุรกรรม จัดกลุ่มต่อ order) + `detectPlatform` kind LZ + `parseDate` รองรับ "28 Jun 2026"
- **ทดสอบ:** ทั้ง 3 ช่อง taxBase/รายจ่าย/สุทธิ reconcile เป๊ะ · หมวดรวม = รายจ่าย
- **ยังไม่ทำ:** "ขายอะไร" (ชื่อสินค้า — Lazada/TikTok มีในไฟล์, Shopee ต้องไฟล์สินค้าเพิ่ม) · ค่าส่งผู้ซื้อ TikTok (ยังหา column ไม่เจอ → taxBase=รายได้รวม)

### 2026-06-30 — Sales Pipeline ขั้นตอน 2 (รับชำระเงิน): เปิดใช้ + เพิ่มแท็บ "ส่งออก RE → AutoKey"
- **เปิด `sales_income` (เมนู "2. รับชำระเงิน") จาก `soon` → `live`** — เดิมสร้าง `renderToolSalesIncome` + `inc*` ไว้แล้ว (commit 4f7b616/35b24cb) แต่ status soon → เข้าไม่ถึง (เจ้าของหา "กระบวนการรับชำระ" ไม่เจอ)
- **แท็บ "ส่งออก RE → AutoKey" เดิมเป็น stub "กำลังพัฒนา" → เขียนจริง** (`incRenderExport` + `incExportRE` + helper `incSetReSeed`/`incBrandOf`/`incReCandidates`/`incReRow`)
  - **จับคู่ income × order_ledger ด้วย `order_id`** → เอาเฉพาะออเดอร์ที่ **คีย์ IV แล้ว** (`ord.iv_no`) · ตัดที่มี `re_no` แล้วออก (คีย์ RE ไปแล้ว) · ต้องโหลดทะเบียน (ขั้นตอน 1) ก่อน
  - **สูตร:** ยอด IV (`ord.sale_amount`) − ค่าธรรมเนียม = เงินเข้าสุทธิ (`inc.net_received`) · diff = ค่าธรรมเนียม = "ส่วนต่างที่ต้องบันทึก" (ตรงที่เจ้าของสอน: IV − จ่ายล่วงหน้า = เข้ากระเป๋าสุทธิ)
  - **reuse format AutoKey RE จาก armap ทั้งดุ้น**: `A_HEAD` (19 คอลัมน์) · `armapRunRE(seed,i)` (รันเลข RE +1) · `bankDownCmd(brand,channel)` (Benya BT/QI × SP/TT) / `mbarkBankDownByCust`+`mbarkCheckCode` (M Bark ตามรหัสลูกค้า) · `forceTextCells([1,3,6,12])` กัน Excel ตัดเลขยาว · ส่งออก xlsx + csv (BOM)
  - **brand เดาจาก** `ord.shop/customer/products` (Betra→BT · Qi→QI) — ใช้เลือก bank ฝั่ง Benya · เตือนถ้าแมพ bank ไม่ได้
- **กระทบหน้าอื่น = 0** — ใช้ helper armap ที่เป็น global · ทะเบียนรับชำระ (`incRenderList`) + ตรวจ 1.9.1 (`incRenderVerify`, tag `re_no` เข้า order_ledger) ที่มีอยู่แล้วไม่แตะ
- **(แก้ตามมาทันที) ตรวจ 1.9.1 ขึ้น "ไม่พบออเดอร์" ทั้งหมด:** ต้นเหตุ = `incRenderVerify` จับคู่ด้วย `iv_no` กับ `order_ledger` แต่ **order_ledger ไม่ถูกโหลด** ถ้าเปิดขั้นตอน 2 ตรง ๆ (ไม่ผ่านขั้นตอน 1) → `ivMap` ว่าง → ทุกแถวไม่เจอ · แก้: (1) `renderToolSalesIncome` auto-`ordLoad()` ถ้า `!ordGet().loaded` (ทุกแท็บ) (2) **cross-match 2 ทาง** `matchOf(r)=ivMap[iv_no] || ordByOrder[order_ref]` (parser 1.9.1 ดึง `order_ref` col[14] มาแล้ว — ตรง req เจ้าของ: จับด้วยออเดอร์ + พ่วง IV) ใช้ทั้ง KPI/ตาราง/`incVerifyTagAll` (3) `incVerifyTagAll` เติม `iv_no` ให้ order_ledger ถ้าจับผ่าน order_ref แต่ยังไม่มี iv (4) สถานะแยกชัด: "ทะเบียนยังไม่โหลด" / "ไม่มีในระบบ" / "พร้อม Tag (ผ่านเลขออเดอร์)"
- **(เพิ่มตามมา) ส่งออก RE — กันซ้ำ + ฟิลเตอร์:** `incExportView(d)` รวม candidate+ฟิลเตอร์ ใช้ทั้ง render+`incExportRE` (ตรงกันเป๊ะ) · **กันส่งซ้ำ**: ตัด IV/ออเดอร์ที่อยู่ในไฟล์ 1.9.1 ที่อัปไว้ (`inReport191` จาก `d.verify.rows` keyedIv/keyedOrder set) แม้ยังไม่กด Tag → ไปนับใน "คีย์แล้ว/พบใน 1.9.1" · **ฟิลเตอร์**: ช่องทาง (`expCh`) · ช่วงวันรับเงิน (`expFrom`/`expTo` เทียบ `paidISO=parseDate(paid_date)`) · "เฉพาะไม่ติดปัญหา" (`expClean`) ซ่อนแถว `_prob` (เลือก bank ไม่ได้/ไม่มียอด IV/เงินเข้า≤0) · แถวติดปัญหาพื้นเหลือง · KPI "กำลังจะส่งออก" = view.length
- **"?" ในคอลัมน์ "เลือก Bank"** = `bankDownCmd(brand,channel)` คืนว่าง (เดาแบรนด์ Betra/Qi ไม่ออกจาก `incBrandOf`) — ฝั่ง Benya เลือก bank ตาม brand×channel · มักเป็นออเดอร์ไม่มียอด IV/แถวคืนเงิน TikTok · ใช้ตัวกรอง "เฉพาะไม่ติดปัญหา" ซ่อนได้
- **ยังไม่ทำ:** Lazada income parser (เฟส 2 · ไฟล์ "Income Overview" โครงสร้างต่าง · ตอนนี้ `incUploadIncome` รับแค่ SP/TT) · จัดการแถวคืนเงิน/ปรับของ TikTok ให้ดีกว่าซ่อน · ปรับ `incBrandOf` ให้เดาแบรนด์แม่นขึ้น (ลด "?")

### 2026-06-27 — รื้อหน้า BigSeller → "บันทึกขายเชื่อในระบบบัญชี (IV)" + ยุบ expressmatch/exportkey
- **เปลี่ยน module `bigseller`** จาก "อัปไฟล์ BigSeller → เทมเพลตคีย์" เป็นหน้าบันทึกขายเชื่อ (IV) ที่เกาะ `order_ledger` ตรง · 3 แท็บ: **🚦 สรุปสถานะการคีย์** · **📤 ส่งออกคีย์ IV (wizard)** · **🔍 ตรวจการคีย์ (141.RWT)**
- **ยุบ `expressmatch` + `exportkey` ออกจาก sidebar** — `renderToolExpressMatch`/`renderToolExportKey` ยังอยู่ในไฟล์ (dead code) · เพิ่ม redirect ใน `renderTool()`: `state.tool` เป็น expressmatch/exportkey → set เป็น 'bigseller' · กัน TOOLS.find=undefined ด้วย fallback 'home'
- **Schema ใหม่ `supabase/iv_export_batches.sql`** (idempotent · EXCEPTION-wrapped · ปิด RLS · NOTIFY pgrst): batch_no/date_from/to/channels[]/start_iv/end_iv/order_count/order_ids jsonb/file_name/exported_email · UNIQUE `(company_id, batch_no)` · index `(company_id, exported_at DESC)`
- **★ Gate logic** (`ivrCanExport`): manual (FACE/LINE/Dealer/other) → ส่งออกได้ทันที (BigSeller = source of truth) · marketplace (SHOPEE/TIKTOK/LAZADA) → ต้อง `order_recon.status='matched'` เท่านั้น · diff/only_be/only_bs/pending → block + เหตุผล
- **★ IV numbering policy** — บัญชีกรอก "เลข IV เริ่มต้น 10 หลัก" (เช่น `2606000007`) ระบบรันต่อในไฟล์ AutoKey เท่านั้น · **ไม่ persist `iv_no` ลง `order_ledger` ตอน export** — รออัป 141.RWT มา verify ก่อน (บัญชีอาจแก้มือในระบบ → 141.RWT คือ source of truth) · auto-suggest = `end_iv ของ batch ล่าสุด + 1`
- **Export workflow:** Step 1 chip ช่วงวัน (วันนี้/เมื่อวาน/7วัน/เดือนนี้/ทั้งหมด/custom) + chip ช่องทาง → Step 2 การ์ดเขียว "ส่งออกได้ X" + การ์ดแดง "ติด gate Y" (modal ดูเหตุผลทุกราย จัดกลุ่มตามสาเหตุ) → Step 3 input เลข IV (border แดง/เขียวตาม validity) + แนะนำ end IV · ปุ่ม "ส่งออก AutoKey" สร้าง batch_no `IV-{co}-YYYYMMDD-NNN` + insert iv_export_batches + ดาวน์โหลด CSV (BOM UTF-8) + alert + auto-bump เลข IV เริ่มต้นต่อไป · ปุ่ม "ประวัติส่งออก" → modal ตาราง 8 คอลัมน์
- **Verify tab** = reuse `ordRenderIv(d)` ทั้งดุ้น (drop-in) — `ordIvUpload`/`ordIvAnalyze`/`ordIvApply` ทำงานเหมือนเดิม · เพิ่ม guard ใน `renderToolOrders`: `state.tool==='bigseller'` → return `renderToolBigSeller()` (กัน ordIv* re-render เด้งกลับหน้า Orders)
- **Visual style** (ตาม Executive Cash Flow ที่เจ้าของชอบ): hero gradient + watermark โลโก้ + KPI 4 ใบ gradient (ready=เขียว, match=น้ำเงิน, diff=แดง, block=ส้ม) + chip มุมขวา · ตาราง preview + status badge สีตาม bucket · wizard 3 step ใน card แยก · ปุ่มมี icon lucide ทุกอัน · CSS scoped ใต้ `.ivr-page` (ไม่ชนหน้าอื่น)
- **ฟังก์ชันใหม่** (`ivr*`): `ivrInitState`/`ivrISO`/`ivrFmt`/`ivrFmt2`/`ivrRangeBounds`/`ivrNextIv`/`ivrPredictEnd`/`ivrCanExport`/`ivrVerifyMapFromIc`/`ivrKpis`/`ivrInjectStyle`/`ivrLoadBatches`/`ivrHeroHtml`/`ivrKpiStripHtml`/`ivrStripHtml`/`ivrTabsHtml`/`ivrRenderBoard`/`ivrRenderExport`/`ivrRenderVerify`/`ivrRenderBlockedModal`/`ivrRenderHistoryModal`/`ivrSetTab`/`ivrBoardFilter`/`ivrSetRange`/`ivrSetDate`/`ivrToggleChannel`/`ivrChannelAll`/`ivrSetStartIv`/`ivrToggleBlocked`/`ivrToggleHistory`/`ivrDoExport`
- **State** = ใช้ `state.ord[co]` ร่วมกับหน้า Orders (key `d.ivrec`) — share `d.rows` + `d.recon` + `d.ivCheck` กับ Orders/Verify → ไม่ต้องโหลดซ้ำ
- **กระทบหน้าอื่น:** Orders ไม่กระทบ · Express CSV import เก่า/SKU master/ประวัติคีย์ของ `bs*` ทั้งหมดยังอยู่ในไฟล์แต่ unreachable (entry เปลี่ยนหมด) · `BS_HEAD`/`BS_SHIP_SKU`/`forceTextCells` ยังใช้ใน `ivrDoExport`

### 2026-06-26 — Recon: ใช้สูตร "ฐานภาษีขาย" ต่อช่องทาง (VAT spec) แทนการเทียบ order_total เฉยๆ
- **เป้าหมาย:** เทียบยอด BigSeller↔หลังบ้านให้ตรงตามฐานภาษีขายจริง (สเปคเต็ม `for-design/order-pipeline/vat-recon-logic.md` · เจ้าของยืนยันผลต่าง 0: Shopee 1,401/1,401 · Lazada 29/29 · TikTok-QI 128/128 · **MBARK TikTok ยังไม่เช็ค**)
- **`ordTaxBase(o, side)` ใหม่** — ฐานภาษีขาย (รวม VAT) = ยอดสินค้าสุทธิ(หักเฉพาะส่วนลดผู้ขาย) + ค่าส่งผู้ซื้อจ่าย · **ไม่หักส่วนลดแพลตฟอร์ม**:
  - `side='be'` (หลังบ้าน=source of truth): Shopee=`net − disc + ship` · Lazada=`net + disc + ship` (sellerDiscount ติดลบ) · TikTok=`gross("Before Discount") − disc + ship`
  - `side='bs'` (BigSeller): Shopee/Lazada ใช้ `order_total`("ราคา") · **TikTok ใช้ `gross_total`("ราคาสินค้าเดิม")** เพราะ TikTok "ราคา" หักส่วนลดแพลตฟอร์มแล้ว · ทุกช่อง − `seller_voucher`("Voucher ของร้านค้า") + ship
- **`ordReconDiffs` เปลี่ยน** — เทียบ `ordTaxBase(bs,'bs')` vs `ordTaxBase(be,'be')` strict ≥0.01 (แทน `ordReconNet`=order_total) + ค่าส่ง (info) + SKU sig
- **ใช้ field ที่ parser เก็บอยู่แล้ว** (gross_total/order_total/seller_discount/seller_voucher/shipping_fee + channel_group) — ไม่แก้ parser/ORD_CH
- **gotcha:** `seller_voucher` ฝั่ง BigSeller parser เป็น bill-level (Math.max) · ถ้า TikTok "Voucher ของร้านค้า" เป็น per-unit จริง อาจต่างตอน qty>1 → ต้องยืนยันกับข้อมูล MBARK ก่อนล็อก · `ordReconNet` (display amount ใน board/coverage) ยังเป็น order_total เหมือนเดิม

### 2026-06-27 — Recon fix: persist seller_voucher + gross_total ลง order_ledger (แก้ TikTok +100)
- **ต้นเหตุ TikTok recon +100:** `order_ledger` ไม่มีคอลัมน์ `seller_voucher`/`gross_total` + `ordIngestChannelOrders` insert ไม่ได้เซฟ → parser อ่าน "Voucher ของร้านค้า" (ส่วนลดผู้ขาย TikTok) แล้ว แต่หล่นตอนเซฟ → recon (ใช้ bs จาก d.rows/order_ledger) เห็น `seller_voucher=0` → ไม่หักส่วนลด → +100 (ไม่ใช่สูตรผิด)
- **`supabase/orders_voucher_gross.sql`** (idempotent): `ALTER TABLE order_ledger ADD COLUMN IF NOT EXISTS seller_voucher/gross_total` + NOTIFY pgrst · ตั้งชื่อ sort หลัง orders.sql/orders_pipeline.sql
- **`ordIngestChannelOrders`** เพิ่ม `seller_voucher`/`gross_total` ใน rec(insert) + select + update (vchChanged/grossChanged → backfill ของเก่า)
- **ต้องอัป BigSeller ใหม่** หลัง deploy → order_ledger เติม voucher/gross → recon ตรง
- **กฎคอลัมน์ครบ (เจ้าของยืนยัน):** ส่วนลดผู้ขายทุกช่อง (Shopee/Lazada/TikTok) อยู่ใน "Voucher ของร้านค้า" ฝั่ง BigSeller · TikTok voucher per-unit (×qty) แต่ parser ยัง Math.max — ถ้า qty>1 ยังต้องเช็ค
- **`ordReconEffStatus`** + board recompute status สด · `ordReconSide` มี gross fallback (items) แล้ว · register นับ active

### 2026-06-26 — Orders redesign Phase 1: ย้าย IV จาก Express ออกไปหน้า "แมพ IV จาก Express"
- **เป้าหมาย:** redesign หน้าทะเบียนคำสั่งซื้อตาม handoff ใหม่ (`for-design/orders-redesign/`) เหลือ 2 แท็บ (สรุปภาพรวม + รายละเอียดการขาย) · เฟสนี้ทำเฉพาะ "ย้าย IV ออกก่อน"
- **ย้ายทั้ง 2 view ของ IV** จาก Orders → `renderToolExpressMatch` (หน้า expressmatch): `ordRenderIvSystem` (📑 IV จาก EXPRESS) + `ordRenderIv` (🧾 คัดกรองและนำเข้า IV) · sub-tab toggle `emSetIvView(v)` เก็บใน `ordGet().emIvView` (default 'ivsys')
- **expressmatch ใช้ `ordGet()` state + `ordLoad`/`ordReconLoad` ร่วมกับ Orders** (IV อ่าน `d.rows`/`d.ivCheck`) · wrap ใน `.ord-page` + `ordInjectStyle()` ให้สไตล์ตรง
- **★ gotcha (re-render routing):** `ordIv*` setter หลายสิบตัวเรียก `renderToolOrders()` ตอน re-render · ใส่ guard หัว `renderToolOrders`: ถ้า `state.tool==='expressmatch'` → `return renderToolExpressMatch()` (กัน #main เด้งกลับหน้า Orders) — ไม่ต้องแก้ call site ทุกตัว
- **Orders เหลือ 2 แท็บ:** 🚦 สรุปสถานะ + 📋 คำสั่งซื้อ BigSeller (ถอด tabBtn + dispatch ของ ivsys/iv ออก) · KPI "recon" ยังคลิกไปแท็บ recon ได้
- **เก่า em* flow ถูกแทน** — `renderToolExpressMatch` เดิม (อัป CSV แมพ IV ง่ายๆ) ถูกเขียนใหม่ · `emGet/emHandleFile/emApply/emResultHTML` ยังอยู่แต่ไม่ถูกเรียก (dead code) · `emClear` ลบแล้ว
### 2026-06-26 — Orders redesign Phase 2: หน้า "สรุปภาพรวม" ตามดีไซน์ใหม่ (KPI แพลตฟอร์ม + สรุปกระทบยอด)
- **`ordRenderBoard` รื้อใหม่** (แท็บ board = "สรุปภาพรวม"):
  - **KPI 4 แพลตฟอร์ม** (Shopee/TikTok/Lazada/อื่นๆ FACE-LINE) — การ์ด border-top สีแบรนด์แพลตฟอร์ม + ยอดเงิน + จำนวนออเดอร์ (group จาก `o.channel_group`, offline+unknown → other)
  - **2 คอลัมน์: สรุปกระทบยอด + กระทบยอดต่อแพลตฟอร์ม** จาก `d.recon.results`:
    - สรุปกระทบยอด: ตรวจทั้งหมด (checkedN) + progress bar 4 สี + 4 แถว (ตรงกัน=matched เขียว · มีในแพลตฟอร์มไม่มีใน BS=only_be แดง · มีใน BS ไม่มีแพลตฟอร์ม=only_bs ส้ม · ยอดไม่ตรง=diff ม่วง) · `resAmt(r)=ordReconNet(r.be||r.bs)`
    - กระทบยอดต่อแพลตฟอร์ม: diverging bars ต่อ channel (ซ้ายแดง=only_be · กลางเขียว=matched · ขวาส้ม=only_bs) จาก `ordReconCoverage` cnt
  - ฝัง `ordRenderRecon(d)` เดิมด้านล่าง (coverage table + รายการไม่แมท + อัปไฟล์ + ใบกระทบยอด) — ไม่ rebuild
- **hero (`renderToolOrders`)** เพิ่ม "อัตราแมท %" (matched/checked) ข้างยอดออเดอร์รวม เมื่อมี recon results
- **ของเดิมที่เอาออกจาก board:** totals hero ซ้ำ · stacked bar สัดส่วนสถานะ · การ์ด status grid · `ordRenderMonth` embed (ฟังก์ชันยังอยู่ แต่ board ไม่เรียกแล้ว)
### 2026-06-26 — Orders redesign Phase 3: ปฏิทินสถานะนำเข้า + สิ่งที่ต้องทำ + ตารางไม่แมท (polish ตามดีไซน์)
- **เลิกฝัง `ordRenderRecon` (สไตล์เก่า) ในหน้าสรุปภาพรวม** → สร้างสามส่วนใหม่ตามดีไซน์ใน `ordRenderBoard`:
  - **ปฏิทินสถานะนำเข้า** (ต่อแพลตฟอร์ม, repeat(3,1fr)): สีวันจาก `ordReconCoverage` bsMax/beMax → `isoDay()` แปลงเป็นวันของเดือนปัจจุบัน · เขียว=ครบ2ระบบ(d≤bsDay&&d≤pfDay) · ส้ม=เหลือ BS(pf only) · ฟ้า=เหลือแพลตฟอร์ม(bs only) · เทา=ยังไม่นำเข้า · วันนี้มี ring · badge "ต่าง N วัน"
  - **สิ่งที่ต้องทำต่อ** (แผงขวา): ต่อช่อง คำนวณ bsGap/pfGap จาก todayDay · ok=gap≤1 (เขียว ✓) ไม่งั้น(ส้ม !) + ปุ่ม "นำเข้า" → `ordReconUpload()` (เหลือแพลตฟอร์ม) / `ordUploadFiles()` (เหลือ BS) + ปุ่ม "นำเข้าข้อมูลเพิ่มเติม"
  - **รายการที่ไม่แมท**: ตาราง grid 6 คอลัมน์ (วันที่/ช่องทาง badge/เลขออเดอร์/ประเภท badge/ยอด/ปุ่มเปิด) จาก res only_be+only_bs · เปิด → `ordSet('q', order_no)` · cap 50
- **action bar:** อัปไฟล์หลังบ้าน (`ordReconUpload`) + สร้างใบกระทบยอด (`ordReconGenReports`) + ประวัติรายงาน (`ordReconToggleHistory` → `ordReconHistoryHtml`) + busy loader
### 2026-06-26 — Orders redesign Phase 4: hero/toolbar/chart ตรงดีไซน์เป๊ะ
- **hero:** subtitle "กระทบยอด BigSeller (หน้าบ้าน) ↔ แพลตฟอร์ม e-commerce..." + ปุ่มสลับบริษัท M Bark/Benya (`setCompany`) + ช่วงข้อมูล (min–max order_date) + อัตราแมท % · เอา "ออเดอร์รวม" ออก
- **เอา KPI strip ออก** (คำสั่งซื้อ/ต้องดำเนินการ/รอเทียบ/ปิดงาน) — ดีไซน์ไม่มี
- **toolbar ใหม่:** tabs (สรุปภาพรวม/รายละเอียดการขาย) ซ้าย + **dropdown นำเข้าข้อมูล** (BigSeller=`ordUploadFiles` · แพลตฟอร์ม=`ordReconUpload`) + **dropdown ส่งออก** (ยังไม่คีย์ IV=`ordExportNoIv` · ใบกระทบยอด=`ordReconGenReports`) + ล้างทะเบียน · เปิด/ปิดผ่าน `ordMenu(v)`/`d._menu` + overlay click-outside
- **date-range chips** (ทั้งหมด/วันนี้/7วัน/เดือนนี้) `ordSetRange`/`d.dateRange` → `ordRangeBounds` กรอง active+res ใน board (เฉพาะแท็บ board)
- **กราฟกระทบยอดต่อแพลตฟอร์ม 4 รูปแบบ** `ordReconChart(cov,mode,fmt,pAgg)` toggle ก/ข/ค/ง (`ordReconViz`/`d.reconViz` default 'b'): **ก**=แท่งเต็ม+legend นับ · **ข**=กระจาย (กล่องกลางเขียว) · **ค**=กึ่งกลาง (แพลตฟอร์ม◀ ... ▶BigSeller) · **ง**=โดนัท conic-gradient %แมท + badge
- **คลิกเด้งดีเทล:** การ์ด KPI แพลตฟอร์ม → `ordPlatGo(p)` (view='reg' + d.fPlatform) · รายการไม่แมท "เปิด" → `ordSet('q',order_no)`
- **gotcha:** perPlat สร้างก่อน calendar → อย่าอ้าง `monthLabel`/`todayDay` ใน perPlat (TDZ)
- **ยังไม่ทำ:** กรอง register ตาม `d.fPlatform` จริง (ตอนนี้แค่ navigate) · restyle ตาราง register ตามดีไซน์ · count/amount display toggle

### 2026-06-24 — Orders ตรวจ IV: รื้อ flow เป็น checklist + เปรียบเทียบยอดสูตรเต็ม + UI ทางการ
- **ปัญหาเดิม:** ปุ่ม "Tag IV ที่ยังว่าง (N)" tag ทั้งหมดทันทีไม่ confirm รายตัว · เคสที่ 723-5 ยอดต่างจาก order_total จะถูก overwrite sale_amount เงียบๆ · ไม่มีฟิลเตอร์/sort/checkbox · เคส 0/0 ที่ user ไม่เชื่อใจถูก mark "ตรงแล้ว" อัตโนมัติ
- **สูตรเทียบยอดใหม่** (`ordIvAnalyze` — `orderCurrent(o)`): ถ้าออเดอร์มี `sale_amount` แล้ว → ใช้ตรง · ถ้ายังไม่ tag → **`order_total + shipping_fee`** (ไม่หักส่วนลด · platform ชดเชยให้ผู้ขาย IV ยังเต็มยอด) · เก็บ `currentBase`/`currentShip`/`currentDisc`/`currentFromSale` ในแต่ละ result ไว้โชว์ breakdown ในตาราง
- **★ ห้ามใช้ `order_total - seller_discount`** — ก่อนหน้าเคยใส่ผิด ถูกผู้ใช้แก้ทันที (ในไฟล์ตัวอย่าง: order_total 500 + ลด 50 → IV 500 = ตรง · ถ้าหักลดจะกลายเป็น diff -50 ทั้งที่จริงตรง)
- **แยก status `new` เป็น 3 buckets:**
  - `new_match` ยอดตรง |diff|<0.01 — auto-tick · พร้อมบันทึก
  - `new_zero` 723-5=0 **และ** BigSeller=0 — ไม่ tick · รอ user ตัดสินใจ (เคสที่ user ไม่เชื่อใจ)
  - `new_diff` ยอดต่าง — ไม่ tick · รอ user รีวิว
- **UI ใหม่ทั้งแท็บ (`ordRenderIv`):**
  - KPI strip **6 ใบ** คลิกกรอง: ทั้งหมด · ยอดตรง · ยอด 0/0 · ยอดต่าง · ตรงแล้ว · ต้องตรวจ (รวม voided+diff+conflict+orphan)
  - Filter chips **"แพลตฟอร์ม E-commerce"** (SHOPEE/TIKTOK/LAZADA/ออฟไลน์/อื่นๆ) นับจริงจาก `r.platform` (เก็บ `ordChannelGroup(channel,customer)` ใน analyze)
  - Date range วันที่ IV from/to · search box ค้นหา IV/order_id/ลูกค้า
  - คอลัมน์ **checkbox หน้าสุด** + master checkbox ติ๊กทุก visible-taggable · คลิกหัวคอลัมน์ sort ↑↓ (doc_date/iv_no/ref/customer/total/cur/diff/_status)
  - คอลัมน์ **"ระบบ BigSeller"** (rename จาก "ในทะเบียน") โชว์ breakdown 2 บรรทัด: ยอดรวม + `380 + ส่ง 10` (transparent) · ถ้า `sale_amount` แล้ว → โชว์ "(sale_amount เดิม)"
  - คอลัมน์ **"ส่วนต่าง"** แยก sort ได้ · "ตรง" สีเขียวสำหรับ new_match · "+50" สีเขียว / "-30" สีแดง สำหรับ diff
  - คอลัมน์ **"ลูกค้า / แพลตฟอร์ม E-commerce"** (rename "ช่องทาง" → "แพลตฟอร์ม E-commerce" — **เฉพาะ heading/label** · ค่าจริง SHOPEE/TIKTOK/LAZADA คงเดิม)
- **Action bar ใหม่:**
  - "เลือกตามเงื่อนไข:" + ปุ่ม "เลือกยอดตรง / เลือกยอด 0/0 / เลือกยอดต่าง / สลับการเลือก / ยกเลิกการเลือก" (`ordIvCheckAuto('match'|'zero'|'diff'|'invert'|'none')`) — ทำกับแถวที่ filter ปัจจุบัน
  - **"บันทึก Tag IV ที่เลือก (N)"** (`ordIvApply('tagSelected')`) confirm พร้อม breakdown: ยอดตรง X · ยอด 0/0 Y · ยอดต่าง Z + ตัวอย่าง 5 รายการแรก
  - "ยกเลิกออเดอร์ที่ Voided" + "ปรับยอดให้ตรงรายงาน"
  - **"ส่งออก Excel (N)"** (`ordIvExport`) — export filter ปัจจุบันเป็น xlsx 15 คอลัมน์ (วันที่ · IV · order_id · ลูกค้า · แพลตฟอร์ม · ยอด 723-5 · BigSeller breakdown 4 คอลัมน์ · ส่วนต่าง · IV เดิม · สถานะ)
- **State (`d.ivCheck`):** `checked Set<iv_no>` (เก็บ iv_no ที่ติ๊ก) · `filter/platform/dateFrom/dateTo/q/sortKey/sortDir` · auto-init `checked` = new_match ทุกตัวตอน upload + reset เป็น new_match ใหม่หลัง apply (re-analyze)
- **`ordIvFiltered(ic)` helper** — รวม filter+sort logic ใช้ทั้ง render/export/toggleAll · default sort = ตามความเร่งด่วน (conflict→diff→voided→orphan→new_diff→new_zero→new_match→matched)
- **สำนวน UI ทางการ:** เลิกใช้ "ติ๊ก" → ใช้ "เลือก" ทั้งหมด ("ติ๊กไว้" → "เลือกไว้ N รายการ" · "ล้างติ๊ก" → "ยกเลิกการเลือก" · "Tag IV ที่ติ๊ก" → "บันทึก Tag IV ที่เลือก" · "Cancel voided" → "ยกเลิกออเดอร์ที่ Voided" · "แก้ยอด diff เดิม" → "ปรับยอดให้ตรงรายงาน")
- **กระทบหน้าอื่น = 0** — เปลี่ยนชื่อ "ช่องทาง" → "แพลตฟอร์ม E-commerce" เฉพาะใน `ordRenderIv` · ไม่กระทบ ord*/bs*/exk*/armap* อื่น
- **gotcha:** `ordIvApply` mode เก่า `tagNew` ถูกแทนด้วย `tagSelected` (ใช้ checked Set) · `fixDiff`/`cancelVoided` คงเดิม · ปุ่มเก่า "Tag IV ที่ยังว่าง (N)" ถูกถอด — ถ้า user คิดถึงพฤติกรรมเดิม (tag ทุก new ทันที) ให้กด "เลือกยอดตรง" + "เลือกยอด 0/0" + "เลือกยอดต่าง" แล้วบันทึก

### 2026-06-24 — Bank Recon Phase B: Import Batch + History
- **เป้าหมาย:** ทุกครั้งที่อัปไฟล์ (Express XML / Statement) → สร้าง **Import Batch** ที่อ่านชัด · เก็บสถิติเต็ม · ดูประวัติย้อนหลังได้
- **`supabase/bankrec-phase-b-batch-history.sql`** (deploy แล้ว · idempotent):
  - `ALTER TABLE brec_imports ADD COLUMN IF NOT EXISTS`: `batch_no text`, `rows_added int`, `rows_dup int`, `rows_ambiguous int`, `rows_failed int`, `uploader_email text`, `summary_json jsonb`
  - `CREATE UNIQUE INDEX uq_brec_imports_batch_no` ON `(company_id, batch_no)` WHERE `batch_no IS NOT NULL AND deleted_at IS NULL`
  - `CREATE INDEX idx_brec_imports_created` ON `(company_id, created_at DESC)` WHERE `deleted_at IS NULL` (สำหรับ list history เร็ว)
- **Batch No format:** `IMP-{SRC}-YYYYMMDD-NNN` — เช่น `IMP-EXP-20260624-001` / `IMP-SCB-20260624-002` / `IMP-BBL-20260624-003`
  - **`brecBatchPrefix(source, bankCode)`** — express → "EXP", bank → bank_code uppercase (SCB/BBL/KBANK ...)
  - **`brecMakeBatchNo(co, prefix)`** — query `batch_no LIKE 'IMP-{prefix}-{ymd}-%'` → max sequence + 1 → pad 3 หลัก
- **`brecUpload` ใหม่ — เพิ่ม:**
  - generate batch_no ก่อน insert · `AUTH.email` เป็น uploader_email · finalStatus = `ambigCount?'warning':'success'`
  - INSERT `brec_imports` พร้อม batch_no + rows_added + rows_dup + rows_ambiguous + rows_failed=0 + summary_json (bank_code/account_no/file_size/file_rows)
  - หลัง insert row จริง: ถ้า failHard|raceSkip → UPDATE rows_failed + rows_dup += raceSkip + status="failed" (กรณี hard fail)
- **`brecLoadHistory()`** — `SELECT … FROM brec_imports WHERE company_id=$co AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 200` · เก็บใน `d.history.list`
- **`brecRenderHistoryModal(d)`** — overlay modal (max-width 1080, click-outside ปิด) · ตาราง 9 คอลัมน์: Batch No · วันเวลา · ประเภท/บัญชี/ไฟล์ · ช่วง · รายการ · เพิ่ม · ซ้ำ · ⚠ (ambig/fail) · สถานะ (badge `.ord-bd ok/warn/danger/mute`) · ผู้อัป
- **ปุ่ม "📚 ประวัติ"** บน toolbar bankrec (ระหว่าง Export กับ ล้างแถวซ้ำ)
- **กระทบหน้าอื่น = 0** — Phase A insert ยังทำงาน (column ใหม่ทุกตัวมี default 0/false) · modal ใช้ HTML inline ไม่ต้อง CSS ใหม่ใหญ่
- **Phase ถัดไป (Phase C-F):** Removed-from-Source detection · Audit Trail · UI overhaul · Period Close · Snapshot Report

### 2026-06-24 — Bank Recon Phase A: Stable Transaction Key + Unique Constraint (แก้บั๊กรายการซ้ำเมื่อยกเลิก PS)
- **เป้าหมาย:** แก้บั๊กหลัก — เมื่อยกเลิก PS กลางงวดใน Express แล้วอัป XML ใหม่ → running balance ของรายการหลังเปลี่ยน → ลายเซ็นเดิมเปลี่ยน → ระบบนับเป็นรายการใหม่ทั้งหมด → false duplicate
- **`supabase/bankrec-phase-a-stable-key.sql`** (deploy แล้ว · idempotent + EXCEPTION-wrapped):
  - `ALTER TABLE` เพิ่ม `ambiguous boolean NOT NULL DEFAULT false` ทั้ง `brec_express_rows` + `brec_bank_rows`
  - cleanup duplicates เก่า: PARTITION BY stable key cols + ORDER BY (has_match DESC, created_at ASC) keep first, soft-delete ที่เหลือ
  - `CREATE UNIQUE INDEX uniq_brec_ex_stable` ON `(bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,''))` WHERE `deleted_at IS NULL AND ambiguous=false`
  - `CREATE UNIQUE INDEX uniq_brec_bk_stable` ON `(bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,''))` WHERE `deleted_at IS NULL AND ambiguous=false`
  - partial index for ambiguous queries · NOTIFY pgrst
- **`brecRowSig(r, source)`** — เลิกใช้ `r.balance` (running balance) เด็ดขาด:
  - Express: `${txn_date}|${withdrawal}|${deposit}|${doc_no}`
  - Bank: `${txn_date}|${withdrawal}|${deposit}|${cheque_no}|${ref_note}`
- **`brecUpload` ใหม่ — 5 ขั้น:**
  1. detect ambiguous **ภายในไฟล์** (Map<stableKey, count> · keys ที่ count≥2 → ambiguous=true ทุกแถว)
  2. query DB เฉพาะแถว `deleted_at IS NULL AND ambiguous=false` → existSig Set
  3. categorize: ambiguous (insert ทั้งหมด flag=true) · dup (skip) · new (insert flag=false)
  4. **Import Result Summary** ครบ 4 บรรทัด — `confirm()` ก่อน insert: ไฟล์มี N · เพิ่มใหม่ X · ซ้ำเดิม Y · Ambiguous Z (พร้อมคำอธิบาย)
  5. insert chunked 500 + **fallback ทีละแถว** เมื่อ chunk fail · regex match `duplicate key|unique constraint|23505` = nigh race (skip ไม่ throw) · อื่นๆ log + count failHard
- **auto-match หลัง insert** — กรองเฉพาะ `!ambiguous` (matching รายการ ambiguous ต้องให้ user resolve ก่อน)
- **กระทบหน้าอื่น = 0** — `brec_matches` ตารางเดิม · `brecDedupExisting` (cleanup tool เก่า) ยังใช้ `brecRowSig` ใหม่ที่ไม่มี balance → ทำงานถูกขึ้น
- **gotcha:** หลัง deploy migration แล้ว ถ้า DB ของลูกค้าเก่ามี duplicate ที่ stable key ตรงกัน → DO $$ block soft-delete อันที่ unmatch หรือใหม่กว่า (เก็บ matched + oldest) · ดังนั้นข้อมูลเก่าจะถูก dedup ครั้งเดียวอัตโนมัติ ก่อน unique index จะถูกสร้าง
- **Phase ถัดไป (Phase B-F):** Import Batch History · Audit Trail · Removed-from-Source detection · UI overhaul (Action-oriented) · Period Close + Version · Snapshot Excel/PDF Report

### 2026-06-25 — Orders ตรวจ IV: รองรับ 141.RWT (ขายเงินเชื่อ) + smart diagnostics + detail panel
- **เป้าหมาย:** 723-5 มีแค่ยอดรวม ตรวจ diff ได้แต่ไม่รู้สาเหตุ — เปลี่ยนมาใช้ 141.RWT (รายงานขายเงินเชื่อ Express) ที่มี **line items + bill discount + VAT breakdown** ตรวจได้ลึกถึงสาเหตุ
- **`bmpParseExpressRwt141(text)`** — parser ใหม่สำหรับ 141.RWT (cp874 CSV, 16 columns):
  - Header row: `[ref, "", iv_no, date, customer, "", flag, "", "", bill_disc, "", goods_ex_vat, vat, total, due_date, so_no, cash_yn]`
  - Detail row (col 0 ว่าง + col 6 = line_no): `sku, name, qty, unit, unit_price, line_disc, line_amount`
  - คืน `{ivs:[{ doc_no, doc_date, total, ref_order_id, customer, channel (SHOPEE/TIKTOK/LAZADA/F), bill_disc, goods_ex_vat, vat, so_no, cash_yn, lines:[{sku,qty,unit_price,line_disc,line_amount}] }]}`
  - ผ่าน 899 IVs ในไฟล์ทดสอบจริง
- **`bmpDetectCsvType`** — เพิ่ม return type `"sales_rwt141"` (sig: `รายละเอียด...ราคาต่อหน่วย...จำนวนเงิน` ใน 4000 ตัวอักษรแรก)
- **`ordIvUpload`** — รับทั้ง 2 format · auto-detect ต่อไฟล์ · เก็บ `d.ivCheck.format = "sales"|"sales_rwt141"|"mixed"` · ต่อท้ายชื่อไฟล์ด้วย "(141.RWT)" ถ้า detect ได้
- **`ordIvAnalyze`** — ส่ง iv-source fields ผ่านเข้า result: `r.ivLines`, `r.ivBillDisc`, `r.ivGoodsExVat`, `r.ivVat`, `r.ivSoNo`, `r.ivCashYn` (null ถ้า 723-5)
- **`ordIvDetailPanel` ส่วน Express row — รื้อใหม่:**
  - ถ้า `hasIvLines` (141.RWT): แสดง header (เลข IV · วันที่ · SO · เก็บเงิน Y/N) + แต่ละ line item (` ↳ บรรทัด N | sku | qty | unit_price | line_disc | net | — | net `) + แถวหักส่วนลดบิลรวม (ถ้ามี) + แถวรวมทั้งสิ้น IV
  - ถ้า 723-5: แสดงแค่ "ยอดรวม IV · 723-5 มีเฉพาะยอดรวม ไม่แยกบรรทัด · ใช้ 141.RWT แทนเพื่อเห็นบรรทัด"
- **Smart diagnostics (Phase D)** — เพิ่ม `smartTip` ในกล่อง verdict (พื้นเหลือง):
  - **ส่วนลดทับซ้อน:** ถ้า IV ใส่ทั้ง line discount + bill discount (ทั้งคู่ > 0) → tip บอกผลรวมส่วนลดเกินจริง + แนะนำให้ลบบิลรวมออก + แก้ line discount = `bs.seller_discount`
  - **ส่วนลดไม่ครบ/เกิน:** ถ้ารวมส่วนลด IV ≠ `bs.seller_discount` → tip บอกต่างเท่าไหร่ + แนะนำให้แก้
  - **SKU ไม่ตรง:** เทียบ ivLines.sku (กรอง SH/SP1 = shipping ออก) vs bs.sku → tip บอกที่ขาด/เกิน
- **กระทบหน้าอื่น = 0** — parser/analyze/render ทั้งหมดอยู่ใต้ ord_iv* · 723-5 เก่ายังใช้ได้ (backward compat) · ผู้ใช้สลับใช้ format ใดก็ได้
- **gotcha:** Phase A parser ของ 723-5 (`bmpParseSalesReport`) ยังต้องเก็บไว้ — บางคนอาจยังมีไฟล์ 723-5 เก่า · `ordIvUpload` auto-detect แล้วเรียก parser ที่เหมาะสม

### 2026-06-24 — Orders: แท็บใหม่ "🧾 ตรวจ IV" (อัปรายงานขาย 723-5 → tag IV + validation + coverage)
- **เป้าหมาย:** ให้รู้ว่า "IV เลขที่อะไรคือคำสั่งซื้ออะไร · คีย์ไปแล้วเท่าไหร่ · ออเดอร์ทั้งหมดมี IV กี่ตัว · สถานะถึงขั้นไหน" — แยกออกจาก Marketplace upload flow ที่ต้องอัป 3 ไฟล์พร้อมกัน
- **`ordIvAnalyze(salesData, rows)`** — pure function · classify IV ใน 723-5 vs `order_ledger` เป็น 6 สถานะ: `new` (จะ tag), `matched` (iv ตรง+ยอดตรง), `diff` (iv ตรงแต่ยอดต่าง), `conflict` (IV ทับเลขเดิม หรือ ref ตรงแต่ ord มี iv อื่น), `voided` (ขึ้นต้น *), `orphan` (ref ไม่มีออเดอร์ match) · index ตาม order_id + iv_no (กัน iv ทับ) · coverage check (gapBefore/gapAfter — ออเดอร์ที่ก่อน/หลังช่วงรายงานที่ยังไม่มี iv)
- **`ordIvUpload()`** — file picker รับหลายไฟล์ CSV → `bmpDecodeCp874` + `bmpDetectCsvType` (reject ถ้าไม่ใช่ "sales") → `bmpParseSalesReport` (reuse parser เดิม) → dedupe by `doc_no` → `ordIvAnalyze` → เก็บ `d.ivCheck` · auto switch view='iv'
- **`ordIvApply(mode)`** — เขียน DB · 3 mode (confirm ก่อนทุกครั้ง):
  - `tagNew` → update `iv_no`/`iv_date`/`sale_amount`/`sale_keyed_at`/`sale_src='ตรวจ IV (723-5)'` ลง order ที่ status='new'
  - `cancelVoided` → set `status='cancelled'` ให้ order ที่ map กับ IV voided (เสนอยืนยันก่อนเสมอ ไม่ auto)
  - `fixDiff` → update `sale_amount` ให้ตรงกับยอดใน 723-5
  - หลังบันทึก `ordLoad(true)` + analyze ใหม่จาก rows ล่าสุด · alert จำนวนสำเร็จ/ล้มเหลว
- **`ordRenderIv(d)`** — UI · empty state (อธิบาย 3 หน้าที่หลัก) + busy + error + เนื้อหา: KPI 5 ใบ override grid-template (`1.3fr 1fr 1fr 1fr 1fr`): ทั้งหมด (brand) · Tag ใหม่ได้ (info) · ตรงแล้ว (ok) · Voided (warn) · ต้องตรวจ (red) คลิกกรองได้ · coverage warning (พื้น amber) ถ้ามี gap · 3 batch action button (tagNew/cancelVoided/fixDiff) ในแถวเดียวกับ filter label · ตารางสถานะรายตัว (วันที่/IV/ref/ลูกค้า+ช่อง/ยอด 723-5/ยอดในทะเบียน+diff/badge) + legend อธิบาย 6 สถานะท้ายตาราง
- **แท็บใหม่ใน `renderToolOrders`** — `🧾 ตรวจ IV` (5th tab) · count chip warn (เลขรายการที่ต้องดำเนินการ = new+diff+conflict+voided+orphan)
- **กระทบหน้าอื่น = 0** — ใช้ `bmpParseSalesReport`/`bmpDecodeCp874`/`bmpDetectCsvType`/`ordLoad` ที่มีอยู่แล้ว · ไม่แตะ schema · CSS reuse `.ord-page` tokens
- **gotcha:** ทำงานเฉพาะ csv 723-5 standalone — ถ้าอยากให้ผูกกับ Marketplace upload flow อัตโนมัติ ต้อง wire เพิ่มใน `bmpRunUpload`

### 2026-06-24 — Orders page UI redesign (Finance OS style) + design system mockups
- **เป้าหมาย:** รื้อ UI หน้าทะเบียนคำสั่งซื้อ ให้ดู Modern Financial Console (อิงสไตล์ Water POG) · ยังไม่แตะ logic/data flow
- **Design system (`for-design/finance-os/`)** — Brand Palette + Design Tokens + 5 mockup HTML (Dashboard / Work Queue / Detail / Data Table / Report PDF Preview) · ใช้เป็น reference เวลา redesign หน้าอื่น · เปิดดูที่ `/for-design/finance-os/index.html` · `data-co="benya|mbark"` สลับธีม teal ↔ navy ใน tokens เดียวกัน
- **`ordInjectStyle()`** — design tokens scoped ใต้ `.ord-page` (ไม่กระทบ CSS หน้าอื่น): `--ok/-wn/-dg/-in/-n-*` palette + hero band + KPI gradient/soft variants + tabs + table + badge dot+label + chips + funnel rows + empty state
- **`renderToolOrders`** — รื้อ shell ใหม่: Hero band (gradient ตาม `--brand` + watermark โลโก้จาง + ชื่อหน้า TH/EN + ยอดออเดอร์รวมขวา) · search box clean · action bar `.ord-btn` + lucide icon · **KPI strip 4 ใบ hierarchy** (brand gradient=ทั้งหมด · soft-red=ต้องทำ · soft-amber=รอเทียบ/หลังบ้านขาด · soft-green=ปิดแล้ว%) คลิกได้ทุกใบ · tabs underline + count chip warn/danger
- **`ordKpis(d)`** — helper คำนวณ 4 KPI จาก rows + rmap: totN/totSum, actN/actSum (recon_diff+wait_iv), flowN, doneN/doneSum, onlyBe, pct
- **Sub-renderers ใช้ tokens ใหม่:**
  - `ordRenderBoard` → `.ord-fn` funnel rows + ic-w สีต่อ status + sticky header uppercase + total row
  - `ordRenderRegister` → `<table>` + `.ord-bd` status badge (dot+icon+label) ไม่พึ่งสีอย่างเดียว · mono สำหรับ order_id/IV · filter `.ord-chip`
  - `ordRenderRecon` → KPI strip 4 ใบ (soft variants ตาม filter) + table แบบเดียวกับ register
  - `ordRenderMonth` → `.ord-card` wrap + แท่งสองชั้น (โปร่ง 33%/border + ทึบ ksum) ขอบมน 8px
  - `ordRenderSearch` → `.ord-sr` result card · header pill + 5-col grid keys + status badge
- **กระทบหน้าอื่น = 0** — CSS scoped ใต้ `.ord-page` ล้วน · function data ไม่แตะ (ordGet/ordSet/ordFiltered/ordSetView/ordReconMap คงเดิม)

### 2026-06-24 — Order Pipeline redesign (Stage 1: schema) — ยุบ order master เดียว + recon ครบสาย
- **เป้าหมาย:** ทะเบียนคำสั่งซื้อ = hub งานด้านรับทั้งสาย (ออเดอร์→ตรวจ BigSeller↔หลังบ้าน→คีย์ IV→รับชำระ→เงินเข้าแบงค์) เกาะออเดอร์เดียว timeline เดียว · export AutoKey ทุกสเตป
- **ตัดสินใจ:** ยึด BigSeller `orders`/`order_items` เป็น **order master เดียว** (deprecate `order_ledger`) · รายงานหลังบ้าน Shopee/TikTok/Lazada = แหล่ง recon
- **Cardinality (เจ้าของยืนยัน):** 1 Order = 1 IV = 1 RE เป๊ะ → flat columns บน `orders` · มีแค่ฝากเช็ค 1 BQ : หลายเช็ค → ใช้ `brec_mp_*` เดิม
- **กฎ recon (strict 0):** เทียบ gross + ค่าส่ง + ส่วนลด + SKU×qty · order_no ตรงเป๊ะ · **gross BigSeller = `ราคาสินค้าเดิม` ?? `ราคา`** (คีย์มือ FACE/LINE/Dealer ใช้ `ราคา`) · หลังบ้าน gross: Shopee=`ราคาขายสุทธิ`, TikTok=`SKU Subtotal Before Discount`, Lazada=`unitPrice`×แถว · ค่าส่ง: Shopee=`ค่าจัดส่งที่ชำระโดยผู้ซื้อ`, TikTok=`Shipping Fee After Discount`, Lazada=`shippingFee`
- **Schema** `supabase/orders_pipeline.sql` (Stage 1, deploy แล้ว · idempotent + EXCEPTION-wrapped · ตั้งชื่อ sort หลัง orders.sql): ขยาย `orders` (iv/re/bq/bank/recon/gross/source_type/approval cols) + `order_items` (returned_qty/refund/net_qty) + ตารางใหม่ `order_recon_runs`/`order_recon` (แช่ 2 ฝั่ง กู้คืนได้)/`import_column_map` (learned header map)/`shop_registry` (ร้าน→บริษัท)/`order_adjustments` (platform ปรับย้อนหลัง) + เพิ่ม col `order_events` (company/order_no)
- **`orders`/`order_items` สร้างจากแอป (ไม่มี migration เดิม)** → ไฟล์นี้ใส่ `CREATE TABLE IF NOT EXISTS` baseline กัน clone ใหม่พัง
- **แผนเต็ม + UI mockup + คอลัมน์จริงทุกช่อง:** `for-design/order-pipeline/` (PLAN.md, schema-draft.sql, channel-field-map.md, recon-mockup.html)
- **Stage 2 (deploy แล้ว) — parse ไฟล์ BigSeller จริง + แยกบริษัทอัตโนมัติ:** แก้ `ORD_CH` (sig "ร้านค้า BigSeller"→**"ร้านค้าเพลตฟอร์ม"** ตามไฟล์จริง · เพิ่ม `gross`/`sku`/`shop`/`cancel` · `perUnitPrice` สำหรับ BigSeller ราคาต่อหน่วย×qty) · `ordParseSalesFile` เก็บ shop/gross/sku, ตัด filter platform เดิม (BigSeller = master ทุก platform), channel_group ต่อออเดอร์จาก platform จริง · helper `ordShopCompany` (ชื่อร้าน→บริษัท จาก `bsSeedShopBrand`+`BMP_SHOP_ROUTING`+brand fallback) + `ordSplitByCompany` · `ordUploadFiles` นำเข้าเฉพาะบริษัทปัจจุบัน, ข้าม+นับของอีกบริษัท, เตือนร้านที่ไม่รู้จัก · ทั้งหมดอยู่ใน `ord*` ไม่แตะ bsImport/exportkey/armap · **ยังเขียนลง `order_ledger`** (ยังไม่ย้ายไป `orders`)
- **Stage 3 (deploy แล้ว) — UI แท็บในหน้าทะเบียนคำสั่งซื้อ:** `renderToolOrders` รื้อเป็นระบบแท็บ + ช่องค้นหา global บนสุด · helper `ordStatusOf(o)` (สถานะจากคอลัมน์ lifecycle: wait_iv→wait_pay→wait_re→wait_deposit→wait_bank→done) + `ORD_STATUS` meta · แท็บใหม่: **สรุปสถานะงาน** (`ordRenderBoard` funnel count+ยอด คลิกกรอง · ยังไม่รวม recon) · **ทะเบียน** (`ordRenderRegister` ตารางเดิม + คอลัมน์สถานะ + filter สถานะ) · **สรุปรายเดือน** (`ordRenderMonth` กราฟแท่ง CSS ต่อแพลตฟอร์ม เต็มแท่ง=ทั้งหมด ทึบ=คีย์ IV) · **ค้นหา** (`ordRenderSearch` พิมพ์ order/IV/RE/BQ/เช็ค → การ์ด + timeline) · แท็บ "ตรวจรายวัน" disabled placeholder · ทดสอบ runtime ผ่าน preview (ทุกฟังก์ชัน parse+รันไม่ error) · **ยังเขียน/อ่าน `order_ledger`**
- **Stage 4 (deploy แล้ว) — แท็บตรวจรายวัน (Recon) + fix pagination + items + cleanup:** `ordRunRecon` เทียบ order_ledger ↔ ไฟล์หลังบ้าน (scope: channel+ช่วงวันของไฟล์) → `matched`/`only_be`(ขายคีย์ไม่ครบ)/`only_bs`/`diff` · `ordReconDiffs` เทียบ gross(`ordGrossVal`=Σ items price×qty)/ค่าส่ง/ส่วนลด/`ordSkuSig`(sku×qty เรียง) strict 0 · `ordRenderRecon` (การ์ดสรุป+ตาราง+export only_be) · helper เพิ่ม: `ordItemsTable` (รายสินค้าใน timeline) · `ordIsLabelOrder` (ข้ามใบปะหน้า/LABEL ยอด0) · `ordUnknownPanel` รายออเดอร์+`ordAssignOrder`(รายตัวข้ามบริษัท+จำ SKU)/`ordRemoveUnknownOrder` · `ordResetLedger` (ล้างเริ่มใหม่) · **★ fix: `ordLoad`/`homeLoadStats` แบ่งหน้า `.range()` (Supabase cap 1000 แถว/query → กระดานเคยโชว์แค่ 1000 ทั้งที่มี 1423)** · insert ทนทาน (chunk พังลองทีละแถว) · order_ledger.items jsonb (migration)
- **Stage 5 (deploy แล้ว) — Recon = Reconciliation Log จริง (บันทึก DB สะสม + coverage):** `ordReconSave` เก็บผลลง `order_recon` **ราย order_no สะสม** (อัปช่อง/วันใหม่ ลบเฉพาะ order_no ในรอบนั้นแล้ว insert ใหม่ — ของช่อง/วันอื่นคงไว้) · `ordReconLoad` โหลดทั้งหมดของบริษัทตอนเข้าหน้า (gate `d.reconLoaded`) → refresh/ออกหน้าแล้วผลยังอยู่ · `ordReconCoverage`/`ordReconCoverageHtml` ตารางสรุปต่อแพลตฟอร์ม: **BigSeller ถึงวันที่** (max order_date ใน order_ledger) · **หลังบ้านถึงวันที่** (max date ใน recon) · ตรวจแล้ว/BigSeller ขาด(only_be)/หลังบ้านขาด(only_bs)/ยอดไม่ตรง(diff) · `ordIsLabelOrder` ขยายจับแถว header/เทมเพลต ("Platform unique order ID", "Platform product name") กรองออกจาก recon · `ordNormSku` STR→SBR (Betra) · Lazada ใช้ `unitPrice` · เทียบ **ยอดสุทธิ** (order_total) ไม่ใช่ gross แยกส่วนลด
- **Stage 6 (deploy แล้ว) — ผูก recon เข้าสรุปสถานะงาน (board):** `ordReconMap(d)` (order_no→recon status) · `ordStatusOf(o, reconMap)` เพิ่มมิติ recon ก่อน lifecycle: `diff`→`recon_diff`(ยอดไม่ตรง) · `matched`+ไม่มี iv→`wait_iv` · ช่อง SP/TT/LZ ที่ยังไม่เทียบ→`recon_pending`(รอเทียบยอดขาย) · manual/มี iv→lifecycle เดิม · ORD_STATUS เพิ่ม recon_pending/recon_diff บนสุด · board เพิ่มแถว `only_be` (หลังบ้านมี · BigSeller ขาด — คลิกไปแท็บ recon filter only_be) · ทุก caller (ordFiltered/Board/Register/Search) ส่ง rmap
- **Stage 7 (deploy แล้ว) — Sales Reconciliation Report (ใบกระทบยอด snapshot ล็อก + Excel/PDF + ประวัติ):** ตาราง `recon_reports` (`supabase/recon-reports.sql`: report_no/platform/date range/summary jsonb/snapshot jsonb/status/version · ปิด RLS) · `ordReconGenReports` แยก 1 ฉบับ/แพลตฟอร์ม จากผลตรวจปัจจุบัน → freeze summary+snapshot (matched/only_be/only_bs/diff) เป็นหลักฐาน ไม่เปลี่ยนแม้อัปใหม่ · report_no `SRR-{PLATFORM}-{YYYYMMDD}-{seq}` · `ordReconReportExcel` (multi-sheet: Summary หัวรายงาน+สรุป+ช่องเซ็น / Matched / Missing in BigSeller / Missing in Platform / Amount Differences · autofilter) · `ordReconReportPdf` (เปิดหน้าต่างรายงานทางการ → print/save PDF · หัว+box สรุป+ตาราง+ช่องเซ็น) · ประวัติ `ordReconReportLoad`/`ordReconHistoryHtml` (ปุ่มสร้างใบกระทบยอด/ประวัติรายงาน ในแท็บ recon) · download ซ้ำได้
- **Stage ถัดไป (ยังไม่ทำ):** report versioning (REV/v2) + status workflow (draft/reviewed/approved) + ลายเซ็นชื่อจริง · resolve workflow ราย order (Matched/Pending/Ignored/Adjusted + note + lock บน `order_recon`) · ผูก recon เข้าสรุปสถานะงาน (board แสดง BigSeller ขาด/หลังบ้านขาด/ยอดไม่ตรง) · จัดประเภท/Exclude non-sales (Platform Fee/Voucher/Refund) เก็บเป็นหลักฐาน · batch import history (`order_recon_runs`) · order_events log + timeline · IV validation (อัป 723-5) · ย้าย order master เป็น `orders` + export AutoKey + header learned-mapping (`import_column_map`) + UI ระบุร้าน (`shop_registry`) · Recon engine + แท็บตรวจรายวัน · IV validation + AR + status board + กราฟรายเดือน + global order search · export AutoKey (reuse `exkExport`)

### 2026-06-23 — Cash Flow Forecast (Staff) = รายงานสะอาดเหมือน snapshot (default) + ซ่อนของวิเคราะห์
- **เจ้าของสั่ง:** หน้า Cash Flow พนักงานบนจอ ให้หน้าตา**เหมือนสแนปชอต** (รายงาน "ประมาณการรายรับ-รายจ่าย" ที่ส่ง LINE) เลย์เอาต์เดียวกันเป๊ะ
- **ดึง HTML รายงานเป็นฟังก์ชันใช้ร่วม** — `cffStaffReportInner(co, dt, R)` (หัวแบรนด์ gradient + ตาราง pivot ธนาคาร เงินคงเหลือใช้ได้/ถึงกำหนด/หมวด/สุทธิ + ตารางรายละเอียดรายจ่าย) + `cffStaffComputeReport(d, dt)` (คำนวณ filtered/cats/bankDue/bankCat/opening/totalDue/netCash/periodLabel) · **ทั้ง `renderToolCashflowStaff` (หน้าจอ) และ `cffOpenSnapshotStaff` (modal export) เรียกตัวเดียวกัน** → เหมือนกันตลอด แก้ทีเดียว
- **หน้าจอ default = รายงานสะอาด** ใน `<div id="cffStaffReportSheet">` (**เต็มความกว้างหน้า** — เดิม cap 1040px กึ่งกลางดูเหมือนรูปแปะ) · **แถบเลือกรอบจ่าย (วันชำระเงิน) ย่อ/ขยายได้** ปุ่มอยู่ขวา (`cffToggleStaffFilter`, `d.staffFilterOpen` default ขยาย · ย่อแล้วโชว์ป้ายงวดข้างหัว) · ของวิเคราะห์เดิม (KPI 5 ใบ · ไฮไลต์สำคัญ · Cash Bridge · ไทม์ไลน์รอบจ่าย) **ห่อด้วย `${detailOpen ? ... : ''}` ซ่อนเป็นค่าเริ่มต้น** — ปุ่ม "รายละเอียดเพิ่มเติม" บนหัว (`cffToggleStaffDetail`, state `d.staffDetailOpen`)
- **เอาตารางหมวดแบบ accordion เดิมทิ้งทั้งก้อน** (ที่มีปุ่มถังขยะ skip รายวัน) — เจ้าของสั่งเอาออกให้เหมือน snapshot เป๊ะ · ปุ่ม Snapshot ย้ายขึ้นหัว · **แถบ "คืนค่า"** รายการ recurring ที่เคย skip ยังอยู่ (กันของค้างหาย) · `cffSkipRecurring` ยังมีอยู่แต่ไม่ถูกเรียกจากหน้านี้แล้ว
- **gotcha:** on-screen ใช้ id `cffStaffReportSheet` (ไม่ใช่ `cffSnap`) — กันชนกับ modal export ที่ `cffExportSnap` หา `getElementById("cffSnap")` · report periodLabel ใช้ "ทั้งหมด" ล้วน (ไม่มีช่วงวันต่อท้าย) ให้ตรง snapshot
- **(เพิ่มรอบเดียวกัน) ชิปด่วน + ย่อ/ขยายกลุ่มค่าใช้จ่าย:**
  - **ชิปด่วนวันชำระเงิน** "สัปดาห์นี้ / สัปดาห์หน้า / ถึงสิ้นเดือน" → `cffSetStaffQuick(kind)` ตั้ง `staffMode='range'` + from/to (คำนวณ local date กัน TZ: สัปดาห์ = จันทร์–อาทิตย์ `(getDay()+6)%7`, ถึงสิ้นเดือน = `new Date(Y,M,0)`) + `d.staffQuick` ไว้ไฮไลต์ชิป · `cffSetStaffAll/Day/Range` เคลียร์ `staffQuick`
  - **กันจอกระพริบตอน toggle/filter:** เดิมทุก toggle เรียก `renderToolCashflowForecast()` → โชว์ "กำลังโหลด..." + `await cffLoad()` (โหลด Supabase ใหม่) ทุกครั้ง = กระพริบ · แก้: helper `cffRerender()` ตั้ง `d._uiOnly=true` → render เช็ค `uiOnly = d._uiOnly && d.data` แล้ว **ข้าม skeleton + ข้าม cffLoad** (ใช้ data เดิม สลับ innerHTML ทีเดียว) · ใช้กับ toggle/filter ทั้งหมด (cffSetView/Staff*, cffToggleCat/BankTl/Round/StaffDetail, cffStaffCatToggleAll) · **ยัง reload จริง** เมื่อ: เข้าหน้าครั้งแรก (ยังไม่มี data), `cffSetHorizon` (ช่วงโหลดเปลี่ยน), `cffSkipRecurring`/`cffUnskipRecurring` (เขียน DB) · guard อยู่ใน render ทั้ง staff + exec (reset flag ทุกครั้ง)
  - **default (ยังไม่เลือก filter) ตัดที่สิ้นเดือนนี้ — ไม่รวมเดือนถัดไป:** เดิม `cffStaffPayments` gen recurring ถึงสิ้นเดือนถัดไป → "ทั้งหมด" นับ recurring ซ้ำ 2 เดือน (เช่นเงินเดือนโผล่ทั้ง 30 มิ.ย.+31 ก.ค.) ยอดเพี้ยน · แก้: helper `cffStaffEOM(dt)` (สิ้นเดือนนี้) + `cffStaffApplyFilter(payments,d,dt)` → โหมด `all`/default กรอง `due_date <= สิ้นเดือนนี้` (ยังเก็บรายการเลยกำหนดจากเดือนก่อน · เลือกช่วง/วัน/quick-chip เข้าเดือนถัดไปเองยังเห็น) · ใช้ทั้ง `renderToolCashflowStaff` (inline) + `cffStaffComputeReport` (snapshot) + cap `upcomingDates` chips ที่สิ้นเดือนนี้ด้วย
  - **กรุ๊ป 3 ชั้นในตารางรายละเอียด (ประเภท → เวนเดอร์ → รายการ):** ชั้นเวนเดอร์ใหม่ default **ย่อ** (เห็นชื่อ+จำนวน+ยอดรวม) · คลิกกาง `cffToggleVendor(cat,ven)` state `d.venOpen["cat|ven"]` (default closed = `===true` ถึงเปิด) · บรรทัดรายการ format **`เลขเอกสาร — คำอธิบาย`** (`cffDocCode(p)` = `p.detail`/เลขบิล · recurring(detail ว่าง) → "รอเอกสารตั้งหนี้" · `cffCleanDesc()` ตัดวันที่ ISO + รหัส PO/WO/IV/RR/RW/AC/IS/PV/PS นำหน้าออกจาก remark) · **ตัวเลือกระดับการดู 3 ขั้น** (แทนปุ่มย่อ/ขยายเดิม) `cffStaffSetGroupLevel(level)`: `cat`=ย่อถึงประเภท · `vendor`=กางประเภท ย่อผู้จำหน่าย (default) · `doc`=กางเอกสารครบ · ป้าย "ดูแบบ: ตามประเภท/ตามผู้จำหน่าย/ตามเอกสาร" · ไฮไลต์จาก `d.staffGroupLevel` (default vendor · คลิก toggle รายตัว `cffToggleCat`/`cffToggleVendor` ตั้งเป็น "custom" = ไม่ไฮไลต์) · **export (interactive=false) กางครบทุกชั้นเสมอ**
  - **ลดความรก:** เวนเดอร์ที่มี **รายการเดียว → ยุบเป็น 1 บรรทัด** (ชื่อ + ยอด · **คำอธิบายโผล่เฉพาะตอนกาง = ระดับ "ตามเอกสาร"**) — ระดับ "ตามผู้จำหน่าย" โชว์แค่ชื่อ+ยอดรวม ไม่บอกว่าจ่ายค่าอะไร · **หลายรายการ → หัวเวนเดอร์** (พื้น `rgba(brand,.04)` จาง + chip จำนวน) แล้วค่อยกางรายการย่อย · **หัวประเภทเด่นกว่าชัดเจน** (พื้น `rgba(brand,.14)` เข้ม + แถบซ้าย 4px solid brand + ตัวหนา 800 ขนาด 13px + chip) → แยกชั้น "ประเภท > ผู้จำหน่าย > เอกสาร" ไม่สับสน · `subLine(p,ven)` = **"คำอธิบาย (เด่น) · เลขเอกสาร (จาง #94a3b8)"** — ขึ้นต้นด้วยคำอธิบายให้อ่านง่าย (เดิม doc ขึ้นก่อนตาอ่านยาก) · ตัด desc ที่ซ้ำชื่อเวนเดอร์ · `cffCleanDesc` ตัด **"· Express:xxxx"** ท้ายทิ้ง (รก/ซ้ำเลขเอกสาร)
  - **ชื่อผู้ขายสะอาด** `cffCleanVendor(name)` ตัดรหัสท้าย " /B007.1" / " /ฒฒ0000017" (บางรายมีบางรายไม่มี → ตัดให้หมด · ไม่ตัด "A/B" ที่มีช่องว่างตามหลัง) · ใช้ใน `cffStaffPayments` ทั้ง AP + recurring (ตัดที่ source → group เวนเดอร์เดียวกันรวมถูก)
  - **`cffStaffReportInner(co,dt,R,opts)`** เพิ่ม `opts.interactive` + `opts.catOpen` + `opts.venOpen` — หน้าจอส่ง `{interactive:true,catOpen:d.catOpen}` (กลุ่มค่าใช้จ่ายในตาราง "รายละเอียดประเภทรายจ่าย" คลิกหัวประเภทย่อ/ขยาย ▾/▸ ใช้ `cffToggleCat`/`d.catOpen` default ขยาย + ปุ่มรวม "ย่อ/ขยายทั้งหมด" `cffStaffCatToggleAll`) · **export ส่ง opts ว่าง → interactive=false กางครบเสมอ ไม่มีปุ่ม** (ภาพ LINE เห็นทุกบรรทัด)

### 2026-06-23 — Executive Dashboard: โหมดนำเสนอ (present mode) เต็มจอ + ไฮไลต์ตามเมาส์ + ฟีลกระจก iOS
- **ปุ่ม "🖥️ นำเสนอ"** (สีส้ม) ในแถบเครื่องมือ `edRenderDashboard` → `edTogglePresent()`
- **เต็มจอ:** `document.documentElement.requestFullscreen()` (ผูกทั้งหน้า → สลับแท็บ/เปลี่ยนเดือน re-render `#main` ไม่หลุด fullscreen) + เพิ่มคลาส `ed-present` + `sb-hidden` (ซ่อน sidebar, จำสถานะเดิมไว้คืนตอนออก) · helper: `edEnterPresent`/`edExitPresent`/`edOnFsChange`/`edPresentKey` + `edInjectPresentCSS()` (inject `<style id=edPresentCSS>` ครั้งเดียว)
- **ไฮไลต์ตามเมาส์:** listener `mousemove` บน document → `e.target.closest("tr, .card, canvas, h1, h2, h3, button, select")` ได้บล็อกที่ชี้ → toggle คลาส `.ed-spot` (ชี้เซลล์ตาราง→ไฮไลต์ทั้งแถว `tr`) · สีตาม `var(--brand)`/`var(--brand-rgb)` ต่อบริษัท
- **ซ่อนตอนนำเสนอ** (คลาส `.ed-hide-present` + CSS `body.ed-present .ed-hide-present{display:none}`): ปุ่ม พิมพ์ PDF/พิมพ์ทั้งรายงาน/+อัปไฟล์เพิ่ม/ล้าง&เริ่มใหม่ + dropdown แนวกระดาษ + แถบ "📅 ข้อมูลที่มี: ปี…" (ปุ่มลบปี) + mergeMsg · **เก็บไว้:** dropdown ช่วงเวลา (เลือกเดือน/ปี) + แท็บ + topbar/printHeader ซ่อนด้วย
- **ฟีลกระจก iOS (glassmorphism):** พื้นหลังไล่เฉดสีแบรนด์ (radial+linear จาก `--page-1`/`--page-2`) · การ์ด/KPI/stat/bankcard/แท็บ → `rgba(255,255,255,.55)` + `backdrop-filter:blur(22px) saturate(180%)` + ขอบสว่าง + มน 20px · `.ed-spot` = กระจกยกตัว blur 26px + เรืองขอบ `--brand` + inset highlight · ปุ่มออก = pill กระจกฝ้า · **เอา `background-attachment:fixed` ออก** (กิน compositing/ทำ screenshot ค้าง)
- **ออก:** ปุ่มลอย `#edPresentBar` มุมขวาบน หรือกด Esc (กด Esc ออก fullscreen เอง → `edOnFsChange` ออกโหมดให้ด้วย) · fullscreen/highlight ทั้งหมดเป็น progressive — ถ้า `requestFullscreen` ถูกปฏิเสธ โหมด (คลาส+ไฮไลต์+กระจก) ยังทำงาน
- **ขอบเขต:** ของเพิ่มใหม่ล้วน ไม่แตะ logic/การแสดงผลเดิมของ Executive Dashboard

### 2026-06-23 — Executive Dashboard: แก้บัญชีซ้ำในกราฟ (normalize เลขบัญชีเป็นตัวเลขล้วน)
- **ปัญหา:** อัปไฟล์รวมหลายปี (2568+2569) แล้ว Bank Accounts tab โชว์บัญชีเดียวกันซ้ำเป็น 2 แถว (โดนัท + bar เปรียบเทียบ รับ/จ่าย) เช่น `BBL 865-098040-5` vs `BBL 865-0-98040-5` — เพราะไฟล์คนละปีเขียนเลขบัญชีคนละฟอร์แมต/มีขีดแฝง (non-breaking hyphen U+2011, en-dash, NBSP) ที่ตัวรวมบัญชีเดิมตัดไม่ออก (`replace(/[\s\-\/]/g,"")` จับแค่ขีด ASCII)
- **แก้:** `edNormAccNo` เปลี่ยนเป็น **เก็บเฉพาะตัวเลขล้วน** (`replace(/\D/g,"")`) + fallback แบบเดิมถ้าไม่มีตัวเลข · จุดสร้าง accountKey ทั้ง 3 ที่ (`edMigrateAccounts`, BHG parser `bankRe`, Benya/MBark parser) เรียก `edNormAccNo` ตัวเดียวกัน + ปัด `bank` เป็น `upper().trim()` ให้ตรงกัน → เลขบัญชีเดียวกันรวมเป็นบัญชีเดียวเสมอ ไม่ว่าขีดชนิดไหน
- **ไม่ต้องอัปไฟล์ใหม่:** `edMigrateAccounts` รันทุกครั้งที่โหลดจาก cloud (`edSyncFromCloud`) → Hard refresh แล้วรวมให้อัตโนมัติ · บัญชีคู่ซ้ำมาจากคนละปี (คนละเดือน) → merge months เป็นการต่อเดือน ไม่บวกซ้ำ
- **ขอบเขต:** แตะแค่ dedup helper — ไม่แตะ logic รวมเลข/แสดงผลของ Executive Dashboard (`renderToolExecDash`/`ed*` render)

### 2026-06-23 — Executive Dashboard รองรับหลายปี (multi-year merge + year filter)
- **ปัญหาเดิม:** อัปไฟล์ใหม่ = `d.data = edParse(...)` **เขียนทับทั้งหมด** → อัป 2025 แล้ว 2026 หายเกลี้ยง
- **แก้:** อัปไฟล์ตอนนี้ **merge** แทน replace — เดือน key ซ้ำ (เช่น `2026.03`) ของใหม่ทับ, เดือน/ปีใหม่เพิ่มเข้าไป
  - `edMergeData(base, add)` — index เดือนตาม key → rebuild `transactions`/`accounts`/`errors` จากเดือนที่ merge แล้ว (กัน tx ซ้ำ, `firstOpen`/`lastClose` ถูกต้องข้ามปีเพราะ sort key ก่อน)
  - `edHandleFile` เช็คว่ามี data อยู่ก่อน → ถ้ามี merge + ตั้ง `d.mergeMsg` (แถบเขียวแจ้ง "เพิ่มปี ... แล้ว") · ถ้าไม่มีก็ set ตรงๆ
  - `edAddFile()` — สร้าง `<input type=file>` ลอยๆ เรียกจากปุ่มในหน้า dashboard
- **Year filter** — month key มี year อยู่แล้ว (`YYYY.MM`) data model เลยรองรับหลายปีได้ทันที เพิ่มแค่ scope:
  - `monthFilter` รับค่าใหม่ `"year:2025"` (นอกจาก `"all"` / `"2025.01"`)
  - helper กลาง: `edScopeMonthKeys(data, mf)` (เดือนใน scope), `edScopeLabel(mf)` (ป้ายไทย), `edOpenClose(data, mf)` (เปิด=เดือนแรกของบัญชีใน scope, ปิด=เดือนสุดท้าย — แทน logic 2 แขนงเดิมใน edAgg/edDrillOpenClose)
  - `edTxsInScope` กรอง `year:` ด้วย `t.month.slice(0,4)`
  - dropdown: หลายปี → `<optgroup>` ต่อปี + "▸ ทั้งปี YYYY" + "ทุกปี (รวม N เดือน)" · ปีเดียว → เหมือนเดิม
  - จุดที่ patch ให้ scope-aware (กันเลขเพี้ยนตอนเลือกปี): `edAgg` opening/closing, `nMonths` (edRenderFinKpis + edDrillFinKpi), periodLabel, monthly chart (Summary), statement columns (edRenderStmt), monthlyOut breakdown, drill labels (edDrillSummary/edDrillActivityIO/edDrillOpenClose)
  - guard ใน edRenderDashboard: ถ้า `monthFilter` ชี้ปี/เดือนที่ไม่มีในข้อมูลแล้ว → reset เป็น `"all"`
- **ปุ่ม UI:** เพิ่ม "+ อัปไฟล์เพิ่ม (รวมปี)" (เขียว) · ปุ่มเดิม "อัปไฟล์ใหม่" → เปลี่ยนชื่อ "ล้าง & เริ่มใหม่" (edReset = ลบหมด)
- **ลบรายปี (`edDeleteYear`)** — แถบ "📅 ข้อมูลที่มี:" ใต้ toolbar โชว์ปีที่มี + ปุ่ม ✕ ต่อปี → ลบเฉพาะปีนั้น (ปีอื่นอยู่ครบ) · ใช้แก้กรณีอัปไฟล์ผิดบริษัท/ผิดปี (เช่น เผลออัป MBark ใส่ Benya — MBark เป็นคนละปีเลยไปแทนปีนั้น → ลบปีนั้นทิ้งแล้วอัปไฟล์ถูกกลับเข้ามา) · refactor `edRebuildFromMonths(monthList, company)` ใช้ร่วมกับ edMergeData (rebuild transactions/accounts/errors จากชุดเดือน)
- **หมายเหตุ:** หน้านี้เคยมาร์ค "ห้ามแตะ" แต่เจ้าของสั่งแก้ — logic การรวมเลขเดิมไม่เปลี่ยน (behavior-preserving สำหรับ single-year), เพิ่มแค่มิติปี

### 2026-06-22 — AP: ยกเลิกการจ่าย / ตั้งเป็น "ยังไม่จ่าย" (แก้คงค้างติดลบ)
- **ปัญหา:** กดปุ่ม "จ่าย" พลาด → insert `ap_payments` · `amount_outstanding` เป็น GENERATED (`amount_total − amount_paid`) → ถ้าจ่ายเกิน/บิลถูกแก้ยอดทีหลัง คงค้างติดลบ · แก้ status ในโมดอลแก้ไขเฉย ๆ ไม่ช่วย (ไม่แตะ `amount_paid`)
- **แก้:** โมดอลปุ่ม "จ่าย" (`apoOpenPay`) เปลี่ยนเป็น "การจ่าย / ประวัติ" — โหลด `ap_payments` ของบิล (`apoRenderPayHist`) แสดงรายการจ่าย + ปุ่ม **ยกเลิก** ต่อรายการ (`apoReversePayment`) + ปุ่ม **↩ ตั้งเป็นยังไม่จ่าย** (`apoUnpayAll`, soft-delete ทุก payment) · ฟอร์มบันทึกจ่ายย้ายไป `<details>` · ยกเลิก = soft-delete `ap_payments` → trigger `fn_ap_recompute` (AFTER UPDATE) คำนวณ `amount_paid`+`status` ใหม่ → คงค้างถูกต้อง · `apoAfterPayChange` reload ตาราง + เปิดโมดอลใหม่ด้วยยอดล่าสุด · default จำนวนจ่าย = `max(0, outstanding)` (กันค่าติดลบ)

### 2026-06-22 — บัญชีตัดจ่าย (pay-from account) ใน AP Outstanding + ค่าใช้จ่ายประจำ
- **ช่อง "ตัดจากบัญชี" (dropdown)** ให้ จนท. เลือกว่าเงินจะตัดออกจากบัญชีไหน — **default = บัญชีเลขลงท้าย `4889`** (Benya SCB 136-2-684889; MBark ไม่มี → fallback บัญชีแรก)
  - **Schema** `supabase/ap-pay-account.sql` (idempotent): `ap_invoices.pay_from_account_id` (ใหม่) + `recurring_expenses.bank_account_id` (`ADD COLUMN IF NOT EXISTS` — base schema มีแล้ว กัน clone เก่า) + `NOTIFY pgrst`. **หมายเหตุ:** `ap_invoices.pay_from_account_id` = บัญชีที่ "ตั้งใจจะตัดจ่าย" ต่างจาก `ap_payments.bank_account_id` (บัญชีจ่ายจริง)
  - **Helper ใช้ร่วม** (prefix `fop*`): `fopLoadAccounts(cid)` · `fopAccLabel(a)` (ชื่อเล่น · ธนาคารไทย เลขบัญชี) · `fopDefaultAccId(accounts)` (หาเลขลงท้าย 4889 ด้วย digits-only) · `fopAccOptions(accounts, selId)`
  - **AP** (`apoLoad` โหลด `d.accounts`): คอลัมน์ใหม่ในตาราง — inline `<select>` ต่อแถว (`apoSetPayAccount`) · null = โชว์ default (border เทา + chip "ค่าเริ่มต้น"), เลือกเอง = border `--in` + พื้น soft · เพิ่มในโมดอลแก้ไข (`apoOpenEdit`/`apoSaveEdit`) ด้วย
  - **ค่าใช้จ่ายประจำ** (`recLoad` โหลด `d.accounts`): คอลัมน์ "ตัดจากบัญชี" ในตาราง (null → โชว์ default) + dropdown ในฟอร์มเพิ่ม/แก้ (`recOpenForm`/`recSave` → `bank_account_id`) default = 4889
  - **★ ผูกเข้า Cash Flow Forecast (พนักงาน) — ตาราง pivot แยกบัญชีถูกต้องแล้ว:** เดิม dump ค่าใช้จ่ายทั้งหมดลงบัญชีเดียว (`mainBankId` = บัญชี amount มากสุด) ทั้งหน้า render + snapshot รายงานรายวัน. แก้: `cffLoad` ดึง `pay_from_account_id` (AP) + `bank_account_id` (recurring ทั้ง occ join + expense) · `cffStaffPayments` แนบ `payAccountId` ทุก payment · helper ใหม่ `cffBankDistribute(filtered, balances)` → `{due, cat}` ต่อ `bank_account_id` (ไม่ผูก/บัญชีไม่มียอด → `cffBankDefaultId` = เลขลงท้าย 4889) · ใช้ทั้ง `renderToolCashflowStaff` (bankMap.due) + snapshot pivot (`cffExportSnap`/รายงานรายวัน)
  - **gotcha:** default เป็นแค่ค่าที่ "โชว์ pre-select" เมื่อ DB null — ไม่ได้ auto-save ทุกแถว · downstream อ่านผ่าน `cffBankDistribute` (AP/recurring) หรือ `pay_from_account_id || fopDefaultAccId(...)`

### 2026-06-22 — Cash Flow Forecast (Staff) redesign + present mode + bank recon dedup + chart polish
- **Cash Flow Staff redesign** (`renderToolCashflowStaff`, design handoff `for-design/cff-redesign/`): (1) แถว **"ไฮไลต์สำคัญ"** 3 การ์ด — เลยกำหนด (sum+count รายการ original_due<today) · รอบจ่ายหนักสุด (group by due_date หา max) · สภาพคล่องสุทธิ. (2) **ตารางหมวดออกแบบใหม่** แทน pivot table เดิม: หัวหมวด **ยุบ/ขยายได้** (`cffToggleCat`, state `d.catOpen`) + ไอคอน (`catIcon`) + chip จำนวน + ยอดรวมหมวดเด่น · รายการย่อย = ชื่อเจ้าหนี้ตัวหนา + chip "ประจำ" + detail·remark·note บรรทัดจาง + **pill วันครบกำหนดสีตามสถานะ** (`dueMeta`: เลยกำหนด=แดง/ใกล้กำหนด≤3วัน=อำพัน/ตามกำหนด=เทา) + ยอดเงินตัวใหญ่ขวา + **ปุ่มลบถังขยะโผล่ตอน hover** (เฉพาะ recurring) · zebra row · แถวรวมท้าย gradient. CSS แยกใน `cffInjectStaffCSS()` (prefix `.cffx-*`) ใช้ var(--brand)/(--brand-rgb) ปรับตามบริษัทอัตโนมัติ. helper/snapshot เดิมคงไว้. (3) **การ์ดธนาคาร + "ไทม์ไลน์รอบการจ่าย"** — สรุป (บัญชีหลัก + ประมาณการคงเหลือหลังจ่ายครบ) + mini stats + timeline ยุบ/ขยาย (`cffToggleBankTl`/`cffToggleRound`, state `d.bankTlOpen`/`d.roundOpen`): รอบจ่ายเรียงตามวัน (`rounds` group by due_date) แต่ละรอบ status pill + ยอดจ่าย + **คงเหลือยกไป** (วิ่งจาก openingCash) + กางดูรายการในรอบ · แถวสุทธิท้าย gradient · ถ้า >1 บัญชี โชว์ per-bank grid เดิมด้านบนด้วย
- **★ Order Ledger ใช้ตาราง `order_ledger` (ไม่ใช่ `orders`)** — `orders` เป็นของ Sales Dashboard/BigSeller เดิม (schema คนละแบบ: `company`/`order_no`/`sale_date`/`platform`/status `pending`). ตอน bisect migration เคยสร้าง `orders` แบบ minimal → `CREATE TABLE IF NOT EXISTS` ข้าม → ord* เขียน/อ่านผิดตาราง (insert ไม่ลง). แก้: ตารางใหม่ `order_ledger` ทั้งใบ (`supabase/orders.sql`) + ทุก `sb.from(...)` ของ ord*/homeLoadStats ชี้ `order_ledger`. **gotcha:** migration ต้อง `ALTER ADD COLUMN IF NOT EXISTS` ครบทุก column (กันตารางเก่า column ไม่ครบ) + ปิดท้าย `NOTIFY pgrst, 'reload schema'` (กัน PGRST204 column not in schema cache หลัง DDL)
- **โหมดพรีเซนต์ (present mode)** — `nisa.y@benyamedical.com` + รหัส `present2026` → `authSignIn` สลับเข้าบัญชี `present@benyamedical.com` อัตโนมัติ (alias routing). `AUTH.isPresent()` = email===present → sidebar เห็นแค่ `execdash` · renderApp/renderTool ล็อก `state.tool="execdash"` · ปลด gate admin-only ของ `renderToolExecDash`. **ต้องสร้างบัญชี `present@benyamedical.com` / `present2026` ใน Supabase เอง** (role executive + access บริษัทที่จะพรีเซนต์) ผ่านหน้าจัดการผู้ใช้. รหัส present2026 อยู่ใน client (read-only account ปลอดภัยพอ)
- **Bank Recon re-upload = dedup ระดับแถว** (`brecUpload` + `brecRowSig`) — เลิก dedup ด้วย file_hash ทั้งไฟล์ (พังเมื่ออัปงวดทับกัน). ลายเซ็นแถว = date+withdrawal+deposit+balance+doc_no(ex)/cheque_no+ref_note(bank) → นำเข้าเฉพาะแถวใหม่ · match/กระทบยอดเดิมไม่ถูกแตะ · `brecAutoMatch` เสนอเฉพาะแถวใหม่. import hash ใส่ `Date.now()` ให้ unique เสมอ
- **ปุ่ม "ล้างแถวซ้ำ"** (`brecDedupExisting`) — ล้างแถวซ้ำย้อนหลังที่เกิดก่อน patch · จัดกลุ่มตามลายเซ็น เก็บ 1 แถว/รายการ · **ถ้าแถวถูกจับคู่ใน brec_matches เก็บอันนั้นไว้เสมอ** (ลบเฉพาะ unmatched) → match ไม่พัง
- **แก้ปุ่ม "เลือกทั้งหมด" (bankrec)** — `JSON.stringify(ids)` สร้าง array double-quote ฝังใน `onclick="..."` (double-quote) → attribute พังกลางคัน. แก้: marketplace `bmpSelectAllWd()` คำนวณ ids เองภายใน · Phase 1 `brecSelectAll` ใช้ single-quote array. **gotcha: อย่าใส่ `JSON.stringify(array)` ใน attribute ที่ครอบด้วย double-quote**
- **Executive Dashboard chart polish** (presentation): (1) สี "สุทธิ" (monthly) + "ลงทุน" (activity) เปลี่ยนเป็น `#8B5CF6` ม่วง — กันซ้ำกับ in(ฟ้า)/out(ส้ม) ใน MBark · (2) plugin `edBarLabelPlugin` — ป้ายตัวเลขสั้นบนหัวแท่ง monthly chart (net มี +/- เช่น `+272K`, ใช้ `edFmtCompact`) · (3) plugin `edDonutPctPlugin` — `%` กลางชิ้นโดนัท Top 5 (ชิ้น <5% ไม่โชว์). plugin นิยามใกล้ `edMakeChart`, ใส่ผ่าน `plugins:[...]` ระดับ cfg

### 2026-06-21 — Order Ledger (ทะเบียนคำสั่งซื้อ) Phase A-E + Home dashboard redesign
- **วิสัยทัศน์ใหม่:** จาก "เครื่องมือ export คีย์" → ระบบติดตามคำสั่งซื้อกลาง · ทุกอัปโหลดแท็กลง order เดียวกัน → timeline ขาย→IV→รับชำระ→ฝากเช็ค→เงินเข้าแบงค์ (1 order = 1 IV)
- **Schema** `orders-phase-a.sql` + `orders-phase-a2.sql`: ตาราง `orders` (key company+order_id, unique · iv_no nullable เติมทีหลัง) + `order_events` log + stage columns ครบ 5 stage
- **โมดูล `orders`** (`renderToolOrders`, helper `ord*`) — หน้า "ทะเบียนคำสั่งซื้อ" ใต้ stage การขาย:
  - **Phase A** parser รายงานขายหลังบ้าน 4 ช่องทาง (`ORD_CH` config · generic group item→order): Shopee/TikTok(xlsx+csv)/Lazada/BigSeller · BigSeller กรองเอาเฉพาะ platform ≠ Shopee/TikTok/Lazada · `ordParseSalesFile` + `ordIngestChannelOrders` (upsert by order_id)
  - **Phase A 723-5** `ordIngestFromSales` เปลี่ยนเป็น "จับ IV ใส่ออเดอร์" (match order_id → tag iv_no/ยอด) + fallback สร้าง
  - **Phase B** `ordTagReceipts(co, arData)` — แท็ก RE/SP/net/fee ผ่าน iv_no (hook ใน bmpRunUpload)
  - **Phase C** `ordTagBankFromWithdrawals(co, withdrawals)` — แท็ก BQ/วันเงินเข้าแบงค์ ผ่าน order_id
  - **Phase D** timeline ต่อออเดอร์ (`ordTimeline`) — คลิกแถวดู 5 stage · filter ช่อง/IV + ค้นหา + ปุ่มส่งออกออเดอร์ยังไม่คีย์ IV (xlsx)
  - **Phase E** `homeLoadStats` — wire dashboard KPI เป็นข้อมูลจริง (% คีย์ IV, รอรับชำระ, เงินเข้าแบงค์, AP จริง, เงินสดจริง)
- **Home redesign** (`renderToolHome`): dashboard ภาพรวม (จาก design handoff) — 5 KPI + งานวันนี้/progress/cashflow/quick access/activity · สีตาม `var(--brand)` ต่อบริษัท

### 2026-06-21 — Bank Reconciliation Phase 2 (Marketplace Withdrawal Recon — Shopee)
- เพิ่ม **แท็บที่ 5 "🛒 ถอน Marketplace"** ใต้ `renderToolBankRec` · helper prefix **`bmp*`** · ปุ่ม "Marketplace (3 ไฟล์)" บน toolbar เปิด modal อัป 3 ไฟล์พร้อมกัน
- **Schema** `supabase/bankrec-mp-phase2.sql` — 3 ตาราง:
  - `brec_mp_imports` (ประวัติอัป + `file_hash` กันซ้ำ · `channel`,`shop_name`,`shopee_filename`,`receipt_filename`,`cheque_filename`)
  - `brec_mp_withdrawals` (1 row = 1 withdrawal event · `bq_number`,`description`,`withdraw_amount`,`sum_gross`,`sum_net`,`total_fee`,`mismatch_count`,`bank_row_id`,`bank_match_status`)
  - `brec_mp_orders` (1 row = 1 order ภายใน withdrawal · `express_gross`,`shopee_net`,`fee_diff`,`has_receipt`,`has_cheque_deposit`,`existing_bq`,`mismatch_flag`,`mismatch_reason`)
  - RLS เดิม + soft delete
- **Parsers 3 ตัว** (vanilla JS):
  - `bmpParseShopeeBalance(workbook)` — Shopee `.xlsx` "Transaction Report" (shop name row 6, periods row 7-8, header row ~18). 3 ประเภท txn: รายรับจากคำสั่งซื้อ / การถอนเงิน / รายการปรับปรุง. sort asc by datetime
  - `bmpParseArReceipt(text)` — Express CSV cp874 "รับชำระหนี้" · scan SP/TT/LZ pattern ในแต่ละแถวต่อ receipt header → ดึง gross + receipt_no
  - `bmpParseChequeReport(text)` — Express CSV cp874 "เช็ครับ เรียงตามวันที่นำฝาก" · ดึง BQ + deposit date ของแต่ละเช็ค (ใช้ทั้ง gen BQ ใหม่ + รู้ว่าออเดอร์ไหน deposit แล้ว) · อ่าน "S/A #..." header → bank account ปลายทาง
  - CSV decode ใช้ `TextDecoder('windows-874')` + NBSP→space + custom CSV parser (รองรับ quoted fields + "" escape)
- **Account routing (BMP_SHOP_ROUTING)** — map ตายตัว shop_name → company + bank + label:
  - `mommam_official` → MBark SCB 136-270928-1 (digits 1362709281 — บัญชีเดียวของ MBark) · descSuffix "Shopee mommam"
  - `benya_official` → Benya SCB 417-077164-0 · descSuffix "Shopee Qi care"
  - `betra_brand` → Benya BBL 865-0-98040-5 · descSuffix "Shopee Betra"
  - ตรวจ company match → ถ้าผิดบริษัทเสนอสลับให้
- **Grouping engine** `bmpGroupWithdrawals()`:
  - sort all Shopee txns ascending by datetime
  - buffer orders + adjustments until เจอ "การถอนเงิน" → close group · withdrawal นี้รวม orders ก่อนหน้ามัน
  - ทุก order ในกลุ่ม lookup ใน arData (รับชำระ) → ดึง gross · lookup ใน chqData (เช็ครับ) → check existing BQ + amount mismatch
  - mismatch flag: ไม่พบใน รับชำระ / เช็ครับ amount ≠ รับชำระ amount
- **BQ generation**:
  - parse "เช็ครับ" → max(seq) ต่อ YYMMDD
  - withdrawal ใหม่: BQ = `${YYMMDD}${(maxSeq+1).padStart(4,'0')}` เช่น `2606040001`
  - กันชน — เก็บ counter ใน Map ระหว่างกระบวนการ
- **UI การ์ดละ 1 withdrawal**: chip channel + shop · row 6 fields (วันที่ถอน, BQ, ยอด, บัญชี, ค่าธรรมเนียม, จำนวนออเดอร์) · description · ขยาย/ซ่อน orders ในการ์ด
  - การ์ดสีเขียว = ตรงครบ · การ์ดสีแดง = `mismatch_count > 0`
  - ตาราง orders ภายในขยาย: เลขที่เช็ค · gross · net · ผลต่าง · สถานะ (มี deposit แล้ว → โชว์ BQ เก่า / mismatch → โชว์เหตุผล)
  - แถว `adjustment` (ค่าธรรมเนียมในกระเป๋า) แสดงด้วย icon 📌 พร้อม description
- **Export 2 ปุ่ม** (รวมทุก withdrawal ใน 1 ไฟล์):
  - **CSV หลัก** (9 cols: No / เลขที่ BQ / วันที่เงินเข้าบัญชี DD/MM/YY / เลขที่เช็ค / มูลค่าเช็ค EXPRESS / เงินที่ออกสุทธิของออเดอร์ / ผลต่าง / ค่าธรรมเนียมรวม / คำอธิบายรายการ) · **ข้าม** withdrawal ที่ mismatch_count > 0 (กันคีย์ผิด) · BOM UTF-8 (เปิด Excel ไทยไม่เพี้ยน)
  - **Excel รายงานไม่ตรง** — ดึงเฉพาะออเดอร์ที่ mismatch สำหรับฝ่ายการเงินตรวจ
- **Validation rule (strict 100%)**: gross Express ของ order ต้องตรง — ยกเว้นค่าธรรมเนียมในกระเป๋าที่ Shopee หัก (อยู่ในแถว adjustment)
- **กันไฟล์ซ้ำ**: `file_hash` (djb2 ของ 3 filenames + sizes) → confirm ถ้าซ้ำ
- **Phase 3 (ยังไม่ทำ)**: TikTok Shop + Lazada payout report (รอ user ส่งไฟล์ตัวอย่าง) · auto-link mp withdrawal กับ bank row ใน statement · ปิดงวด

### 2026-06-20 — Bank Reconciliation Phase 1 (Express ↔ Bank Statement)
- โมดูล `bankrec` เปลี่ยนจาก `soon` → live · ฟังก์ชันหลัก `renderToolBankRec` + helper prefix **`brec*`**
- **Schema** `supabase/bankrec-phase1.sql` — 4 ตาราง:
  - `brec_imports` (ประวัติอัป + `file_hash` กันซ้ำ + period_from/to + status)
  - `brec_express_rows` (วันที่/MNE/doc_no/withdrawal/deposit/balance/remark — จาก Express XML)
  - `brec_bank_rows` (วันที่/tr_code/description/cheque_no/withdrawal/deposit/**ref_note** — SCB only)
  - `brec_matches` (express_row_id × bank_row_id, status: `suggested/confirmed/manual/interaccount/excluded`, confidence, match_reason)
  - RLS เดิม (read=ทุก user ของ company / write=admin·finance_mgr·accountant·treasury) + soft delete
  - UNIQUE index บน express_row_id/bank_row_id (where deleted_at is null) — กันคู่ซ้ำ
- **Parsers 3 ตัว** (vanilla JS):
  - `brecParseExpressXml(text)` — Excel SpreadsheetML XML รูปแบบ "งบกระทบยอด" (วันที่/MNE/เลขที่/ยอดถอน/ยอดฝาก/ยอดคงเหลือ/สถานะเช็ค/หมายเหตุ) ใช้ได้ทั้ง BBL+SCB Express. ดึง bank_code+account_no จาก header `S/A #...`
  - `brecParseScbXlsx(workbook)` — SCB BusinessNet sheet `RPT_01009_XLSX` 16 cols, **ใช้คอลัมน์ `Note`** (เลขใบสำคัญ PS/BT...) สำหรับ ref match
  - `brecParseBblXls(workbook)` — BBL iBanking `.xls` (BIFF), header row ~16, 9 cols (Debit/Credit/Ledger). **ไม่มี ref** — ต้อง match ด้วย date+amount เท่านั้น
  - `brecParseStatement(wb)` — auto-detect SCB vs BBL จาก header signature
- **Matching rule (strict)**:
  - **วันที่ต้องตรงเป๊ะ — ไม่มี ±N วัน** (เจ้าของเน้นย้ำ: "ต้องไม่ต่างกันสักวันเดียวนะ")
  - Tier 1 `exact`: ref ตรง + วันตรง + ยอดตรง · ref normalize ด้วย `brecRefKey()` (strip Q prefix ใน QPPS → PS)
  - Tier 2 `suggested`: วันตรง + ยอดตรง (ไม่มี ref) — สำหรับ BBL
  - ทุก match เริ่มที่ `status='suggested'` → user กดยืนยันถึงเป็น `confirmed`
- **UI 4 แท็บ (PEAK-style)**: รอยืนยัน · รอกระทบยอด · กระทบแล้ว · ทั้งหมด
  - Toolbar: เลือกบัญชี + งวด (**toggle รายเดือน/ช่วงวัน**) + ปุ่ม upload Express+Statement + จับคู่อัตโนมัติ + Export
  - Summary 5 การ์ด: Express / Bank / ผลต่าง (สมดุล✓ หรือไม่) / กระทบแล้ว / ค้างกระทบ
  - ตารางเทียบ **side-by-side** (Express ซ้าย | ↔ | Bank ขวา | confidence | actions)
  - สี border ซ้ายต่อสถานะ: matched=เขียว · suggested=ส้ม · unmatched-ex=brand · unmatched-bk=น้ำเงิน · confirmed=เขียว+พื้น
  - Action bar: เลือกแล้วกี่รายการ · จับคู่เอง (เลือก ex 1 + bk 1) · ยืนยันที่เลือก
- **Auto-create bank_accounts**: ถ้าอัปโหลดไฟล์แล้วเจอเลขบัญชีที่ยังไม่มี → `brecEnsureAccount()` สร้างใหม่อัตโนมัติ (bank_code จาก header BBL/SCB, normalize account_no = digits-only)
- **กันไฟล์ซ้ำ**: `file_hash` (djb2 ของ filename+size+row_count+period) → confirm ก่อนถ้าซ้ำ
- **Export**: 3 sheets (กระทบแล้ว / ค้าง Express / ค้าง Bank) เป็น XLSX
- **บัญชีที่ระบบรองรับใน Phase 1**:
  - Benya: BBL 865-0-98040-5 · SCB 136-2-684889 · SCB 417-077164-0
  - MBark: SCB 136-270928-1 (digits 1362709281 — บัญชีเดียว ง่ายสุด)
- **Mockup** `for-design/bankrec-mockup.html` — static preview HTML (เปิดในเบราว์เซอร์ดู layout/สี/ปุ่ม) — ใช้ตอน design review ก่อนเขียนจริง
- **Phase 2 (ยังไม่ทำ)**: Marketplace Recon (Shopee/TikTok payout ↔ เงินเข้า) — รอไฟล์ตัวอย่าง · 1-to-many matching · ปิดงวด · template UI

### 2026-06-20 — Executive Cash Flow polish + พิมพ์ทั้งรายงาน + สีพาสเทล MBark + ปุ่มซ่อน sidebar
**หมายเหตุ:** หน้า Executive Dashboard ที่เคยมาร์ค "ห้ามแตะ" ถูกแก้รอบนี้ตามที่เจ้าของสั่ง — ปรับ "presentation polish" ไม่แตะ logic การรวมเลข/ตัดโอน
- **งบกระแสเงินสด (`edRenderStmt`) — สี + netting:** (1) **ตัวเลขติดลบ = แดง `#dc2626`** · ไม่ติดลบ = `ED_COLORS.in` (helper `stmtClr`) ใช้ใน statement + KPI Summary/Activity + ตาราง Category/Banks net (กราฟ Pareto คงสีหมวด) · (2) **จัดประเภทหมวดตามชื่อ** (`stmtSide`: ขึ้นต้น "รายรับ/รายได้"→รับ · "รายจ่าย/ค่าใช้จ่าย"→จ่าย · ไม่ชัด→ดู net) แล้ว **net รับ-จ่ายในหมวด** (`catNet`) → หมวดรายจ่ายที่มี refund บวก **หักกลบในฝั่งจ่าย ไม่เด้งไปโชว์ฝั่งรายรับ** · cell drill ใช้ dir=null (ทุกธุรกรรมของหมวด)
- **คลิกชื่อหมวด (▶) = คลี่รายการ inline แบบ Excel** (`edStmtToggle`) · คลิกตัวเลขเดือน = popup เดิม (`edDrillStmt`)
- **ตัวเลขวิ่ง count-up:** `edAnimNums` (Summary headline ผ่าน `data-anim`/`data-to`, kind money|pct) + `edAnimMoney` (auto ทุก cell ที่เป็นเงิน `x,xxx.xx` — ปี/วันที่/เลขบัญชีไม่โดน, ข้ามตาราง >300 cell กัน jank) เรียกรวมศูนย์ใน `edRenderDashboard` → วิ่งทุกแท็บตอนสลับหน้า · CSS `@keyframes edGrow/edShimmer/edShine/edGlow` (แถบโต + การ์ดปลายงวดแสงวิ่ง+เรืองแสง)
- **PDF แนวตั้ง/แนวนอน (`edExportPDF` + `d.pdfOrient`):** dropdown เลือก `landscape`(หลายหน้า เดิม) / `portrait`(ย่อ 1 หน้า) · **กฎ override ตามแท็บ:** `stmt`=ล็อคแนวนอน+ย่อ 1 หน้าเสมอ · `explorer`=แนวนอนหลายหน้าเสมอ (ข้อมูลเยอะ) · อื่นๆ ตาม dropdown · โหมด `fitOne` = ย่อทั้ง canvas ลง 1 หน้า (ไม่ slice)
- **Executive Summary redesign (`edRenderSummary` ส่วนบน):** จาก design handoff (Claude Design) — แทน 5 KPI การ์ด + 3 การ์ดกิจกรรมแบบเดิม ด้วย **hero band** (การ์ดซ้าย: เงินรับ/จ่ายรวม gradient + แถบ + chip กระแสเงินสดสุทธิ · การ์ดขวา: เงินสดปลายงวด hero gradient + ต้นงวด→เปลี่ยนแปลง %) + **การ์ดกิจกรรม 3 ใบ** (แถบซ้ายสี + ไอคอน + badge รับ/จ่ายสุทธิ + progress สัดส่วน `|net|/Σ|net|`) · **ปรับสีตามธีมบริษัท** (MBark ฟ้า/ส้ม gradient · Benya teal/pink · hero ใช้ `co.gradient`) + **ติดลบ=แดง** · ใช้ข้อมูล `A` (edAgg) + handler เดิม (`edDrillSummary`/`edDrillActivityIO`/`edDrillOpenClose`) · กราฟรายเดือน/โดนัท + Top5 + FinKpis เดิมคงไว้ด้านล่าง
- **โลโก้ icon-only (ตัดชื่อบริษัทในรูปออก):** เพิ่ม `logos/mbark-icon.png` + `logos/benya-icon.png` (ครอปเฉพาะสัญลักษณ์ด้วย PIL — ตัดที่ "ช่องว่างใหญ่สุด" ระหว่างไอคอนกับข้อความ) — **ใช้ทุกที่** (COMPANIES `logo` ชี้ไฟล์ icon เลย): sidebar/หน้าจอ/login/print/PDF (ทุกจุดใช้ `object-fit:contain` หรือ `width:auto` กันรูปไม่จัตุรัสเบี้ยว) · `logos/mbark.png`/`benya.png` (มีชื่อ) ยังเก็บไว้ในรีโปแต่ไม่ถูกอ้างแล้ว · print/PDF ใช้ `co.logoIcon||co.logo` (logoIcon ถูกถอดออก → fallback มา logo)
  - **เดิม (กลับ 2026-06-20):** เคยทำเป็น icon เฉพาะ print/PDF + เก็บโลโก้เต็มที่ sidebar/login — ภายหลังเจ้าของสั่งให้ตัดชื่อทุกที่
- **เอาสัญลักษณ์ `฿` ออกทุกหน้า** (เคยดูเหมือนมีเลข 8 เพิ่ม) — ลบจาก `edFmt`/`fopFmt`/`fmt`/`fmtMoney` + AR inline (`฿${arFmt(` → `${arFmt(`). คง `฿` ไว้แค่ regex parse (l.956) + CSV header matching BigSeller (l.1149/1152). แทนด้วย **"หน่วย: บาท"** ที่หัวหน้า/หัวตารางของหน้าเงิน (Executive on-screen+PDF, AR, AP, Bank, Cashflow staff+exec, Recurring, Armap)
- **KPI ทางการเงิน:** เปลี่ยน `≥`/`≤` ในเกณฑ์มาตรฐาน → "ไม่ต่ำกว่า" / "ไม่เกิน" (อ่านง่ายตอนพรีเซนต์)
- **ลดความรกการ์ด Executive Summary:** เอา "· คลิกดูที่มา" ออกจากทุกการ์ด (ทั้ง `edRenderSummary` kpiCard + `edRenderFinKpis` card — ยังคลิก drill ได้/มี hover) + เอาบรรทัดย่อยใต้ตัวเลขออก (รายการ/เป็นบวก-ลบ/in÷out)
- **Pareto:** Top 20 → **Top 5** (`slice(0,5)`) + ป้ายชื่อยาวขึ้น (40 ตัว) สีแยกรับ(in)/จ่าย(out) เหมือนเดิม
- **สีพาสเทล MBark (`edApplyTheme`):** กราฟ in `#1e3a8a`→**`#6E9BE8`** (ฟ้าพาสเทล), out `#ed7235`→**`#F2A968`** (ส้มพาสเทล), brand/op/inv/fin ปรับตาม — **ตัวหนังสือ/หัวข้อ/ปุ่ม navy เข้มคงเดิม** (อ่านง่าย); `edStmtPalette` MBark คงเดิม (พื้นพาสเทล+ตัวอักษรเข้มอยู่แล้ว); Benya ไม่แตะ
- **ปุ่มซ่อน sidebar (เดสก์ท็อป):** ปุ่ม `≡` (เดิมโชว์เฉพาะ ≤820px) โชว์ทุกขนาด → `toggleSidebar()`: เดสก์ท็อป toggle `body.sb-hidden` (CSS `body.sb-hidden .sidebar{display:none}`) + จำใน `localStorage ft-sb-hidden`; มือถือยัง toggle `.show` เหมือนเดิม; restore ตอน `buildShell`
- **PDF (Executive) แก้ + เพิ่ม:**
  - กราฟวงกลมเคยเพี้ยนเป็นวงรี → snapshot canvas เปลี่ยน `object-fit:contain` (html2canvas ไม่รองรับ) เป็น **`width:100%;height:auto`** (คงสัดส่วน)
  - คมขึ้น: html2canvas `scale 2→3` (ตัวแปร `SCALE` คุมรวม — เดิม hardcode `2` ทั้ง scale/thead/rowBounds)
  - ชื่อไฟล์ตามหัวข้อหน้า: `curTab.id`→**`curTab.l`** (เช่น `M_Bark_งบกระแสเงินสด_*.pdf`)
  - หัวข้อ (h3) ไม่หลุดจากตาราง: rowBounds ของ h3 ใช้ขอบ **บน** (snap ตัดหน้า "ก่อน" หัวข้อ = keep-with-next)
  - **ปุ่ม "พิมพ์ทั้งรายงาน"** (`edExportFullPDF`) — วน 6 แท็บ (set `d.tab` → เรียก renderer → รอ ~450ms → แคป) รวมเป็น PDF เล่มเดียว, ปิด `Chart.defaults.animation` ชั่วคราว, เลขหน้า global (`edDrawPdfFooters` เรียกท้ายสุด), restore tab + `edRenderDashboard()`. แยก helper `edCaptureContentToPdf`/`edPdfDims` (edExportPDF เดิมไม่ถูกแตะ — ลดความเสี่ยง)
- **`.claude/launch.json`** เพิ่มไว้ preview ผ่าน `python -m http.server 8000`

### 2026-06-19 — Bank Balance รื้อเป็นตารางกรอกรายวัน + คาดการณ์ล่วงหน้า (พรุ่งนี้)
- รื้อ `renderToolBankBalance()` จาก modal → **ตารางกรอกรายวัน inline** (อ้างอิงดีไซน์เว็บอีกทีม "ของป๊อก")
- เลือกวันด้วย **chip** (วันนี้−6 .. วันนี้ + "พรุ่งนี้") + dropdown ปี/เดือน/วัน — chip โชว์ยอดรวมต่อวัน
- คอลัมน์: ยอดเมื่อวาน · ยอด(input) · Δ · HOLD ล่าสุด · HOLD(input) · ใช้ได้จริง · สถานะ + ปุ่ม ↩️ ใช้ค่าเมื่อวาน
- **คาดการณ์ "พรุ่งนี้"**: ค่าตั้งต้น = carry-forward จากยอดล่าสุด (auto) แล้ว **แก้ทับเองได้** → บันทึก `source='forecast'`
- ใช้ constraint เดิม `bal_no_future (balance_date <= current_date+1)` ได้พอดี → **ไม่มี migration**; ยอดพรุ่งนี้ไม่ปนยอดวันนี้ (fn_balance_as_of กรอง ≤ as_of)
- ฟังก์ชันใหม่ (bb*): `bbLoadGrid` ใน `bbLoad`, `bbSetDate` `bbDateSel` `bbCopyPrev`/`bbCopyAllPrev` `bbRecalc` (Δ/ใช้ได้จริง/รวม/เตือน >100k สด) `bbSaveGrid`; date helpers `bbAddDays`/`bbDateObj`/`bbChipLabel` (ใช้ `cffISO` กัน TZ), reuse `cffBankLogo`/`cffBankName`
- **ลบบัญชี:** ปุ่ม 🗑 ต่อแถว → soft-delete `bank_accounts` (`bbDeleteAccount`) ซ่อนจากทุกหน้า
- **นอกขอบเขต (เฟสหน้า):** คาดการณ์เกินพรุ่งนี้ (ต้อง migration + ตาราง forecast แยก), หัก AP/recurring อัตโนมัติจากยอดคาดการณ์, กลุ่มบัญชี dormant
- **AP Outstanding — ปุ่ม ✏️ แก้ไขทุกคอลัมน์** (`apoOpenEdit`/`apoSaveEdit`): ผู้ขาย/เลขบิล/remark/วันที่บิล/ครบกำหนด/วันชำระเงิน/ยอดรวม/สถานะ/หมวด/หมายเหตุเพิ่ม — `amount_outstanding` เป็น GENERATED column (total−paid) แก้ผ่าน `amount_total`
- Cash Flow Staff: เพิ่ม recurring ตามวันจ่าย (`cffStaffPayments`) + เรียงผู้ขายเดียวกันติดกัน (`cffItemCmp`) · recurring ทุกตัวจัดกลุ่มเป็นหมวด "ค่าใช้จ่ายประจำ" หมวดเดียว (หมวดย่อย rent/payroll/... ไปอยู่คำอธิบายผ่าน `cffRecurCat`)
- **ลบค่าใช้จ่ายประจำ (ประมาณการ) ออกจากประมาณการรายวัน** — ปุ่ม ✕ บนรายการ recurring → upsert `recurring_occurrences` status=`skipped` (UNIQUE recurring_id+due_date) = ซ่อนเฉพาะวันนั้น persist; มีแถบ "คืนค่า" (`cffSkipRecurring`/`cffUnskipRecurring`); cffLoad โหลด `recSkips`, ทั้ง `cffStaffPayments` + `cffCompute` กรองออกด้วย `skipSet` (recurring_id|due_date)

### 2026-06-19 — Cash Flow Forecast (Staff + Executive) + AP multi-filter + cloud-first sync
- **Cash Flow Forecast** เปลี่ยนจาก soon → live, มี 2 view toggle:
  - **📋 พนักงาน** (default, daily LINE report) — filter pills "วันชำระเงิน" + 5 KPI + Cash Bridge 5 boxes + Bank cards (โลโก้จริง) + Pivot ตามหมวด + Snapshot PNG/PDF
  - **📊 ผู้บริหาร** — 30-day forecast + Chart.js timeline + drill-down + alerts + Snapshot
- **★ Staff view = AP ที่ จนท. กรอก `planned_payment_date` + ค่าใช้จ่ายประจำ (recurring) ผูกตามวันจ่าย** — helper `cffStaffPayments(dt,d)` (ใช้ทั้งหน้า render + snapshot)
  - AP: ต้องกรอก `planned_payment_date` ก่อน (manual control เดิม) ถึงนับเข้า
  - Recurring: gen วันครบกำหนดจาก `day_of_month` (รายเดือน, `-1` = สิ้นเดือน) ในช่วง "ต้นเดือนนี้ → สิ้นเดือนถัดไป" (ขยายถึง `staffTo` ถ้าเลือกช่วงไกลกว่า) — dedupe กับ `recurring_occurrences` ที่ materialise แล้ว, หมวดแปลงเป็นไทยด้วย `cffRecurCat()`
  - ★ ใช้ `cffISO()` (local-date) ไม่ใช่ `toISOString().slice(0,10)` — กัน timezone shift TH (UTC+7) ทำวันเพี้ยน -1
- Cash Flow Staff filter รองรับ range (from + to) + chips ราย day
- **AP Outstanding**:
  - เพิ่ม column `planned_payment_date` (date input inline) + `internal_note` (modal กรอกหมายเหตุเพิ่ม)
  - ปุ่ม **ลบ** soft-delete (status=void)
  - แก้ `due_date` inline ได้ (date input)
  - แก้ `category` inline ได้ (dropdown 8 ตัว)
  - **multi-select checkbox dropdown** สำหรับ filter: ผู้ขาย/ประเภท/อายุหนี้/สถานะ (เลือกหลายค่าพร้อมกัน OR logic)
  - per-column filter row (date pickers, text search)
  - Filter "วันชำระทั้งหมด/กำหนดแล้ว/ยังไม่กำหนด"
- **Cloud-first sync** (`edSyncFromCloud`): ถ้า Supabase มี data → ใช้เสมอ (ignore local timestamp); cloud ว่าง + local มี → push อัตโนมัติ
- **Merge duplicate bank accounts** (`edMigrateAccounts`): normalize `account_no` (strip `-/space`) — กัน "865-0-98040-5" vs "865-098040-5" นับเป็น 2 บัญชี
- Layout: `main max-width: 1400 → none` (ใช้พื้นที่จอเต็ม)

### 2026-06-18 — FinOps Phase 1 (Bank/AP/Recurring) + Executive Dashboard nicht touched
- สร้าง schema `finops-phase1.sql` (8 ตารางใหม่ + RLS + triggers)
- ตัว parser Excel import (Bank_balance sheet + ค่าใช้จ่ายประจำ sheet)
- Express XML AP parser (Excel XML 2003 format) — dynamic header detection รองรับทั้ง MBark + Benya layout (column shift +1 ระหว่าง 2 format)
- AP CSV upload (vendor_name, invoice_no, invoice_date, due_date, amount_total)
- ที่จัดประเภท `apoClassify()` แมพ remark → 8 ประเภท (เงินกู้ยืม/เงินเดือน/เงินสดย่อย/มัดจำ/ค่าใช้จ่ายประจำ/ประมาณการสำรอง/สำรองจ่าย/เจ้าหนี้การค้า)
- อายุหนี้ตามสูตร Excel: <0=อยู่ในกำหนด, <30=ไม่ถึง 30 วัน, <60=30วัน, <90=60วัน, <120=90วัน, ≥120=120+ วัน
- Vendor favicons (Recurring page) — Google s2 service: TRUE, AIS, SCB, KBANK, กรมสรรพากร, สสร., Microsoft, Google, ฯลฯ

### 2026-06-17/18 — Executive Cash Flow Dashboard (admin only, นิ่งแล้ว)
- หน้า 6 tab (Summary / Activity / Category / Banks / Explorer / Statement)
- ติดลบเป็น `()` ทั่ว report
- คลิก drill-down ทุก KPI + cell + chart
- Statement จัดกลุ่ม รับ→จ่าย ต่อกิจกรรม
- PDF export (jsPDF + html2canvas) — landscape A4, thead repeat ทุกหน้า, slice ตาม row boundary (ไม่ตัดกลางตัวหนังสือ), Thai font ผ่าน canvas image
- Snapshot mode 1-page export (สำหรับ LINE)
- Per-company persistence via `exec_cashflow` table (jsonb)
- Color: pastel teal/pink ตาม palette

### 2026-06-15/16 — Foundation
- Login redesign (Water POG style — 2 company logos)
- Sidebar collapsible stage groups (default collapsed)
- Lucide icons
- IBM Plex Sans Thai font
- Auth fix (drop trigger ที่เคย break login)
- Users management page (admin only)
- BigSeller unknown shop card (แสดงตัวอย่างออเดอร์ + เลขแถว)

## Push rule: keep this file current
**ทุกครั้งที่ push** มีการเพิ่ม feature ใหญ่หรือเปลี่ยน convention — **อัปเดต `CLAUDE.md`** ให้ตรง (architecture, gotchas, recent changes section). ทำเป็น part ของ push เหมือนการเขียน commit message.

### 2026-07-08 — Recon fix: BigSeller "Voucher ของร้านค้า" เป็น bill-level (เลิก ×qty)
- **อาการ (เจ้าของจับได้):** Shopee ออเดอร์ qty=2 · voucher จริง 10 (หลังบ้านโชว์ "โค้ดส่วนลดร้าน SFP-... −฿10") แต่ระบบเก็บ 20 → ฐานภาษี bs 670 ≠ be 680 → ฟ้องผลต่างหลอก
- **ต้นเหตุ:** parser BigSeller เอา `voucher × mul` (mul=qty เพราะ perUnitPrice) — สมมติ voucher เป็น per-unit เหมือน "ราคา" · จริงๆ "Voucher ของร้านค้า" (โค้ดส่วนลดร้าน Shopee) = **bill-level ต่อออเดอร์** ใส่ซ้ำทุกแถว
- **แก้:** voucher ใช้ `cfg.discBillLevel ? Math.max : sum` เหมือน `disc` (เดิม 2026-06-26 ก็เป็น Math.max ก่อนถูกเปลี่ยนเป็น ×qty ตามเคส unverified) · qty=1 ได้ผลเท่าเดิม · ออเดอร์ไม่มี voucher ไม่กระทบ
- **ต้องทำ:** re-upload BigSeller → `ordIngestChannelOrders` vchChanged backfill `seller_voucher` (20→10) → recon กลับมาตรง
- **ความเสี่ยง (แจ้ง user):** ถ้ามีโปร voucher แบบ per-unit จริง (qty>1) จะกลายเป็นน้อยไป — ยังไม่เจอในข้อมูลจริง · ถ้าเจอค่อยทำ channel-aware

### 2026-07-08 — Recon fix (แก้ที่ถูกต้อง): voucher "ต่อชิ้น/ต่อแถว" แยกตามช่องทาง
- **PR #8 (Math.max ทั้งช่อง) ผิด → ทำ TikTok พัง** · วินิจฉัยจากข้อมูลจริง 3 ออเดอร์ (search view `ordReconDetailHtml`):
  - **TikTok** 584825... : 1 แถว qty 4 · voucher/แถว 385.20 · หลังบ้าน (SKU Seller Discount) = 1,540.80 = **385.20×4** → **per-unit (×qty)**
  - **Shopee** 260706 : 2 แถว qty1 · voucher 5/แถว · หลังบ้าน 10 = **5+5** → per-แถว (sum, mul=1)
  - **Shopee** 260703 : 1 แถว qty2 · voucher 10 · หลังบ้าน 10 → sum (mul=1)
- **สรุป:** code เดิม (×qty ทุกช่อง) ผิดกับ Shopee · PR #8 (Math.max) ผิดกับ TikTok+Shopee หลายแถว · **ที่ถูก = แยกช่องทาง:** `vmul = /tiktok/.test(platform) ? lineQty : 1` แล้ว `g.voucher += voucher*vmul` (sum เสมอ)
- **`ordParseSalesFile` voucher block** อ่าน platform จาก row ปัจจุบัน (`row[ci.platform]`) → tiktok ×qty · shopee/lazada ×1 · **unit test:** SP10→10 · SP(2แถว5)→10 · TT(qty4 385.2)→1540.8
- **ต้อง re-upload BigSeller** อีกครั้ง → backfill seller_voucher ให้ถูก → TikTok+Shopee ที่ฟ้องผลต่างจะหาย
- **Lazada:** default = ×1 (เหมือน Shopee · ยังไม่มีข้อมูลยืนยัน · ถ้าต่างค่อยเพิ่ม)

### 2026-07-08 — Orders board: แยกช่องทาง "อื่นๆ" ตามรหัสคำสั่งซื้อ + เพิ่ม CSR (ยอด 0)
- **เจ้าของขอ:** สอนให้ระบบรู้จักออเดอร์ช่องทางที่ไม่มีแพลตฟอร์ม จาก prefix รหัส: `FB…`=FACE · `LMS…`=LINE · อื่นๆ=Dealer · **ยอด 0 = CSR** (แจก/เคลม/ตัวอย่าง)
- **`ordChannelDetail(o)`** เปลี่ยนจากเดา text (channel/customer) → ดู `order_id` prefix + เช็ค `order_total===0` ก่อน (→csr) · marketplace (cg shopee/tiktok/lazada) return ตามเดิม (ตรวจก่อน)
- **`ORD_BOARD_CHANS_OTHER`** เพิ่ม `{k:"csr",l:"CSR",c:"#7c3aed"}` (ไม่มี img → badge ตัว C ม่วง) → matrix/othAgg/display columns/chip รองรับอัตโนมัติ (dynamic จาก array)
- **อัปเดต hardcode `["face","line","dealer"]` → เพิ่ม "csr"** ที่ `ordBoardDetailRows` (_oth filter), cntCh._oth, chLab (ใบส่งกลับฝ่ายขาย)
- **display-only** — ไม่แตะ channel_group ใน DB · ไม่ต้อง re-upload (จัดกลุ่มตอน render จาก order_id/order_total ที่มี) · **unit test:** FB→face · LMS→line · DR/XYZ→dealer · ยอด0→csr · marketplace→cg

### 2026-07-08 — Month scope + register icons (หน้าคำสั่งซื้อ/ส่งออก/หน้าแรก = เฉพาะเดือนปัจจุบัน)
- **เจ้าของขอ:** (1) หน้า "ออเดอร์ที่แมพแล้ว" มีไอคอนช่องทางคลิกได้ (2) หน้าส่งออกไปคีย์ = เฉพาะเดือนปัจจุบัน (3) หน้าแรกภาพรวมเดือน = เฉพาะเดือนปัจจุบัน
- **register icons** (`ordRenderRegister` chChip): เพิ่ม `ordPlatLogo(v,17)` หน้าชิป (all = icon layout-grid) → เห็นโลโก้ Shopee/TikTok/Lazada/offline
- **หน้าแรก** (`homeLoadStats`): สถิติออเดอร์ (ivPct/ivKeyed/ordTotal/cancelled/rePending/bankIn/saleSum) กรอง `order_date` = เดือนปัจจุบัน (`todayISO.slice(0,7)`) · AP/เงินสด = ยอด ณ ปัจจุบัน (balance ไม่ผูกเดือน)
- **หน้า 1.คำสั่งซื้อ/ส่งออก** (`renderToolSalesOrders`): `mrows = d.rows กรองเดือนปัจจุบัน` (via `cffISO`) → ส่งเข้า `salesKpis`/`salesRenderList`(param ใหม่ chip counts)/`unKeyedAll` · ivr export default `range:'today'→'month'`
- **display-only** — ไม่แตะ data/DB · board ยังมี month picker แยก (dateRange) เหมือนเดิม

### 2026-07-08 — Register "ออเดอร์ที่แมพแล้ว": โชว์ขายตรง (FACE/LINE/Dealer/CSR) ครบตามบอร์ด
- **อาการ:** ชิป "หน้าร้าน/อื่น" โชว์ว่างเปล่า แต่บอร์ดมี FACE/LINE/Dealer/CSR — เพราะ register กรอง `recOf(o)==='matched'` เท่านั้น แต่ขายตรงไม่มี recon (BigSeller = ความจริง) → หลุดหมด · แถมชิป offline จับ `channel_group===fCh` แต่บางออเดอร์เป็น 'other'
- **`ordRenderRegister`:** `show(o) = isMp(o) ? recOf==='matched' : true` (marketplace เฉพาะ matched · ขายตรง=โชว์ทุกใบ) · `inChip` offline = `!isMp(o)` (จับ offline+other) · `chCount` นับ marketplace matched + offline ทั้งหมด · column ช่องทางใช้ `chLabel(o)=ordChannelDetail→label` (Shopee/FACE/…) · status badge ขายตรง = "ขายตรง · ไม่ต้องกระทบ" (เขียว) แทน "รอเทียบยอดขาย"
- **unit test:** SP matched→show · SP diff→hide · offline(FB/LMS/DR)→show ทุกใบ · chCount shopee1/tiktok1/offline3
