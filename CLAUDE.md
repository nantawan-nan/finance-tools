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
- `ap_payments` + trigger `fn_ap_recompute` (auto-update `amount_paid` + `status`)
- `recurring_expenses` + `recurring_occurrences` + `fn_materialise_recurring()`
- `csv_imports` (audit trail)
- RLS: read = ทุก user ของ company, write = admin/finance_mgr/accountant/treasury

### Other tables
- `exec_cashflow` — `(company_id PK, data jsonb)` — Executive Dashboard data per company (`supabase/exec-cashflow.sql`)
- `ar_receipts` — Phase 0 AR module (`supabase/ar-module.sql`)
- (อนาคต: ar_invoices, marketplace_settlements, forecast_items)

## Modules (TOOLS array — render dispatcher in `renderTool()`)

| id | function | สถานะ | หมายเหตุ |
|---|---|---|---|
| `home` | `renderToolHome` | live | Hub grid + greeting "สวัสดี <user>" — auto-fill toolcard |
| `execdash` | `renderToolExecDash` | live (admin only) | **★ ห้ามแก้ — นิ่งแล้ว** ใช้เป็น reference สี/สไตล์ |
| `orders` | `renderToolOrders` | live | **ทะเบียนคำสั่งซื้อ** (Order Ledger) — รับรู้ออเดอร์ 4 ช่องทางก่อนมี IV · timeline ขาย→IV→รับชำระ→แบงค์ · ord* helpers |
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
| `ap_outstanding` | `renderToolApOutstanding` | live | **AP จริง** (finops phase 1) |
| `bank_balance` | `renderToolBankBalance` | live | **ตารางกรอกยอดรายวัน** (chip เลือกวัน + "พรุ่งนี้" คาดการณ์ carry-forward) — bb* helpers |
| `recurring` | `renderToolRecurring` | live | ค่าใช้จ่ายประจำ |
| `cashflow` | `renderToolCashflowForecast` | live | **Cash Flow Forecast** — มี 2 view: 📋 พนักงาน (daily LINE) + 📊 ผู้บริหาร (30d) |
| `tasks` | (none) | soon | — |
| `docs` | (none) | soon | — |
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
