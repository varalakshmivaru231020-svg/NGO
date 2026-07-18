'use client'
import { useState } from 'react'
import Link from 'next/link'

const AMOUNTS = [500, 1000, 2500, 5000, 10000, 25000]
const CAUSES = [
  { id: 'education',   label: 'Education Support',  icon: '🎓' },
  { id: 'sponsorship', label: 'Child Sponsorship',  icon: '❤️' },
  { id: 'health',      label: 'Healthcare Camp',    icon: '🏥' },
  { id: 'nutrition',   label: 'Nutrition Drive',    icon: '🥗' },
  { id: 'skill',       label: 'Skill Development',  icon: '💼' },
  { id: 'women',       label: 'Women Empowerment',  icon: '👩' },
  { id: 'general',     label: 'Where Needed Most',  icon: '🌱' },
]

const MODES = ['UPI', 'Credit/Debit Card', 'Net Banking', 'Cheque']

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api/v1'

const IMPACT = [
  { amount: 500,   text: 'feeds a child for a month' },
  { amount: 1000,  text: 'buys textbooks for one child for a year' },
  { amount: 2500,  text: 'funds a health camp for 5 families' },
  { amount: 5000,  text: 'provides uniforms and stationery for 3 children' },
  { amount: 10000, text: 'sponsors one child\'s education for a year' },
  { amount: 25000, text: 'funds a full healthcare camp for a village' },
]

