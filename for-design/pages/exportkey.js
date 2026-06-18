// renderToolExportKey — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
async function renderToolExportKey(){
  const t = TOOLS.find(x=>x.id===state.tool);
  const company = state.company;
  const d = exkGet();

  if(!d.orders){
    document.getElementById("main").innerHTML = `
      <div class="page-head"><h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===company).name}</span></h1>
      <div class="sub">${t.long}</div></div>
      <div class="card"><div class="empty">⏳ กำลังโหลด...</div></div>`;
    try{ await exkLoad(); }catch(err){
      document.getElementById("main").innerHTML += `<div class="card" style="color:#dc2626">โหลดไม่สำเร็จ: ${esc(err.message||err)}</div>`;
      return;
    }
  }

  const rows = exkFiltered();
  // distinct values for filter chips
  const allPlatforms = Array.from(new Set(d.orders.map(o=>o.platform||"").filter(Boolean))).sort();
  const allBrands    = Array.from(new Set(d.orders.map(o=>o.brand||"").filter(Boolean))).sort();
  const f = d.filters;

  // เลือกทั้งหมด/ไม่เลือก (ตาม filter ปัจจุบัน)
  const selectedCount = rows.filter(r=>d.selected[r.order_no]).length;

  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <div class="card">
      <h3>1 · กรองออเดอร์</h3>
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-top:8px">
        <label style="font-size:13px;font-weight:600;color:#334155">สถานะ
          <select onchange="exkSetFilter('status', this.value)" style="display:block;width:100%;margin-top:4px;padding:8px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;font-family:inherit">
            <option value="pending" ${f.status==="pending"?"selected":""}>ยังไม่คีย์ IV</option>
            <option value="keyed" ${f.status==="keyed"?"selected":""}>คีย์ IV แล้ว</option>
            <option value="all" ${f.status==="all"?"selected":""}>ทั้งหมด (ยกเว้นยกเลิก)</option>
          </select>
        </label>
        <label style="font-size:13px;font-weight:600;color:#334155">ขายตั้งแต่
          <input type="date" value="${f.from}" onchange="exkSetFilter('from', this.value)"
            style="display:block;width:100%;margin-top:4px;padding:8px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;font-family:inherit">
        </label>
        <label style="font-size:13px;font-weight:600;color:#334155">ถึงวันที่
          <input type="date" value="${f.to}" onchange="exkSetFilter('to', this.value)"
            style="display:block;width:100%;margin-top:4px;padding:8px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;font-family:inherit">
        </label>
        <label style="font-size:13px;font-weight:600;color:#334155">เลข IV ล่าสุดในระบบ
          <input type="text" placeholder="เช่น 2606000005" value="${esc(d.lastIv||"")}" oninput="exkSetIv(this.value)"
            style="display:block;width:100%;margin-top:4px;padding:8px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;font-family:inherit">
        </label>
      </div>
      <div style="margin-top:12px">
        <div style="font-size:13px;font-weight:600;color:#334155;margin-bottom:6px">ช่องทาง</div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          ${allPlatforms.length===0?`<span style="color:#94a3b8;font-size:13px">— ไม่มีข้อมูล —</span>`:""}
          ${allPlatforms.map(p=>`
            <button onclick="exkToggle('platforms','${esc(p)}')" style="padding:5px 12px;border:1px solid ${f.platforms.includes(p)?'#2563eb':'#e2e8f0'};background:${f.platforms.includes(p)?'#eff6ff':'#fff'};color:${f.platforms.includes(p)?'#1e40af':'#475569'};border-radius:999px;font-size:12px;font-weight:600;cursor:pointer">${esc(p)||"(ไม่ระบุ)"}</button>
          `).join("")}
        </div>
      </div>
      <div style="margin-top:10px">
        <div style="font-size:13px;font-weight:600;color:#334155;margin-bottom:6px">แบรนด์</div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          ${allBrands.length===0?`<span style="color:#94a3b8;font-size:13px">— ไม่มีข้อมูล —</span>`:""}
          ${allBrands.map(b=>`
            <button onclick="exkToggle('brands','${esc(b)}')" style="padding:5px 12px;border:1px solid ${f.brands.includes(b)?'#2563eb':'#e2e8f0'};background:${f.brands.includes(b)?'#eff6ff':'#fff'};color:${f.brands.includes(b)?'#1e40af':'#475569'};border-radius:999px;font-size:12px;font-weight:600;cursor:pointer">${esc(b)}</button>
          `).join("")}
        </div>
      </div>
      <button class="btn ghost" style="margin-top:12px;font-size:12px" onclick="exkResetCache()">🔄 โหลดข้อมูลใหม่จาก Supabase</button>
    </div>

    <div class="card">
      <h3>2 · ออเดอร์ที่เลือก (${rows.length} ใบ · ติ๊กไว้ ${selectedCount})</h3>
      <div class="btnrow" style="margin-bottom:10px">
        <button class="btn ghost" style="font-size:12px" onclick="exkSelectAll(true)">เลือกทั้งหมดในรายการนี้</button>
        <button class="btn ghost" style="font-size:12px" onclick="exkSelectAll(false)">ไม่เลือก</button>
        ${selectedCount>0 ? `<button class="btn" style="margin-left:auto" onclick="exkExport()">⬇ ดาวน์โหลด CSV (${selectedCount} ออเดอร์)</button>` : ""}
      </div>
      ${rows.length===0?`<div class="empty">ไม่มีออเดอร์ตามเงื่อนไข</div>`:`
      <div class="table-wrap"><table>
        <thead><tr>
          <th style="width:30px"></th>
          <th>วันที่ขาย</th><th>เลขออเดอร์</th><th>ช่องทาง</th><th>แบรนด์</th><th>ร้านค้า</th>
          <th>รหัสลูกค้า</th><th>IV</th><th>สถานะ</th>
        </tr></thead>
        <tbody>${rows.slice(0,500).map(o=>`
          <tr style="background:${d.selected[o.order_no]?'#eff6ff':''}">
            <td><input type="checkbox" ${d.selected[o.order_no]?'checked':''} onchange="exkToggleRow('${esc(o.order_no)}')"></td>
            <td>${esc(o.sale_date||"")}</td>
            <td>${esc(o.order_no)}</td>
            <td>${esc(o.platform||"")}</td>
            <td>${esc(o.brand||"")}</td>
            <td>${esc(o.shop_name||"")}</td>
            <td>${esc(o.cust_code||"")}</td>
            <td>${o.iv_no?`<b>${esc(o.iv_no)}</b>`:`<span style="color:#94a3b8">—</span>`}</td>
            <td><span style="font-size:11px;padding:2px 8px;border-radius:999px;background:${o.status==="cancelled"?"#fee2e2":o.iv_no?"#dcfce7":"#fef3c7"};color:${o.status==="cancelled"?"#991b1b":o.iv_no?"#15803d":"#92400e"}">${esc(o.status==="cancelled"?"ยกเลิก":o.iv_no?"คีย์แล้ว":"ยังไม่คีย์")}</span></td>
          </tr>`).join("")}</tbody>
      </table></div>
      ${rows.length>500?`<div class="hint" style="margin-top:6px">แสดง 500 แถวแรก · ใช้ฟิลเตอร์ลดจำนวน</div>`:""}
      `}
    </div>
  `;
}