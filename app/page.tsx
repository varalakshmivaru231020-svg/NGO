import Link from 'next/link'

const STATS = [
  { num: '12,400+', label: 'Children Educated' },
  { num: '₹5.6 Cr',  label: 'Funds Raised 2026' },
  { num: '1,247',   label: 'Active Donors' },
  { num: '14',      label: 'Cities Covered' },
]

const PROGRAMS = [
  { icon: '🎓', title: 'Education Support',  color: '#0E8C76', desc: 'Free tuition, books, and uniforms for children from low-income families across our 12 learning centres.' },
  { icon: '❤️', title: 'Child Sponsorship',  color: '#F2685E', desc: 'Pair a child with a caring sponsor who funds their education, nutrition, and health for a full year.' },
  { icon: '🏥', title: 'Healthcare Camps',   color: '#2D9CDB', desc: 'Monthly health camps providing free check-ups, medicines, and preventive care in underserved areas.' },
  { icon: '🥗', title: 'Nutrition Drive',    color: '#F6A723', desc: 'Daily mid-day meals and monthly ration kits ensuring no child studies on an empty stomach.' },
  { icon: '💼', title: 'Skill Development',  color: '#7C6CF0', desc: 'Vocational training for youth aged 18–25 — tailoring, IT skills, and entrepreneurship workshops.' },
  { icon: '👩', title: 'Women Empowerment', color: '#EC5B8B', desc: 'Self-help groups, micro-finance support, and digital literacy programs for women in rural communities.' },
]

const STORIES = [
  { name: 'Aarav Singh',  age: 13, center: 'Dharavi Centre',  quote: 'Saksham gave me my first textbooks. Now I want to become an engineer and build things for my village.', initials: 'AS', color: '#0E8C76' },
  { name: 'Kavya Desai',  age: 15, center: 'Hadapsar Centre', quote: 'I won a state-level drawing competition. My teacher at Saksham always believed in me when no one else did.', initials: 'KD', color: '#7C6CF0' },
  { name: 'Rohan Kamble', age: 14, center: 'Dharavi Centre',  quote: 'I have 100% attendance for 2 years. Saksham made school feel safe and exciting for the first time.', initials: 'RK', color: '#F6A723' },
]

const CAUSES = [
  { title: 'Feed a Child for a Month',    amount: 1500,  raised: 87, icon: '🥗', color: '#F6A723' },
  { title: 'Sponsor Education — 1 Year',  amount: 12000, raised: 64, icon: '🎓', color: '#0E8C76' },
  { title: 'Healthcare Camp — 1 Village', amount: 25000, raised: 42, icon: '🏥', color: '#2D9CDB' },
]

