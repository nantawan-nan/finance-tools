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
  - **ลดความรก:** เวนเดอร์ที่มี **รายการเดียว → ยุบเป็น 1 บรรทัด** (ชื่อ + ยอด · **คำอธิบายโผล่เฉพาะตอนกาง = ระดับ "ตามเอกสาร"**) — ระดับ "ตามผู้จำหน่าย" โชว์แค่ชื่อ+ยอดรวม ไม่บอกว่าจ่ายค่าอะไร · **หลายรายการ → หัวเวนเดอร์เด่น** (พื้น `rgba(brand,.04)` + ตัวหนา brand-dark + chip จำนวน) แล้วค่อยกางรายการย่อย · `subLine(p,ven)` = **"คำอธิบาย (เด่น) · เลขเอกสาร (จาง #94a3b8)"** — ขึ้นต้นด้วยคำอธิบายให้อ่านง่าย (เดิม doc ขึ้นก่อนตาอ่านยาก) · ตัด desc ที่ซ้ำชื่อเวนเดอร์ · `cffCleanDesc` ตัด **"· Express:xxxx"** ท้ายทิ้ง (รก/ซ้ำเลขเอกสาร)
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
