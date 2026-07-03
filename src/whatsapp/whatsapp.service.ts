import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

// Node 18+ ships a global fetch; cast through globalThis so we don't depend on
// the DOM lib being enabled in tsconfig.
const httpPost = (globalThis as any).fetch as (
  url: string,
  init?: any,
) => Promise<{ ok: boolean; status: number; text: () => Promise<string> }>;

const DEFAULT_ENDPOINT = 'https://crmapp.botsyncwa.com/api/v1/messages';
const DEFAULT_META_VERSION = 'v19.0';

interface WaConfig {
  apiUrl: string;
  apiToken: string;
  phoneNumberId: string;
  apiVersion: string;
  authHeader: string;
  authPrefix: string;
  countryCode: string;
}

/**
 * Sends approved WhatsApp message templates through BotSyncWA (WhatsApp Business
 * API). BotSyncWA exposes two integration modes, both confirmed against the
 * live gateway; which one is used is auto-detected from the configured apiUrl:
 *
 *  1. On-premises style (default) — apiUrl is a fixed messages endpoint, e.g.
 *     https://crmapp.botsyncwa.com/api/v1/messages
 *       POST <apiUrl>
 *       Authorization: Bearer <apiToken>
 *       phone_number_id: <id>   (sent both as a header AND a body field)
 *       body: { phone_number_id, to, recipient_type:"individual",
 *               type:"template", template:{ name, language:{policy,code}, components } }
 *
 *  2. Native Meta passthrough — apiUrl contains "/api/meta" (no version/id
 *     segments), e.g. https://crmapp.botsyncwa.com/api/meta. The full send URL
 *     is built Meta-Graph-API style: `${apiUrl}/${apiVersion}/${phoneNumberId}/messages`.
 *       POST <apiUrl>/<apiVersion>/<phoneNumberId>/messages
 *       Authorization: Bearer <apiToken>
 *       body: { messaging_product:"whatsapp", to, type:"template",
 *               template:{ name, language:{code}, components } }
 *     (wabaId / businessId are account-identifying metadata only — not sent.)
 *
 * Config is read DB-first (WhatsappSetting singleton, edited from the admin
 * panel) and falls back to .env. Every method is best-effort and NEVER throws —
 * WhatsApp delivery must not break the donation / receipt flow.
 */
@Injectable()
export class WhatsappService {
  private readonly logger = new Logger('WhatsappService');

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  /** Merge the admin-panel DB settings over the .env defaults. */
  private async loadConfig(): Promise<WaConfig> {
    let row: any = null;
    try {
      row = await this.prisma.whatsappSetting.findUnique({ where: { id: 'singleton' } });
    } catch {
      row = null;
    }
    const pick = (dbVal: string | null | undefined, envKey: string): string =>
      (dbVal && dbVal.trim()) || this.config.get<string>(envKey) || '';
    return {
      apiUrl: pick(row?.apiUrl, 'BOTSYNK_API_URL') || DEFAULT_ENDPOINT,
      apiToken: pick(row?.apiToken, 'BOTSYNK_API_KEY'),
      phoneNumberId: pick(row?.phoneNumberId, 'BOTSYNK_PHONE_NUMBER_ID'),
      apiVersion: pick(row?.apiVersion, 'BOTSYNK_API_VERSION') || DEFAULT_META_VERSION,
      authHeader: this.config.get<string>('BOTSYNK_AUTH_HEADER') || 'Authorization',
      authPrefix:
        this.config.get<string>('BOTSYNK_AUTH_PREFIX') !== undefined
          ? this.config.get<string>('BOTSYNK_AUTH_PREFIX')!
          : 'Bearer ',
      countryCode: this.config.get<string>('WHATSAPP_COUNTRY_CODE') || '91',
    };
  }

  /** Normalise a phone number to WhatsApp form: digits only, with country code, no '+'. */
  private normalise(raw: string, countryCode: string): string | null {
    if (!raw) return null;
    let digits = raw.replace(/\D/g, '');
    if (digits.length === 10) digits = countryCode + digits;
    else if (digits.length === 11 && digits.startsWith('0')) digits = countryCode + digits.slice(1);
    if (digits.length < 11) return null;
    return digits;
  }

