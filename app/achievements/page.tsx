'use client'
import { useState } from 'react'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'

const CAT_CONFIG: Record<string, { label: string; icon: string; color: string; bg: string; variant: 'green'|'violet'|'amber'|'sky'|'coral' }> = {
  ACADEMIC:  { label: 'Academic',  icon: 'grad',    color: '#7C6CF0', bg: 'var(--violet-100)', variant: 'violet' },
  SPORTS:    { label: 'Sports',    icon: 'star',    color: '#F6A723', bg: 'var(--amber-100)',  variant: 'amber' },
  CULTURAL:  { label: 'Cultural',  icon: 'heart',   color: '#F2685E', bg: 'var(--coral-100)',  variant: 'coral' },
  COMMUNITY: { label: 'Community', icon: 'users',   color: '#0E8C76', bg: 'var(--brand-100)', variant: 'green' },
}

const STUDENTS_LIST = ['Aarav Singh', 'Diya Patil', 'Rohan Kamble', 'Kavya Desai', 'Aryan Chavan', 'Sneha More']

const INITIAL = [
  { id: 'a1', student: 'Aarav Singh', studentId: 'DHR0001', center: 'Dharavi Centre', title: 'District Science Olympiad — 1st Place', category: 'ACADEMIC', date: '2026-03-15', description: 'Won district-level Science Olympiad representing the centre.' },
  { id: 'a2', student: 'Kavya Desai', studentId: 'HDP0001', center: 'Hadapsar Centre', title: 'State-Level Drawing Competition — Runner Up', category: 'CULTURAL', date: '2026-04-22', description: 'Awarded runner up at Maharashtra state drawing competition.' },
  { id: 'a3', student: 'Rohan Kamble', studentId: 'DHR0003', center: 'Dharavi Centre', title: '100% Attendance — Academic Year 2025-26', category: 'SPORTS', date: '2026-05-30', description: 'Perfect attendance record for the full academic year.' },
  { id: 'a4', student: 'Diya Patil', studentId: 'DHR0002', center: 'Dharavi Centre', title: 'City Spell Bee — 2nd Place', category: 'ACADEMIC', date: '2026-02-10', description: 'Secured 2nd place in city-level Spell Bee contest.' },
  { id: 'a5', student: 'Aryan Chavan', studentId: 'HDP0002', center: 'Hadapsar Centre', title: 'Kho-Kho District Championship', category: 'SPORTS', date: '2026-01-18', description: 'Part of the winning team in district Kho-Kho championship.' },
]

function fmt_date(d: string) {
  return new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
}

export default function AchievementsPage() {
  const [filter, setFilter] = useState('All')
  const [list, setList] = useState(INITIAL)
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({ student: 'Aarav Singh', title: '', category: 'ACADEMIC', date: new Date().toISOString().split('T')[0], description: '' })
  const cats = ['All', 'ACADEMIC', 'SPORTS', 'CULTURAL', 'COMMUNITY']

  const filtered = list.filter(a => filter === 'All' || a.category === filter)

  const save = () => {
    if (!form.title) return
    const newItem = { id: `a${Date.now()}`, student: form.student, studentId: 'NEW', center: 'Dharavi Centre', title: form.title, category: form.category, date: form.date, description: form.description }
    setList(l => [newItem, ...l])
    setShowModal(false)
    setForm({ student: 'Aarav Singh', title: '', category: 'ACADEMIC', date: new Date().toISOString().split('T')[0], description: '' })
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Student Achievements</h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Celebrating the success of our children</p>
        </div>
        <button onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white"
          style={{ background: '#7C6CF0' }}>
          <Icon name="plus" size={16} color="#fff" /> Log Achievement
        </button>
      </div>

      <div className="flex gap-2 flex-wrap">
        {cats.map(c => {
          const cfg = CAT_CONFIG[c]
          const active = filter === c
          return (
            <button key={c} onClick={() => setFilter(c)}
              className="flex items-center gap-1.5 px-3.5 h-9 rounded-xl text-[12.5px] font-bold transition-all"
              style={{ background: active ? (cfg?.color ?? 'var(--primary)') : 'var(--surface)', color: active ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
              {cfg && <Icon name={cfg.icon} size={13} color={active ? '#fff' : cfg.color} />}
              {cfg?.label ?? 'All'}
            </button>
          )
        })}
      </div>

      <div className="space-y-3">
        {filtered.map(a => {
          const cfg = CAT_CONFIG[a.category]
          return (
            <div key={a.id} className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
              <div className="flex items-start gap-4">
                <div className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: cfg.bg }}>
                  <Icon name={cfg.icon} size={20} color={cfg.color} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <div className="font-bold text-[14.5px]" style={{ color: 'var(--on-surface)' }}>{a.title}</div>
                      <div className="text-[12.5px] mt-0.5" style={{ color: 'var(--on-surface-2)' }}>{a.description}</div>
                    </div>
                    <Badge variant={cfg.variant}>{cfg.label}</Badge>
                  </div>
                  <div className="flex items-center gap-4 mt-3">
                    <div className="flex items-center gap-2">
                      <Avatar name={a.student} size={22} />
                      <span className="text-[12.5px] font-semibold" style={{ color: 'var(--on-surface)' }}>{a.student}</span>
                      <span className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>({a.studentId})</span>
                    </div>
                    <span className="text-[11.5px]" style={{ color: 'var(--on-surface-3)' }}>·</span>
                    <span className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{a.center}</span>
                    <span className="text-[11.5px]" style={{ color: 'var(--on-surface-3)' }}>·</span>
                    <span className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{fmt_date(a.date)}</span>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
        {filtered.length === 0 && (
          <div className="rounded-2xl border p-10 text-center" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <p style={{ color: 'var(--on-surface-2)', fontSize: 14 }}>No achievements in this category yet.</p>
          </div>
        )}
      </div>

      {/* Log Achievement Modal */}
      {showModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div style={{ background: 'var(--surface)', borderRadius: 20, width: '100%', maxWidth: 520, padding: 28, boxShadow: 'var(--shadow-lg)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <h2 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: 'var(--on-surface)' }}>Log Achievement</h2>
              <button onClick={() => setShowModal(false)} style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="x" size={16} color="var(--on-surface-2)" />
              </button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <Fl label="Student">
                <select value={form.student} onChange={e => setForm(f => ({ ...f, student: e.target.value }))} style={inp}>
                  {STUDENTS_LIST.map(s => <option key={s}>{s}</option>)}
                </select>
              </Fl>
              <Fl label="Achievement Title *">
                <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="e.g. 1st Place — District Science Olympiad" style={inp} />
              </Fl>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Fl label="Category">
                  <select value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))} style={inp}>
                    {['ACADEMIC','SPORTS','CULTURAL','COMMUNITY'].map(c => <option key={c}>{c}</option>)}
                  </select>
                </Fl>
                <Fl label="Date">
                  <input type="date" value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} style={inp} />
                </Fl>
              </div>
              <Fl label="Description">
                <textarea value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} rows={3} placeholder="Brief description..." style={{ ...inp, resize: 'vertical' }} />
              </Fl>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button onClick={() => setShowModal(false)} style={{ padding: '9px 20px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>Cancel</button>
              <button onClick={save} style={{ padding: '9px 20px', borderRadius: 10, border: 'none', background: '#7C6CF0', color: '#fff', cursor: 'pointer', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="check" size={15} color="#fff" /> Save Achievement
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
