'use client'
import Link from 'next/link'

export function Footer() {
  return (
    <footer style={{ background: '#071410', color: 'rgba(255,255,255,0.75)', padding: '64px 0 32px' }}>
      <div className="container">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 40, marginBottom: 48 }}>
          {/* Brand */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: 'var(--brand)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M12 2L3 7v5c0 5.25 3.75 10.15 9 11.35C17.25 22.15 21 17.25 21 12V7L12 2z" fill="white"/><path d="M9 12l2 2 4-4" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
              <div>
                <div style={{ fontSize: 16, fontWeight: 800, color: '#fff' }}>Saksham Foundation</div>
                <div style={{ fontSize: 10, color: 'var(--brand-l)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>Empowering Lives</div>
              </div>
            </div>
            <p style={{ fontSize: 13.5, lineHeight: 1.7, maxWidth: 260 }}>
              Educating, empowering, and uplifting underprivileged children and communities across India since 2012.
            </p>
            <div style={{ marginTop: 20, display: 'flex', gap: 10 }}>
              {['Facebook','Twitter','Instagram','LinkedIn'].map(s => (
                <div key={s} style={{ width: 34, height: 34, borderRadius: 8, background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700, cursor: 'pointer' }}>
                  {s[0]}
                </div>
              ))}
            </div>
          </div>

          {/* Quick links */}
          <div>
            <h4 style={{ color: '#fff', fontSize: 14, fontWeight: 700, marginBottom: 16, textTransform: 'uppercase', letterSpacing: '0.06em' }}>Quick Links</h4>
            {[['/', 'Home'],['/about','About Us'],['/programs','Programs'],['/impact','Our Impact'],['/contact','Contact']].map(([href, label]) => (
              <Link key={href} href={href} style={{ display: 'block', fontSize: 13.5, marginBottom: 10, transition: 'color 0.15s' }}
                onMouseEnter={e => { (e.target as HTMLElement).style.color = 'var(--brand-l)' }}
                onMouseLeave={e => { (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.75)' }}>
                {label}
              </Link>
            ))}
          </div>

          {/* Programs */}
          <div>
            <h4 style={{ color: '#fff', fontSize: 14, fontWeight: 700, marginBottom: 16, textTransform: 'uppercase', letterSpacing: '0.06em' }}>Programs</h4>
            {['Education Support','Child Sponsorship','Healthcare Camp','Nutrition Drive','Skill Development','Women Empowerment'].map(p => (
              <Link key={p} href="/programs" style={{ display: 'block', fontSize: 13.5, marginBottom: 10 }}>{p}</Link>
            ))}
          </div>

          {/* Contact */}
          <div>
            <h4 style={{ color: '#fff', fontSize: 14, fontWeight: 700, marginBottom: 16, textTransform: 'uppercase', letterSpacing: '0.06em' }}>Contact</h4>
            {[
              { icon: '📍', text: '12, Nariman Point, Mumbai — 400021' },
              { icon: '📞', text: '+91 22 4001 2233' },
              { icon: '✉️', text: 'info@sakshamfoundation.org' },
              { icon: '🕐', text: 'Mon – Sat: 9 AM – 6 PM' },
            ].map(c => (
              <div key={c.text} style={{ display: 'flex', gap: 10, marginBottom: 12, fontSize: 13.5 }}>
                <span>{c.icon}</span>
                <span>{c.text}</span>
              </div>
            ))}
            <div style={{ marginTop: 20, padding: '12px 16px', background: 'rgba(14,140,118,0.15)', borderRadius: 10, border: '1px solid rgba(14,140,118,0.3)' }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--brand-l)', marginBottom: 4 }}>80G TAX EXEMPT</div>
              <div style={{ fontSize: 12 }}>Trust Reg. No. E/4872/Mumbai<br />PAN: AAATS1234P · 12AA Certified</div>
            </div>
          </div>
        </div>

        <div style={{ borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: 28, display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', gap: 12, fontSize: 12 }}>
          <span>© 2026 Saksham Foundation. All rights reserved.</span>
          <div style={{ display: 'flex', gap: 20 }}>
            <Link href="/privacy">Privacy Policy</Link>
            <Link href="/terms">Terms of Use</Link>
            <Link href="/donate" style={{ color: 'var(--brand-l)', fontWeight: 700 }}>Donate Now →</Link>
          </div>
        </div>
      </div>
    </footer>
  )
}
