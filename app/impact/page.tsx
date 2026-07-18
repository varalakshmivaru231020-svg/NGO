import Link from 'next/link'

const NUMBERS = [
  { num: '12,400+', label: 'Children Supported',   icon: '👦', color: '#0E8C76' },
  { num: '1,247',   label: 'Active Donors',         icon: '❤️', color: '#F2685E' },
  { num: '₹5.6 Cr', label: 'Raised in 2025–26',    icon: '💰', color: '#F6A723' },
  { num: '14',      label: 'Cities & Towns',        icon: '🏙️', color: '#2D9CDB' },
  { num: '94%',     label: 'Board Exam Pass Rate',  icon: '🎓', color: '#7C6CF0' },
  { num: '210',     label: 'Full-time Educators',   icon: '👩‍🏫', color: '#EC5B8B' },
  { num: '48',      label: 'Health Camps in 2025',  icon: '🏥', color: '#0E8C76' },
  { num: '1,800',   label: 'Women in SHGs',         icon: '👩', color: '#F6A723' },
]

const STORIES = [
  {
    name: 'Aarav Singh', age: 13, center: 'Dharavi Centre', initials: 'AS', color: '#0E8C76', year: '2024',
    story: 'Aarav came to Saksham at age 9 with no access to books or schooling. Today he is in Class 8 with distinction marks in Maths and Science. He dreams of becoming a civil engineer. His mother, who works as a domestic helper, says Saksham changed the trajectory of her entire family.',
  },
  {
    name: 'Kavya Desai', age: 15, center: 'Hadapsar Centre', initials: 'KD', color: '#7C6CF0', year: '2024',
    story: 'Kavya had dropped out of school due to financial pressure. After joining Saksham\'s centre at 12, she was identified as gifted in visual arts. With Saksham\'s support she won a national-level drawing competition in 2023 and is now on a full scholarship at a fine arts school in Pune.',
  },
  {
    name: 'Rohan Kamble', age: 14, center: 'Dharavi Centre', initials: 'RK', color: '#F6A723', year: '2025',
    story: 'Rohan used to skip school frequently due to a difficult home situation. After our counsellor started working with him and his family, he achieved 100% attendance for two consecutive years. He was honoured by the Maharashtra government as a "Young Achiever" in 2025.',
  },
  {
    name: 'Lata Shinde', age: 34, center: 'Women Empowerment — Nashik', initials: 'LS', color: '#EC5B8B', year: '2025',
    story: 'Lata joined a Saksham self-help group in 2022 with no income of her own. Through micro-finance support and tailoring training, she now runs a small garment business with 3 employees. She has fully repaid her micro-loan and sponsors a child at the Nashik centre.',
  },
  {
    name: 'Anish Patil', age: 22, center: 'Skill Development — Pune', initials: 'AP', color: '#2D9CDB', year: '2025',
    story: 'Anish was a school dropout who spent 4 years unemployed. He enrolled in our IT skills course in 2024, completed it in 3 months, and was placed as a data entry operator at a logistics firm in Pune. His salary has tripled since the placement.',
  },
  {
    name: 'Preethi R.', age: 11, center: 'Chennai Centre', initials: 'PR', color: '#F2685E', year: '2026',
    story: 'Preethi\'s family was flagged as critically malnourished in 2023. Our nutrition team enrolled her in the daily meals program and gave her family monthly ration kits. In 18 months her weight-for-age moved from red to green on the WHO chart. She now tops her class.',
  },
]

const ANNUAL = [
  { year: '2022–23', children: 8400,  raised: 2.8, donors: 620 },
  { year: '2023–24', children: 10200, raised: 4.1, donors: 890 },
  { year: '2024–25', children: 11600, raised: 5.0, donors: 1100 },
  { year: '2025–26', children: 12400, raised: 5.6, donors: 1247 },
]

