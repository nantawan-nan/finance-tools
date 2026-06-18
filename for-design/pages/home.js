// renderToolHome — paste function นี้ให้ Claude Design พร้อมกับ ../style.html
function renderToolHome(){
  const co = COMPANIES.find(c=>c.id===state.company);
  const groups = {};
  TOOLS.forEach(t => {
    if(t.id==="home") return;
    if(t.adminOnly && AUTH.role!=="admin") return;
    if(!groups[t.stage]) groups[t.stage] = [];
    groups[t.stage].push(t);
  });
  document.getElementById("main").innerHTML = `
    <div style="background:linear-gradient(135deg,var(--gradient-1) 0%,var(--gradient-2) 100%);border-radius:14px;padding:26px 28px;color:#fff;margin-bottom:20px">
      <div style="font-size:11px;opacity:.7;font-weight:700;letter-spacing:.8px;text-transform:uppercase;margin-bottom:6px">${esc(co.brand)}</div>
      <div style="font-size:24px;font-weight:800;letter-spacing:-.4px">Finance Operations</div>
      <div style="font-size:13px;opacity:.8;margin-top:5px">${esc(co.name)} · เลือกโมดูลจาก sidebar หรือกดด้านล่าง</div>
    </div>

    ${Object.keys(groups).map(stage => `
      <div class="card" style="padding:16px 18px;margin-bottom:12px">
        <div style="font-size:10.5px;font-weight:700;color:var(--ink-3);text-transform:uppercase;letter-spacing:.7px;margin-bottom:12px">${stage}</div>
        <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:8px">
          ${groups[stage].map(t => {
            const ic = t.icon ? `<i data-lucide="${t.icon}" style="width:18px;height:18px;stroke-width:1.7"></i>` : (t.ic || "");
            return `<button onclick="setTool('${t.id}')" style="text-align:left;padding:13px 14px;border:1px solid var(--line);background:#fff;border-radius:9px;cursor:pointer;transition:.12s;position:relative;display:flex;align-items:flex-start;gap:10px"
              onmouseover="this.style.background='var(--brand-soft)';this.style.borderColor='var(--brand)'"
              onmouseout="this.style.background='#fff';this.style.borderColor='var(--line)'">
              <span style="display:inline-flex;align-items:center;justify-content:center;color:var(--brand);flex-shrink:0;margin-top:2px;width:20px;height:20px">${ic}</span>
              <span>
                <span style="display:block;font-weight:700;font-size:13px;color:var(--ink)">${t.name}</span>
                <span style="font-size:11.5px;color:var(--ink-3);margin-top:2px;display:block">${t.desc}</span>
              </span>
              ${t.status==="soon" ? `<span style="position:absolute;top:8px;right:8px;font-size:9px;background:#fef3c7;color:#92400e;padding:2px 6px;border-radius:999px;font-weight:700;letter-spacing:.2px">เร็วๆนี้</span>` : ""}
            </button>`;
          }).join("")}
        </div>
      </div>
    `).join("")}
  `;
  if(window.lucide && window.lucide.createIcons){ try{ window.lucide.createIcons(); }catch(e){} }
}