'use client'
import { useState, useEffect } from 'react'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { api } from '@/lib/api'

type Reminder = { id: string; type: string; donorName: string; message: string; dueDate: string; status: 'PENDING'|'COMPLETED'; priority: string }

const TYPE_CONFIG: Record<string, { icon: string; label: string; color: string; bg: string }> = {
  BIRTHDAY:  { icon: 'heart',   label: 'Birthday',  color: '#F2685E', bg: 'var(--coral-100)' },
  FOLLOW_UP: { icon: 'phone',   label: 'Follow Up', color: '#0E8C76', bg: 'var(--brand-100)' },
  RENEWAL:   { icon: 'refresh', label: 'Renewal',   color: '#7C6CF0', bg: 'var(--violet-100)' },
  CUSTOM:    { icon: 'bell',    label: 'Custom',    color: '#F6A723', bg: 'var(--amber-100)' },
}

const PRIORITY_VARIANT: Record<string, 'coral'|'amber'|'gray'> = { HIGH: 'coral', MEDIUM: 'amber', LOW: 'gray' }

const DONORS = ['Rajesh Khanna', 'Priya Sharma', 'Arjun Mehta', 'Sunita Iyer', 'Vivek Gupta', 'Ananya Patel', 'Kiran Reddy', 'Meera Nambiar']

function daysDiff(d: string) {
  const diff = Math.ceil((new Date(d).getTime() - new Date('2026-06-16').getTime()) / 86400000)
  if (diff === 0) return 'Today'
  if (diff === 1) return 'Tomorrow'
  if (diff < 0) return `${Math.abs(diff)}d ago`
  return `In ${diff}d`
}

/** Normalise a raw API reminder row to the Reminder shape the UI expects */
function normalise(raw: any): Reminder {
  return {
    id:        String(raw.id ?? raw._id ?? ''),
    type:      (raw.type ?? raw.reminderType ?? 'CUSTOM').toString().toUpperCase(),
    donorName: raw.donorName ?? raw.donor_name ?? raw.donor?.name ?? raw.name ?? '',
    message:   raw.message ?? raw.description ?? raw.notes ?? '',
    dueDate:   (raw.dueDate ?? raw.due_date ?? raw.date ?? '').toString().split('T')[0],
    status:    (raw.status ?? 'PENDING').toString().toUpperCase() as 'PENDING' | 'COMPLETED',
    priority:  (raw.priority ?? 'MEDIUM').toString().toUpperCase(),
  }
}

