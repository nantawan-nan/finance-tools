# Bank Reconciliation — Design & Implementation Handoff

> Self-contained spec for transferring the bank reconciliation feature to another codebase/AI.
> Source: finance-tools (Benya + MBark · single-file SPA · Supabase backend)

---

## 1. Goal & Workflow

ระบบกระทบยอด **Express** (สมุดธนาคารภายในระบบบัญชี Express) ↔ **Bank Statement** (XLSX จากธนาคาร) สำหรับหลายบริษัท หลายบัญชีต่อบริษัท

- **Input:** Express XML (1 บัญชี/ไฟล์) + Bank Statement XLSX (SCB / BBL / KBank ฯลฯ)
- **Output:** บอกได้ทันทีว่ารายการไหนตรง/ค้าง/ไม่ตรง · % กระทบเทียบ row count
- **กฎสำคัญ:**
  - วันที่ Express **ต้องตรงเป๊ะ** กับวันที่ Statement (ไม่มี ±N วัน)
  - ยอดต้องตรง **±0.01**

### ขั้นตอนใช้งานจริง (User Workflow)

1. เลือกบัญชีจาก dropdown (หรือคลิก card จาก overview landing)
2. กด **"ล้าง+อัปใหม่ Express"** → เลือกไฟล์ → import
3. กด **"ล้าง+อัปใหม่ Statement"** → เลือกไฟล์ → import
4. กด **"จับคู่อัตโนมัติ"** → AI match
5. แท็บ "รอยืนยัน" → กด **"ยืนยันทั้งหมด"** 1 คลิก
6. แท็บ "รอกระทบยอด" → จับคู่ที่เหลือเอง (รองรับ M-to-N)

---

## 2. Data Model (Supabase / Postgres)

```sql
-- บัญชีธนาคาร (master)
bank_accounts (
  id uuid PK, company_id uuid,
  bank_code text,           -- 'BBL', 'SCB', 'KBANK', ...
  account_no text,          -- raw รวม dashes ('865-0-980405' OK)
  nickname text,            -- ⚠ ห้ามใช้แสดง — กัน label เหมือนแต่ data ต่าง
  is_active bool,
  deleted_at timestamptz    -- soft delete
)

-- ประวัติการอัปไฟล์ (audit trail · batch metadata)
brec_imports (
  id, company_id, bank_account_id,
  source text,              -- 'express' | 'bank'
  filename, file_hash, period_from, period_to, row_count, status,
  batch_no text,            -- 'IMP-{SRC}-YYYYMMDD-NNN' (SRC = EXP/SCB/BBL/...)
  rows_added, rows_dup, rows_ambiguous, rows_failed,
  uploader_email, summary_json jsonb,
  created_at, deleted_at
)

-- แถวรายการต่อฝั่ง
brec_express_rows (
  id, company_id, bank_account_id, import_id,
  txn_date date, mne text, doc_no text,
  withdrawal numeric(18,2), deposit numeric(18,2), balance numeric(18,2),
  remark text, cheque_status text,
  ambiguous bool default false,        -- flag เมื่อ stable-key ซ้ำในไฟล์เดียวกัน
  deleted_at
)

brec_bank_rows (
  id, company_id, bank_account_id, import_id,
  txn_date date, tr_code text, description text, cheque_no text,
  withdrawal, deposit, balance,
  ref_note text,                       -- "Note" จาก SCB BusinessNet (เลขใบสำคัญ PS/BT...)
  ambiguous bool default false,
  deleted_at
)

-- การจับคู่ (M-to-N supported)
brec_matches (
  id, company_id, bank_account_id,
  express_row_id uuid, bank_row_id uuid,
  status text,             -- 'suggested' | 'confirmed' | 'manual' | 'group'
  confidence text,         -- 'exact' | 'suggested' | 'manual' | 'group'
  match_reason text,
  match_group_id text,     -- ★ group tag สำหรับ M-to-N (NULL = 1:1)
  confirmed_at, deleted_at
)
```

### Indexes สำคัญ

