// renderToolArmap — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
function renderToolArmap(){
  const t=TOOLS.find(x=>x.id===state.tool);
  const d=armapGet();
  const ready=d.ar && d.sales && d.platforms.length;
  document.getElementById("main").innerHTML=`
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===state.company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <div class="slots">
      ${slotHTML("ar","📋","รายงานลูกหนี้คงค้าง","CSV จาก Express · 1 ไฟล์", d.ar?[d.ar]:[], false)}
      ${slotHTML("sales","🛒","รายงานขายแบบเห็นออเดอร์","CSV จาก Express · 1 ไฟล์", d.sales?[d.sales]:[], false)}
      ${slotHTML("platform","💰","หลังบ้าน Shopee / TikTok","XLSX · ลากกี่ไฟล์/แบรนด์ก็ได้", d.platforms, true)}
    </div>

    <div class="btnrow" style="justify-content:center;margin-bottom:18px">
      <button class="btn bigbtn" ${ready?"":"disabled"} onclick="armapCompute()"><span class="ic">⚡</span> ประมวลผล &amp; แมพข้อมูล</button>
      ${(d.ar||d.sales||d.platforms.length)?`<button class="btn ghost" onclick="armapClearAll()">ล้างทั้งหมด</button>`:""}
    </div>

    ${d.result ? armapResultHTML(d.result, d.activeTab) : `
      <div class="card"><div class="empty">ยังไม่มีผลลัพธ์ — ใส่ไฟล์ครบ 3 ช่องแล้วกด "ประมวลผล"</div></div>
    `}
  `;
  armapWireDrops();
}