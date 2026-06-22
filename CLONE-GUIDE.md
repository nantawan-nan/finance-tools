# คู่มือ Clone เว็บไปใช้กับกิจการใหม่ (แยก DB + แยกเว็บ 100%)

> ใช้ทำ "เว็บใหม่" สำหรับกิจการอื่น (เช่น บ.เล็ก / คุมค่าใช้จ่ายบ้าน) โดยข้อมูล **แยกขาด**จากของเดิม
> โค้ด engine ชุดเดียวกัน เปลี่ยนแค่ค่าไม่กี่จุด → ของเดิมไม่กระทบเลย

แต่ละ clone = **Supabase ใหม่ 1 project + GitHub repo ใหม่ 1 repo** ของตัวเอง

---

## ภาพรวม 6 ขั้น (ต่อ 1 clone)

| # | ขั้นตอน | ใครทำ |
|---|---|---|
| 1 | สร้าง Supabase project ใหม่ | แนน (ต้อง login Supabase) |
| 2 | สร้าง GitHub repo ใหม่ (ก๊อปจาก finance-tools) | แนน |
| 3 | แก้ config ในโค้ด (URL/คีย์ + โมดูล + บริษัท) | ตามคู่มือนี้ |
| 4 | ตั้ง secrets + push → migration สร้างตารางอัตโนมัติ | แนน |
| 5 | สร้าง user login | แนน (หน้าจัดการผู้ใช้) |
| 6 | เปิด GitHub Pages → ได้ลิงก์เว็บใหม่ | แนน |

---

## ขั้น 1 — Supabase project ใหม่

1. ไป https://supabase.com/dashboard → **New project** (ชื่อเช่น `finance-blek` / `finance-baan`)
2. ตั้งรหัส database (จดไว้) → เลือก region Singapore
3. รอสร้างเสร็จ ~2 นาที → เข้า **Settings → API** จดค่า:
   - **Project URL** (เช่น `https://abcd1234.supabase.co`)
   - **anon public key** (ขึ้นต้น `eyJ...`)
   - **service_role key** (สำหรับสร้าง user — เก็บเป็นความลับ)
