-- สถานะออนไลน์ (heartbeat) + บังคับออกจากระบบ (kick) — ต่อผู้ใช้
-- ★ idempotent · RLS ปิด (แอปภายใน · ทุก client เขียน presence ตัวเองได้)
create table if not exists public.user_presence (
  user_id      uuid primary key,
  email        text,
  display_name text,
  role         text,
  last_seen    timestamptz default now(),
  current_tool text,
  kick_at      timestamptz     -- ถ้ามากกว่าเวลาเริ่ม session ของ client → เด้งออก
);
alter table public.user_presence add column if not exists kick_at timestamptz;
alter table public.user_presence disable row level security;

-- ให้แอปบันทึก "บังคับออกจากระบบ" ลง audit_log_v2 ได้ (เดิมมีแค่ SELECT policy · append-only ปลอดภัย)
drop policy if exists p_audit_insert on public.audit_log_v2;
create policy p_audit_insert on public.audit_log_v2 for insert to authenticated with check (true);

notify pgrst, 'reload schema';
