import Link from 'next/link'

const TEAM = [
  { name: 'Priya Sharma',     role: 'Founder & CEO',           initials: 'PS', color: '#0E8C76', bio: '20+ years in social work. Former UNICEF India advisor. IIM Ahmedabad alumnus.' },
  { name: 'Rajesh Nair',      role: 'Director — Programs',     initials: 'RN', color: '#7C6CF0', bio: 'Built Saksham\'s flagship education model. Ex-Teach For India fellow. MBA from XLRI.' },
  { name: 'Anita Kulkarni',   role: 'CFO & Compliance Head',   initials: 'AK', color: '#2D9CDB', bio: 'CA with 18 years in non-profit finance. Ensures 100% transparent fund utilisation.' },
  { name: 'Suresh Menon',     role: 'Head — Donor Relations',  initials: 'SM', color: '#F6A723', bio: 'Grew donor base from 80 to 1,247 in four years. Certified fundraising executive.' },
  { name: 'Deepa Iyer',       role: 'Head — Field Operations', initials: 'DI', color: '#F2685E', bio: 'Manages 14 city centres and 210 field staff. MSW from TISS Mumbai.' },
  { name: 'Kiran Bose',       role: 'Technology & Data Lead',  initials: 'KB', color: '#EC5B8B', bio: 'Built the Saksham impact tracking platform. IIT Delhi grad, former Infosys engineer.' },
]

const MILESTONES = [
  { year: '2012', event: 'Founded in a one-room office in Dharavi, Mumbai with 3 staff and 24 students.' },
  { year: '2014', event: 'Registered as a Public Charitable Trust. Received first major CSR grant of ₹15 lakh.' },
  { year: '2016', event: 'Expanded to 3 cities. Launched Child Sponsorship program. 1,000 students milestone.' },
  { year: '2018', event: 'Received 12AA & 80G certification. Crossed ₹1 Cr annual donations.' },
  { year: '2020', event: 'Pivoted to hybrid learning during COVID. Distributed 8,400 meal kits. Zero dropout.' },
  { year: '2022', event: 'Expanded to 10 cities. Women Empowerment program launched. 7,500 beneficiaries.' },
  { year: '2024', event: 'Launched Skill Development vertical. 14 cities. ₹5 Cr+ annual impact budget.' },
  { year: '2026', event: '12,400+ children served. 1,247 active donors. National NGO Excellence Award.' },
]

const VALUES = [
  { icon: '🔍', title: 'Transparency',   desc: 'Every rupee is accounted for. Annual audited reports, real-time impact dashboards, and quarterly donor statements.' },
  { icon: '❤️', title: 'Child-First',    desc: 'Every decision — from program design to fund allocation — starts and ends with what is best for the child.' },
  { icon: '🌱', title: 'Sustainability', desc: 'We build lasting change, not dependency. Programs include community ownership and local leader training.' },
  { icon: '🤝', title: 'Inclusion',      desc: 'No discrimination by caste, religion, gender, or ability. We actively seek out the most marginalised families.' },
]

