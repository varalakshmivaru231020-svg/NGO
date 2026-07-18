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
        this.page(orgName, org, `<p class="err">Receipt not found or has been removed.</p>`),
      );
      return;
    }
    const amount = Number(d.amount || 0).toLocaleString('en-IN');
    const date = d.date
      ? new Date(d.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
      : '';
    const donor = d.donor ?? {};
    const donorAddressLines = [donor.address, donor.city, donor.state, donor.pincode, donor.country]
      .filter((v) => v && String(v).trim())
      .join(', ');
    const type = this.esc(d.type?.label ?? 'Donation');
    const mode = this.esc(String(d.paymentMode ?? '').replace(/_/g, ' '));
    const receiptNo = this.esc(d.receiptNo ?? '');
    const status = this.esc(String(d.status ?? '').replace(/_/g, ' '));

    const orgAddressLines = [org.address, org.city, org.state, org.pincode, org.country]
      .filter((v) => v && String(v).trim())
      .join(', ');
    const orgContactLine = [org.phone, org.email, org.website].filter(Boolean).map((v) => this.esc(v)).join(' &nbsp;·&nbsp; ');
    const orgStatutoryLine = [
      org.registrationNumber && `Reg. No. ${this.esc(org.registrationNumber)}`,
      org.pan && `PAN ${this.esc(org.pan)}`,
      org.reg12A && `12A ${this.esc(org.reg12A)}`,
      org.cert80G && `80G ${this.esc(org.cert80G)}`,
    ].filter(Boolean).join(' &nbsp;·&nbsp; ');
    const logo = org.logoBase64 || this.fallbackLogo();

    const body = `
      <div class="rc">
        <div class="hdr">
          ${logo ? `<img class="logo" src="${logo}" alt="${this.esc(orgName)} logo" />` : ''}
          <div class="org-block">
            <div class="org">${this.esc(orgName)}</div>
            ${orgAddressLines ? `<div class="org-sub">${this.esc(orgAddressLines)}</div>` : ''}
            ${orgContactLine ? `<div class="org-sub">${orgContactLine}</div>` : ''}
            ${orgStatutoryLine ? `<div class="org-sub org-stat">${orgStatutoryLine}</div>` : ''}
          </div>
        </div>

        <div class="badge">✓ Donation Received</div>
        <h1>Donation Receipt</h1>
        <div class="amt">₹${amount}</div>

        <div class="section-title">Donor Details</div>
        <table>
          <tr><td>Name</td><td>${this.esc(donor.name ?? 'Donor')}</td></tr>
          ${donor.mobile ? `<tr><td>Mobile</td><td>${this.esc(donor.mobile)}</td></tr>` : ''}
          ${donor.email ? `<tr><td>Email</td><td>${this.esc(donor.email)}</td></tr>` : ''}
          <tr><td>Address</td><td>${donorAddressLines ? this.esc(donorAddressLines) : '—'}</td></tr>
          ${donor.pan ? `<tr><td>PAN</td><td>${this.esc(donor.pan)}</td></tr>` : ''}
        </table>

        <div class="section-title">Donation Details</div>
        <table>
          <tr><td>Invoice No.</td><td>${receiptNo}</td></tr>
          <tr><td>Date</td><td>${this.esc(date)}</td></tr>
          <tr><td>Donation Purpose</td><td>${type}</td></tr>
          <tr><td>Payment Method</td><td>${mode || '—'}</td></tr>
          ${d.reference ? `<tr><td>Transaction ID</td><td>${this.esc(d.reference)}</td></tr>` : ''}
          <tr><td>Status</td><td>${status || '—'}</td></tr>
        </table>

        <p class="thanks">Thank you for your generous contribution. Your support is helping
        transform children's lives through education, care, and holistic development.</p>

        <div class="sign">
          <div class="sign-line"></div>
          <div class="sign-label">Authorized Signature — ${this.esc(orgName)}</div>
        </div>

        <p class="disclaimer">This receipt is issued electronically and is valid without a physical signature.
        ${org.cert80G ? 'Donations to this organization are eligible for tax exemption under Section 80G of the Income Tax Act, subject to applicable terms.' : ''}</p>

        <button class="print" onclick="window.print()">Download / Print Receipt</button>
      </div>`;
    res.status(200).type('html').send(this.page(orgName, org, body));
  }

  private esc(s: any): string {
    return String(s ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  private page(orgName: string, org: any, inner: string): string {
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${this.esc(orgName)} · Receipt</title>
<style>
  :root{--brand:#F97316;--brand700:#EA6A0A;--ink:#1F2937;--sub:#6B7280;--line:#E5E7EB;--bg-light:#F8FAFC}
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg-light);color:var(--ink);padding:16px}
  .wrap{max-width:440px;margin:0 auto}
  .rc{background:#fff;border:1px solid var(--line);border-radius:10px;padding:20px 18px}
  .hdr{display:flex;align-items:center;gap:12px;margin-bottom:14px;padding-bottom:14px;border-bottom:1px solid var(--line)}
  .logo{width:52px;height:52px;object-fit:contain;flex-shrink:0}
  .org-block{min-width:0}
  .org{font-size:15px;font-weight:800;color:var(--ink)}
  .org-sub{font-size:10px;color:var(--sub);line-height:1.5}
  .org-stat{font-weight:600}
  .badge{display:inline-block;background:#FFF1E7;color:var(--brand700);font-size:10.5px;font-weight:800;padding:3px 10px;border-radius:20px;margin-bottom:8px}
  h1{font-size:16px;font-weight:800;letter-spacing:-.2px}
  .amt{font-size:26px;font-weight:800;color:var(--brand700);letter-spacing:-.5px;margin:10px 0 16px}
  .section-title{font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;color:var(--sub);margin:14px 0 6px}
  table{width:100%;border-collapse:collapse;margin-top:2px}
  td{padding:7px 0;border-bottom:1px dashed var(--line);font-size:12.5px;vertical-align:top}
  td:first-child{color:var(--sub);font-weight:600;width:38%}
  td:last-child{font-weight:700;text-align:right;word-break:break-word}
  .thanks{font-size:11px;color:var(--sub);line-height:1.5;margin:16px 0 4px}
  .sign{margin-top:28px;text-align:right}
  .sign-line{border-top:1px solid var(--ink);width:180px;margin-left:auto}
  .sign-label{font-size:10px;color:var(--sub);margin-top:4px}
  .disclaimer{font-size:9.5px;color:var(--sub);line-height:1.5;margin-top:14px;padding-top:10px;border-top:1px solid var(--line)}
  .print{width:100%;margin-top:14px;background:var(--brand);color:#fff;border:0;border-radius:8px;padding:11px;font-size:13px;font-weight:800;cursor:pointer}
  .err{text-align:center;color:#C0392B;font-weight:600;padding:20px}
  @media print{
    @page{size:A4;margin:12mm}
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