```sql
-- Stable-key dedup (ห้าม row เดียวกันถูก import ซ้ำ)
CREATE UNIQUE INDEX uniq_brec_ex_stable ON brec_express_rows
  (bank_account_id, txn_date, withdrawal, deposit, COALESCE(doc_no,''))
  WHERE deleted_at IS NULL AND ambiguous=false;

CREATE UNIQUE INDEX uniq_brec_bk_stable ON brec_bank_rows
  (bank_account_id, txn_date, withdrawal, deposit, COALESCE(cheque_no,''), COALESCE(ref_note,''))
  WHERE deleted_at IS NULL AND ambiguous=false;

-- Match pair-unique (allow M-to-N · ห้ามแค่คู่เดียวกันซ้ำ)
CREATE UNIQUE INDEX uq_brec_match_pair ON brec_matches
  (express_row_id, bank_row_id) WHERE deleted_at IS NULL;
```

---

## 3. Parsers (3 ตัว)

```js
brecParseExpressXml(text)
  // Excel SpreadsheetML XML "งบกระทบยอด" — ใช้ได้กับ BBL+SCB Express
  // ดึง bank_code+account_no จาก header 'S/A #...'

brecParseScbXlsx(workbook)
  // SCB BusinessNet sheet 'RPT_01009_XLSX' 16 cols
  // ใช้คอลัมน์ 'Note' (เลขใบสำคัญ PS/BT...) สำหรับ ref match

brecParseBblXls(workbook)
  // BBL iBanking .xls (BIFF format)
  // header row ~16, 9 cols (Debit/Credit/Ledger)
  // ไม่มี ref field → match ด้วย date+amount เท่านั้น

brecParseStatement(wb)
  // auto-detect SCB vs BBL จาก header signature
```

**Critical:** parsers ต้องเก็บ `withdrawal` และ `deposit` เป็น **เลขบวกเสมอ** (absolute value · ห้ามใส่ลบ). Sign convention ใช้ที่ display layer (deposit=+ / withdrawal=−)

---

## 4. Matching Algorithm

```js
// Tier 1 EXACT: confidence='exact', status='suggested'
//   ref+date+ยอด ตรงเป๊ะ (ref normalize ด้วย refKey: strip Q prefix ของ QPPS → PS)
// Tier 2 SUGGEST: confidence='suggested', status='suggested'
//   date+ยอด ตรง (ไม่มี ref) — สำหรับ BBL ที่ไม่มี ref field
// ทุก match เริ่ม status='suggested' → user กดยืนยันถึงเป็น 'confirmed'

function brecAutoMatch(exRows, bkRows, existing){
  // ★ ห้ามใช้ tolerance วันที่ — ตรงเป๊ะเท่านั้น
  // ★ ใช้ Math.abs ทั้ง 2 ฝั่งกัน parser เก็บ sign แตก
  const proposed = [];
  for(const ex of unmatchedEx){
    const exact = unmatchedBk.find(bk =>
      bk.txn_date === ex.txn_date
      && refKey(bk.ref_note) === refKey(ex.doc_no)
      && Math.abs(absAmt(ex) - absAmt(bk)) < 0.01
    );
    if(exact){ proposed.push({...pair, confidence:'exact'}); continue; }
    const sugg = unmatchedBk.find(bk =>
      bk.txn_date === ex.txn_date
      && Math.abs(absAmt(ex) - absAmt(bk)) < 0.01
    );
    if(sugg) proposed.push({...pair, confidence:'suggested'});
  }
  return proposed;
}
```

---

## 5. M-to-N Group Match (สำคัญ)

**เคสจริง:** ลูกค้าโอน 2,450 บาท แต่โอนขาด → โอนมาเพิ่ม 10 บาท
- Express 1 รายการ +2,450
- Bank 2 รายการ +2,440 / +10
- ผลรวมตรง → match ได้

