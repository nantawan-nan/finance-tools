// renderToolAr — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
async function renderToolAr(){
  const t = TOOLS.find(x=>x.id===state.tool);
  const co = state.company;
  const d = arGet();
  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.name} <span class="badge">${COMPANIES.find(c=>c.id===co).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>
    <div class="card"><div class="empty" style="color:var(--ink-3)">กำลังโหลดข้อมูล...</div></div>
  `;
  try{ await arLoad(); }
  catch(err){
    document.getElementById("main").innerHTML += `<div class="card"><div style="color:var(--bad)">โหลดข้อมูลไม่สำเร็จ: ${esc(err.message||err)}</div></div>`;
    return;
  }

  const rows = arBuildRows(d.orders, d.receipts);
  const rowsIv = rows.filter(r => r.iv_no);

  const arReal  = rows.reduce((s,r)=>s+r.out, 0);
  const arAcct  = rowsIv.reduce((s,r)=>s+r.out, 0);
  const arGap   = arReal - arAcct;

  const canWrite = AUTH.role && ["admin","finance_mgr","accountant","treasury"].includes(AUTH.role);

  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.name} <span class="badge">${COMPANIES.find(c=>c.id===co).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>

    <!-- KPI 3 การ์ด -->
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:18px">
      <div class="card" style="border-top:4px solid var(--bad);margin-bottom:0">
        <div style="font-size:11px;font-weight:700;color:var(--ink-3);letter-spacing:.5px;text-transform:uppercase">AR จริง (ค้างรับทั้งหมด)</div>
        <div style="font-size:26px;font-weight:800;color:var(--bad);margin:6px 0 2px">฿${arFmt(arReal)}</div>
        <div style="font-size:12px;color:var(--ink-2)">${rows.filter(r=>r.out>0).length} ออเดอร์ · ทุกช่องทาง</div>
      </div>
      <div class="card" style="border-top:4px solid var(--warn);margin-bottom:0">
        <div style="font-size:11px;font-weight:700;color:var(--ink-3);letter-spacing:.5px;text-transform:uppercase">AR บัญชี (มี IV แล้ว)</div>
        <div style="font-size:26px;font-weight:800;color:var(--warn);margin:6px 0 2px">฿${arFmt(arAcct)}</div>
        <div style="font-size:12px;color:var(--ink-2)">${rowsIv.filter(r=>r.out>0).length} ออเดอร์ · คีย์ IV แล้ว</div>
      </div>
      <div class="card" style="border-top:4px solid var(--ink-3);margin-bottom:0">
        <div style="font-size:11px;font-weight:700;color:var(--ink-3);letter-spacing:.5px;text-transform:uppercase">Gap (ยังไม่คีย์ IV)</div>
        <div style="font-size:26px;font-weight:800;color:var(--ink-2);margin:6px 0 2px">฿${arFmt(arGap)}</div>
        <div style="font-size:12px;color:var(--ink-2)">${rows.filter(r=>r.out>0&&!r.iv_no).length} ออเดอร์ · รอคีย์ IV</div>
      </div>
    </div>

    <!-- แท็บ -->
    <div class="card">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px">
        <div class="tabs" style="margin-bottom:0;flex:1">
          <button class="${d.tab==='real'?'active':''}" onclick="arSetTab('real')">AR จริง <span class="c">${rows.filter(r=>r.out>0).length}</span></button>
          <button class="${d.tab==='acct'?'active':''}" onclick="arSetTab('acct')">AR บัญชี + Aging <span class="c">${rowsIv.filter(r=>r.out>0).length}</span></button>
          <button class="${d.tab==='hist'?'active':''}" onclick="arSetTab('hist')">ประวัติรับเงิน <span class="c">${d.receipts.length}</span></button>
        </div>
        <button class="btn ghost btn sm" style="margin-left:10px;white-space:nowrap" onclick="arRefresh()">รีเฟรช</button>
      </div>
      ${d.tab==='real' ? arTabReal(rows, canWrite)
      : d.tab==='acct' ? arTabAcct(rowsIv, canWrite)
      : arTabHist(d.receipts)}
    </div>
  `;
}