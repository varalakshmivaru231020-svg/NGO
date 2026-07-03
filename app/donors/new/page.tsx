'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Icon } from '@/components/ui/Icon'
import { api } from '@/lib/api'

const TIERS = ['SILVER', 'GOLD', 'PLATINUM']
const GENDERS = ['MALE', 'FEMALE', 'OTHER']
const CATEGORIES = ['Corporate', 'Individual', 'Recurring', 'Education Sponsor', 'Health']
const STATES = [
  'Andhra Pradesh','Assam','Bihar','Delhi','Goa','Gujarat','Haryana',
  'Karnataka','Kerala','Madhya Pradesh','Maharashtra','Odisha','Punjab',
  'Rajasthan','Tamil Nadu','Telangana','Uttar Pradesh','West Bengal',
]

export default function AddDonorPage() {
  const router = useRouter()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [form, setForm] = useState({
    name: '', mobile: '', whatsapp: '', email: '', gender: 'MALE', dob: '',
    occupation: '', company: '', address: '', city: '', state: '', pincode: '',
    tier: 'SILVER', notes: '', categories: [] as string[],
  })

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }))

  const toggleCat = (cat: string) =>
    setForm(f => ({
      ...f,
      categories: f.categories.includes(cat)
        ? f.categories.filter(c => c !== cat)
        : [...f.categories, cat],
    }))

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    if (!form.name.trim()) { setError('Full name is required'); return }
    if (!form.mobile.trim()) { setError('Mobile number is required'); return }
    setSaving(true)
    try {
      await api.donors.create(form)
      router.push('/donors')
    } catch (err: any) {
      setError(err?.message ?? 'Failed to save donor. Please try again.')
      setSaving(false)
    }
  }

  return (
    <div style={{ maxWidth: 800, margin: '0 auto' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
        <button onClick={() => router.back()}
          style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', color: 'var(--on-surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', width: 36, height: 36, borderRadius: 10 }}>
          <Icon name="chevL" size={20} />
        </button>
        <div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--on-surface)' }}>Add New Donor</h1>
          <p style={{ margin: 0, fontSize: 13, color: 'var(--on-surface-2)' }}>Fill in the details to register a new donor</p>
        </div>
      </div>

      {error && (
        <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)', color: '#dc2626', padding: '12px 16px', borderRadius: 12, marginBottom: 16, fontSize: 14, fontWeight: 600 }}>
          {error}
        </div>
      )}
      <form onSubmit={submit}>
        <Section title="Personal Information">
          <Row>
            <Field label="Full Name *">
              <input value={form.name} onChange={e => set('name', e.target.value)} required placeholder="Rajesh Khanna" style={inp} />
            </Field>
            <Field label="Gender">
              <select value={form.gender} onChange={e => set('gender', e.target.value)} style={inp}>
                {GENDERS.map(g => <option key={g}>{g}</option>)}
              </select>
            </Field>
          </Row>
          <Row>
            <Field label="Date of Birth">
              <input type="date" value={form.dob} onChange={e => set('dob', e.target.value)} style={inp} />
            </Field>
            <Field label="Tier">
              <select value={form.tier} onChange={e => set('tier', e.target.value)} style={inp}>
                {TIERS.map(t => <option key={t}>{t}</option>)}
              </select>
            </Field>
          </Row>
        </Section>

        <Section title="Contact Details">
          <Row>
            <Field label="Mobile *">
              <input value={form.mobile} onChange={e => set('mobile', e.target.value)} required placeholder="+91 98200 12345" style={inp} />
            </Field>
            <Field label="WhatsApp">
              <input value={form.whatsapp} onChange={e => set('whatsapp', e.target.value)} placeholder="+91 98200 12345" style={inp} />
            </Field>
          </Row>
          <Row>
            <Field label="Email">
              <input type="email" value={form.email} onChange={e => set('email', e.target.value)} placeholder="email@example.com" style={inp} />
            </Field>
          </Row>
        </Section>

        <Section title="Professional Info">
          <Row>
            <Field label="Occupation">
              <input value={form.occupation} onChange={e => set('occupation', e.target.value)} placeholder="Business Owner" style={inp} />
            </Field>
            <Field label="Company / Organisation">
              <input value={form.company} onChange={e => set('company', e.target.value)} placeholder="Acme Corp" style={inp} />
            </Field>
          </Row>
        </Section>

        <Section title="Address">
          <Field label="Street Address">
            <textarea value={form.address} onChange={e => set('address', e.target.value)} rows={2}
              placeholder="House / Flat, Street, Area" style={{ ...inp, resize: 'vertical' }} />
          </Field>
          <Row>
            <Field label="City">
              <input value={form.city} onChange={e => set('city', e.target.value)} placeholder="Mumbai" style={inp} />
            </Field>
            <Field label="State">
              <select value={form.state} onChange={e => set('state', e.target.value)} style={inp}>
                <option value="">Select state</option>
                {STATES.map(s => <option key={s}>{s}</option>)}
              </select>
            </Field>
            <Field label="Pincode">
              <input value={form.pincode} onChange={e => set('pincode', e.target.value)} placeholder="400001" maxLength={6} style={inp} />
            </Field>
          </Row>
        </Section>

        <Section title="Donor Categories">
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
            {CATEGORIES.map(cat => {
              const active = form.categories.includes(cat)
              return (
                <button key={cat} type="button" onClick={() => toggleCat(cat)}
                  style={{ padding: '7px 16px', borderRadius: 20, border: `2px solid ${active ? 'var(--primary)' : 'var(--border)'}`, background: active ? 'var(--primary)' : 'transparent', color: active ? '#fff' : 'var(--on-surface)', cursor: 'pointer', fontSize: 13, fontWeight: 600, transition: 'all 0.15s' }}>
                  {cat}
                </button>
              )
            })}
          </div>
        </Section>

        <Section title="Notes">
          <Field label="Internal Notes">
            <textarea value={form.notes} onChange={e => set('notes', e.target.value)} rows={3}
              placeholder="Any notes about this donor..." style={{ ...inp, resize: 'vertical' }} />
          </Field>
        </Section>

        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end', paddingBottom: 32 }}>
          <button type="button" onClick={() => router.back()}
            style={{ padding: '10px 24px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>
            Cancel
          </button>
          <button type="submit" disabled={saving}
            style={{ padding: '10px 28px', borderRadius: 10, border: 'none', background: 'var(--primary)', color: '#fff', cursor: saving ? 'not-allowed' : 'pointer', fontWeight: 700, opacity: saving ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: 8 }}>
            {saving ? 'Saving…' : <><Icon name="check" size={16} color="#fff" /> Save Donor</>}
          </button>
        </div>
      </form>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ background: 'var(--surface)', borderRadius: 16, border: '1px solid var(--border)', padding: '20px 24px', marginBottom: 20 }}>
      <h3 style={{ margin: '0 0 16px', fontSize: 11, fontWeight: 700, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>{title}</h3>
      {children}
    </div>
  )
}

function Row({ children }: { children: React.ReactNode }) {
  return <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginBottom: 16 }}>{children}</div>
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <label style={{ fontSize: 11, fontWeight: 700, color: 'var(--on-surface-2)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
      {children}
    </div>
  )
}

const inp: React.CSSProperties = {
  width: '100%', padding: '9px 12px', borderRadius: 10,
  border: '1.5px solid var(--border)', background: 'var(--surface-2)',
  color: 'var(--on-surface)', fontSize: 14, outline: 'none',
  boxSizing: 'border-box',
}
