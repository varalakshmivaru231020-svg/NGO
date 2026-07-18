'use client'
import { useState } from 'react'

const OFFICES = [
  { city: 'Mumbai (HQ)', address: '12, Nariman Point, Mumbai — 400021', phone: '+91 22 4001 2233', email: 'mumbai@sakshamfoundation.org' },
  { city: 'Pune',        address: '45, Hadapsar Industrial Estate, Pune — 411013', phone: '+91 20 2678 9900', email: 'pune@sakshamfoundation.org' },
  { city: 'Chennai',     address: '8, Anna Salai, Teynampet, Chennai — 600018', phone: '+91 44 4356 7890', email: 'chennai@sakshamfoundation.org' },
  { city: 'Bangalore',   address: '22, Koramangala 5th Block, Bangalore — 560095', phone: '+91 80 4567 2200', email: 'bangalore@sakshamfoundation.org' },
]

const FAQS = [
  { q: 'How do I get my 80G tax receipt?', a: 'Your 80G receipt is emailed automatically within 24 hours of a confirmed donation. If you do not receive it, email us at receipts@sakshamfoundation.org with your transaction ID.' },
  { q: 'Can I sponsor a specific child?', a: 'Yes! Visit our Donate page and choose the "Child Sponsorship" cause. You can request a child profile matching specific criteria (age, city, program) by emailing sponsor@sakshamfoundation.org.' },
  { q: 'How is my donation used?', a: 'At least 85% of every donation goes directly to program costs. Administrative and fundraising expenses are capped at 15%. Our annual audited report is published every July on this website.' },
  { q: 'Can my company do CSR with Saksham?', a: 'Absolutely. We accept CSR contributions under Schedule VII of the Companies Act. Write to csr@sakshamfoundation.org with your company details and we will respond within 48 hours.' },
  { q: 'How can I volunteer?', a: 'We welcome weekend educators, medical volunteers, legal helpers, and tech volunteers. Fill out the contact form below with "Volunteer" as your subject and we will be in touch.' },
]

