# วิธีถอดรหัสและ Restore Backup

## ถอดรหัสไฟล์

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in  backup_2026-06-17_1900.sql.gz.enc \
  -out backup_2026-06-17_1900.sql.gz \
  -k   "YOUR_BACKUP_PASSPHRASE"

gunzip backup_2026-06-17_1900.sql.gz
```

## Restore ไปยัง Supabase

```bash
psql \
  --host=db.qbsuynmsjieqglxzbqpw.supabase.co \
  --port=5432 \
  --username=postgres \
  --dbname=postgres \
  -f backup_2026-06-17_1900.sql
```

## Restore ไปยัง Postgres อื่น (กรณี Supabase ล่ม)

```bash
# ตั้ง Postgres ที่ไหนก็ได้ (Render, Railway, Neon, AWS RDS)
psql postgresql://USER:PASS@HOST:5432/DB -f backup_2026-06-17_1900.sql
```

## สิ่งที่ต้องเก็บให้ปลอดภัย

- `BACKUP_PASSPHRASE` — เก็บแยกจาก GitHub (เช่น 1Password, Bitwarden)
- Supabase DB Password — ใน GitHub Secrets เท่านั้น
- ห้าม commit passphrase ลงใน repo ไม่ว่ากรณีใด
