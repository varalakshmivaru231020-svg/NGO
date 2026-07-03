'use client'
import { useState } from 'react'
import { Icon } from '@/components/ui/Icon'
import { Badge } from '@/components/ui/Badge'

const INITIAL_OFFICES = [
  { id: 'o1', name: 'Mumbai Head Office', city: 'Mumbai', state: 'Maharashtra', address: 'Dharavi, Mumbai, Maharashtra 400017', phone: '+91 22 2619 4400', email: 'mumbai@sakshamfoundation.org', centers: 1, staff: 12, students: 187, raised: 42800000 },
  { id: 'o2', name: 'Pune Regional Office', city: 'Pune', state: 'Maharashtra', address: 'Hadapsar, Pune, Maharashtra 411028', phone: '+91 20 2690 3300', email: 'pune@sakshamfoundation.org', centers: 1, staff: 8, students: 125, raised: 13300000 },
]

function fmt_inr(n: number) {
  if (n >= 10000000) return `₹${(n/10000000).toFixed(1)}Cr`
  if (n >= 100000) return `₹${(n/100000).toFixed(1)}L`
  return `₹${n.toLocaleString('en-IN')}`
}

export default function OfficesPage() {
  const [offices, setOffices] = useState(INITIAL_OFFICES)
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({ name: '', city: '', state: 'Maharashtra', address: '', phone: '', email: '' })

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }))

  const save = () => {
    if (!form.name || !form.city) return
    setOffices(o => [...o, { id: `o${Date.now()}`, ...form, centers: 0, staff: 0, students: 0, raised: 0 }])
    setShowModal(false)
    setForm({ name: '', city: '', state: 'Maharashtra', address: '', phone: '', email: '' })
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Offices & Centres</h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Manage regional offices and learning centres</p>
        </div>
        <button onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white"
          style={{ background: 'var(--primary)' }}>
          <Icon name="plus" size={16} color="#fff" /> Add Office
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {offices.map(o => (
          <div key={o.id} className="rounded-2xl border overflow-hidden" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <div className="px-5 py-4" style={{ background: 'linear-gradient(135deg, #0B6E5D 0%, #14A98C 100%)' }}>
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-bold text-[15px] text-white">{o.name}</h3>
                  <div className="flex items-center gap-1.5 text-[12px] text-white/80 mt-1">
                    <Icon name="mapPin" size={12} color="rgba(255,255,255,0.8)" />
                    {o.address}
                  </div>
                </div>
                <Badge variant="green">Active</Badge>
              </div>
            </div>

            <div className="grid grid-cols-4 border-b" style={{ borderColor: 'var(--border)' }}>
              {[
                { label: 'Centres', value: o.centers, icon: 'home' },
                { label: 'Staff', value: o.staff, icon: 'users' },
                { label: 'Students', value: o.students, icon: 'grad' },
                { label: 'Raised', value: fmt_inr(o.raised), icon: 'wallet' },
              ].map((s, i) => (
                <div key={i} className="p-4 text-center border-r last:border-r-0" style={{ borderColor: 'var(--border)' }}>
                  <div className="text-[17px] font-bold mb-0.5" style={{ color: 'var(--on-surface)' }}>{s.value}</div>
                  <div className="text-[11px]" style={{ color: 'var(--on-surface-2)' }}>{s.label}</div>
                </div>
              ))}
            </div>

            <div className="p-5 space-y-2.5">
              {o.phone && (
                <div className="flex items-center gap-2 text-[12.5px]">
                  <Icon name="phone" size={14} color="var(--on-surface-3)" />
                  <span style={{ color: 'var(--on-surface)' }}>{o.phone}</span>
                </div>
              )}
              {o.email && (
                <div className="flex items-center gap-2 text-[12.5px]">
                  <Icon name="mail" size={14} color="var(--on-surface-3)" />
                  <span style={{ color: 'var(--on-surface)' }}>{o.email}</span>
                </div>
              )}
            </div>

            <div className="px-5 pb-4 flex gap-2">
              <button className="flex items-center gap-1.5 px-3.5 h-8 rounded-lg text-[12.5px] font-bold" style={{ background: 'var(--brand-100)', color: 'var(--brand-700)' }}>
                <Icon name="edit" size={13} color="var(--brand-700)" /> Edit
              </button>
              <button className="flex items-center gap-1.5 px-3.5 h-8 rounded-lg text-[12.5px] font-bold" style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
                <Icon name="users" size={13} color="var(--on-surface-2)" /> Manage Staff
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Add Office Modal */}
      {showModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div style={{ background: 'var(--surface)', borderRadius: 20, width: '100%', maxWidth: 520, padding: 28, boxShadow: 'var(--shadow-lg)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <h2 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: 'var(--on-surface)' }}>Add Office</h2>
              <button onClick={() => setShowModal(false)} style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="x" size={16} color="var(--on-surface-2)" />
              </button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <Fl label="Office Name *">
                <input value={form.name} onChange={e => set('name', e.target.value)} placeholder="Delhi Regional Office" style={inp} />
              </Fl>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Fl label="City *">
                  <input value={form.city} onChange={e => set('city', e.target.value)} placeholder="Delhi" style={inp} />
                </Fl>
                <Fl label="State">
                  <input value={form.state} onChange={e => set('state', e.target.value)} placeholder="Delhi" style={inp} />
                </Fl>
              </div>
              <Fl label="Address">
                <textarea value={form.address} onChange={e => set('address', e.target.value)} rows={2} placeholder="Street, Area, City" style={{ ...inp, resize: 'vertical' }} />
              </Fl>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Fl label="Phone">
                  <input value={form.phone} onChange={e => set('phone', e.target.value)} placeholder="+91 11 4400 0000" style={inp} />
                </Fl>
                <Fl label="Email">
                  <input type="email" value={form.email} onChange={e => set('email', e.target.value)} placeholder="delhi@sakshamfoundation.org" style={inp} />
                </Fl>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button onClick={() => setShowModal(false)} style={{ padding: '9px 20px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>Cancel</button>
              <button onClick={save} style={{ padding: '9px 20px', borderRadius: 10, border: 'none', background: 'var(--primary)', color: '#fff', cursor: 'pointer', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="check" size={15} color="#fff" /> Add Office
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function Fl({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
      <label style={{ fontSize: 11, fontWeight: 700, color: 'var(--on-surface-2)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
      {children}
    </div>
  )
}

const inp: React.CSSProperties = {
  width: '100%', padding: '9px 12px', borderRadius: 10,
  border: '1.5px solid var(--border)', background: 'var(--surface-2)',
  color: 'var(--on-surface)', fontSize: 14, outline: 'none', boxSizing: 'border-box',
}