export default function RemindersPage() {
  const [reminders, setReminders] = useState<Reminder[]>([])
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState<string | null>(null)
  const [tab, setTab]             = useState<'PENDING'|'COMPLETED'>('PENDING')
  const [showModal, setShowModal] = useState(false)
  const [form, setForm]           = useState({ donorName: 'Rajesh Khanna', type: 'FOLLOW_UP', message: '', dueDate: new Date().toISOString().split('T')[0], priority: 'MEDIUM' })

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    api.reminders.list()
      .then((res: any) => {
        if (cancelled) return
        const items: any[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
        setReminders(items.map(normalise))
      })
      .catch((err: any) => {
        if (cancelled) return
        setError(err?.message ?? 'Failed to load reminders')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  const pending = reminders.filter(r => r.status === 'PENDING')
  const done    = reminders.filter(r => r.status === 'COMPLETED')
  const shown   = tab === 'PENDING' ? pending : done

  const markDone = (id: string) => {
    // Optimistic update; also call API
    setReminders(rs => rs.map(r => r.id === id ? { ...r, status: 'COMPLETED' } : r))
    api.reminders.done(id).catch(() => {
      // Revert on failure
      setReminders(rs => rs.map(r => r.id === id ? { ...r, status: 'PENDING' } : r))
    })
  }

  const reopen = (id: string) =>
    setReminders(rs => rs.map(r => r.id === id ? { ...r, status: 'PENDING' } : r))

  const saveNew = () => {
    if (!form.message) return
    const payload = { ...form }
    api.reminders.create(payload)
      .then((res: any) => {
        const created: Reminder = normalise({ ...payload, id: res?.id ?? res?._id ?? `r${Date.now()}` })
        setReminders(rs => [created, ...rs])
      })
      .catch(() => {
        // Fallback: add locally even if API fails
        const r: Reminder = { id: `r${Date.now()}`, ...form, status: 'PENDING' }
        setReminders(rs => [r, ...rs])
      })
    setShowModal(false)
    setForm({ donorName: 'Rajesh Khanna', type: 'FOLLOW_UP', message: '', dueDate: new Date().toISOString().split('T')[0], priority: 'MEDIUM' })
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-[14px]" style={{ color: 'var(--on-surface-2)' }}>Loading...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="rounded-2xl border p-6 text-center" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <p className="text-[14px] font-semibold" style={{ color: '#F2685E' }}>Failed to load reminders</p>
          <p className="text-[13px] mt-1" style={{ color: 'var(--on-surface-2)' }}>{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="mt-4 px-4 h-9 rounded-xl text-[13px] font-bold text-white"
            style={{ background: 'var(--primary)' }}>
            Retry
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Reminders</h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>{pending.length} pending · auto birthday reminders run daily at 8 AM</p>
        </div>
        <button onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white"
          style={{ background: 'var(--primary)' }}>
          <Icon name="plus" size={16} color="#fff" /> New Reminder
        </button>
      </div>

      <div className="flex gap-2">
        {(['PENDING', 'COMPLETED'] as const).map(t => (
          <button key={t} onClick={() => setTab(t)}
            className="px-5 h-10 rounded-xl text-[13px] font-bold transition-all"
            style={{ background: tab === t ? 'var(--primary)' : 'var(--surface)', color: tab === t ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
            {t === 'PENDING' ? `Pending (${pending.length})` : `Completed (${done.length})`}
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {shown.map(r => {
          const tc = TYPE_CONFIG[r.type] ?? TYPE_CONFIG.CUSTOM
          return (
            <div key={r.id} className="rounded-2xl border p-4 flex items-start gap-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)', opacity: r.status === 'COMPLETED' ? 0.65 : 1 }}>
              <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: tc.bg }}>
                <Icon name={tc.icon} size={18} color={tc.color} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="font-bold text-[14px]" style={{ color: 'var(--on-surface)' }}>{r.donorName}</div>
                    <div className="text-[12.5px] mt-0.5" style={{ color: 'var(--on-surface-2)' }}>{r.message}</div>
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0">
                    <Badge variant={PRIORITY_VARIANT[r.priority]}>{r.priority}</Badge>
                    <Badge variant={tc.label === 'Birthday' ? 'coral' : tc.label === 'Follow Up' ? 'green' : 'violet'}>{tc.label}</Badge>
                  </div>
                </div>
                <div className="flex items-center gap-4 mt-3">
                  <div className="flex items-center gap-1.5 text-[12px]" style={{ color: r.status === 'COMPLETED' ? 'var(--on-surface-3)' : 'var(--primary)' }}>
                    <Icon name="clock" size={13} color={r.status === 'COMPLETED' ? 'var(--on-surface-3)' : 'var(--primary)'} />
                    {daysDiff(r.dueDate)}
                  </div>
                  <div className="flex items-center gap-2 ml-auto">
                    {r.status === 'PENDING' ? (
                      <>
                        <button className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold" style={{ background: 'var(--brand-100)', color: 'var(--brand-700)' }}>
                          <Icon name="phone" size={12} color="var(--brand-700)" /> Call
                        </button>
                        <button className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold" style={{ background: '#DDF5E4', color: '#1FA971' }}>
                          <Icon name="whatsapp" size={12} color="#1FA971" /> WhatsApp
                        </button>
                        <button onClick={() => markDone(r.id)}
                          className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold" style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
                          <Icon name="checkCircle" size={12} color="var(--on-surface-2)" /> Done
                        </button>
                      </>
                    ) : (
                      <button onClick={() => reopen(r.id)}
                        className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold" style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
                        <Icon name="refresh" size={12} color="var(--on-surface-2)" /> Reopen
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )
        })}
        {shown.length === 0 && (
          <div className="rounded-2xl border p-10 text-center" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <p style={{ color: 'var(--on-surface-2)', fontSize: 14 }}>
              {tab === 'PENDING' ? 'All caught up! No pending reminders.' : 'No completed reminders yet.'}
            </p>
          </div>
        )}
      </div>

      {/* New Reminder Modal */}
      {showModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div style={{ background: 'var(--surface)', borderRadius: 20, width: '100%', maxWidth: 500, padding: 28, boxShadow: 'var(--shadow-lg)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <h2 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: 'var(--on-surface)' }}>New Reminder</h2>
              <button onClick={() => setShowModal(false)} style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="x" size={16} color="var(--on-surface-2)" />
              </button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <Fl label="Donor">
                <select value={form.donorName} onChange={e => setForm(f => ({ ...f, donorName: e.target.value }))} style={inp}>
                  {DONORS.map(d => <option key={d}>{d}</option>)}
                </select>
              </Fl>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Fl label="Type">
                  <select value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))} style={inp}>
                    {['BIRTHDAY','FOLLOW_UP','RENEWAL','CUSTOM'].map(t => <option key={t}>{t}</option>)}
                  </select>
                </Fl>
                <Fl label="Priority">
                  <select value={form.priority} onChange={e => setForm(f => ({ ...f, priority: e.target.value }))} style={inp}>
                    {['HIGH','MEDIUM','LOW'].map(p => <option key={p}>{p}</option>)}
                  </select>
                </Fl>
              </div>
              <Fl label="Due Date">
                <input type="date" value={form.dueDate} onChange={e => setForm(f => ({ ...f, dueDate: e.target.value }))} style={inp} />
              </Fl>
              <Fl label="Message *">
                <textarea value={form.message} onChange={e => setForm(f => ({ ...f, message: e.target.value }))} rows={3}
                  placeholder="What should be done?" style={{ ...inp, resize: 'vertical' }} />
              </Fl>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button onClick={() => setShowModal(false)} style={{ padding: '9px 20px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>Cancel</button>
              <button onClick={saveNew} style={{ padding: '9px 20px', borderRadius: 10, border: 'none', background: 'var(--primary)', color: '#fff', cursor: 'pointer', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="check" size={15} color="#fff" /> Save Reminder
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
