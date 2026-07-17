import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import type { Response } from 'express';
import { ConfigService } from '@nestjs/config';
import { DonationsService } from './donations.service';

// Public (no auth) printable receipt page. The link is sent to donors over
// WhatsApp (receipt_generated {{3}}); the donation id is a UUID so it's an
// unguessable, unlisted URL. Uses @Res() to return raw HTML, bypassing the
// JSON TransformInterceptor.
@ApiTags('receipts')
@Controller('receipts')
export class ReceiptController {
  constructor(
    private readonly svc: DonationsService,
    private readonly config: ConfigService,
  ) {}

  @Get(':id')
  @ApiOperation({ summary: 'Public printable donation receipt (HTML)' })
  async receipt(@Param('id') id: string, @Res() res: Response) {
    const org = this.config.get<string>('ORG_NAME') || 'Sri Krishnashraya Educational Trust';
    let d: any = null;
    try { d = await this.svc.findOne(id); } catch { d = null; }
    if (!d) {
      res.status(404).type('html').send(
        this.page(org, `<p class="err">Receipt not found or has been removed.</p>`),
      );
      return;
    }
    const amount = Number(d.amount || 0).toLocaleString('en-IN');
    const date = d.date
      ? new Date(d.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
      : '';
    const donor = this.esc(d.donor?.name ?? 'Donor');
    const type = this.esc(d.type?.label ?? 'Donation');
    const mode = this.esc(String(d.paymentMode ?? '').replace(/_/g, ' '));
    const receiptNo = this.esc(d.receiptNo ?? '');

    const body = `
      <div class="rc">
        <div class="badge">✓ Donation Received</div>
        <h1>Donation Receipt</h1>
        <p class="rno">${receiptNo}</p>
        <div class="amt">₹${amount}</div>
        <table>
          <tr><td>Donor</td><td>${donor}</td></tr>
          <tr><td>Donation Type</td><td>${type}</td></tr>
          <tr><td>Payment Mode</td><td>${mode || '—'}</td></tr>
          <tr><td>Date</td><td>${this.esc(date)}</td></tr>
          <tr><td>Receipt No.</td><td>${receiptNo}</td></tr>
        </table>
        <p class="thanks">Thank you for your generous contribution. Your support is helping
        transform children's lives through education, care, and holistic development.</p>
        <button class="print" onclick="window.print()">Download / Print Receipt</button>
      </div>`;
    res.status(200).type('html').send(this.page(org, body));
  }

  private esc(s: string): string {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  private page(org: string, inner: string): string {
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${this.esc(org)} · Receipt</title>
<style>
  :root{--brand:#F97316;--brand700:#EA6A0A;--ink:#1F2937;--sub:#6B7280;--line:#E5E7EB;--bg-light:#F8FAFC}
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg-light);color:var(--ink);padding:16px}
  .wrap{max-width:440px;margin:0 auto}
  .org{text-align:center;font-size:15px;font-weight:800;color:var(--ink);margin-bottom:2px}
  .org-sub{text-align:center;font-size:10.5px;color:var(--sub);margin-bottom:12px}
  .rc{background:#fff;border:1px solid var(--line);border-radius:10px;padding:16px 16px}
  .badge{display:inline-block;background:#FFF1E7;color:var(--brand700);font-size:10.5px;font-weight:800;padding:3px 10px;border-radius:20px;margin-bottom:8px}
  h1{font-size:16px;font-weight:800;letter-spacing:-.2px}
  .rno{color:var(--sub);font-size:10.5px;font-weight:600;margin-top:1px}
  .amt{font-size:26px;font-weight:800;color:var(--brand700);letter-spacing:-.5px;margin:10px 0}
  table{width:100%;border-collapse:collapse;margin-top:2px}
  td{padding:7px 0;border-bottom:1px dashed var(--line);font-size:12.5px;vertical-align:top}
  td:first-child{color:var(--sub);font-weight:600;width:42%}
  td:last-child{font-weight:700;text-align:right}
  .thanks{font-size:10.5px;color:var(--sub);line-height:1.4;margin:12px 0 4px}
  .print{width:100%;margin-top:10px;background:var(--brand);color:#fff;border:0;border-radius:8px;padding:11px;font-size:13px;font-weight:800;cursor:pointer}
  .err{text-align:center;color:#C0392B;font-weight:600;padding:20px}
  @media print{body{background:#fff;padding:0}.print{display:none}.rc{border:0}}
</style></head>
<body><div class="wrap">
  <div class="org">${this.esc(org)}</div>
  <div class="org-sub">Official Donation Receipt</div>
  ${inner}
</div></body></html>`;
  }
}
