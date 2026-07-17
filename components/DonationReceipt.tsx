'use client'

import { Logo } from '@/components/ui/Logo'

export interface ReceiptData {
  receiptNo: string
  date: string
  mode: string
  gatewayRef?: string
  donor: {
    name: string
    phone: string
    city: string
    pan?: string
  }
  items: {
    product: string
    description: string
    qty: number
    cost: number
  }[]
  amountInWords: string
  trustPan?: string
  reg12AA?: string
  cert80G?: string
  supportEmail?: string
}

const ORANGE = '#F97316'
const ORANGE_LT = '#FFF1E7'
const DARK = '#1F2937'
const GREY = '#6B7280'
const BORDER = '#E5E7EB'
const BG_LIGHT = '#F8FAFC'

function fmt(n: number) {
  return n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

export function DonationReceipt({ data }: { data: ReceiptData }) {
  const subtotal = data.items.reduce((s, i) => s + i.cost * i.qty, 0)

  return (
    <div
      id="receipt-print"
      style={{
        fontFamily: "'Segoe UI', Arial, sans-serif",
        maxWidth: 620,
        margin: '0 auto',
        background: '#fff',
        border: `1px solid ${BORDER}`,
        borderRadius: 8,
        padding: '20px 22px',
        color: DARK,
      }}
    >
      {/* ── Header: logo + org (left) | receipt no / date / mode (right) ── */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{
          width: 40, height: 40, borderRadius: 6, background: ORANGE_LT,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <Logo size={26} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 15, fontWeight: 800, color: DARK, letterSpacing: '-0.2px' }}>
            Saksham Foundation
          </div>
          <div style={{ fontSize: 10.5, color: GREY, marginTop: 1 }}>
            Sri Saksham Educational & Welfare Trust
          </div>
          <div style={{ fontSize: 9.5, color: GREY, marginTop: 2, lineHeight: 1.4 }}>
            Dharavi Community Centre, Dr. Ambedkar Road, Dharavi, Mumbai – 400 017, Maharashtra
          </div>
        </div>
        <div style={{ textAlign: 'right', flexShrink: 0 }}>
          <div style={{ fontSize: 11, fontWeight: 800, color: ORANGE }}>
            Receipt No: {data.receiptNo}
          </div>
          <div style={{ fontSize: 10, color: GREY, marginTop: 3 }}>Date: {data.date}</div>
          <div style={{ fontSize: 10, color: GREY }}>Mode: {data.mode}</div>
          {data.gatewayRef && (
            <div style={{ fontSize: 10, color: GREY }}>Ref: {data.gatewayRef}</div>
          )}
        </div>
      </div>

      <div style={{ borderTop: `1px solid ${BORDER}`, margin: '14px 0' }} />

      {/* ── Donor Details | Donation Details ── */}
      <div style={{ display: 'flex', gap: 16 }}>
        <div style={{ flex: 4, minWidth: 0 }}>
          <div style={{ fontSize: 9.5, fontWeight: 800, color: ORANGE, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 5 }}>
            Donor Details
          </div>
          <div style={{ fontSize: 14, fontWeight: 800, color: DARK }}>{data.donor.name}</div>
          <div style={{ fontSize: 11, color: GREY, marginTop: 3 }}>Mobile: {data.donor.phone}</div>
          <div style={{ fontSize: 11, color: GREY, marginTop: 1 }}>{data.donor.city}</div>
          {data.donor.pan && (
            <div style={{ fontSize: 11, fontWeight: 700, color: ORANGE, marginTop: 4 }}>
              PAN: {data.donor.pan}
            </div>
          )}
        </div>
        <div style={{ width: 1, background: BORDER, flexShrink: 0 }} />
        <div style={{ flex: 5, minWidth: 0 }}>
          <div style={{ fontSize: 9.5, fontWeight: 800, color: ORANGE, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 5 }}>
            Donation Details
          </div>
          {data.items.map((item, idx) => (
            <div key={idx} style={{ marginBottom: idx < data.items.length - 1 ? 10 : 0 }}>
              <div style={{ fontSize: 14, fontWeight: 800, color: DARK }}>{item.product}</div>
              <div style={{ fontSize: 11, color: GREY, marginTop: 2 }}>
                Amount: ₹{fmt(item.cost)}   ·   Qty: {item.qty}
              </div>
              <div style={{ fontSize: 10, color: GREY, marginTop: 4, lineHeight: 1.4 }}>
                {item.description}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ borderTop: `1px solid ${BORDER}`, margin: '14px 0' }} />

      {/* ── Amount in words (left) | Subtotal / Tax / Total (right) ── */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
        <div style={{
          flex: 1, background: ORANGE_LT, borderRadius: 6, padding: '10px 12px',
        }}>
          <div style={{ fontSize: 8.5, fontWeight: 800, color: ORANGE, letterSpacing: 0.6, textTransform: 'uppercase' }}>
            Amount in Words
          </div>
          <div style={{ fontSize: 12.5, fontWeight: 700, color: DARK, marginTop: 3 }}>
            {data.amountInWords}
          </div>
        </div>
        <div style={{
          minWidth: 180, border: `1px solid ${BORDER}`, borderRadius: 6, padding: '10px 14px', flexShrink: 0,
        }}>
          {[
            { label: 'Subtotal', value: `₹${fmt(subtotal)}` },
            { label: 'Tax (0%)', value: '₹0.00' },
          ].map(row => (
            <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: GREY, padding: '2px 0' }}>
              <span>{row.label}</span>
              <span>{row.value}</span>
            </div>
          ))}
          <div style={{ borderTop: `1px solid ${BORDER}`, margin: '5px 0' }} />
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, fontWeight: 800, color: ORANGE }}>
            <span>Grand Total</span>
            <span>₹{fmt(subtotal)}</span>
          </div>
        </div>
      </div>

      <div style={{ height: 14 }} />

      {/* ── Statutory footer bar ── */}
      <div style={{
        background: BG_LIGHT,
        border: `1px solid ${BORDER}`,
        borderRadius: 6,
        padding: '10px 12px',
      }}>
        <div style={{ fontSize: 9.5, fontWeight: 800, color: DARK }}>
          {data.trustPan && <span>PAN: {data.trustPan}</span>}
          {data.reg12AA && <span>&nbsp;&nbsp;|&nbsp;&nbsp;12AB: {data.reg12AA}</span>}
          {data.cert80G && <span>&nbsp;&nbsp;|&nbsp;&nbsp;80G: {data.cert80G}</span>}
        </div>
        <div style={{ color: GREY, marginTop: 5, fontSize: 8.5, lineHeight: 1.4 }}>
          Electronically generated receipt — no signature required. Thanks for your support!
          {data.supportEmail && ` For verification or support, write to ${data.supportEmail}.`}
        </div>
      </div>
    </div>
  )
}
