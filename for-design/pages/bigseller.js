// renderToolBigSeller — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
function renderToolBigSeller(){
  bsSeedShopBrand();
  // โหลด SKU master จาก Supabase (ครั้งแรก/ตอนเปลี่ยนบริษัท)
  if(!state.skuCloud[state.company]){
    bsLoadSkuCloud().then(()=>{
      const d = bsGet(); if(d.raw) d.result = bsBuildResult();
      renderTool();
    });
  }
  const t = TOOLS.find(x=>x.id===state.tool);
  const d = bsGet();
  const sku = bsLoadJSON(BS_LS_SKU, {});
  const seedCount = bsSeedSkuFor(state.company).length;
  const extraCount = (sku[state.company]||[]).length;
  const skuCount = seedCount + extraCount;
  const histCount = (bsLoadJSON(BS_LS_HISTORY, {})[state.company]||[]).length;

  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===state.company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <div class="slots" style="grid-template-columns:2fr 1fr 1fr">
      <div class="slot ${d.file?'ready':''}">
        <div class="lbl"><span class="step">1</span> 📤 อัปไฟล์ Big Seller</div>
        <div class="hint">Excel จาก BigSeller → Order-SKU all</div>
        <div class="drop" data-slot="bsmain">
          <div class="big">📂</div>
          <div>ลากหรือคลิก</div>
          <input type="file" data-slotinp="bsmain" accept=".xlsx,.xls" style="display:none">
        </div>
        ${d.file?`<div class="files"><div class="fchip"><span>📄 ${esc(d.file)}<div class="meta">${d.raw?d.raw.items.length:0} แถว · ${d.raw?(new Set(d.raw.items.map(i=>i.orderNo))).size:0} ออเดอร์</div></span><button onclick="bsClear()">✕</button></div></div>`:""}
      </div>

      <div class="slot">
        <div class="lbl"><span class="step">2</span> 🗂️ SKU Master</div>
        <div class="hint">รหัสสินค้าที่ระบบบัญชีมี · ${skuCount} รายการ${seedCount?` (built-in ${seedCount}${extraCount?` + เพิ่มเอง ${extraCount}`:""})`:""}</div>
        <div class="drop" data-slot="bssku" style="padding:16px;font-size:13px">
          <div class="big" style="font-size:22px">📥</div>
          <div>ลากไฟล์ SKU เพื่อนำเข้าเพิ่ม</div>
          <input type="file" data-slotinp="bssku" accept=".xlsx,.xls,.csv" style="display:none">
        </div>
        ${extraCount?`<button class="btn ghost" style="font-size:12px;padding:6px 10px" onclick="bsClearSku()">ล้างที่เพิ่มเอง</button>`:""}
      </div>

      <div class="slot">
        <div class="lbl"><span class="step">3</span> 📚 ประวัติคีย์</div>
        <div class="hint">${histCount} ออเดอร์เคยคีย์แล้ว</div>
        <div class="btnrow" style="flex-direction:column;gap:6px;align-items:stretch">
          <button class="btn ghost" style="font-size:12px" onclick="bsExportHistory()">⬇ Export JSON</button>
          <label class="btn ghost" style="font-size:12px;text-align:center;cursor:pointer">⬆ Import CSV/JSON<input type="file" accept=".csv,.json" onchange="bsImportHistory(this.files[0])" style="display:none"></label>
        </div>
        <div class="hint" style="margin-top:4px;font-size:11px;opacity:.7">CSV = รายงานขายแบบเห็นออเดอร์ (Express)</div>
      </div>
    </div>

    ${d.result ? bsResultHTML(d.result) : `<div class="card"><div class="empty">ยังไม่มีไฟล์ — อัป Big Seller ด้านบน</div></div>`}
  `;
  bsWireDrops();
}