```js
async function brecManualLink(){
  // Unified: รองรับ 1:1, 1:N, M:1, M:N
  const exRows = selectedEx;  // user เลือกหลายแถว
  const bkRows = selectedBk;
  if(!exRows.length || !bkRows.length) return reject("เลือก Ex ≥1 + Bk ≥1");

  const exSum = exRows.reduce((s,r)=>s + brecSignedAmt(r), 0);
  const bkSum = bkRows.reduce((s,r)=>s + brecSignedAmt(r), 0);
  if(Math.abs(exSum - bkSum) >= 0.01){
    return reject(`❌ ผลรวมไม่ตรงเป๊ะ\n• Ex ${exRows.length} = ${exSum}\n• Bk ${bkRows.length} = ${bkSum}\n• ต่าง ${Math.abs(exSum-bkSum)}`);
  }

  // สร้าง cross product matches (M × N records) ผูก group_id เดียวกัน
  const isGroup = exRows.length>1 || bkRows.length>1;
  const groupId = isGroup
    ? `GRP-${Date.now().toString(36)}-${Math.random().toString(36).slice(2,7)}`
    : null;
  const inserts = [];
  for(const ex of exRows){
    for(const bk of bkRows){
      inserts.push({
        express_row_id: ex.id, bank_row_id: bk.id,
        status: 'confirmed', confidence: isGroup ? 'group' : 'manual',
        match_group_id: groupId, match_reason: isGroup ? `กลุ่ม ${exRows.length}×${bkRows.length}` : 'manual',
        confirmed_at: now
      });
    }
  }
  await sb.from('brec_matches').insert(inserts);
}
```

**Schema requirement:** `brec_matches` ต้อง drop single-side unique (`uq_brec_match_express`, `uq_brec_match_bank`) แล้วใช้ pair-unique `(express_row_id, bank_row_id)` แทน · ไม่งั้นจะ insert ไม่ได้

---

## 6. Sign Convention (เคยพังหลายรอบ)

```js
// ★ ใช้ Math.abs ทั้ง 2 ฝั่งเสมอ — parser บางตัวเก็บ withdrawal เป็นลบ (-20)
//   ทำให้ deposit - withdrawal = 0 - (-20) = +20 (sign แตก)
function brecSignedAmt(r){
  const dep = Math.abs(Number(r.deposit)||0);
  const wd  = Math.abs(Number(r.withdrawal)||0);
  return dep - wd;
}
// Display: ฝาก = "+X" สีเขียว, ถอน = "-X" สีแดง (ใช้ abs ก่อนเอามาใส่ prefix)
//   ห้ามใช้ formatter ที่แสดงลบเป็น "(X)" ตรงนี้ — จะกลายเป็น "-(20.00)" double-negative
function displayAmt(r){
  const inAmt = Math.abs(Number(r.deposit)||0);
  const outAmt = Math.abs(Number(r.withdrawal)||0);
  return inAmt > 0 ? `+${fmtPos(inAmt)}` : `-${fmtPos(outAmt)}`;
}
```

---

## 7. Stable-Key Dedup (Phase A — สำคัญ)

**ปัญหาเดิม:** เมื่อยกเลิก PS กลางงวดใน Express แล้วอัป XML ใหม่ → running balance ของรายการหลังเปลี่ยน → ลายเซ็นเดิมเปลี่ยน → ระบบนับเป็นรายการใหม่ทั้งหมด → false duplicate

**แก้:**

- **ห้ามใช้ balance ใน stable key** (running balance เปลี่ยนได้)
- Stable key Express: `date|withdrawal|deposit|doc_no`
- Stable key Bank: `date|withdrawal|deposit|cheque_no|ref_note`
- Detect ambiguous (key ซ้ำใน file เดียวกัน) → insert ทั้งหมด flag `ambiguous=true` → user resolve

```js
function brecRowSig(r, source){
  if(source === 'express')
    return `${r.txn_date}|${r.withdrawal}|${r.deposit}|${r.doc_no||''}`;
  return `${r.txn_date}|${r.withdrawal}|${r.deposit}|${r.cheque_no||''}|${r.ref_note||''}`;
}

// Upload flow:
// 1. detect ambiguous WITHIN file (Map<stableKey, count> · keys count≥2 → ambiguous=true)
// 2. query existing rows (non-ambiguous + non-deleted) → existSig Set
// 3. categorize: ambiguous (insert all flag=true) · dup (skip) · new (insert flag=false)
// 4. confirm dialog แสดงผลก่อน insert
// 5. chunked insert + per-row fallback ถ้า chunk fail (race: skip 23505 / duplicate key)
```

---

## 8. UI Architecture

### Overview landing (default view)

```
Hero (gradient · brand color)
KPI strip 4 ใบ: บัญชีทั้งหมด · % เฉลี่ย · รอยืนยัน · ค้างกระทบ

Card grid (auto-fit minmax 310px):
  ┌────────────────────────────────────┐
  │ 🏦 [logo] BBL 865-0-980405         │
  │           กรุงเทพ · 160 รายการแบงค์│
  │ 95% กระทบแล้ว · 152/160 รายการแบงค์ │
  │ ████████████████████████████  95%   │
  │ ✓ กระทบ 152    ⏳ รอยืนยัน 5      │
  │ ⚠ ค้าง Ex 2    ⚠ ค้าง Bk 1        │
  │ 🕒 อัปล่าสุด: 2 ชม.ที่แล้ว           │
  │              เปิดดูรายละเอียด →     │
  └────────────────────────────────────┘
```

