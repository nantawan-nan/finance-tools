// renderToolUsers — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
async function renderToolUsers(){
  const t = TOOLS.find(x=>x.id==="users");
  const co = COMPANIES.find(c=>c.id===state.company);
  const main = document.getElementById("main");

  // gate: admin only
  if(AUTH.role !== "admin"){
    main.innerHTML = `
      <div class="page-head"><h1>${t.name}</h1></div>
      <div class="card" style="text-align:center;padding:48px 20px">
        <div style="font-size:16px;font-weight:700;color:var(--bad);margin-bottom:6px">ไม่มีสิทธิ์เข้าถึง</div>
        <div style="color:var(--ink-3);font-size:13px">หน้านี้สำหรับ admin เท่านั้น</div>
      </div>`;
    return;
  }

  // service_role key gate
  if(!usrSrKey()){
    main.innerHTML = `
      <div class="page-head">
        <h1>${t.name} <span class="badge">${esc(co.name)}</span></h1>
        <div class="sub">${t.long}</div>
      </div>
      <div class="card" style="max-width:620px">
        <h3>ใส่ Service Role Key ก่อนใช้งาน</h3>
        <div class="note">
          key นี้ใช้สำหรับเรียก Supabase Admin API (สร้าง/ลบ user) — เก็บใน <b>sessionStorage</b> ของ browser นี้เท่านั้น
          ปิด tab แล้วหาย ไม่ขึ้น cloud ไม่บันทึกไฟล์
        </div>
        <div style="display:flex;flex-direction:column;gap:10px;margin-top:10px">
          <div>
            <label style="display:block;font-size:12px;font-weight:700;color:var(--ink-2);margin-bottom:4px">SUPABASE SERVICE_ROLE KEY</label>
            <input id="usrSrInput" type="password" placeholder="eyJhbGc... (ขึ้นต้นด้วย eyJ)"
              style="width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:8px;font-family:monospace;font-size:12px">
          </div>
          <div style="font-size:11.5px;color:var(--ink-3);background:var(--brand-soft);padding:10px 12px;border-radius:7px;line-height:1.7">
            ดู key ที่:
            <a href="https://supabase.com/dashboard/project/qbsuynmsjieqglxzbqpw/settings/api-keys" target="_blank" style="color:var(--brand);font-weight:600">Supabase Dashboard → Settings → API Keys</a>
            <br>เลือก <b>service_role</b> (secret) — กดเปิดดูแล้วก๊อปทั้งสาย
          </div>
          <div style="display:flex;gap:8px">
            <button class="btn" onclick="usrSaveKey()">บันทึก key + โหลด users</button>
          </div>
        </div>
      </div>`;
    return;
  }

  main.innerHTML = `
    <div class="page-head">
      <h1>${t.name} <span class="badge">${esc(co.name)}</span></h1>
      <div class="sub">${t.long}</div>
    </div>
    <div class="card"><div class="empty">กำลังโหลดผู้ใช้...</div></div>`;

  try{ await usrLoadAll(); }
  catch(err){
    main.innerHTML = `
      <div class="page-head"><h1>${t.name}</h1></div>
      <div class="card">
        <div style="color:var(--bad);font-weight:600;margin-bottom:10px">โหลดไม่สำเร็จ: ${esc(err.message||err)}</div>
        <div style="display:flex;gap:8px">
          <button class="btn" onclick="renderToolUsers()">ลองอีกครั้ง</button>
          <button class="btn ghost" onclick="usrClearKey()">ใส่ key ใหม่</button>
        </div>
      </div>`;
    return;
  }

  const users = state.users.list || [];
  const cos = state.users.companies || [];

  main.innerHTML = `
    <div class="page-head" style="display:flex;justify-content:space-between;align-items:flex-end;gap:12px;flex-wrap:wrap">
      <div>
        <h1>${t.name} <span class="badge">${esc(co.name)}</span></h1>
        <div class="sub">${users.length} users · ${cos.length} companies</div>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn ghost btn sm" onclick="usrClearKey()">เปลี่ยน key</button>
        <button class="btn" onclick="usrOpenAdd()">+ เพิ่มผู้ใช้</button>
      </div>
    </div>

    <div class="card" style="padding:0;overflow:hidden">
      <div class="table-wrap" style="max-height:none;border:none;margin-top:0;border-radius:0">
        <table>
          <thead><tr>
            <th>อีเมล</th>
            <th>ชื่อ</th>
            <th>Default Role</th>
            <th>สิทธิ์เข้าบริษัท</th>
            <th>เข้าระบบล่าสุด</th>
            <th style="text-align:right">จัดการ</th>
          </tr></thead>
          <tbody>
            ${users.length===0 ? `<tr><td colspan="6" class="empty">ยังไม่มีผู้ใช้</td></tr>` :
              users.map(u => {
                const meta = u.app_metadata || {};
                const role = meta.role || "—";
                const acc = usrAccessByUser(u.id);
                const last = u.last_sign_in_at ? new Date(u.last_sign_in_at).toLocaleString("th-TH",{dateStyle:"short",timeStyle:"short"}) : "—";
                const name = (u.user_metadata && u.user_metadata.display_name) || (u.email||"").split("@")[0];
                return `
                <tr>
                  <td style="font-family:monospace;font-size:12px">${esc(u.email||"—")}</td>
                  <td>${esc(name)}</td>
                  <td>${role==="—"?'<span style="color:var(--ink-3)">—</span>':`<span class="badge">${esc(role)}</span>`}</td>
                  <td>${acc.length===0 ? '<span style="color:var(--ink-3);font-size:12px">ไม่มี</span>' :
                    acc.map(a => `<span style="display:inline-block;background:var(--brand-soft);color:var(--brand-dark);padding:1px 7px;border-radius:999px;font-size:11px;margin-right:3px">${esc(usrCoName(a.company_id))}: ${esc(a.role)}</span>`).join("")}</td>
                  <td style="font-size:12px;color:var(--ink-3)">${esc(last)}</td>
                  <td style="text-align:right;white-space:nowrap">
                    <button class="btn ghost btn sm" onclick="usrOpenEdit('${u.id}')">แก้ไข</button>
                    <button class="btn ghost btn sm" style="color:var(--bad);border-color:#fca5a5" onclick="usrConfirmDelete('${u.id}', ${JSON.stringify(u.email||"").replace(/"/g,'&quot;')})">ลบ</button>
                  </td>
                </tr>`;
              }).join("")
            }
          </tbody>
        </table>
      </div>
    </div>
  `;
}