# วิธีถอดรหัสและ Restore Backup

แต่ละคืน (ตี 2 ICT) workflow `db-backup` จะสร้าง backup 2 ไฟล์ (เข้ารหัส AES-256):

| ไฟล์ | คือ | ใช้ตอนไหน |
|---|---|---|
| `backup_<วันที่>.sql.gz.enc` | **SQL dump ทั้ง DB** (pg_dump schema `public` — ทุกตาราง + function + RLS) | กู้คืนทั้งระบบ / ย้าย DB |
| `backup_<วันที่>.csv.tar.gz.enc` | **CSV ต่อแต่ละตาราง** | เปิดดูใน Excel / กู้เฉพาะบางตาราง |

> 🔑 ใช้ `BACKUP_PASSPHRASE` (passphrase เดียวกับที่ตั้งใน GitHub secret) ในการถอดรหัส

---

## 1) ถอดรหัส + restore แบบ SQL (กู้ทั้ง DB)

```bash
# ถอดรหัส
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in  backup_2026-06-19_0016.sql.gz.enc \
  -out backup.sql.gz \
  -k   "YOUR_BACKUP_PASSPHRASE"

gunzip backup.sql.gz        # ได้ backup.sql

# restore กลับเข้า Supabase (ใช้ connection string เดียวกับที่ backup — Session pooler URI)
psql "postgresql://postgres.qbsuynmsjieqglxzbqpw:DB_PASSWORD@aws-0-<region>.pooler.supabase.com:5432/postgres" \
  -f backup.sql

# หรือ restore ไป Postgres อื่น (กรณี Supabase ล่ม — Neon / Railway / RDS)
psql "postgresql://USER:PASS@HOST:5432/DB" -f backup.sql
```

## 2) ถอดรหัส + เปิดดู CSV (หรือกู้เฉพาะบางตาราง)

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in  backup_2026-06-19_0016.csv.tar.gz.enc \
  -out backup.csv.tar.gz \
  -k   "YOUR_BACKUP_PASSPHRASE"

tar -xzf backup.csv.tar.gz   # ได้ไฟล์ <ตาราง>.csv ทุกตาราง → เปิดใน Excel ได้เลย

# กู้คืนเฉพาะตารางเดียวจาก CSV
psql "$DB_URL" -c "\copy public.bank_balances from 'bank_balances.csv' with csv header"
```

---

## สิ่งที่ต้องเก็บให้ปลอดภัย

- `BACKUP_PASSPHRASE` — เก็บแยกจาก GitHub (เช่น 1Password / Bitwarden)
- `SUPABASE_DB_URL` (Session pooler URI + รหัส DB) — อยู่ใน GitHub Secrets เท่านั้น
- ห้าม commit passphrase หรือรหัส DB ลง repo ไม่ว่ากรณีใด

## ตั้งค่า secret ที่ต้องมี (ครั้งเดียว)
GitHub repo → **Settings → Secrets and variables → Actions**:
- `SUPABASE_DB_URL` — Supabase Dashboard → Project Settings → Database → Connection string → **URI (Session pooler)** แล้วแทน `[YOUR-PASSWORD]` ด้วยรหัส DB จริง
- `BACKUP_PASSPHRASE` — รหัสสำหรับเข้ารหัสไฟล์ backup (ตั้งเอง เก็บให้ดี)