export default function HomePage() {
  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0B2A24 60%,#0E8C76 100%)', minHeight: '100vh', display: 'flex', alignItems: 'center', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', width: 500, height: 500, borderRadius: '50%', border: '2px solid rgba(255,255,255,0.08)', top: -200, right: -100 }} />
        <div style={{ position: 'absolute', width: 300, height: 300, borderRadius: '50%', border: '2px solid rgba(255,255,255,0.06)', bottom: 50, left: -80 }} />
        <div style={{ position: 'absolute', width: 180, height: 180, borderRadius: '50%', border: '2px solid rgba(255,255,255,0.1)', top: 120, right: '25%' }} />
        <div className="container" style={{ paddingTop: 100, paddingBottom: 80 }}>
          <div style={{ maxWidth: 700 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(14,140,118,0.2)', border: '1px solid rgba(14,140,118,0.4)', padding: '6px 16px', borderRadius: 99, marginBottom: 24 }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#14A98C', display: 'inline-block' }} />
              <span style={{ fontSize: 12, fontWeight: 700, color: '#34C3A6', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Empowering 12,400+ children</span>
            </div>
            <h1 style={{ fontSize: 'clamp(36px,6vw,68px)', fontWeight: 800, color: '#fff', lineHeight: 1.1, marginBottom: 24 }}>
              Every Child<br />Deserves a<br /><span style={{ color: '#34C3A6' }}>Bright Future</span>
            </h1>
            <p style={{ fontSize: 18, color: 'rgba(255,255,255,0.75)', lineHeight: 1.75, marginBottom: 40, maxWidth: 560 }}>
              Saksham Foundation works across India to provide education, healthcare, and nutrition to underprivileged children — because potential has no postal code.
            </p>
            <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
              <Link href="/donate" className="btn-white">❤️ Donate Now</Link>
              <Link href="/programs" className="btn-outline">Explore Programs →</Link>
            </div>
            <div style={{ marginTop: 48, display: 'flex', gap: 24, flexWrap: 'wrap' }}>
              {['🏛️ Govt. Registered NGO','✅ 80G Tax Exempt','🔒 Secure Donations','⭐ 4.9 GuideStar Rating'].map(b => (
                <div key={b} style={{ fontSize: 12.5, fontWeight: 600, color: 'rgba(255,255,255,0.6)' }}>{b}</div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* STATS */}
      <section style={{ background: 'var(--brand)', padding: '48px 0' }}>
        <div className="container">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px,1fr))' }}>
            {STATS.map((s, i) => (
              <div key={s.label} style={{ textAlign: 'center', padding: '24px 16px', borderRight: i < STATS.length - 1 ? '1px solid rgba(255,255,255,0.2)' : 'none' }}>
                <div style={{ fontSize: 'clamp(28px,4vw,44px)', fontWeight: 800, color: '#fff', lineHeight: 1 }}>{s.num}</div>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'rgba(255,255,255,0.75)', marginTop: 6, textTransform: 'uppercase', letterSpacing: '0.04em' }}>{s.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* PROGRAMS */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ marginBottom: 48 }}>
            <div className="section-label">Our Programs</div>
            <h2 className="section-title">What We Do</h2>
            <p className="section-sub">Six focused programs targeting every dimension of a child&apos;s development — from classroom to clinic.</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px,1fr))', gap: 24 }}>
            {PROGRAMS.map(p => (
              <div key={p.title} style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 28 }}>
                <div style={{ width: 56, height: 56, borderRadius: 16, background: p.color + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28, marginBottom: 18 }}>{p.icon}</div>
                <h3 style={{ fontSize: 17, fontWeight: 700, color: 'var(--text)', marginBottom: 10 }}>{p.title}</h3>
                <p style={{ fontSize: 14, color: 'var(--muted)', lineHeight: 1.7 }}>{p.desc}</p>
                <Link href="/programs" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 18, fontSize: 13.5, fontWeight: 700, color: p.color }}>Learn more →</Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CAUSES */}
      <section className="section" style={{ background: '#fff' }}>
        <div className="container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', flexWrap: 'wrap', gap: 16, marginBottom: 40 }}>
            <div>
              <div className="section-label">Active Causes</div>
              <h2 className="section-title">Fund a Cause Today</h2>
            </div>
            <Link href="/donate" className="btn-primary">See All Causes</Link>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px,1fr))', gap: 24 }}>
            {CAUSES.map(c => (
              <div key={c.title} style={{ background: '#fff', border: '1px solid var(--border)', borderRadius: 20, overflow: 'hidden', boxShadow: '0 2px 12px rgba(13,31,27,0.06)' }}>
                <div style={{ height: 140, background: `linear-gradient(135deg,${c.color}22,${c.color}44)`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 60 }}>{c.icon}</div>
                <div style={{ padding: '20px 24px' }}>
                  <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)', marginBottom: 12 }}>{c.title}</h3>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12.5, fontWeight: 600, marginBottom: 6 }}>
                    <span style={{ color: 'var(--muted)' }}>Goal: ₹{c.amount.toLocaleString('en-IN')}</span>
                    <span style={{ color: c.color }}>{c.raised}% funded</span>
                  </div>
                  <div style={{ height: 8, background: '#F0F4F3', borderRadius: 99, overflow: 'hidden', marginBottom: 16 }}>
                    <div style={{ height: '100%', width: `${c.raised}%`, background: c.color, borderRadius: 99 }} />
                  </div>
                  <Link href="/donate" className="btn-primary" style={{ width: '100%', justifyContent: 'center', boxShadow: 'none', background: c.color }}>Contribute Now</Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* STORIES */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">Real Stories</div>
            <h2 className="section-title">Voices of Change</h2>
            <p className="section-sub" style={{ margin: '14px auto 0' }}>Every child has a story. Here are just three of the thousands we are proud to be part of.</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px,1fr))', gap: 24 }}>
            {STORIES.map(s => (
              <div key={s.name} style={{ background: '#fff', border: '1px solid var(--border)', borderRadius: 20, padding: 28, position: 'relative' }}>
                <div style={{ fontSize: 48, color: s.color, opacity: 0.15, position: 'absolute', top: 20, right: 24, fontFamily: 'serif', lineHeight: 1 }}>&ldquo;</div>
                <p style={{ fontSize: 15, lineHeight: 1.75, color: 'var(--text)', fontStyle: 'italic', marginBottom: 24 }}>&ldquo;{s.quote}&rdquo;</p>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 44, height: 44, borderRadius: '50%', background: s.color, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: 14, flexShrink: 0 }}>{s.initials}</div>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 14 }}>{s.name}, Age {s.age}</div>
                    <div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{s.center}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: 'center', marginTop: 40 }}>
            <Link href="/impact" className="btn-primary">Read More Stories →</Link>
          </div>
        </div>
      </section>

      {/* CTA BANNER */}
      <section style={{ background: 'linear-gradient(135deg,#0B6E5D 0%,#14A98C 100%)', padding: '80px 24px', textAlign: 'center' }}>
        <div style={{ maxWidth: 640, margin: '0 auto' }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: 'rgba(255,255,255,0.65)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 16 }}>Make a Difference</div>
          <h2 style={{ fontSize: 'clamp(28px,4vw,44px)', fontWeight: 800, color: '#fff', lineHeight: 1.2, marginBottom: 18 }}>₹500 can feed a child<br />for an entire month</h2>
          <p style={{ fontSize: 16, color: 'rgba(255,255,255,0.8)', marginBottom: 36, lineHeight: 1.7 }}>Your donation is 80G tax-exempt. Every rupee is tracked and reported. We believe in full transparency.</p>
          <div style={{ display: 'flex', gap: 14, justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href="/donate" className="btn-white">❤️ Donate Now</Link>
            <Link href="/about" className="btn-outline">Our Transparency →</Link>
          </div>
        </div>
      </section>
    </>
  )
}
