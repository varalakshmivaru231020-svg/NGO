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
        maxWidth: 800,
        margin: '0 auto',
        background: '#fff',
        border: '1px solid #e0e0e0',
        borderRadius: 4,
        overflow: 'hidden',
      }}
    >
      {/* ── Header ── */}
      <div style={{ padding: '24px 32px 16px', display: 'flex', alignItems: 'center', gap: 18 }}>
        {/* Logo placeholder — matches SKET logo position */}
        <div style={{
          width: 80, height: 80, borderRadius: 8, background: '#f0faf7',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <Logo size={56} />
        </div>
        <div>
          <div style={{ fontSize: 22, fontWeight: 800, color: '#0B6E5D', letterSpacing: '-0.3px' }}>
            Saksham Foundation
          </div>
          <div style={{ fontSize: 11, color: '#5A7068', marginTop: 2 }}>
            Sri Saksham Educational & Welfare Trust
          </div>
        </div>
      </div>

      {/* ── Address banner (orange→teal) ── */}
      <div style={{
        background: '#0E8C76',
        color: '#fff',
        fontSize: 11.5,
        padding: '8px 32px',
        fontWeight: 500,
      }}>
        Dharavi Community Centre, Dr. Ambedkar Road, Dharavi, Mumbai – 400 017, Maharashtra, India
      </div>

      {/* ── Recipient + Receipt box ── */}
      <div style={{ padding: '28px 32px', display: 'flex', justifyContent: 'space-between', gap: 32 }}>
        {/* Left: Recipient */}
        <div>
          <div style={{ fontSize: 10.5, fontWeight: 700, color: '#555', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 8 }}>
            Recipient:
          </div>
          <div style={{ fontSize: 20, fontWeight: 300, color: '#1A2A24', marginBottom: 4 }}>
            {data.donor.name}
          </div>
          <div style={{ fontSize: 13, color: '#444', marginBottom: 2 }}>{data.donor.phone}</div>
          <div style={{ fontSize: 13, color: '#444', marginBottom: 8 }}>{data.donor.city}</div>
          {data.donor.pan && (
            <div style={{ fontSize: 12.5, fontWeight: 700, color: '#0E8C76' }}>
              PAN: {data.donor.pan}
            </div>
          )}
        </div>

        {/* Right: Receipt number panel — matches SKET orange box → teal */}
        <div style={{
          background: '#0E8C76',
          color: '#fff',
          borderRadius: 4,
          padding: '16px 24px',
          minWidth: 240,
          flexShrink: 0,
        }}>
          <div style={{ fontSize: 18, fontWeight: 800, marginBottom: 14 }}>
            Receipt for #{data.receiptNo}
          </div>
          <div style={{ fontSize: 12.5, marginBottom: 4 }}>
            Transaction Date: {data.date}
          </div>
          <div style={{ fontSize: 12.5, marginBottom: 4 }}>
            Mode: {data.mode}
          </div>
          {data.gatewayRef && (
            <div style={{ fontSize: 12.5 }}>
              Gateway Ref: <strong>{data.gatewayRef}</strong>
            </div>
          )}
        </div>
      </div>

      {/* ── Line items table ── */}
      <div style={{ padding: '0 32px' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr style={{ background: '#0E8C76', color: '#fff' }}>
              {['Product / Service', 'Description', 'Qty.', 'Cost', 'Total'].map((h, i) => (
                <th key={h} style={{
                  padding: '10px 12px',
                  textAlign: i < 2 ? 'left' : 'center',
                  fontWeight: 700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  textTransform: 'uppercase',
                }}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.items.map((item, idx) => (
              <tr key={idx} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '14px 12px', fontWeight: 700, verticalAlign: 'top', color: '#1A2A24' }}>
                  {item.product}
                </td>
                <td style={{ padding: '14px 12px', color: '#555', lineHeight: 1.5, verticalAlign: 'top' }}>
                  {item.description}
                </td>
                <td style={{ padding: '14px 12px', textAlign: 'center', color: '#333' }}>{item.qty}</td>
                <td style={{ padding: '14px 12px', textAlign: 'center', color: '#333' }}>
                  {fmt(item.cost)}
                </td>
                <td style={{ padding: '14px 12px', textAlign: 'center', fontWeight: 700, color: '#1A2A24' }}>
                  ₹{fmt(item.cost * item.qty)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* ── Receipt for Payment summary ── */}
      <div style={{ padding: '28px 32px' }}>
        <div style={{ textAlign: 'center', fontSize: 15, fontWeight: 700, color: '#1A2A24', marginBottom: 20 }}>
          Receipt for Payment
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          {/* Amount in words */}
          <div>
            <div style={{ fontSize: 10.5, fontWeight: 700, color: '#555', textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 4 }}>
              Receipt for Payment (Amount in Words)
            </div>
            <div style={{ fontSize: 13.5, fontStyle: 'italic', color: '#2C5F4A', fontWeight: 600 }}>
              {data.amountInWords}
            </div>
          </div>

          {/* Subtotal / Tax / Total */}
          <div style={{ minWidth: 220 }}>
            {[
              { label: 'Subtotal', value: `₹${fmt(subtotal)}` },
              { label: 'Tax (0%)', value: '₹0.00' },
            ].map(r => (
              <div key={r.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', borderBottom: '1px solid #eee', fontSize: 13 }}>
                <span style={{ color: '#555' }}>{r.label}</span>
                <span style={{ color: '#333' }}>{r.value}</span>
              </div>
            ))}
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', fontSize: 15 }}>
              <span style={{ fontWeight: 700, color: '#1A2A24' }}>Total</span>
              <span style={{ fontWeight: 800, color: '#1A2A24' }}>₹{fmt(subtotal)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Dashed divider ── */}
      <div style={{ borderTop: '2px dashed #d0e8e1', margin: '0 32px' }} />

      {/* ── Thank you ── */}
      <div style={{ textAlign: 'center', padding: '20px 32px', fontSize: 16, fontWeight: 800, fontStyle: 'italic', color: '#0B6E5D' }}>
        Thanks for your support!
      </div>

      {/* ── Dashed divider ── */}
      <div style={{ borderTop: '2px dashed #d0e8e1', margin: '0 32px' }} />

      {/* ── Statutory registration details ── */}
      <div style={{
        margin: '20px 32px 28px',
        padding: '14px 16px',
        borderLeft: '4px solid #0E8C76',
        background: '#f5faf8',
        borderRadius: '0 4px 4px 0',
        fontSize: 11.5,
      }}>
        <div style={{ fontWeight: 700, color: '#0B6E5D', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.5 }}>
          Statutory Registration Details (Tax Benefits)
        </div>
        <div style={{ color: '#333', lineHeight: 1.7 }}>
          {data.trustPan && <span>• <strong>Trust PAN:</strong> {data.trustPan} &nbsp;|&nbsp; </span>}
          {data.reg12AA && <span>• <strong>12AA Registration:</strong> {data.reg12AA} &nbsp;|&nbsp; </span>}
          {data.cert80G && <span>• <strong>80G Certification:</strong> {data.cert80G}</span>}
        </div>
        <div style={{ color: '#777', marginTop: 8, fontSize: 11 }}>
          This is an electronically generated receipt confirmation. No physical signature is required.
          {data.supportEmail && ` For verification or support, write to ${data.supportEmail}.`}
        </div>
      </div>
    </div>
  )
}
