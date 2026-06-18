// renderToolDashboard — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
async function renderToolDashboard(){
  const t = TOOLS.find(x=>x.id===state.tool);
  const company = state.company;
  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>
    <div class="card"><div class="empty">⏳ กำลังโหลดข้อมูลจาก Supabase...</div></div>
  `;
  let rows;
  try{ rows = await dashLoad(); }
  catch(err){
    document.getElementById("main").innerHTML += `<div class="card"><div style="color:#dc2626">โหลดข้อมูลไม่สำเร็จ: ${esc(err.message||err)}</div></div>`;
    return;
  }
  state.dash[company] = rows;

  const total = rows.length;
  const cancelled = rows.filter(r=>r.status==="cancelled").length;
  const keyed = rows.filter(r=>r.iv_no).length;
  const pending = rows.filter(r=>!r.iv_no && r.status!=="cancelled").length;

  // วันที่ขายล่าสุด / คีย์ล่าสุด
  const saleDates = rows.map(r=>r.sale_date).filter(Boolean).sort();
  const keyDates = rows.filter(r=>r.key_date).map(r=>r.key_date).sort();
  const latestSale = saleDates.length ? saleDates[saleDates.length-1] : "-";
  const oldestSaleNotKeyed = rows.filter(r=>!r.iv_no && r.status!=="cancelled" && r.sale_date)
    .map(r=>r.sale_date).sort()[0] || "-";
  const latestKey = keyDates.length ? keyDates[keyDates.length-1] : "-";

  // กลุ่มตามวันขาย (รายวัน 14 วันล่าสุด)
  const dailyMap = {};
  for(const r of rows){
    if(!r.sale_date) continue;
    const k = r.sale_date;
    if(!dailyMap[k]) dailyMap[k] = { date:k, total:0, keyed:0, cancelled:0 };
    dailyMap[k].total++;
    if(r.iv_no) dailyMap[k].keyed++;
    if(r.status==="cancelled") dailyMap[k].cancelled++;
  }
  const daily = Object.values(dailyMap).sort((a,b)=>a.date<b.date?1:-1).slice(0,14);

  // group by ช่องทาง (ที่ยังไม่คีย์)
  const pendingByPlatform = {};
  for(const r of rows){
    if(r.iv_no || r.status==="cancelled") continue;
    const k = r.platform || r.shop_name || "-";
    pendingByPlatform[k] = (pendingByPlatform[k]||0)+1;
  }

  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <div class="card">
      <div class="pill-stat">
        <div class="stat"><div class="n">${total.toLocaleString()}</div><div class="l">ออเดอร์ทั้งหมด</div></div>
        <div class="stat"><div class="n" style="color:#16a34a">${keyed.toLocaleString()}</div><div class="l">คีย์ IV แล้ว</div></div>
        <div class="stat"><div class="n" style="color:#d97706">${pending.toLocaleString()}</div><div class="l">ยังไม่คีย์</div></div>
        <div class="stat"><div class="n" style="color:#94a3b8">${cancelled.toLocaleString()}</div><div class="l">ยกเลิก</div></div>
      </div>
      <div class="pill-stat" style="margin-top:8px">
        <div class="stat"><div class="n" style="font-size:18px">${esc(latestSale)}</div><div class="l">ออเดอร์ล่าสุด</div></div>
        <div class="stat"><div class="n" style="font-size:18px">${esc(latestKey)}</div><div class="l">คีย์ IV ล่าสุด</div></div>
        <div class="stat"><div class="n" style="font-size:18px;color:#dc2626">${esc(oldestSaleNotKeyed)}</div><div class="l">ออเดอร์เก่าสุดที่ยังไม่คีย์</div></div>
      </div>
      <button class="btn ghost" style="margin-top:10px;font-size:12px" onclick="renderToolDashboard()">🔄 รีเฟรช</button>
    </div>

    ${total===0 ? `<div class="card"><div class="empty">ยังไม่มีข้อมูลใน Supabase — อัป BigSeller ที่หน้า "จัดฟอร์แมต Big Seller" แล้วกด "บันทึกลง Supabase"</div></div>` : `
    <div class="card">
      <h3>📅 รายวัน (14 วันล่าสุด)</h3>
      <div class="table-wrap"><table>
        <thead><tr><th>วันที่ขาย</th><th>ทั้งหมด</th><th>คีย์ IV แล้ว</th><th>ยังไม่คีย์</th><th>%</th></tr></thead>
        <tbody>${daily.map(d=>{
          const left = d.total - d.keyed - d.cancelled;
          const pct = d.total ? Math.round(d.keyed*100/d.total) : 0;
          return `<tr>
            <td>${esc(d.date)}</td>
            <td>${d.total}</td>
            <td style="color:#16a34a">${d.keyed}</td>
            <td style="color:${left>0?'#d97706':'#94a3b8'}">${left}</td>
            <td>${pct}%</td>
          </tr>`;
        }).join("")}</tbody>
      </table></div>
    </div>

    ${pending>0 ? `
    <div class="card">
      <h3>📌 ออเดอร์ค้างคีย์ ตามช่องทาง</h3>
      <div class="pill-stat">
        ${Object.keys(pendingByPlatform).sort().map(k=>`
          <div class="stat"><div class="n">${pendingByPlatform[k]}</div><div class="l">${esc(k)}</div></div>
        `).join("")}
      </div>
    </div>` : ""}
    `}
  `;
}