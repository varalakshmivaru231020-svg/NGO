import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import type { Response } from 'express';
import { readFileSync } from 'fs';
import { join } from 'path';
import { DonationsService } from './donations.service';
import { SettingsService } from '../settings/settings.service';

// Public (no auth) printable receipt page. The link is sent to donors over
// WhatsApp (receipt_generated {{3}}); the donation id is a UUID so it's an
// unguessable, unlisted URL. Uses @Res() to return raw HTML, bypassing the
// JSON TransformInterceptor.
@ApiTags('receipts')
@Controller('receipts')
export class ReceiptController {
  constructor(
    private readonly svc: DonationsService,
    private readonly settings: SettingsService,
  ) {}

  // Lazily read + cache the bundled fallback logo as a data URI so it can be
  // embedded inline (no separate static-file route needed). Used only when
  // no OrgSettings.logoBase64 override has been configured.
  private static fallbackLogoDataUri: string | null | undefined;
  private fallbackLogo(): string | null {
    if (ReceiptController.fallbackLogoDataUri === undefined) {
      try {
        const bytes = readFileSync(join(__dirname, '..', '..', 'assets', 'sket-logo.png'));
        ReceiptController.fallbackLogoDataUri = `data:image/png;base64,${bytes.toString('base64')}`;
      } catch {
        ReceiptController.fallbackLogoDataUri = null;
      }
    }
    return ReceiptController.fallbackLogoDataUri;
  }

