// renderToolSoon — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
function renderToolSoon(t){
  document.getElementById("main").innerHTML = `
    <div class="page-head">
      <h1>${t.name} <span class="badge">${COMPANIES.find(c=>c.id===state.company).name}</span></h1>
      <div class="sub">${t.long}</div>
    </div>
    <div class="card" style="padding:48px 30px;text-align:center">
      <div style="width:48px;height:48px;border-radius:12px;background:var(--brand-soft);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;font-size:22px;color:var(--brand);font-weight:800">${t.ic}</div>
      <div style="font-size:17px;font-weight:700;color:var(--ink);margin-bottom:6px">กำลังพัฒนา</div>
      <div style="color:var(--ink-3);font-size:13px;max-width:480px;margin:0 auto;line-height:1.7">${t.long}</div>
      <div style="margin-top:20px;display:inline-block;background:var(--brand-soft);color:var(--brand-dark);font-size:12px;padding:6px 16px;border-radius:999px;font-weight:600">อยู่ใน roadmap</div>
    </div>
  `;
}