**สูตร %:** `distinct bank_row_id ที่มี confirmed match / total bank rows × 100`
- count รายการ ไม่ใช่มูลค่า
- รองรับ M-to-N (1 bank_row อาจมี multiple match records แต่ count 1 ครั้ง)
- สี progress bar: ≥90% เขียว · 60-89% ส้ม · <60% แดง

### Detail view (single account)

```
← ภาพรวมบัญชี / BBL 865-0-980405  (breadcrumb)

Toolbar:
  [บัญชี ▾] [งวด: รายเดือน|ช่วงวัน] [เดือน |---]
  [📥 นำเข้า ▾] [📤 ส่งออก ▾] [⚡ จับคู่อัตโนมัติ]

KPI cards: ยอด Express · ยอด Bank · ผลต่าง · กระทบแล้ว · ค้างกระทบ

Tabs: รอยืนยัน N | รอกระทบยอด N | กระทบแล้ว N | ทั้งหมด N | 🛒 Marketplace

Filter bar:
  🔍 [ค้นหา ref/desc/amount...]
  📅 [date from] → [date to]   💰 [min] — [max]   🔃 [sort ▾]

Action bar (เลือกแล้ว N รายการ):
  [จับคู่ที่เลือก (1:1 / M-N)] [ยืนยันที่เลือก]

Rows: compact single-line (~30px height) · ~12-18 visible per screen
```

### Row layout (single-line)

```
[☑] [date | ref-pill | mne] [description-ellipsis...] [+/-amount]   ↔   [Bank side same]   [status badge]   [actions]
```

Grid: `26px 1fr 22px 1fr 96px 92px`
Height: 30px (was 80-100px before compact)

---

## 9. Toolbar Pattern (Dropdown menus)

```
[📥 นำเข้าข้อมูล ▾]
  ├ เพิ่มเข้าของเดิม
  │  ├ Express XML
  │  └ Bank Statement
  ├ ล้าง+อัปใหม่ (เริ่มงวดใหม่สะอาด)
  │  ├ ล้าง+อัปใหม่ Express
  │  └ ล้าง+อัปใหม่ Statement
  └ Marketplace 3 ไฟล์ (Shopee + Express AR + Cheque)

[📤 ส่งออก ▾]
  ├ Excel (กระทบ + รอกระทบ + ค้าง)
  └ ประวัติการอัปไฟล์
```

### "ล้าง+อัปใหม่" workflow

```js
async function brecReplaceUpload(kind){
  if(!confirm(`ลบรายการ ${kind} ทั้งหมดในบัญชีนี้ + ลบ match ทั้งหมด?`)) return;
  const table = kind==='express' ? 'brec_express_rows' : 'brec_bank_rows';
  await sb.from(table).update({deleted_at:now}).eq('bank_account_id', acctId).is('deleted_at',null);
  await sb.from('brec_matches').delete().eq('bank_account_id', acctId);
  await brecLoad();
  brecUpload(kind);  // เปิด file picker
}
```

ใช้แทน upload ปกติเมื่อต้องการเริ่มงวดใหม่สะอาด (กันรายการซ้ำ/match เก่าค้าง)

---

## 10. Account Management (Critical)

### Normalization (strip invisible chars)

```js
brecNormBankCode(s){
  return String(s||'').toUpperCase()
    .replace(/[\s ​‌‍‎‏  　﻿]+/g,'');
  // strip: standard whitespace + NBSP + zero-width spaces + BOM
}
brecNormAcctNo(s){ return String(s||'').replace(/\D/g,''); }
```

### Dup detection + auto-banner