export default function DonatePage() {
  const [amount, setAmount] = useState<number | ''>('')
  const [custom, setCustom] = useState(false)
  const [cause, setCause] = useState('general')
  const [mode, setMode] = useState('UPI')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [pan, setPan] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [gatewayDown, setGatewayDown] = useState(false)
  const [error, setError] = useState('')

  const amt = typeof amount === 'number' ? amount : 0
  const impactMsg = IMPACT.slice().reverse().find(i => amt >= i.amount)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!amt || !name || !email) return
    setError('')
    setGatewayDown(false)
    setSubmitting(true)
    try {
      const res = await fetch(`${API_BASE}/public/donations/initiate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          mobile: phone,
          email,
          pan: pan || undefined,
          cause,
          amount: amt,
        }),
      })

      if (res.status === 503) {
        setGatewayDown(true)
        setSubmitting(false)
        return
      }

      const json = await res.json().catch(() => null)

      if (!res.ok) {
        const msg = json?.message?.message || json?.message || 'Something went wrong. Please try again.'
        setError(typeof msg === 'string' ? msg : 'Something went wrong. Please try again.')
        setSubmitting(false)
        return
      }

      const razorpayShortUrl = json?.data?.razorpayShortUrl
      if (razorpayShortUrl) {
        window.location.href = razorpayShortUrl
        return
      }

      setError('Something went wrong starting your payment. Please try again.')
      setSubmitting(false)
    } catch {
      setError('Network error — please check your connection and try again.')
      setSubmitting(false)
    }
  }

  if (gatewayDown) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)', padding: '100px 24px' }}>
        <div style={{ background: '#fff', borderRadius: 24, border: '1px solid var(--border)', padding: 48, maxWidth: 520, textAlign: 'center', boxShadow: '0 8px 40px rgba(13,31,27,0.08)' }}>
          <div style={{ width: 80, height: 80, borderRadius: '50%', background: '#FFF4E5', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px', fontSize: 36 }}>🙏</div>
          <h2 style={{ fontSize: 24, fontWeight: 800, marginBottom: 12 }}>Online Donations Temporarily Unavailable</h2>
          <p style={{ color: 'var(--muted)', lineHeight: 1.8, marginBottom: 24 }}>
            We're sorry, {name.split(' ')[0] || 'friend'} — online payments are temporarily unavailable. Please contact us directly and our team will help you complete your donation.
          </p>
          <Link href="/" className="btn-primary">← Back to Home</Link>
        </div>
      </div>
    )
  }

  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0D3B32 100%)', padding: '130px 24px 80px', textAlign: 'center' }}>
        <div style={{ maxWidth: 600, margin: '0 auto' }}>
          <div className="section-label" style={{ justifyContent: 'center', background: 'rgba(14,140,118,0.2)', color: '#34C3A6', border: '1px solid rgba(14,140,118,0.4)' }}>Make a Difference</div>
          <h1 style={{ fontSize: 'clamp(28px,4.5vw,50px)', fontWeight: 800, color: '#fff', lineHeight: 1.2, marginTop: 16, marginBottom: 16 }}>Donate to Saksham Foundation</h1>
          <p style={{ fontSize: 16, color: 'rgba(255,255,255,0.75)', lineHeight: 1.8 }}>100% of your donation reaches the cause. 80G tax exemption. Fully transparent.</p>
        </div>
      </section>

      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px,1fr))', gap: 32, alignItems: 'start' }}>

            {/* FORM */}
            <form onSubmit={handleSubmit} style={{ background: '#fff', borderRadius: 24, border: '1px solid var(--border)', padding: '36px', boxShadow: '0 4px 24px rgba(13,31,27,0.06)' }}>
              <h2 style={{ fontSize: 20, fontWeight: 800, marginBottom: 28 }}>Donation Details</h2>

              {/* CAUSE */}
              <div style={{ marginBottom: 24 }}>
                <label style={{ fontSize: 13, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 10 }}>Choose a Cause</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(130px,1fr))', gap: 8 }}>
                  {CAUSES.map(c => (
                    <button key={c.id} type="button" onClick={() => setCause(c.id)}
                      style={{ padding: '10px 12px', borderRadius: 10, border: `2px solid ${cause === c.id ? 'var(--brand)' : 'var(--border)'}`, background: cause === c.id ? 'var(--brand)' : '#fff', color: cause === c.id ? '#fff' : 'var(--text)', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', transition: 'all 0.15s', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 6 }}>
                      {c.icon} {c.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* AMOUNT */}
              <div style={{ marginBottom: 24 }}>
                <label style={{ fontSize: 13, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 10 }}>Donation Amount (₹)</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginBottom: 10 }}>
                  {AMOUNTS.map(a => (
                    <button key={a} type="button" onClick={() => { setAmount(a); setCustom(false) }}
                      style={{ padding: '12px', borderRadius: 10, border: `2px solid ${!custom && amount === a ? 'var(--brand)' : 'var(--border)'}`, background: !custom && amount === a ? 'var(--brand)' : '#fff', color: !custom && amount === a ? '#fff' : 'var(--text)', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}>
                      ₹{a.toLocaleString('en-IN')}
                    </button>
                  ))}
                </div>
                <input type="number" placeholder="Enter custom amount" min={100}
                  value={custom ? (amount || '') : ''}
                  onChange={e => { setCustom(true); setAmount(e.target.value ? Number(e.target.value) : '') }}
                  onFocus={() => setCustom(true)}
                  style={{ width: '100%', padding: '12px 16px', borderRadius: 10, border: `2px solid ${custom ? 'var(--brand)' : 'var(--border)'}`, fontSize: 15, fontWeight: 600, outline: 'none', boxSizing: 'border-box' }} />
                {impactMsg && amt > 0 && (
                  <div style={{ marginTop: 8, padding: '10px 14px', background: '#EAFBF6', borderRadius: 8, fontSize: 13, color: 'var(--brand)', fontWeight: 600 }}>
                    ✨ ₹{amt.toLocaleString('en-IN')} {impactMsg.text}
                  </div>
                )}
              </div>

              {/* PAYMENT MODE */}
              <div style={{ marginBottom: 24 }}>
                <label style={{ fontSize: 13, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 10 }}>Payment Mode</label>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {MODES.map(m => (
                    <button key={m} type="button" onClick={() => setMode(m)}
                      style={{ padding: '9px 16px', borderRadius: 99, border: `2px solid ${mode === m ? 'var(--brand)' : 'var(--border)'}`, background: mode === m ? 'var(--brand)' : '#fff', color: mode === m ? '#fff' : 'var(--text)', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
                      {m}
                    </button>
                  ))}
                </div>
              </div>

              {/* PERSONAL */}
              <div style={{ marginBottom: 24 }}>
                <label style={{ fontSize: 13, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 10 }}>Your Details</label>
                {[
                  { label: 'Full Name *', val: name, set: setName, type: 'text', ph: 'Rajesh Kumar' },
                  { label: 'Email *', val: email, set: setEmail, type: 'email', ph: 'you@example.com' },
                  { label: 'Phone', val: phone, set: setPhone, type: 'tel', ph: '+91 9876543210' },
                  { label: 'PAN (for 80G receipt)', val: pan, set: setPan, type: 'text', ph: 'ABCDE1234F' },
                ].map(f => (
                  <div key={f.label} style={{ marginBottom: 12 }}>
                    <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--muted)', display: 'block', marginBottom: 4 }}>{f.label}</label>
                    <input type={f.type} placeholder={f.ph} value={f.val} onChange={e => f.set(e.target.value)}
                      style={{ width: '100%', padding: '11px 14px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 14, outline: 'none', boxSizing: 'border-box', transition: 'border-color 0.15s' }}
                      onFocus={e => e.currentTarget.style.borderColor = 'var(--brand)'}
                      onBlur={e => e.currentTarget.style.borderColor = 'var(--border)'} />
                  </div>
                ))}
              </div>

              {error && (
                <div style={{ background: '#FDECEC', border: '1px solid #F5B5B5', borderRadius: 10, padding: '12px 16px', marginBottom: 16, fontSize: 13.5, color: '#B42318' }}>
                  ⚠️ {error}
                </div>
              )}

              <button type="submit" className="btn-primary" disabled={submitting} style={{ width: '100%', justifyContent: 'center', fontSize: 16, padding: '16px', opacity: submitting ? 0.7 : 1, cursor: submitting ? 'not-allowed' : 'pointer' }}>
                {submitting ? 'Redirecting to secure payment…' : `❤️ Donate ₹${amt ? amt.toLocaleString('en-IN') : '—'} Now`}
              </button>
              <p style={{ fontSize: 12, color: 'var(--muted)', textAlign: 'center', marginTop: 12, lineHeight: 1.6 }}>
                🔒 Secure payment via Razorpay · 80G receipt after confirmation · No hidden charges
              </p>
            </form>

            {/* SIDEBAR */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              {/* Tax benefit */}
              <div style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
                <div style={{ fontSize: 22, marginBottom: 10 }}>🧾</div>
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Save Tax on Your Donation</h3>
                <p style={{ fontSize: 13.5, color: 'var(--muted)', lineHeight: 1.7, marginBottom: 12 }}>Saksham Foundation is 80G certified. Donations are eligible for 50% deduction under Section 80G of the Income Tax Act.</p>
                <div style={{ background: 'var(--bg)', borderRadius: 10, padding: '12px 16px', fontSize: 13, color: 'var(--text)' }}>
                  <strong>Example:</strong> Donate ₹10,000 → Save ₹1,500 in tax (30% bracket)
                </div>
              </div>

              {/* Impact */}
              <div style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16 }}>What Your Donation Does</h3>
                {IMPACT.map(i => (
                  <div key={i.amount} style={{ display: 'flex', gap: 12, marginBottom: 12, alignItems: 'flex-start' }}>
                    <div style={{ background: 'var(--brand)', color: '#fff', borderRadius: 8, padding: '4px 8px', fontSize: 12, fontWeight: 700, flexShrink: 0, marginTop: 1 }}>₹{i.amount >= 1000 ? `${i.amount/1000}k` : i.amount}</div>
                    <span style={{ fontSize: 13.5, color: 'var(--muted)', lineHeight: 1.5 }}>{i.text}</span>
                  </div>
                ))}
              </div>

              {/* Certifications */}
              <div style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>Certifications</h3>
                {['✅ 80G Tax Exempt · AAATS1234P', '🏛️ Public Charitable Trust Reg. E/4872', '📋 12AA Certified', '⭐ GuideStar India Platinum'].map(c => (
                  <div key={c} style={{ fontSize: 13, color: 'var(--muted)', marginBottom: 8 }}>{c}</div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  )
}
