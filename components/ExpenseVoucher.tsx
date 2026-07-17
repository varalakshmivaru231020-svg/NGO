'use client'

export interface VoucherData {
  voucherNo: string
  date: string
  paidTo: string
  purpose: string
  amount: number
  paymentMode: string
  reference?: string
  categoryLabel: string
  preparedBy?: string
  approvedBy?: string
  receivedBy?: string
}

const DARK = '#1F2937'
const GREY = '#6B7280'
const BORDER = '#1F2937'
const ACCENT = '#F97316'
const SERIF = 'Georgia, "Times New Roman", Times, serif'

function fmt(n: number) {
  return n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// Int -> Indian-English words, e.g. 24000 -> "Rupees Twenty Four Thousand Only".
function amountInWords(n: number): string {
  if (n === 0) return 'Rupees Zero Only'
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']
  function words(num: number): string {
    if (num === 0) return ''
    if (num < 20) return `${ones[num]} `
    if (num < 100) return `${tens[Math.floor(num / 10)]} ${words(num % 10)}`
    if (num < 1000) return `${ones[Math.floor(num / 100)]} Hundred ${words(num % 100)}`
    if (num < 100000) return `${words(Math.floor(num / 1000))}Thousand ${words(num % 1000)}`
    if (num < 10000000) return `${words(Math.floor(num / 100000))}Lakh ${words(num % 100000)}`
    return `${words(Math.floor(num / 10000000))}Crore ${words(num % 10000000)}`
  }
  return `Rupees ${words(n).trim()} Only`
}

const MODE_LABEL: Record<string, string> = {
  CASH: 'Cash', UPI: 'UPI', BANK_TRANSFER: 'Bank Transfer', CHEQUE: 'Cheque', CARD: 'Card',
}

export function ExpenseVoucher({ data }: { data: VoucherData }) {
  return (
    <div
      id="voucher-print"
      style={{
        fontFamily: "'Segoe UI', Arial, sans-serif",
        maxWidth: 680,
        margin: '0 auto',
        background: '#fff',
        border: `1.5px solid ${BORDER}`,
        color: DARK,
      }}
    >
      {/* ── Header: PAYMENT VOUCHER title + org details, all centered ── */}
      <div style={{ textAlign: 'center', padding: '18px 24px 14px' }}>
        <div style={{
          display: 'inline-block', fontSize: 15, fontWeight: 700, letterSpacing: 1,
          textTransform: 'uppercase', borderBottom: `2px solid ${DARK}`, paddingBottom: 2,
        }}>
          Payment Voucher
        </div>
        <div style={{ fontFamily: SERIF, fontSize: 22, fontWeight: 700, marginTop: 10, textTransform: 'uppercase' }}>
          Sri Krishnashraya Educational Trust
        </div>
        <div style={{ fontSize: 10.5, color: GREY, marginTop: 6, lineHeight: 1.6, maxWidth: 560, marginLeft: 'auto', marginRight: 'auto' }}>
          No. 50, 2nd cross, Ripco Shanthinikethan layout, near SJES College, Medahalli, Virgo Nagar Post,
          Bangalore – 560049. Mob: 9986064411, 9620794141. Email: aakrishnashraya@gmail.com Website: www.krishnashraya.in
        </div>
      </div>

      <div style={{ borderTop: `1.5px solid ${BORDER}` }} />

      {/* ── Voucher No. / Date ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 24px', fontSize: 12.5 }}>
        <span>Voucher No.: <strong>{data.voucherNo}</strong></span>
        <span>Date: <strong>{data.date}</strong></span>
      </div>

      {/* ── Paid to ── */}
      <div style={{ padding: '0 24px 12px', fontSize: 13 }}>
        Paid to <strong style={{ borderBottom: `1px solid ${DARK}`, paddingBottom: 1 }}>{data.paidTo}</strong>
        <span style={{ color: GREY, fontSize: 11 }}> ({data.categoryLabel})</span>
      </div>

      <div style={{ borderTop: `1.5px solid ${BORDER}` }} />

      {/* ── Being paid towards / Rupees (left) | Amount box (right) ── */}
      <div style={{ display: 'flex' }}>
        <div style={{ flex: 7, padding: '16px 24px', borderRight: `1.5px solid ${BORDER}` }}>
          <div style={{ fontSize: 13 }}>
            <strong>Being paid towards</strong> {data.purpose}
          </div>
          <div style={{ fontSize: 13, marginTop: 28 }}>
            <strong>Rupees</strong> {amountInWords(data.amount)}
          </div>
        </div>
        <div style={{ flex: 3, padding: '16px 12px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: ACCENT }}>₹{fmt(data.amount)}</div>
          <div style={{ fontSize: 8.5, color: GREY, textTransform: 'uppercase', letterSpacing: 0.6, marginTop: 2 }}>Amount</div>
          <div style={{ fontSize: 10.5, color: GREY, marginTop: 10 }}>
            Payment: {MODE_LABEL[data.paymentMode] ?? data.paymentMode}
          </div>
          {data.reference && (
            <div style={{ fontSize: 10.5, color: GREY, marginTop: 2 }}>Ref: {data.reference}</div>
          )}
        </div>
      </div>

      <div style={{ borderTop: `1.5px solid ${BORDER}` }} />

      {/* ── Prepared by / Approved by / Received by ── */}
      <div style={{ display: 'flex', padding: '20px 24px' }}>
        {[
          { label: 'Prepared by', value: data.preparedBy },
          { label: 'Approved by', value: data.approvedBy },
          { label: 'Received by', value: data.receivedBy },
        ].map(row => (
          <div key={row.label} style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 700, minHeight: 18, borderBottom: `1px solid ${DARK}`, paddingBottom: 6, marginBottom: 6 }}>
              {row.value || ' '}
            </div>
            <div style={{ fontSize: 11, color: GREY }}>{row.label}</div>
          </div>
        ))}
      </div>

      <div style={{ color: GREY, padding: '0 24px 16px', fontSize: 9.5, lineHeight: 1.4, textAlign: 'center' }}>
        This is an internal payment voucher. Electronically generated — no signature required unless printed.
      </div>
    </div>
  )
}