```js
function brecFindDupGroups(accts){
  const groups = {};
  accts.forEach(a => {
    const k = brecNormBankCode(a.bank_code) + '|' + brecNormAcctNo(a.account_no);
    (groups[k] = groups[k] || []).push(a);
  });
  return Object.values(groups).filter(g => g.length > 1);
}

// ใน render: ถ้าเจอ dup → banner สีแดง + ปุ่ม "รวมเลย"
// merge: เก็บ canonical (ตัวที่มี dashes อ่านง่าย) · ย้าย child rows ทั้งหมด
//        (brec_express_rows, brec_bank_rows, brec_matches, bank_balances, brec_mp_*)
//        ไปบัญชีหลัก · soft-delete อื่น
```

### Block auto-create

```js
async function brecEnsureAccount(co, bankCode, accountNo, opts){
  const allowCreate = !opts || opts.allowCreate !== false;
  const norm = brecNormAcctNo(accountNo);
  const codeNorm = brecNormBankCode(bankCode);
  if(!norm || !codeNorm) return null;
  const { data } = await sb.from('bank_accounts').select('id,...').eq('company_id', co);
  const matches = data.filter(a =>
    brecNormBankCode(a.bank_code) === codeNorm
    && brecNormAcctNo(a.account_no) === norm
  );
  const active = matches.find(a => !a.deleted_at);
  if(active) return active.id;
  if(!allowCreate) return null;   // ★ lookup-only mode
  if(matches.length){ /* revive soft-deleted */ }
  // else: create new
}

// Usage:
// - Marketplace upload: allowCreate:false (กัน routing สร้างบัญชีใหม่)
// - Bank Balance Excel: default true (จำเป็นตอน setup ครั้งแรก)
// - Express/Statement upload: require user pick account จาก dropdown (no auto-create)
```

### Account label

- **ห้ามใช้ nickname** (เคย mislead — label เหมือนแต่ data ต่าง)
- โชว์ `{bank_code} {account_no}` raw
- เพิ่ม `· #xxxx` (id-suffix 4 ตัว) **เฉพาะ** เมื่อ label ซ้ำกับบัญชีอื่นใน list

```js
function brecAcctLabel(a, allAccts){
  const base = `${(a.bank_code||'').trim()} ${(a.account_no||'').trim()}`;
  if(Array.isArray(allAccts)){
    const clash = allAccts.some(x => x.id !== a.id
      && `${(x.bank_code||'').trim()} ${(x.account_no||'').trim()}` === base);
    if(clash) return `${base} · #${String(a.id||'').slice(-4)}`;
  }
  return base;
}
```

---

## 11. Migration Order (Gotcha)

Workflow รัน `.sql` แบบ **alphabetical**. ถ้ามี migration ที่ต้อง drop/recreate index ของ schema เดิม (`bankrec-phase1.sql`):

- ใช้ prefix `zz-*` ให้รัน **หลัง** phase1 เสมอ
- ตัวอย่าง: `zz-bankrec-multi-match.sql` ← drop `uq_brec_match_express` หลัง phase1 recreate ทุก push
- ทุก DDL ห่อ `BEGIN EXECUTE '...' EXCEPTION WHEN OTHERS THEN NULL; END;` กัน fail ทั้งไฟล์
- ทุกไฟล์ต้อง idempotent (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`)
- ปิดท้าย `NOTIFY pgrst, 'reload schema'` กัน PostgREST cache

```sql
-- zz-bankrec-multi-match.sql (รันท้ายสุดทุก push · override phase1)
DO $$
BEGIN
  -- drop old single-column unique (Phase 1) — ทั้ง INDEX + CONSTRAINT form
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_brec_match_express'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'DROP INDEX IF EXISTS uq_brec_match_bank'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE brec_matches DROP CONSTRAINT IF EXISTS uq_brec_match_express'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'ALTER TABLE brec_matches DROP CONSTRAINT IF EXISTS uq_brec_match_bank'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_brec_match_pair ON brec_matches (express_row_id, bank_row_id) WHERE deleted_at IS NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
ALTER TABLE brec_matches ADD COLUMN IF NOT EXISTS match_group_id text;
NOTIFY pgrst, 'reload schema';
```

---

## 12. Batch History (Phase B)

ทุก import สร้าง record `brec_imports` พร้อม:

- `batch_no` format `IMP-{SRC}-YYYYMMDD-NNN` (auto-increment ต่อวัน · src=EXP/SCB/BBL/KBANK...)
- stats: `rows_added`, `rows_dup`, `rows_ambiguous`, `rows_failed`, `uploader_email`
- `summary_json`: `bank_code`, `account_no`, `file_size`, `file_rows`
- `status`: `success` / `warning` (มี ambig) / `failed`

