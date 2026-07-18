import Link from 'next/link'

const PROGRAMS = [
  {
    icon: '🎓', color: '#0E8C76', title: 'Education Support',
    tagline: 'Free learning for every child',
    desc: 'Our flagship program runs 12 after-school learning centres across India. We provide free tuition, textbooks, stationery, uniforms, and access to digital learning tools for children aged 6–16 from families below the poverty line.',
    impact: ['12 learning centres across India', '7,200 children actively enrolled', '94% pass rate in board exams', '210 trained educators on staff'],
    how: 'Children attend evening sessions 5 days a week. Each centre has a library, computer lab, and trained educators.',
  },
  {
    icon: '❤️', color: '#F2685E', title: 'Child Sponsorship',
    tagline: 'One donor, one child, one year',
    desc: 'Our sponsorship program connects a caring donor with a specific child for a full academic year. The sponsor funds that child\'s education, nutrition, health check-ups, and school supplies — and receives quarterly impact reports.',
    impact: ['840 children currently sponsored', '₹12,000 sponsors one child per year', 'Quarterly photo & progress updates', '100% sponsor-child match rate'],
    how: 'Donors choose a child profile, make one payment, and receive personal updates every 3 months until the year ends.',
  },
  {
    icon: '🏥', color: '#2D9CDB', title: 'Healthcare Camps',
    tagline: 'Health is a right, not a privilege',
    desc: 'Monthly free health camps provide basic check-ups, dental care, eye screening, vaccinations, and distribution of medicines. We partner with local hospitals and medical colleges to staff each camp.',
    impact: ['48 camps conducted in 2025', '14,600 beneficiaries screened', '1,240 referrals to hospitals', 'Partnered with 8 medical colleges'],
    how: 'Camps are held in schools, community halls, and our learning centres, rotating across our 14 city locations every month.',
  },
  {
    icon: '🥗', color: '#F6A723', title: 'Nutrition Drive',
    tagline: 'No child learns on an empty stomach',
    desc: 'We provide mid-day meals at every learning centre and distribute monthly ration kits to the most vulnerable families. Our nutrition team monitors each child\'s growth and flags malnourishment for targeted intervention.',
    impact: ['7,200 meals served daily', '1,600 family ration kits monthly', 'Registered dietician monitors growth', '12% drop in malnourishment 2025'],
    how: 'Meals are prepared fresh at each centre. Ration kits contain rice, dal, oil, and fortified flour for a family of four for 30 days.',
  },
  {
    icon: '💼', color: '#7C6CF0', title: 'Skill Development',
    tagline: 'From classroom to career',
    desc: 'Our Skill Development vertical targets youth aged 18–25 who lack formal employment pathways. We run 3-month certificate courses in tailoring & fashion, computer basics & data entry, and small business entrepreneurship.',
    impact: ['480 youth trained in 2025', '72% placed within 3 months', '₹8,500 average monthly income', 'Courses certified by NSDC'],
    how: 'Courses run Monday to Friday, 9 AM–1 PM for 12 weeks. Graduates receive a NSDC-recognised certificate and job placement support.',
  },
  {
    icon: '👩', color: '#EC5B8B', title: 'Women Empowerment',
    tagline: 'Empowering mothers, transforming families',
    desc: 'When a mother is empowered, her entire family benefits. Our women\'s program runs self-help groups (SHGs), digital literacy sessions, micro-finance access, and vocational training for women aged 20–45 in rural and peri-urban areas.',
    impact: ['1,800 women in active SHGs', '320 micro-loans disbursed', '94% loan repayment rate', '3 States: MH, KA, TN'],
    how: 'SHGs meet weekly in community spaces. Field coordinators provide training in savings, loan management, and business basics.',
  },
]

export default function ProgramsPage() {
  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0D3B32 100%)', padding: '130px 24px 80px', textAlign: 'center' }}>
        <div style={{ maxWidth: 680, margin: '0 auto' }}>
          <div className="section-label" style={{ justifyContent: 'center', background: 'rgba(14,140,118,0.2)', color: '#34C3A6', border: '1px solid rgba(14,140,118,0.4)' }}>What We Do</div>
          <h1 style={{ fontSize: 'clamp(30px,5vw,54px)', fontWeight: 800, color: '#fff', lineHeight: 1.15, marginTop: 16, marginBottom: 20 }}>Six Programs.<br />One Goal: Change Lives.</h1>
          <p style={{ fontSize: 17, color: 'rgba(255,255,255,0.75)', lineHeight: 1.8 }}>Every program targets a specific barrier children face — and together they create a complete support system.</p>
        </div>
      </section>

      {/* PROGRAMS */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 48 }}>
            {PROGRAMS.map((p, i) => (
              <div key={p.title} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px,1fr))', gap: 32, alignItems: 'center', direction: i % 2 === 1 ? 'rtl' : 'ltr' }}>
                <div style={{ direction: 'ltr' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
                    <div style={{ width: 64, height: 64, borderRadius: 18, background: p.color + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32 }}>{p.icon}</div>
                    <div>
                      <div style={{ fontSize: 12, fontWeight: 700, color: p.color, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>{p.tagline}</div>
                      <h2 style={{ fontSize: 24, fontWeight: 800, color: 'var(--text)' }}>{p.title}</h2>
                    </div>
                  </div>
                  <p style={{ fontSize: 15, color: 'var(--muted)', lineHeight: 1.8, marginBottom: 20 }}>{p.desc}</p>
                  <div style={{ background: p.color + '10', border: `1px solid ${p.color}30`, borderRadius: 12, padding: '14px 18px', marginBottom: 20 }}>
                    <div style={{ fontSize: 12, fontWeight: 700, color: p.color, textTransform: 'uppercase', marginBottom: 8 }}>How it works</div>
                    <p style={{ fontSize: 13.5, color: 'var(--text)', lineHeight: 1.7 }}>{p.how}</p>
                  </div>
                  <Link href="/donate" className="btn-primary" style={{ background: p.color, boxShadow: `0 4px 20px ${p.color}40` }}>Support This Program</Link>
                </div>
                <div style={{ direction: 'ltr', background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 28 }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 16 }}>2025 Impact</div>
                  {p.impact.map(item => (
                    <div key={item} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 16 }}>
                      <div style={{ width: 22, height: 22, borderRadius: '50%', background: p.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>
                        <svg width="10" height="8" viewBox="0 0 10 8" fill="none"><path d="M1 4L3.5 6.5L9 1" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>
                      </div>
                      <span style={{ fontSize: 14.5, color: 'var(--text)', lineHeight: 1.5 }}>{item}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ background: 'linear-gradient(135deg,#0B6E5D 0%,#14A98C 100%)', padding: '72px 24px', textAlign: 'center' }}>
        <h2 style={{ fontSize: 'clamp(24px,3.5vw,38px)', fontWeight: 800, color: '#fff', marginBottom: 16 }}>Pick a Program to Support</h2>
        <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: 16, marginBottom: 32 }}>100% of your donation goes directly to the program you choose.</p>
        <Link href="/donate" className="btn-white">❤️ Donate Now</Link>
      </section>
    </>
  )
}