4. **Settings → API Keys → Access Token** (หรือ https://supabase.com/dashboard/account/tokens) → สร้าง token ใหม่ = `SUPABASE_ACCESS_TOKEN` (ใช้รัน migration)
5. **Settings → Database → Connection string → Session pooler (IPv4)** → คัดลอก URI ใส่รหัส db = `SUPABASE_DB_URL` (ใช้ backup)

---

## ขั้น 2 — GitHub repo ใหม่

วิธีง่ายสุด (ก๊อปทั้งโค้ด):
```bash
# ดาวน์โหลด finance-tools มาเป็น repo ใหม่ (ไม่ผูก history เดิม)
git clone https://github.com/nantawan-nan/finance-tools.git finance-blek
cd finance-blek
rm -rf .git
git init
# สร้าง repo เปล่าใน GitHub ชื่อ finance-blek ก่อน แล้ว:
git remote add origin https://github.com/nantawan-nan/finance-blek.git
```
(ยังไม่ push — แก้ config ขั้น 3 ก่อน)

---

## ขั้น 3 — แก้ config ในโค้ด (จุดเดียวที่ต้องแตะ)

### 3.1 ชี้ Supabase ใหม่ — `index.html` บรรทัด ~384
```js
const SUPABASE_URL  = "https://abcd1234.supabase.co";   // ← Project URL ใหม่
const SUPABASE_ANON = "eyJ...";                          // ← anon key ใหม่
```

### 3.2 เลือกโมดูล + บริษัท — `index.html` ที่ `const APP_CONFIG = {`
ของเดิม `enabledTools:null` + `companies:null` = โชว์ทุกอย่าง 2 บริษัท
สำหรับ clone กระแสเงินสด ตั้งแบบนี้:
```js
const APP_CONFIG = {
  // โชว์เฉพาะโมดูลกระแสเงินสด
  enabledTools: ["home","execdash","cashflow","bank_balance","ap_outstanding","recurring","users"],

  // 1 บริษัท (ใช้ id "benya" เพื่อได้ธีมสี teal · หรือ "mbark" = navy)
  companies: [{ id:"benya", name:"บ.เล็ก", short:"S", brand:"บ.เล็ก",
    fullName:"บริษัท ... จำกัด", logo:"logos/benya-icon.png", gradient:["#0d9488","#2dd4bf"] }],
};
```
> โมดูลที่เปิด: หน้าหลัก · Executive Cash Flow · Cash Flow Forecast · ยอดเงินคงเหลือธนาคาร · AP Outstanding · ค่าใช้จ่ายประจำ · จัดการผู้ใช้
> ที่เหลือ (ขาย/BigSeller/Order/AR/Bank Recon ฯลฯ) จะถูกซ่อนอัตโนมัติ
> **Express import:** AP Outstanding มีปุ่มอัป Express XML อยู่แล้ว → ใช้ได้เลย

**สำหรับ "คุมค่าใช้จ่ายบ้าน"** ก็ตั้งเหมือนกัน เปลี่ยนแค่ `name:"บ้านนาย"` (id ใช้ "mbark" จะได้สีกันสับสนกับ บ.เล็ก)

### 3.3 ⚠️ สำคัญ — แก้ project ref ใน workflow migration
`.github/workflows/migrate.yml` มีบรรทัด **hardcode project ref ของเว็บเดิม** — ถ้าไม่แก้ migration จะวิ่งไป **DB เดิม**!
```yaml
SUPA_PROJECT_REF: qbsuynmsjieqglxzbqpw   # ← เปลี่ยนเป็น project ref ของ Supabase ใหม่
```
project ref = ส่วนหน้าของ URL (เช่น `https://abcd1234.supabase.co` → ref = `abcd1234`)
> `backup.yml` ไม่ต้องแก้ (ใช้ secret `SUPABASE_DB_URL` อยู่แล้ว)

---

## ขั้น 4 — Secrets + push (migration สร้างตารางเอง)

ใน repo ใหม่ → **Settings → Secrets and variables → Actions → New repository secret**:
- `SUPABASE_ACCESS_TOKEN` = token จากขั้น 1.4
- `SUPABASE_DB_URL` = connection string จากขั้น 1.5
- `BACKUP_PASSPHRASE` = ตั้งรหัสอะไรก็ได้ (เข้ารหัส backup)

แล้ว push:
```bash
git add -A && git commit -m "clone: finance-blek" && git push -u origin main
```
→ workflow `db-migrate` จะรัน `supabase/*.sql` ทั้งหมดบน Supabase ใหม่ = สร้างตารางครบ (~1 นาที)
→ ตาราง order/sales ที่ไม่ใช้ก็ถูกสร้างแต่ปล่อยว่างไว้ ไม่เป็นไร

---

## ขั้น 5 — สร้าง user

1. เปิดเว็บใหม่ (ขั้น 6) → ยังเข้าไม่ได้เพราะไม่มี user
2. ใช้ **Supabase Dashboard → Authentication → Add user** สร้าง user แรก (admin) + ยืนยันอีเมล
3. เข้าเว็บด้วย user นั้น → ไปหน้า **จัดการผู้ใช้** → วาง `service_role key` (ขั้น 1.3) → ตั้ง role = admin + ให้สิทธิ์บริษัท
4. (หรือสร้าง user เพิ่มทั้งหมดจากหน้าจัดการผู้ใช้)

---

## ขั้น 6 — เปิด GitHub Pages

repo ใหม่ → **Settings → Pages → Source: Deploy from a branch → main / root** → Save
ได้ลิงก์ `https://nantawan-nan.github.io/finance-blek/`

---

## สรุปสิ่งที่ "แยกขาด"
- ✅ ฐานข้อมูล + ผู้ใช้ + รหัส = Supabase project ใหม่ (คนละอัน)
- ✅ เว็บไซต์ + ลิงก์ = repo + Pages ใหม่
- ✅ backup รายคืน = ของใครของมัน
- ✅ แก้/อัปเดตของเดิม ไม่กระทบ clone (และกลับกัน)

## อัปเดต engine ในอนาคต (optional)
ถ้าแก้ feature ในของเดิมแล้วอยากให้ clone ได้ด้วย — ก๊อป `index.html` + `supabase/*.sql` ใหม่ทับ
(ระวังอย่าทับ `APP_CONFIG` + `SUPABASE_URL/ANON` ของ clone)
