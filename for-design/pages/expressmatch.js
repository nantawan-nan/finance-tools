// renderToolExpressMatch — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
function renderToolExpressMatch(){
  const t = TOOLS.find(x=>x.id===state.tool);
  const d = emGet();
  const canUpload = AUTH.can("upload_express");

  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.ic} ${t.name} <span class="badge">${COMPANIES.find(c=>c.id===state.company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <div class="card">
      <h3>1 · อัปไฟล์ CSV จาก Express</h3>
      <div class="note">รายงานขายแบบเห็นออเดอร์ (มีเลข IV + เลขออเดอร์ในคอลัมน์ "อ้างอิง")</div>
      <div class="drop" id="emDrop" ${canUpload?"":"style='opacity:.5;pointer-events:none'"}>
        <div class="big">📂</div>
        <div>ลากไฟล์ CSV มาวาง หรือ <b>คลิกเพื่อเลือก</b></div>
        <div class="sm">${canUpload?"":"⚠ คุณไม่มีสิทธิ์อัปโหลด (role = "+esc(AUTH.role||"")+")"}</div>
        <input type="file" id="emInput" accept=".csv" style="display:none">
      </div>
      ${d.file?`<div class="filechip">📄 ${esc(d.file)} <button onclick="emClear()">✕</button></div>`:""}
    </div>

    ${d.result ? emResultHTML(d.result) : ""}
  `;

  const drop = document.getElementById("emDrop");
  const inp = document.getElementById("emInput");
  if(drop && inp && canUpload){
    drop.onclick = ()=>inp.click();
    inp.onchange = e => { const f=e.target.files[0]; inp.value=""; if(f) emHandleFile(f); };
    drop.ondragover = e => { e.preventDefault(); drop.classList.add("over"); };
    drop.ondragleave = ()=>drop.classList.remove("over");
    drop.ondrop = e => { e.preventDefault(); drop.classList.remove("over"); const f=e.dataTransfer.files[0]; if(f) emHandleFile(f); };
  }
}