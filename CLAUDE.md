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
| `bankrec` | (none) | soon | Bank Reconciliation |
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
- Cash Flow Staff: เพิ่ม recurring ตามวันจ่าย (`cffStaffPayments`) + เรียงผู้ขายเดียวกันติดกัน (`cffItemCmp`)
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
