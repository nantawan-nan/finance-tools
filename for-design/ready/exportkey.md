# Prompt for Claude Design

ฉันมีแอป Finance Tools เป็น single-file SPA (vanilla JS + Supabase + Chart.js + Lucide icons)
ช่วยออกแบบ UI ใหม่ให้หน้า **ส่งออกคีย์ AutoKey** ทันสมัย สวย เป็นมืออาชีพ

**ห้ามแตะ logic** — ส่งกลับเป็น HTML template + CSS เท่านั้น ฉันจะ merge กับ JS เดิมเอง
เก็บ class names + onclick handlers + data attributes เดิมไว้ (เช่น setTool, arOpenReceipt, edSetTab)

## โทนสี (ตามโลโก้บริษัท)
- M Bark: navy blue เข้ม (#1e3a8a) — corporate professional
- Benya: teal/cyan (#0d9488) — clean medical fresh
- ใช้ CSS var --brand, --brand-soft (data-co="mbark"/"benya" บน body)
- positive: #14B8A6 (teal soft)
- negative: #E18AAA (pink soft)
- bg gradient pastel ตาม brand

## Stack
- ฟอนต์ IBM Plex Sans Thai (ไทย) + IBM Plex Sans (อังกฤษ)
- ไอคอน Lucide `<i data-lucide="name">`
- glassmorphism cards, micro-interactions, spacing โปร่ง
- responsive: ใช้งานในกรอบ main (~1100px) บน desktop

---

## STYLE ปัจจุบัน
ใช้เป็น reference ของ CSS variables, base components, palette

```html
<!-- <style> ส่วนกลางของแอป — ใช้ Lucide icons, IBM Plex Sans Thai, palette teal/pink -->
<style>
  :root{
    --brand:#1e3a8a; --brand-dark:#172554; --brand-soft:#eff6ff;
    --ink:#0f172a; --ink-2:#475569; --ink-3:#94a3b8;
    --line:#e2e8f0; --bg:#f4f6f9; --card:#ffffff;
    --ok:#16a34a; --warn:#d97706; --bad:#dc2626;
    --radius:12px;
    --shadow:0 1px 2px rgba(15,23,42,.06),0 4px 16px rgba(15,23,42,.06);
    --shadow-md:0 2px 8px rgba(15,23,42,.08),0 12px 32px rgba(15,23,42,.08);
  }
  body[data-co="mbark"]{ --brand:#1e3a8a; --brand-dark:#172554; --brand-soft:#dbeafe;
    --gradient-1:#1e3a8a; --gradient-2:#2563eb; }
  body[data-co="benya"]{ --brand:#0d9488; --brand-dark:#115e59; --brand-soft:#ccfbf1;
    --gradient-1:#0d9488; --gradient-2:#14b8a6; }
  *{box-sizing:border-box}
  body{margin:0;font-family:"IBM Plex Sans Thai","IBM Plex Sans",ui-sans-serif,system-ui,-apple-system,sans-serif;background:var(--bg);color:var(--ink);font-size:14.5px;line-height:1.6;-webkit-font-smoothing:antialiased}
  .page-head h1,.card h3{font-family:"IBM Plex Sans","IBM Plex Sans Thai",ui-sans-serif,sans-serif;letter-spacing:-.3px}
  button{font-family:inherit;cursor:pointer}

  /* ---- topbar ---- */
  .topbar{display:flex;align-items:center;gap:12px;background:var(--card);border-bottom:1px solid var(--line);padding:0 24px;position:sticky;top:0;z-index:20;height:54px}
  .crumb{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--ink-3);flex:1;min-width:0}
  .crumb .co{font-weight:700;color:var(--brand-dark);font-size:13.5px}
  .crumb .sep{color:var(--line)}
  .crumb .pg{color:var(--ink);font-weight:600;font-size:13px}
  .topbar .date{font-size:12px;color:var(--ink-3);font-weight:500;white-space:nowrap;letter-spacing:.2px}
  .topbar .user{display:flex;align-items:center;gap:8px;font-size:12px;color:var(--ink-2)}
  .topbar .user .u-email{color:var(--ink-3);font-size:12px;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .topbar .user .pill{background:var(--brand);color:#fff;padding:2px 9px;border-radius:999px;font-size:10.5px;font-weight:700;text-transform:uppercase;letter-spacing:.4px}
  .topbar .logout{border:1px solid var(--line);background:#fff;border-radius:7px;padding:5px 12px;font-size:12px;color:var(--ink-2);font-weight:500;transition:.15s}
  .topbar .logout:hover{background:var(--bg);color:var(--bad);border-color:#fca5a5}

  /* ---- sidebar ---- */
  .wrap{display:flex;min-height:100vh}
  .sidebar{width:232px;flex-shrink:0;background:var(--card);border-right:1px solid var(--line);display:flex;flex-direction:column;height:100vh;position:sticky;top:0}
  .sb-brand{padding:18px 14px 12px;border-bottom:1px solid var(--line);display:flex;flex-direction:column;align-items:center;gap:6px}
  .sb-brand .sb-logo-img{height:46px;width:auto;max-width:160px;object-fit:contain}
  .sb-brand .sb-tagline{font-size:11px;color:var(--ink-3);font-weight:500;letter-spacing:.3px;margin-top:2px}
  .company-switch{display:flex;gap:4px;padding:8px 10px;border-bottom:1px solid var(--line)}
  .company-switch button{flex:1;border:1px solid var(--line);background:#fff;color:var(--ink-3);padding:5px 8px;border-radius:7px;font-weight:600;font-size:11.5px;transition:.15s}
  .company-switch button.active{background:var(--brand);color:#fff;border-color:var(--brand)}
  .sb-nav{flex:1;overflow-y:auto;padding:8px 6px 16px;scrollbar-width:thin;scrollbar-color:var(--line) transparent}
  .stage-label{display:flex;align-items:center;justify-content:space-between;font-size:11.5px;font-weight:700;color:var(--ink-2);letter-spacing:.4px;padding:12px 10px 6px;cursor:pointer;user-select:none;border-radius:6px;transition:.12s}
  .stage-label:hover{color:var(--brand);background:#f1f5f9}
  .stage-label .chev{display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;color:#475569;transition:transform .2s ease}
  .stage-label .chev svg{width:16px;height:16px;stroke-width:2.4}
  .stage-label:hover .chev{color:var(--brand)}
  .stage-group.collapsed .stage-label .chev{transform:rotate(-90deg)}
  .stage-items{display:flex;flex-direction:column;overflow:hidden;transition:max-height .2s ease}
  .stage-group.collapsed .stage-items{max-height:0!important;display:none}
  .nav-item{display:flex;gap:9px;align-items:center;padding:8px 10px;border-radius:8px;cursor:pointer;transition:.12s;margin-bottom:1px;color:var(--ink-2)}
  .nav-item:hover{background:var(--brand-soft);color:var(--ink)}
  .nav-item.active{background:var(--brand-soft);color:var(--brand-dark);font-weight:600}
  .nav-item.active{border-left:2.5px solid var(--brand);padding-left:8px}
  .nav-item .ic{display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;flex-shrink:0;color:#64748b}
  .nav-item .ic svg{width:16px;height:16px;stroke-width:1.7}
  .nav-item.active .ic{color:var(--brand)}
  .nav-item:hover .ic{color:var(--brand)}
  .nav-item .t{font-size:12.5px;font-weight:500}
  .nav-item.active .t{font-weight:700;color:var(--brand-dark)}
  .nav-item .badge-mini{margin-left:auto;font-size:9px;background:#fef3c7;color:#92400e;padding:1px 6px;border-radius:999px;font-weight:700;letter-spacing:.2px}
  .sb-footer{padding:10px 12px;border-top:1px solid var(--line);font-size:10.5px;color:var(--ink-3);display:flex;align-items:center;gap:6px}
  .sb-footer .dot{width:6px;height:6px;border-radius:50%;background:var(--ok);flex-shrink:0}

  /* ---- main ---- */
  .main{flex:1;padding:24px 28px;overflow-x:auto;min-width:0;max-width:1400px}

  /* ---- page header ---- */
  .page-head{margin-bottom:20px}
  .page-head h1{margin:0 0 4px;font-size:20px;font-weight:800;letter-spacing:-.4px;color:var(--ink)}
  .page-head .sub{color:var(--ink-3);font-size:13px}
  .badge{display:inline-block;font-size:10.5px;font-weight:700;padding:2px 8px;border-radius:999px;background:var(--brand-soft);color:var(--brand-dark);vertical-align:middle;margin-left:7px;letter-spacing:.2px}

  /* ---- cards ---- */
  .card{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);padding:20px;margin-bottom:16px}
  .card h3{margin:0 0 4px;font-size:14px;font-weight:700;color:var(--ink)}
  .card .note{color:var(--ink-3);font-size:12.5px;margin-bottom:14px}

  /* ---- dropzone ---- */
  .drop{border:1.5px dashed var(--line);border-radius:10px;padding:28px;text-align:center;color:var(--ink-3);transition:.15s;background:#fafbfd;cursor:pointer}
  .drop:hover,.drop.over{border-color:var(--brand);background:var(--brand-soft)}
  .drop .big{font-size:28px;margin-bottom:6px;opacity:.6}
  .drop b{color:var(--brand)}
  .drop .sm{font-size:11.5px;margin-top:6px}
  .filechip{display:inline-flex;align-items:center;gap:8px;background:var(--brand-soft);color:var(--brand-dark);border-radius:999px;padding:5px 14px;font-size:12.5px;font-weight:600;margin-top:10px}
  .filechip button{border:none;background:none;color:var(--brand-dark);font-size:14px;line-height:1;opacity:.7}
  .filechip button:hover{opacity:1}
  .sheet-row{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:12px;padding:10px 14px;background:var(--bg);border:1px solid var(--line);border-radius:9px}
  .sheet-row .sheet-lbl{font-size:12.5px;font-weight:700;color:var(--ink-2)}
  .sheet-row select{border:1px solid var(--line);border-radius:7px;padding:5px 10px;font-size:12.5px;font-family:inherit;background:#fff;min-width:180px;color:var(--ink)}
  .sheet-row .sheet-auto{font-size:11.5px;color:var(--ok);font-weight:600}
  .sheet-row .sheet-manual{font-size:11.5px;color:var(--warn);font-weight:600}

  /* ---- slots (armap) ---- */
  .slots{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:16px}
  @media(max-width:1100px){.slots{grid-template-columns:1fr}}
  .slot{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:7px}
  .slot .lbl{display:flex;align-items:center;gap:7px;font-weight:700;font-size:13px;color:var(--ink)}
  .slot .lbl .step{display:inline-flex;width:20px;height:20px;border-radius:50%;background:var(--brand);color:#fff;font-size:11px;align-items:center;justify-content:center;font-weight:800;flex-shrink:0}
  .slot .hint{font-size:11.5px;color:var(--ink-3);line-height:1.4}
  .slot .drop{padding:16px;font-size:12.5px}
  .slot .drop .big{font-size:20px;margin-bottom:2px}
  .slot.ready{border-color:var(--ok);background:#f0fdf4}
  .slot .files{display:flex;flex-direction:column;gap:4px}
  .slot .fchip{display:flex;align-items:center;justify-content:space-between;gap:6px;background:var(--brand-soft);color:var(--brand-dark);border-radius:7px;padding:5px 10px;font-size:11.5px}
  .slot .fchip .meta{font-size:10px;color:var(--ink-2);opacity:.8}
  .slot .fchip button{border:none;background:none;color:var(--brand-dark);font-size:13px;cursor:pointer;opacity:.7}
  .slot .ok{font-size:11.5px;color:var(--ok);font-weight:600;margin-top:2px}
  .slot .err{font-size:11.5px;color:var(--bad);font-weight:600;margin-top:2px}
  .bigbtn{padding:12px 28px;font-size:14.5px;border-radius:10px}

  /* ---- tabs ---- */
  .tabs{display:flex;gap:3px;background:#f1f5f9;padding:3px;border-radius:9px;margin-bottom:14px}
  .tabs button{flex:1;border:none;background:transparent;padding:8px 12px;font-size:12.5px;font-weight:600;color:var(--ink-3);border-radius:7px;cursor:pointer;transition:.15s}
  .tabs button.active{background:#fff;color:var(--brand-dark);box-shadow:0 1px 3px rgba(0,0,0,.09);font-weight:700}
  .tabs button .c{display:inline-block;margin-left:5px;background:var(--brand-soft);color:var(--brand-dark);border-radius:999px;padding:1px 7px;font-size:10.5px}
  .tabs button.active .c{background:var(--brand);color:#fff}

  /* ---- state colors ---- */
  .warning-row{background:#fffbeb!important}
  .neg{color:var(--bad);font-weight:600}
  .pos{color:var(--ok);font-weight:600}

  /* ---- buttons ---- */
  .btn{border:1px solid var(--brand);background:var(--brand);color:#fff;padding:8px 16px;border-radius:8px;font-weight:600;font-size:13px;transition:.15s;letter-spacing:.1px}
  .btn:hover{background:var(--brand-dark);border-color:var(--brand-dark)}
  .btn[disabled]{opacity:.4;cursor:not-allowed}
  .btn.ghost{background:#fff;color:var(--brand);border-color:var(--brand)}
  .btn.ghost:hover{background:var(--brand-soft)}
  .btn.sm{padding:5px 12px;font-size:12px;border-radius:7px}
  .btnrow{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:14px}

  /* ---- dropdown ---- */
  .dd{position:relative;display:inline-block}
  .dd-menu{position:absolute;top:calc(100% + 5px);left:0;background:#fff;border:1px solid var(--line);border-radius:9px;box-shadow:var(--shadow-md);min-width:165px;overflow:hidden;display:none;z-index:10}
  .dd.open .dd-menu{display:block}
  .dd-menu button{display:flex;width:100%;gap:8px;align-items:center;border:none;background:#fff;padding:10px 14px;font-size:13px;text-align:left;color:var(--ink);transition:.12s}
  .dd-menu button:hover{background:var(--brand-soft)}
  .dd-menu .x{font-size:10.5px;color:var(--ink-3)}

  /* ---- table ---- */
  .table-wrap{overflow:auto;border:1px solid var(--line);border-radius:9px;margin-top:12px;max-height:440px}
  table{border-collapse:collapse;width:100%;font-size:12.5px;white-space:nowrap}
  th,td{border-bottom:1px solid var(--line);padding:8px 12px;text-align:left}
  th{background:#f8fafc;position:sticky;top:0;font-weight:700;color:var(--ink-2);font-size:11.5px;letter-spacing:.3px;text-transform:uppercase}
  tbody tr:last-child td{border-bottom:none}
  tbody tr:hover{background:#f8fafc}
  .empty{padding:40px;text-align:center;color:var(--ink-3);font-size:13px}

  /* ---- options ---- */
  .opts{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:8px}
  .opt{display:flex;align-items:center;gap:6px;font-size:12.5px;color:var(--ink-2)}
  .opt input{width:15px;height:15px;accent-color:var(--brand)}
  .pill-stat{display:flex;gap:12px;flex-wrap:wrap;margin:12px 0 0}
  .stat{background:var(--brand-soft);border-radius:9px;padding:10px 16px;min-width:100px}
  .stat .n{font-size:20px;font-weight:800;color:var(--brand-dark)}
  .stat .l{font-size:11px;color:var(--ink-2);font-weight:600;margin-top:1px}
  .stat.warn{background:#fffbeb}.stat.warn .n{color:var(--warn)}
  .stat.bad{background:#fef2f2}.stat.bad .n{color:var(--bad)}
  .soon-note{font-size:12px;color:var(--ink-3);background:#f8fafc;border-radius:7px;padding:10px 14px;margin-top:12px;border:1px solid var(--line)}

  /* ---- responsive ---- */
  @media(max-width:820px){
    .sidebar{position:fixed;left:-260px;transition:.22s;height:100%;z-index:30}
    .sidebar.show{left:0}
    .main{padding:16px}
    .menu-toggle{display:inline-block!important}
  }
  .menu-toggle{display:none;border:1px solid var(--line);background:#fff;border-radius:7px;padding:5px 10px;font-size:18px;line-height:1;color:var(--ink-2)}

  /* ---- Executive Dashboard styling ---- */
  .ed-page{background:linear-gradient(180deg,#f5f9ff 0%,#eef5ff 100%);min-height:calc(100vh - 54px);margin:-24px -28px;padding:24px 28px}
  .ed-card{background:rgba(255,255,255,.85);backdrop-filter:blur(8px);border:1px solid #d6e4ff;border-radius:14px;box-shadow:0 1px 3px rgba(30,58,138,.06),0 4px 16px rgba(30,58,138,.05);padding:18px 20px;margin-bottom:14px}
  .ed-card h3{margin:0 0 10px;font-family:"IBM Plex Sans","IBM Plex Sans Thai",ui-sans-serif,sans-serif;font-size:14.5px;font-weight:700;color:#1e3a8a;letter-spacing:-.2px}
  .ed-tabs{display:flex;gap:4px;background:rgba(99,179,237,.12);padding:4px;border-radius:11px;margin-bottom:16px;flex-wrap:wrap}
  .ed-tabs button{flex:1;min-width:120px;border:none;background:transparent;padding:9px 14px;font-size:12.5px;font-weight:600;color:#475569;border-radius:8px;cursor:pointer;transition:.15s;font-family:inherit}
  .ed-tabs button:hover{background:rgba(255,255,255,.5)}
  .ed-tabs button.active{background:#fff;color:#1e40af;box-shadow:0 2px 8px rgba(79,138,247,.18);font-weight:700}

  /* Print header (visible only when printing) */
  #printHeader{display:none}
  @media print{
    body{background:#fff!important;-webkit-print-color-adjust:exact;print-color-adjust:exact}
    .sidebar,.topbar,#exportDD,.ed-tabs,.menu-toggle,.btn,button{display:none!important}
    .main{padding:0!important;max-width:none!important;overflow:visible!important}
    .ed-page{background:#fff!important;margin:0!important;padding:14mm!important;min-height:auto!important}
    .wrap{display:block!important}
    .ed-card,.card{box-shadow:none!important;border:1px solid #cbd5e1!important;backdrop-filter:none!important;background:#fff!important;page-break-inside:avoid;margin-bottom:10px!important}
    #printHeader{display:block;border-bottom:3px solid #4F8AF7;padding:0 0 14px;margin-bottom:18px}
    #printHeader .ph-row{display:flex;align-items:center;justify-content:space-between;gap:14px}
    #printHeader .ph-co{display:flex;align-items:center;gap:14px}
    #printHeader .ph-logo{width:62px;height:62px;object-fit:contain}
    #printHeader .ph-co-name{font-family:"IBM Plex Sans","IBM Plex Sans Thai",ui-sans-serif,sans-serif;font-size:18px;font-weight:800;color:#0f172a;letter-spacing:-.4px}
    #printHeader .ph-co-sub{font-size:11px;color:#64748b;margin-top:2px;text-transform:uppercase;letter-spacing:.7px;font-weight:600}
    #printHeader .ph-meta{text-align:right;font-size:11.5px;color:#475569;line-height:1.7}
    #printHeader .ph-title{font-size:13px;font-weight:700;color:#1e40af;letter-spacing:.3px;text-transform:uppercase}
    #printHeader .ph-period{font-size:14.5px;font-weight:700;color:#0f172a;margin-top:1px}
    #printHeader .ph-ts{color:#94a3b8;font-size:10.5px;margin-top:2px;font-style:italic}
    .page-head,h1{break-after:avoid}
    .table-wrap{max-height:none!important;overflow:visible!important;border:none!important}
    table{font-size:10px!important}
    th,td{padding:5px 7px!important}
    th{background:#eff6ff!important;color:#1e40af!important;border-bottom:1.5px solid #4F8AF7!important}
    .ed-print-only{display:block!important}
    canvas{max-width:100%!important;height:auto!important}
    @page{size:A4 landscape;margin:10mm}
  }
  .ed-print-only{display:none}
</style>
```

---

## หน้าที่ออกแบบใหม่: ส่งออกคีย์ AutoKey

```javascript
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
```