  @Get(':id')
  @ApiOperation({ summary: 'Public printable donation receipt (HTML)' })
  async receipt(@Param('id') id: string, @Res() res: Response) {
    const org = await this.settings.getOrganization();
    const orgName = org.name || 'Sri Krishnashraya Educational Trust';
    let d: any = null;
    try { d = await this.svc.findOne(id); } catch { d = null; }
    if (!d) {
      res.status(404).type('html').send(
        this.page(orgName, `<p class="err">Receipt not found or has been removed.</p>`),
      );
      return;
    }
    const amountNum = Number(d.amount || 0);
    const amount = amountNum.toLocaleString('en-IN');
    const date = d.date
      ? new Date(d.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
      : '';
    const donor = d.donor ?? {};
    const donorLocationLine = [donor.city, donor.state, donor.country]
      .filter((v) => v && String(v).trim())
      .map((v) => this.esc(v))
      .join(', ');
    const type = this.esc(d.type?.label ?? 'Donation');
    const mode = this.esc(String(d.paymentMode ?? '').replace(/_/g, ' '));
    const receiptNo = this.esc(d.receiptNo ?? '');

    const orgAddressLines = [org.address, org.city, org.state, org.pincode, org.country]
      .filter((v) => v && String(v).trim())
      .join(', ');
    const statutoryParts = [
      org.pan && `Trust PAN: ${this.esc(org.pan)}`,
      org.reg12A && `12AA Registration: ${this.esc(org.reg12A)}`,
      org.cert80G && `80G Certification: ${this.esc(org.cert80G)}`,
      org.registrationNumber && `Reg. No. ${this.esc(org.registrationNumber)}`,
    ].filter(Boolean);
    const logo = org.logoBase64 || this.fallbackLogo();

    const body = `
      <div class="rc">
        <div class="hdr">
          ${logo ? `<img class="logo" src="${logo}" alt="${this.esc(orgName)} logo" />` : `<div class="org-name">${this.esc(orgName)}</div>`}
        </div>
        ${orgAddressLines ? `<div class="addr-bar">${this.esc(orgAddressLines)}</div>` : ''}

        <div class="top-grid">
          <div class="recipient">
            <div class="label">RECIPIENT:</div>
            <div class="name">${this.esc(donor.name ?? 'Donor')}</div>
            ${donor.mobile ? `<div class="sub">${this.esc(donor.mobile)}</div>` : ''}
            ${donorLocationLine ? `<div class="sub">${donorLocationLine}</div>` : ''}
            ${donor.pan ? `<div class="pan">PAN: ${this.esc(donor.pan)}</div>` : ''}
          </div>
          <div class="receipt-info">
            <div class="ri-head">Receipt for #${receiptNo}</div>
            <div class="ri-body">
              <div>Transaction Date: ${this.esc(date)}</div>
              <div>Mode: ${mode || '—'}</div>
              ${d.reference ? `<div>Gateway Ref: ${this.esc(d.reference)}</div>` : ''}
            </div>
          </div>
        </div>

        <table class="items">
          <thead>
            <tr><th>DONATION / SERVICE</th><th>DESCRIPTION</th><th class="c">UNIT</th><th class="r">COST</th><th class="r">TOTAL</th></tr>
          </thead>
          <tbody>
            <tr>
              <td class="strong">${type}</td>
              <td class="desc">Contribution allocated towards trust operational support, community educational aid, and welfare programs.${d.taxExemption ? ' Clean tax exemption applicable.' : ''}</td>
              <td class="c">1</td>
              <td class="r">₹${amount}</td>
              <td class="r strong">₹${amount}</td>
            </tr>
          </tbody>
        </table>

        <div class="rule"></div>
        <h2 class="section-h">Receipt for Payment</h2>

        <div class="pay-grid">
          <div class="words">
            <div class="label">RECEIPT FOR PAYMENT (AMOUNT IN WORDS)</div>
            <div class="words-val">${this.amountInWords(amountNum)}</div>
          </div>
          <div class="totals">
            <div class="trow"><span>Subtotal</span><span>₹${amount}</span></div>
            <div class="trow"><span>Tax (0%)</span><span>₹0</span></div>
            <div class="trow total"><span>Total</span><span>₹${amount}</span></div>
          </div>
        </div>

        <div class="rule dashed"></div>
        <div class="thanks">Thanks for your support!</div>

        ${statutoryParts.length ? `
        <div class="statutory">
          <div class="statutory-h">Statutory Registration Details (Tax Benefits)</div>
          <div class="statutory-line">${statutoryParts.join(' &nbsp;|&nbsp; ')}</div>
          <div class="statutory-note">This is an electronically generated receipt confirmation. No physical signature is required.
          ${org.email ? ` For verification or support, write to ${this.esc(org.email)}.` : ''}</div>
        </div>` : ''}

        <button class="print" onclick="window.print()">Download / Print Receipt</button>
      </div>`;
    res.status(200).type('html').send(this.page(orgName, body));
  }

  // Indian-numbering (lakh/crore) amount-in-words, mirroring the Flutter
  // app's receipt generator so both surfaces read identically.
  private amountInWords(n: number): string {
    n = Math.round(n);
    if (n === 0) return 'Zero Rupees Only';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    const words = (num: number): string => {
      if (num === 0) return '';
      if (num < 20) return `${ones[num]} `;
      if (num < 100) return `${tens[Math.floor(num / 10)]} ${words(num % 10)}`;
      if (num < 1000) return `${ones[Math.floor(num / 100)]} Hundred ${words(num % 100)}`;
      if (num < 100000) return `${words(Math.floor(num / 1000))}Thousand ${words(num % 1000)}`;
      if (num < 10000000) return `${words(Math.floor(num / 100000))}Lakh ${words(num % 100000)}`;
      return `${words(Math.floor(num / 10000000))}Crore ${words(num % 10000000)}`;
    };
    return `Rupees ${words(n).trim()} Only`;
  }

  private esc(s: any): string {
    return String(s ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  private page(orgName: string, inner: string): string {
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${this.esc(orgName)} · Receipt</title>
<style>
  :root{--brand:#F97316;--ink:#1F2937;--sub:#6B7280;--line:#E5E7EB;--bg-light:#F8FAFC}
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg-light);color:var(--ink);padding:20px 14px}
  .wrap{max-width:760px;margin:0 auto}
  .rc{background:#fff;border:1px solid var(--line);border-radius:10px;padding:28px 26px}
  .hdr{margin-bottom:18px}
  .logo{height:46px;display:block}
  .org-name{font-size:20px;font-weight:800;color:var(--ink)}
  .addr-bar{background:var(--brand);color:#fff;font-size:12.5px;font-weight:700;padding:9px 12px;border-radius:4px;margin-bottom:20px}
  .top-grid{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:22px}
  .recipient{flex:1 1 260px;min-width:0}
  .label{font-size:11px;font-weight:800;color:var(--ink);letter-spacing:.04em}
  .recipient .name{font-size:22px;font-weight:600;color:var(--ink);margin:6px 0}
  .recipient .sub{font-size:12.5px;color:var(--sub);margin-top:2px}
  .recipient .pan{font-size:12.5px;font-weight:700;color:var(--brand);margin-top:5px}
  .receipt-info{flex:1 1 220px;min-width:0}
  .ri-head{background:var(--brand);color:#fff;font-size:13px;font-weight:800;padding:8px 12px;border-radius:6px 6px 0 0}
  .ri-body{background:var(--bg-light);font-size:11.5px;color:var(--ink);padding:10px 12px;border-radius:0 0 6px 6px}
  .ri-body div{padding:2px 0}
  table.items{width:100%;border-collapse:collapse;margin-bottom:16px}
  table.items thead th{background:var(--brand);color:#fff;font-size:10px;font-weight:800;text-align:left;padding:9px 10px;letter-spacing:.03em}
  table.items thead th.c{text-align:center}
  table.items thead th.r{text-align:right}
  table.items tbody td{padding:14px 10px;font-size:12px;color:var(--ink);vertical-align:top}
  table.items tbody td.desc{color:var(--sub);line-height:1.5}
  table.items tbody td.c{text-align:center}
  table.items tbody td.r{text-align:right}
  table.items tbody td.strong{font-weight:700}
  .rule{height:2px;background:var(--ink);margin:18px 0}
  .rule.dashed{height:0;border-top:1px dashed var(--line);background:none;margin:20px 0}
  .section-h{text-align:center;font-size:19px;font-weight:800;color:var(--ink);margin-bottom:18px}
  .pay-grid{display:flex;gap:16px;flex-wrap:wrap}
  .words{flex:1 1 280px;min-width:0}
  .words-val{font-size:15px;font-style:italic;font-weight:700;color:var(--brand);margin-top:8px}
  .totals{flex:0 1 240px;min-width:200px}
  .trow{display:flex;justify-content:space-between;font-size:13px;color:var(--sub);padding:4px 0}
  .trow.total{font-weight:800;color:var(--ink);font-size:15px;padding-top:6px}
  .thanks{text-align:center;font-size:17px;font-style:italic;font-weight:800;color:var(--brand);margin-bottom:20px}
  .statutory{background:var(--bg-light);border-left:3px solid var(--brand);border-radius:4px;padding:12px 14px}
  .statutory-h{font-size:11px;font-weight:800;color:var(--brand);letter-spacing:.03em;text-transform:uppercase;margin-bottom:6px}
  .statutory-line{font-size:12px;font-weight:700;color:var(--ink);margin-bottom:6px}
  .statutory-note{font-size:10.5px;color:var(--sub);line-height:1.5}
  .print{width:100%;margin-top:20px;background:var(--brand);color:#fff;border:0;border-radius:8px;padding:12px;font-size:13px;font-weight:800;cursor:pointer}
  .err{text-align:center;color:#C0392B;font-weight:600;padding:20px}
  @media (max-width:520px){
    .rc{padding:20px 16px}
    .recipient .name{font-size:19px}
    .section-h{font-size:16px}
  }
  @media print{
    @page{size:A4;margin:14mm}
    body{background:#fff;padding:0}
    .wrap{max-width:100%}
    .print{display:none}
    .rc{border:0;padding:0}
  }
</style></head>
<body><div class="wrap">
  ${inner}
</div></body></html>`;
  }
}