UI: ปุ่ม "📚 ประวัติ" → modal ตาราง 9 cols (batch / time / type / period / count / added / dup / ⚠ / status / uploader)

---

## 13. Bulk Actions UX

```
แท็บ "รอยืนยัน":
  Banner เขียวบนสุด: "🤖 AI จับคู่ได้ X คู่ (EXACT a · SUGGEST b)"
  [ปุ่มเขียวใหญ่: ยืนยันทั้งหมด (X)]  ← 1 คลิก confirm ทั้งหมด
  ตารางด้านล่าง: รายการพร้อม checkbox + ปุ่มต่อแถว

แท็บ "รอกระทบยอด":
  Filter bar: search + วันที่ + ยอด + sort
  ตาราง: ex-only / bk-only · checkbox ทุกแถว
  Action: "จับคู่ที่เลือก" (รับทั้ง 1:1 และ M:N · validate sum ±0.01)
```

```js
async function brecConfirmAllPending(){
  const pending = buckets.pending;  // matches with status != 'confirmed'
  const exactN = pending.filter(p => p.m.confidence === 'exact').length;
  const sugN = pending.length - exactN;
  if(!confirm(`ยืนยัน ${pending.length} คู่ที่ AI จับไว้?\nEXACT: ${exactN} · SUGGEST: ${sugN}`)) return;
  d.sel.ex = new Set(pending.map(p => p.m.id));
  await brecConfirmSelected();   // bulk update status='confirmed'
}
```

---

## 14. Filter & Sort (ทุก tab)

```js
d.filter = { q:'', dateFrom:'', dateTo:'', amountMin:'', amountMax:'', sort:'date_desc' }

function brecFilterRow(r, f){
  if(!r) return false;
  if(f.dateFrom && r.txn_date < f.dateFrom) return false;
  if(f.dateTo && r.txn_date > f.dateTo) return false;
  const amt = Math.abs(Number(r.deposit||0) || Number(r.withdrawal||0));
  if(f.amountMin && amt < +f.amountMin) return false;
  if(f.amountMax && amt > +f.amountMax) return false;
  if(f.q){
    const q = String(f.q).toLowerCase();
    const txt = `${r.txn_date} ${r.doc_no||''} ${r.ref_note||''} ${r.cheque_no||''} ${r.mne||''} ${r.remark||''} ${r.description||''} ${amt}`.toLowerCase();
    if(!txt.includes(q)) return false;
  }
  return true;
}
function brecFilterPair(ex, bk, f){
  // pair ผ่านถ้าฝั่งใดฝั่งหนึ่งผ่าน filter
  return brecFilterRow(ex, f) || brecFilterRow(bk, f);
}
// Sort: date asc/desc · amount asc/desc
```

---

## 15. Recent Critical Fixes (รู้ไว้กันพลาดซ้ำ)

| Bug | Root Cause | Fix |
|---|---|---|
| รายการซ้ำ stable key (Phase A) | ใช้ balance ใน key → cancellation เปลี่ยน balance | Stable key ไม่รวม balance |
| Dup accounts | NBSP/zero-width ใน bank_code | normalize strip invisible chars |
| Auto-create accounts | Routing format ต่างจาก DB → สร้างใหม่ | `allowCreate:false` option · block in marketplace upload |
| M-to-N "duplicate key" | `phase1.sql` recreate single-side unique ทุก push | rename migration `zz-*` ให้รันท้าย |
| Sign แตก double-negative | parser เก็บ withdrawal เป็นลบ | `Math.abs` ทั้ง dep+wd |
| "ยืนยันที่เลือก" ไม่ทำงาน | `d.sel.ex` ใช้ match.id แต่ unmatched tab ตั้งเป็น row.id | แยก action ตาม tab · unmatched ใช้ `brecManualLink` |
| Date display "-(20.00)" | `fopFmt` ที่มี () + prefix `-` → double negative | ใช้ plain formatter ใน brecSideHTML |

---

## 16. State Shape (in-memory)

