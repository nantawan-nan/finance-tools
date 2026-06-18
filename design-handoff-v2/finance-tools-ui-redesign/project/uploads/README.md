# For Design — code snippets สำหรับส่ง Claude Design

## วิธีใช้

ส่งให้ Claude Design 3 ก้อนต่อ 1 หน้า:
1. **`style.html`** — `<style>` กลางของแอป (palette, font, base components) — **ส่งทุกรอบ**
2. **`pages/{ชื่อหน้า}.js`** — function `renderToolXxx` ของหน้านั้น
3. **Screenshot** ของหน้านั้นในแอป (แคปเอง)

## หน้าที่มี

| ไฟล์ | function | คำอธิบาย |
|---|---|---|
| `pages/home.js` | `renderToolHome` | หน้าหลัก — Hub grid ของแต่ละโมดูล |
| `pages/ar.js` | `renderToolAr` | AR Outstanding — ลูกหนี้คงค้าง 3 tabs |
| `pages/bigseller.js` | `renderToolBigSeller` | BigSeller → IV |
| `pages/expressmatch.js` | `renderToolExpressMatch` | แมพ IV จาก Express |
| `pages/exportkey.js` | `renderToolExportKey` | ส่งออกคีย์ AutoKey |
| `pages/dashboard.js` | `renderToolDashboard` | Sales Dashboard |
| `pages/armap.js` | `renderToolArmap` | Map ลูกหนี้ → เงินเข้า |
| `pages/users.js` | `renderToolUsers` | จัดการผู้ใช้ (admin) |
| `pages/soon.js` | `renderToolSoon` | หน้า Coming Soon |

## Prompt template

```
ฉันมีแอป Finance Tools เป็น single-file SPA (vanilla JS + Supabase + Chart.js + Lucide icons)
ช่วยออกแบบ UI ใหม่ให้หน้านี้ ทันสมัย สวย เป็นมืออาชีพ

ส่งกลับเป็น HTML template + CSS เท่านั้น — ฉันจะ merge กับ JS logic เดิมเอง
เก็บ class names + data attributes + onclick handlers เดิม (เช่น setTool, arOpenReceipt)

โทนสี:
- M Bark: navy blue เข้ม (#1e3a8a) → corporate professional
- Benya: teal/cyan (#0d9488) → clean medical fresh
- positive: #14B8A6 (teal soft)
- negative: #E18AAA (pink soft)
- bg gradient pastel ตาม brand

Stack:
- IBM Plex Sans Thai (ไทย) + IBM Plex Sans (อังกฤษ)
- Lucide icons (<i data-lucide="name">)
- glassmorphism cards, micro-interactions, spacing โปร่ง

[แนบ style.html + pages/xxx.js + screenshot]
```