export default function ContactPage() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [subject, setSubject] = useState('')
  const [message, setMessage] = useState('')
  const [sent, setSent] = useState(false)
  const [openFaq, setOpenFaq] = useState<number | null>(null)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!name || !email || !message) return
    setSent(true)
  }

  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0D3B32 100%)', padding: '130px 24px 80px', textAlign: 'center' }}>
        <div style={{ maxWidth: 600, margin: '0 auto' }}>
          <div className="section-label" style={{ justifyContent: 'center', background: 'rgba(14,140,118,0.2)', color: '#34C3A6', border: '1px solid rgba(14,140,118,0.4)' }}>Reach Us</div>
          <h1 style={{ fontSize: 'clamp(28px,4.5vw,50px)', fontWeight: 800, color: '#fff', lineHeight: 1.2, marginTop: 16, marginBottom: 16 }}>We&apos;d Love to Hear from You</h1>
          <p style={{ fontSize: 16, color: 'rgba(255,255,255,0.75)', lineHeight: 1.8 }}>Donor queries, volunteer interest, CSR partnerships, or just a question — reach out and we will respond within 24 hours.</p>
        </div>
      </section>

      {/* CONTACT FORM + INFO */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px,1fr))', gap: 32, alignItems: 'start' }}>

            {/* FORM */}
            <div style={{ background: '#fff', borderRadius: 24, border: '1px solid var(--border)', padding: 36, boxShadow: '0 4px 24px rgba(13,31,27,0.06)' }}>
              {sent ? (
                <div style={{ textAlign: 'center', padding: '40px 0' }}>
                  <div style={{ fontSize: 48, marginBottom: 16 }}>✅</div>
                  <h3 style={{ fontSize: 20, fontWeight: 800, marginBottom: 10 }}>Message Sent!</h3>
                  <p style={{ color: 'var(--muted)', lineHeight: 1.7 }}>Thank you, {name.split(' ')[0]}. We will get back to you at <strong>{email}</strong> within 24 hours.</p>
                  <button onClick={() => { setSent(false); setName(''); setEmail(''); setSubject(''); setMessage('') }}
                    style={{ marginTop: 24, padding: '10px 24px', borderRadius: 99, background: 'var(--brand)', color: '#fff', border: 'none', fontWeight: 700, cursor: 'pointer', fontSize: 14 }}>
                    Send Another
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit}>
                  <h2 style={{ fontSize: 20, fontWeight: 800, marginBottom: 24 }}>Send a Message</h2>
                  {[
                    { label: 'Your Name *', val: name, set: setName, type: 'text', ph: 'Anjali Mehta' },
                    { label: 'Email Address *', val: email, set: setEmail, type: 'email', ph: 'you@example.com' },
                    { label: 'Subject', val: subject, set: setSubject, type: 'text', ph: 'Donation query / Volunteer / CSR' },
                  ].map(f => (
                    <div key={f.label} style={{ marginBottom: 14 }}>
                      <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--muted)', display: 'block', marginBottom: 5 }}>{f.label}</label>
                      <input type={f.type} placeholder={f.ph} value={f.val} onChange={e => f.set(e.target.value)}
                        style={{ width: '100%', padding: '12px 14px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 14, outline: 'none', boxSizing: 'border-box' }}
                        onFocus={e => e.currentTarget.style.borderColor = 'var(--brand)'}
                        onBlur={e => e.currentTarget.style.borderColor = 'var(--border)'} />
                    </div>
                  ))}
                  <div style={{ marginBottom: 20 }}>
                    <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--muted)', display: 'block', marginBottom: 5 }}>Message *</label>
                    <textarea rows={5} placeholder="How can we help you?" value={message} onChange={e => setMessage(e.target.value)}
                      style={{ width: '100%', padding: '12px 14px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 14, outline: 'none', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }}
                      onFocus={e => e.currentTarget.style.borderColor = 'var(--brand)'}
                      onBlur={e => e.currentTarget.style.borderColor = 'var(--border)'} />
                  </div>
                  <button type="submit" className="btn-primary" style={{ width: '100%', justifyContent: 'center' }}>
                    Send Message →
                  </button>
                </form>
              )}
            </div>

            {/* INFO */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              <div style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16 }}>Quick Contacts</h3>
                {[
                  { icon: '📞', label: 'General Enquiries', val: '+91 22 4001 2233', href: 'tel:+912240012233' },
                  { icon: '✉️', label: 'Email Us',          val: 'info@sakshamfoundation.org', href: 'mailto:info@sakshamfoundation.org' },
                  { icon: '💬', label: 'WhatsApp',          val: '+91 98765 43210', href: 'https://wa.me/919876543210?text=Hello%20Saksham%20Foundation' },
                  { icon: '🏢', label: 'Head Office',       val: 'Mumbai, Maharashtra', href: undefined },
                  { icon: '🕐', label: 'Working Hours',     val: 'Mon – Sat, 9 AM – 6 PM', href: undefined },
                ].map(c => (
                  <div key={c.label} style={{ display: 'flex', gap: 14, marginBottom: 14, alignItems: 'flex-start' }}>
                    <div style={{ fontSize: 18, flexShrink: 0, marginTop: 2 }}>{c.icon}</div>
                    <div>
                      <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 2 }}>{c.label}</div>
                      {c.href ? (
                        <a href={c.href} target={c.href.startsWith('http') ? '_blank' : undefined} rel="noreferrer"
                          style={{ fontSize: 14, fontWeight: 600, color: 'var(--brand)' }}>{c.val}</a>
                      ) : (
                        <span style={{ fontSize: 14, color: 'var(--text)' }}>{c.val}</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <div style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>Our Offices</h3>
                {OFFICES.map(o => (
                  <div key={o.city} style={{ marginBottom: 16, paddingBottom: 16, borderBottom: '1px solid var(--border)', lastChild: { border: 'none' } }}>
                    <div style={{ fontWeight: 700, fontSize: 14, color: 'var(--brand)', marginBottom: 4 }}>{o.city}</div>
                    <div style={{ fontSize: 13, color: 'var(--muted)', lineHeight: 1.6 }}>{o.address}</div>
                    <div style={{ fontSize: 13, marginTop: 4 }}>
                      <a href={`tel:${o.phone.replace(/\s/g,'')}`} style={{ color: 'var(--text)' }}>{o.phone}</a>
                      {' · '}
                      <a href={`mailto:${o.email}`} style={{ color: 'var(--brand)' }}>{o.email}</a>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="section" style={{ background: '#fff' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">Common Questions</div>
            <h2 className="section-title">FAQ</h2>
          </div>
          <div style={{ maxWidth: 760, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>
            {FAQS.map((f, i) => (
              <div key={i} style={{ background: 'var(--bg)', borderRadius: 14, border: '1px solid var(--border)', overflow: 'hidden' }}>
                <button onClick={() => setOpenFaq(openFaq === i ? null : i)}
                  style={{ width: '100%', padding: '18px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'none', border: 'none', cursor: 'pointer', fontWeight: 700, fontSize: 15, color: 'var(--text)', textAlign: 'left', gap: 16 }}>
                  {f.q}
                  <span style={{ fontSize: 18, flexShrink: 0, transform: openFaq === i ? 'rotate(45deg)' : 'none', transition: 'transform 0.2s' }}>+</span>
                </button>
                {openFaq === i && (
                  <div style={{ padding: '0 20px 18px', fontSize: 14.5, color: 'var(--muted)', lineHeight: 1.75 }}>{f.a}</div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  )
}