  /**
   * Send an approved template. `bodyParams` fills {{1}}, {{2}}, … in order.
   * `opts.buttonUrl` supplies the dynamic suffix for a URL button (index 0).
   */
  async sendTemplate(
    to: string,
    templateName: string,
    bodyParams: (string | number)[],
    opts: { languageCode?: string; buttonUrl?: string } = {},
  ): Promise<boolean> {
    const cfg = await this.loadConfig();
    if (!cfg.apiUrl || !cfg.apiToken) {
      this.logger.warn(`WhatsApp not configured — skipped template "${templateName}"`);
      return false;
    }
    const number = this.normalise(to, cfg.countryCode);
    if (!number) {
      this.logger.warn(`Invalid phone "${to}" — skipped template "${templateName}"`);
      return false;
    }

    const components: any[] = [
      {
        type: 'body',
        parameters: bodyParams.map((p) => ({ type: 'text', text: String(p) })),
      },
    ];
    if (opts.buttonUrl) {
      components.push({
        type: 'button',
        sub_type: 'url',
        index: '0',
        parameters: [{ type: 'text', text: opts.buttonUrl }],
      });
    }

    const isMetaMode = cfg.apiUrl.toLowerCase().includes('/api/meta');
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      [cfg.authHeader]: cfg.authPrefix + cfg.apiToken,
    };
    let sendUrl = cfg.apiUrl;
    let payload: any;

    if (isMetaMode) {
      // Native Meta passthrough: URL carries the version + phone number id,
      // Graph-API-style; body needs messaging_product, no recipient_type/policy.
      const base = cfg.apiUrl.replace(/\/+$/, '');
      sendUrl = `${base}/${cfg.apiVersion}/${cfg.phoneNumberId}/messages`;
      payload = {
        messaging_product: 'whatsapp',
        to: number,
        type: 'template',
        template: {
          name: templateName,
          language: { code: opts.languageCode || 'en' },
          components,
        },
      };
    } else {
      // On-premises style: fixed endpoint; phone_number_id sent both in the
      // body and as a header (belt-and-suspenders; extra fields are ignored).
      payload = {
        to: number,
        recipient_type: 'individual',
        type: 'template',
        template: {
          name: templateName,
          language: { policy: 'deterministic', code: opts.languageCode || 'en' },
          components,
        },
      };
      if (cfg.phoneNumberId) {
        payload.phone_number_id = cfg.phoneNumberId;
        headers['phone_number_id'] = cfg.phoneNumberId;
      }
    }

    try {
      const res = await httpPost(sendUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        this.logger.error(
          `BotSyncWA send failed (${res.status}) for "${templateName}": ${text.slice(0, 300)}`,
        );
        return false;
      }
      this.logger.log(`Sent "${templateName}" to ${number}`);
      return true;
    } catch (e) {
      this.logger.error(`BotSyncWA send error for "${templateName}": ${String(e)}`);
      return false;
    }
  }

  private inr(amount: number): string {
    try {
      return amount.toLocaleString('en-IN');
    } catch {
      return String(amount);
    }
  }

  /** donation_received — {{1}} donor name, {{2}} amount. */
  sendDonationReceived(mobile: string, donorName: string, amount: number): Promise<boolean> {
    return this.sendTemplate(mobile, 'donation_received', [donorName, this.inr(amount)]);
  }

  /** receipt_generated — {{1}} donor name, {{2}} amount, {{3}} receipt link. */
  sendReceiptGenerated(
    mobile: string,
    donorName: string,
    amount: number,
    receiptUrl: string,
  ): Promise<boolean> {
    return this.sendTemplate(mobile, 'receipt_generated', [donorName, this.inr(amount), receiptUrl]);
  }

  /** payment_failed — {{1}} donor name, {{2}} amount, {{3}} retry link. */
  sendPaymentFailed(
    mobile: string,
    donorName: string,
    amount: number,
    retryUrl: string,
  ): Promise<boolean> {
    return this.sendTemplate(mobile, 'payment_failed', [donorName, this.inr(amount), retryUrl]);
  }

  /** birthday_wishes — {{1}} donor name. */
  sendBirthdayWishes(mobile: string, donorName: string): Promise<boolean> {
    return this.sendTemplate(mobile, 'birthday_wishes', [donorName]);
  }

  /** donation_anniversary — {{1}} donor name, {{2}} number of years. */
  sendDonationAnniversary(mobile: string, donorName: string, years: number): Promise<boolean> {
    return this.sendTemplate(mobile, 'donation_anniversary', [donorName, String(years)]);
  }
}
