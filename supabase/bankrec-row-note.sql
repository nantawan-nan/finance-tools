-- Bank Recon: ช่องหมายเหตุ (user_note) ต่อแถว — จนท. พิมพ์เองท้ายบรรทัดในตารางกระทบยอด
-- idempotent · แยกจาก remark/ref_note (ที่ parse จากไฟล์) เพื่อไม่ให้ถูกทับตอนอัปซ้ำ
ALTER TABLE brec_express_rows ADD COLUMN IF NOT EXISTS user_note text;
ALTER TABLE brec_bank_rows    ADD COLUMN IF NOT EXISTS user_note text;
NOTIFY pgrst, 'reload schema';