export default function AboutPage() {
  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0D3B32 100%)', padding: '130px 24px 80px', textAlign: 'center' }}>
        <div style={{ maxWidth: 700, margin: '0 auto' }}>
          <div className="section-label" style={{ justifyContent: 'center', background: 'rgba(14,140,118,0.2)', color: '#34C3A6', border: '1px solid rgba(14,140,118,0.4)' }}>Our Story</div>
          <h1 style={{ fontSize: 'clamp(32px,5vw,56px)', fontWeight: 800, color: '#fff', lineHeight: 1.15, marginTop: 16, marginBottom: 20 }}>
            14 Years of Changing<br />Children&apos;s Lives
          </h1>
          <p style={{ fontSize: 17, color: 'rgba(255,255,255,0.75)', lineHeight: 1.8 }}>
            What started in a one-room office in Dharavi with 24 students has grown into a pan-India movement touching 12,400+ lives every year.
          </p>
        </div>
      </section>

      {/* MISSION & VISION */}
      <section className="section" style={{ background: '#fff' }}>
        <div className="container">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px,1fr))', gap: 32 }}>
            <div style={{ background: 'var(--bg)', borderRadius: 20, padding: 36 }}>
              <div style={{ fontSize: 40, marginBottom: 16 }}>🎯</div>
              <h2 style={{ fontSize: 22, fontWeight: 800, marginBottom: 12 }}>Our Mission</h2>
              <p style={{ color: 'var(--muted)', lineHeight: 1.8, fontSize: 15 }}>
                To provide quality education, healthcare, and nutrition to underprivileged children across India — empowering them to break the cycle of poverty and build self-sufficient futures.
              </p>
            </div>
            <div style={{ background: 'var(--bg)', borderRadius: 20, padding: 36 }}>
              <div style={{ fontSize: 40, marginBottom: 16 }}>🔭</div>
              <h2 style={{ fontSize: 22, fontWeight: 800, marginBottom: 12 }}>Our Vision</h2>
              <p style={{ color: 'var(--muted)', lineHeight: 1.8, fontSize: 15 }}>
                An India where every child, regardless of economic background, has access to the tools and opportunities they need to thrive — and where no talent goes to waste due to poverty.
              </p>
            </div>
            <div style={{ background: 'var(--bg)', borderRadius: 20, padding: 36 }}>
              <div style={{ fontSize: 40, marginBottom: 16 }}>📋</div>
              <h2 style={{ fontSize: 22, fontWeight: 800, marginBottom: 12 }}>Our Approach</h2>
              <p style={{ color: 'var(--muted)', lineHeight: 1.8, fontSize: 15 }}>
                Holistic child development — not just academics, but nutrition, health, emotional wellbeing, and life skills. We work with families and communities, not just children.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* VALUES */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">What Drives Us</div>
            <h2 className="section-title">Our Core Values</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px,1fr))', gap: 24 }}>
            {VALUES.map(v => (
              <div key={v.title} style={{ background: '#fff', borderRadius: 20, padding: 28, border: '1px solid var(--border)' }}>
                <div style={{ fontSize: 36, marginBottom: 14 }}>{v.icon}</div>
                <h3 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>{v.title}</h3>
                <p style={{ fontSize: 14, color: 'var(--muted)', lineHeight: 1.75 }}>{v.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* TIMELINE */}
      <section className="section" style={{ background: '#fff' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 56 }}>
            <div className="section-label">Since 2012</div>
            <h2 className="section-title">Our Journey</h2>
          </div>
          <div style={{ maxWidth: 720, margin: '0 auto', position: 'relative' }}>
            <div style={{ position: 'absolute', left: 48, top: 0, bottom: 0, width: 2, background: 'var(--border)' }} />
            {MILESTONES.map((m, i) => (
              <div key={m.year} style={{ display: 'flex', gap: 28, marginBottom: 36, position: 'relative' }}>
                <div style={{ width: 96, flexShrink: 0, display: 'flex', alignItems: 'flex-start', justifyContent: 'flex-end', paddingTop: 2 }}>
                  <div style={{ width: 40, height: 40, borderRadius: '50%', background: i % 2 === 0 ? 'var(--brand)' : 'var(--accent)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 12, flexShrink: 0, zIndex: 1, position: 'relative' }}>
                    {m.year.slice(2)}
                  </div>
                </div>
                <div style={{ background: 'var(--bg)', borderRadius: 16, padding: '16px 20px', flex: 1 }}>
                  <div style={{ fontWeight: 800, fontSize: 15, color: 'var(--brand)', marginBottom: 4 }}>{m.year}</div>
                  <p style={{ fontSize: 14, color: 'var(--muted)', lineHeight: 1.7 }}>{m.event}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* TEAM */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">The People Behind It</div>
            <h2 className="section-title">Our Leadership Team</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px,1fr))', gap: 24 }}>
            {TEAM.map(t => (
              <div key={t.name} style={{ background: '#fff', borderRadius: 20, padding: '28px', border: '1px solid var(--border)', display: 'flex', gap: 18, alignItems: 'flex-start' }}>
                <div style={{ width: 56, height: 56, borderRadius: '50%', background: t.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 16, flexShrink: 0 }}>{t.initials}</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 16 }}>{t.name}</div>
                  <div style={{ fontSize: 13, color: t.color, fontWeight: 600, marginBottom: 8 }}>{t.role}</div>
                  <p style={{ fontSize: 13.5, color: 'var(--muted)', lineHeight: 1.65 }}>{t.bio}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ background: 'linear-gradient(135deg,#0B6E5D 0%,#14A98C 100%)', padding: '72px 24px', textAlign: 'center' }}>
        <h2 style={{ fontSize: 'clamp(24px,3.5vw,38px)', fontWeight: 800, color: '#fff', marginBottom: 16 }}>Join Our Mission</h2>
        <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: 16, marginBottom: 32 }}>Be a donor, volunteer, or partner. Every form of support matters.</p>
        <div style={{ display: 'flex', gap: 14, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link href="/donate" className="btn-white">❤️ Donate Now</Link>
          <Link href="/contact" className="btn-outline">Get in Touch →</Link>
        </div>
      </section>
    </>
  )
}