```js
state.brec[companyId] = {
  // Account / context
  accounts: [],          // จาก brec_loadAccounts (filter deleted_at)
  accountId: null,       // selected
  dupGroups: [],         // จาก brecFindDupGroups (auto-detected)
  companyId: null,

  // View
  view: 'overview',      // 'overview' (default landing) | 'detail'
  tab: 'pending',        // 'pending' | 'unmatched' | 'done' | 'all' | 'mp'

  // Period (detail view)
  period: { mode:'month', month:'2026-06', from:null, to:null },

  // Data (detail view)
  express: [], bank: [], matches: [],

  // Overview cache
  overviewStats: { [acctId]: { bankN, expressN, matchedBankN, pendingMatchN, ... } },
  overviewLoadedAt: 0,   // re-fetch ทุก 60 วินาที

  // Selection (multi-select for actions)
  sel: { ex: new Set(), bk: new Set() },

  // Filter (per-tab search/date/amount/sort)
  filter: { q, dateFrom, dateTo, amountMin, amountMax, sort },

  // Marketplace (separate sub-feature)
  mp: { withdrawals, orders, mismatchOrders, ... },

  busy: false
}
```

---

## 17. Tech Stack & Constraints

- **No build step** — single HTML file (~18k lines) · vanilla JS · global functions
- **No framework** — `renderToolBankRec()` assigns `main.innerHTML` ทั้งหน้า
- **Supabase** — Postgres + Auth + RLS (RLS ปิดสำหรับ brec_* tables · ใช้ company_id ใน query แทน)
- **Libs:** `XLSX` (SheetJS), `supabase-js`, `lucide` icons
- **Auto-deploy:** `git push` → GitHub Pages + workflow `db-migrate` รัน `supabase/*.sql` ตาม alphabetical
- **State persistence:** localStorage cache for small UI prefs · main data via Supabase

---

## 18. Module File Convention (for porting)

```
supabase/
  bankrec-phase1.sql              # baseline schema (tables + initial indexes)
  bankrec-phase-a-stable-key.sql  # Phase A (dedup with stable key)
  bankrec-phase-b-batch-history.sql # Phase B (batch tracking)
  hotfix-bankrec-*.sql            # hot-fixes (run after fix-*)
  zz-bankrec-*.sql                # overrides that must run LAST (post phase1)
```

Helper prefix in JS: `brec*` (Bank Reconciliation core), `bmp*` (Marketplace sub-feature)

---

## 19. CSS Tokens / Visual Design

```css
/* Colors */
--brand: var(--brand);  /* per company: Benya teal, MBark navy */
--ok:    #10b981;  --ok-700:  #065f46;
--wn:    #f59e0b;  --wn-700:  #92400e;
--dg:    #dc2626;  --dg-700:  #991b1b;
--in:    #3b82f6;  --in-700:  #1d4ed8;

/* Status badges */
.brec-tag.exact { bg:#dcfce7; color:#166534 }
.brec-tag.sug   { bg:#fef3c7; color:#92400e }
.brec-tag.man   { bg:#e0e7ff; color:#3730a3 }
.brec-tag.conf  { bg:#dbeafe; color:#1e40af }

/* Row left-border by tab */
.matched   { border-left: 3px solid #16a34a }
.suggested { border-left: 3px solid #d97706 }
.unex      { border-left: 3px solid var(--brand) }
.unbk      { border-left: 3px solid #2563eb }
.confirmed { background:#f0fdf4; border-left: 3px solid #16a34a }

/* Compact row */
.brec-row { display:grid; grid-template-columns: 26px 1fr 22px 1fr 96px 100px;
            gap: 6px; padding: 5px 10px; align-items:center }
.brec-side { height: 30px; padding: 4px 9px; display:flex; gap:7px;
             border-radius: 6px; background: #f8fafc }
```

---

## 20. Open Areas (สำหรับ next iterations)

- Period Close (Phase C) — lock งวด · snapshot · ห้ามแก้ย้อนหลัง
- Removed-from-Source detection — เมื่อรายการหายจาก Express ใหม่ → flag
- Audit Trail enhancement
- Snapshot Excel/PDF Report (full reconciliation report สำหรับเซ็น)
- Table view สำหรับ overview เมื่อมีบัญชี >10 (current = card grid)

---

**ผู้ที่จะ port spec นี้:** อ่านพร้อม `supabase/bankrec-*.sql` (~7 ไฟล์) เป็น source-of-truth สำหรับ schema. JS helpers prefix `brec*` ใน `index.html` (search `function brec` จะเจอ ~40 functions). UI mockup อ้างอิงได้จาก `for-design/bankrec-mockup.html`