export default function ImpactPage() {
  return (
    <>
      {/* HERO */}
      <section style={{ background: 'linear-gradient(135deg,#071410 0%,#0D3B32 100%)', padding: '130px 24px 80px', textAlign: 'center' }}>
        <div style={{ maxWidth: 680, margin: '0 auto' }}>
          <div className="section-label" style={{ justifyContent: 'center', background: 'rgba(14,140,118,0.2)', color: '#34C3A6', border: '1px solid rgba(14,140,118,0.4)' }}>Proof of Change</div>
          <h1 style={{ fontSize: 'clamp(30px,5vw,54px)', fontWeight: 800, color: '#fff', lineHeight: 1.15, marginTop: 16, marginBottom: 20 }}>Real Numbers.<br />Real Lives Changed.</h1>
          <p style={{ fontSize: 17, color: 'rgba(255,255,255,0.75)', lineHeight: 1.8 }}>We track every rupee spent and every child supported. Here is what 14 years of work looks like.</p>
        </div>
      </section>

      {/* IMPACT GRID */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div className="section-label">By the Numbers</div>
          <h2 className="section-title" style={{ marginBottom: 40 }}>2025–26 At a Glance</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px,1fr))', gap: 20 }}>
            {NUMBERS.map(n => (
              <div key={n.label} style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: '28px 24px', textAlign: 'center' }}>
                <div style={{ fontSize: 40, marginBottom: 12 }}>{n.icon}</div>
                <div style={{ fontSize: 'clamp(26px,3vw,36px)', fontWeight: 800, color: n.color, lineHeight: 1 }}>{n.num}</div>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--muted)', marginTop: 8, textTransform: 'uppercase', letterSpacing: '0.04em' }}>{n.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* GROWTH TABLE */}
      <section className="section" style={{ background: '#fff' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">Year on Year</div>
            <h2 className="section-title">Our Growth Story</h2>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 15 }}>
              <thead>
                <tr style={{ background: 'var(--bg)' }}>
                  {['Financial Year','Children Supported','Funds Raised','Active Donors'].map(h => (
                    <th key={h} style={{ padding: '14px 20px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.05em', borderBottom: '2px solid var(--border)' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {ANNUAL.map((r, i) => (
                  <tr key={r.year} style={{ borderBottom: '1px solid var(--border)', background: i === ANNUAL.length - 1 ? 'var(--brand-50,#EAFBF6)' : '#fff' }}>
                    <td style={{ padding: '16px 20px', fontWeight: 700, color: i === ANNUAL.length - 1 ? 'var(--brand)' : 'var(--text)' }}>{r.year}{i === ANNUAL.length - 1 ? ' (current)' : ''}</td>
                    <td style={{ padding: '16px 20px', color: 'var(--text)' }}>{r.children.toLocaleString('en-IN')}+</td>
                    <td style={{ padding: '16px 20px', color: 'var(--text)' }}>₹{r.raised} Cr</td>
                    <td style={{ padding: '16px 20px', color: 'var(--text)' }}>{r.donors.toLocaleString('en-IN')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* STORIES */}
      <section className="section" style={{ background: 'var(--bg)' }}>
        <div className="container">
          <div style={{ textAlign: 'center', marginBottom: 48 }}>
            <div className="section-label">Human Impact</div>
            <h2 className="section-title">Stories That Define Us</h2>
            <p className="section-sub" style={{ margin: '14px auto 0' }}>Six of the 12,400 stories we carry with us every day.</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px,1fr))', gap: 24 }}>
            {STORIES.map(s => (
              <div key={s.name} style={{ background: '#fff', borderRadius: 20, border: '1px solid var(--border)', padding: 28 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18 }}>
                  <div style={{ width: 50, height: 50, borderRadius: '50%', background: s.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 16, flexShrink: 0 }}>{s.initials}</div>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 15 }}>{s.name}{s.age ? `, Age ${s.age}` : ''}</div>
                    <div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{s.center} · {s.year}</div>
                  </div>
                </div>
                <p style={{ fontSize: 14, color: 'var(--muted)', lineHeight: 1.75 }}>{s.story}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ background: 'linear-gradient(135deg,#0B6E5D 0%,#14A98C 100%)', padding: '72px 24px', textAlign: 'center' }}>
        <h2 style={{ fontSize: 'clamp(24px,3.5vw,38px)', fontWeight: 800, color: '#fff', marginBottom: 16 }}>Add Your Name to This Story</h2>
        <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: 16, marginBottom: 32 }}>Every donation, big or small, creates a story like these.</p>
        <div style={{ display: 'flex', gap: 14, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link href="/donate" className="btn-white">❤️ Donate Now</Link>
          <Link href="/programs" className="btn-outline">Our Programs →</Link>
        </div>
      </section>
    </>
  )
}
