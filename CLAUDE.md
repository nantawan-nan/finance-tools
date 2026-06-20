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
| `dashboard` | `renderToolDashboard` | live | Sales Dashboard |
| `bigseller` | `renderToolBigSeller` | live | BigSeller → IV import |
| `expressmatch` | `renderToolExpressMatch` | live | แมพ IV จาก Express CSV |
| `exportkey` | `renderToolExportKey` | live | ส่งออกคีย์ AutoKey |
| `ar` | `renderToolAr` | live | AR Outstanding |
| `armap` | `renderToolArmap` | live | Map ลูกหนี้ → เงินเข้า |
| `settle` | (none — generic) | live | จับยอด Settlement |
| `bankrec` | `renderToolBankRec` | live | **Full Bank Reconciliation** (Phase 1) — Express XML ↔ Statement (SCB XLSX / BBL XLS) · strict same-date · brec* helpers |
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
  - MBark: SCB 136-2-270928-1 (บัญชีเดียว ง่ายสุด)
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
