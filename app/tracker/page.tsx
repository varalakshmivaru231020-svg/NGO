'use client'
import { useState } from 'react'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'

type Status = 'PENDING' | 'PARTIAL' | 'OVERDUE' | 'COLLECTED'

interface Pledge {
  id: string
  donor: string
  phone: string
  whatsapp: string
  email: string
  amount: number
  received?: number
  pledgedDate: string
  dueDate: string
  status: Status
  notes: string
  purpose: string
}

const INITIAL: Pledge[] = [
  { id: 'p1', donor: 'Arjun Mehta',   phone: '+919004088876', whatsapp: '919004088876', email: 'arjun.mehta@techcorp.in',    amount: 200000, pledgedDate: '2026-05-10', dueDate: '2026-06-20', status: 'PENDING',   notes: 'Pledged at Founder Day event. Education fund allocation.', purpose: 'Education Fund' },
  { id: 'p2', donor: 'Meera Nambiar', phone: '+919456723456', whatsapp: '919456723456', email: 'meera@gmail.com',            amount: 500000, received: 200000, pledgedDate: '2026-04-15', dueDate: '2026-06-30', status: 'PARTIAL', notes: 'Annual renewal — ₹2L received, ₹3L pending.', purpose: 'General Donation' },
  { id: 'p3', donor: 'Vivek Gupta',   phone: '+918800155432', whatsapp: '918800155432', email: 'vivek.gupta@gmail.com',      amount: 80000,  pledgedDate: '2026-05-28', dueDate: '2026-07-15', status: 'PENDING',   notes: 'Healthcare support pledge.', purpose: 'Healthcare' },
  { id: 'p4', donor: 'Ananya Patel',  phone: '+919123467890', whatsapp: '919123467890', email: 'ananya.patel@corp.com',      amount: 150000, pledgedDate: '2026-03-01', dueDate: '2026-05-31', status: 'OVERDUE',   notes: 'CSR pledge — multiple follow-ups sent.', purpose: 'General Donation' },
  { id: 'p5', donor: 'Sunita Iyer',   phone: '+919765033212', whatsapp: '919765033212', email: 'sunita.iyer@gmail.com',      amount: 60000,  pledgedDate: '2026-05-05', dueDate: '2026-06-10', status: 'COLLECTED', notes: 'Received in full via UPI.', purpose: 'Education Fund' },
  { id: 'p6', donor: 'Kiran Reddy',   phone: '+919345612345', whatsapp: '919345612345', email: 'kiran.reddy@tech.in',        amount: 40000,  pledgedDate: '2026-05-18', dueDate: '2026-06-15', status: 'COLLECTED', notes: 'Bank transfer received.', purpose: 'General Donation' },
]

const STATUS_CONFIG: Record<Status, { label: string; variant: 'amber'|'sky'|'coral'|'green'; color: string; bg: string }> = {
  PENDING:   { label: 'Pending',   variant: 'amber', color: '#F6A723', bg: 'var(--amber-100)' },
  PARTIAL:   { label: 'Partial',   variant: 'sky',   color: '#3ABCF7', bg: 'var(--sky-100)' },
  OVERDUE:   { label: 'Overdue',   variant: 'coral', color: '#F2685E', bg: 'var(--coral-100)' },
  COLLECTED: { label: 'Collected', variant: 'green', color: '#0E8C76', bg: 'var(--brand-100)' },
}

function daysDiff(d: string) {
  const diff = Math.ceil((new Date(d).getTime() - new Date('2026-06-16').getTime()) / 86400000)
  if (diff === 0) return 'Due today'
  if (diff < 0) return `${Math.abs(diff)}d overdue`
  return `Due in ${diff}d`
}

export default function TrackerPage() {
  const [pledges, setPledges] = useState<Pledge[]>(INITIAL)
  const [filter, setFilter] = useState('All')
  const [viewPledge, setViewPledge] = useState<Pledge | null>(null)
  const [toast, setToast] = useState('')

  const filtered = pledges.filter(p => filter === 'All' || p.status === filter)

  const totalPledged  = pledges.reduce((s, p) => s + p.amount, 0)
  const totalReceived = pledges.reduce((s, p) => {
    if (p.status === 'COLLECTED') return s + p.amount
    if (p.status === 'PARTIAL')   return s + (p.received ?? 0)
    return s
  }, 0)
  const totalOverdue = pledges.filter(p => p.status === 'OVERDUE').reduce((s, p) => s + p.amount, 0)
  const pct = Math.round((totalReceived / totalPledged) * 100)

  const markCollected = (id: string) => {
    setPledges(ps => ps.map(p => p.id === id ? { ...p, status: 'COLLECTED', received: p.amount } : p))
    setViewPledge(v => v?.id === id ? { ...v, status: 'COLLECTED', received: v.amount } : v)
    showToast('Marked as Collected!')
  }

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  return (
    <div className="space-y-5">
      <div>
        <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Donation Tracker</h2>
        <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Track pledges, follow-ups, and outstanding amounts</p>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: 'Total Pledged',    value: fmt.inr(totalPledged, true),  color: 'var(--on-surface)',    bg: 'var(--surface)' },
          { label: 'Collected',        value: fmt.inr(totalReceived, true), color: '#0E8C76',              bg: 'var(--brand-50)' },
          { label: 'Overdue',          value: fmt.inr(totalOverdue, true),  color: '#F2685E',              bg: 'var(--coral-50,#FFF5F4)' },
          { label: 'Collection Rate',  value: `${pct}%`,                    color: '#7C6CF0',              bg: 'var(--violet-50,#F5F3FF)' },
        ].map((s, i) => (
          <div key={i} className="rounded-2xl border p-4" style={{ background: s.bg, borderColor: 'var(--border)' }}>
            <div className="text-[11.5px] font-semibold mb-1" style={{ color: 'var(--on-surface-2)' }}>{s.label}</div>
            <div className="text-[22px] font-bold" style={{ color: s.color }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Progress */}
      <div className="rounded-2xl border p-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
        <div className="flex justify-between text-[12.5px] mb-2">
          <span className="font-semibold" style={{ color: 'var(--on-surface)' }}>Overall Collection Progress</span>
          <span style={{ color: 'var(--on-surface-2)' }}>{fmt.inr(totalReceived, true)} of {fmt.inr(totalPledged, true)}</span>
        </div>
        <div className="h-3 rounded-full overflow-hidden" style={{ background: 'var(--surface-2)' }}>
          <div className="h-full rounded-full transition-all" style={{ width: `${pct}%`, background: 'linear-gradient(90deg, #0B6E5D, #14A98C)' }} />
        </div>
        <div className="text-right text-[12px] mt-1 font-bold" style={{ color: 'var(--primary)' }}>{pct}%</div>
      </div>

      {/* Filter */}
      <div className="flex gap-2 flex-wrap">
        {(['All', 'PENDING', 'PARTIAL', 'OVERDUE', 'COLLECTED'] as const).map(s => {
          const cfg = STATUS_CONFIG[s as Status]
          const active = filter === s
          const count = s === 'All' ? pledges.length : pledges.filter(p => p.status === s).length
          return (
            <button key={s} onClick={() => setFilter(s)}
              className="px-3.5 h-9 rounded-xl text-[12.5px] font-bold transition-all"
              style={{ background: active ? (cfg?.color ?? 'var(--primary)') : 'var(--surface)', color: active ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
              {cfg?.label ?? 'All'} ({count})
            </button>
          )
        })}
      </div>

      {/* Cards */}
      <div className="space-y-3">
        {filtered.map(p => {
          const sc = STATUS_CONFIG[p.status]
          const isOverdue = p.status === 'OVERDUE'
          const collectedPct = p.status === 'PARTIAL' && p.received
            ? Math.round((p.received / p.amount) * 100)
            : p.status === 'COLLECTED' ? 100 : 0

          return (
            <div key={p.id} className="rounded-2xl border p-5"
              style={{ background: 'var(--surface)', borderColor: isOverdue ? '#F2685E55' : 'var(--border)', transition: 'all 0.2s' }}>
              {/* Header row */}
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-start gap-3">
                  <Avatar name={p.donor} size={44} />
                  <div>
                    <div className="font-bold text-[14.5px]" style={{ color: 'var(--on-surface)' }}>{p.donor}</div>
                    <div className="text-[12.5px] mt-0.5" style={{ color: 'var(--on-surface-2)' }}>{p.notes}</div>
                    <div className="text-[11.5px] mt-1 font-semibold" style={{ color: 'var(--on-surface-3)' }}>{p.purpose}</div>
                  </div>
                </div>
                <div className="flex items-center gap-3 flex-shrink-0">
                  <Badge variant={sc.variant}>{sc.label}</Badge>
                  <div className="text-right">
                    <div className="text-[17px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(p.amount, true)}</div>
                    <div className="text-[11.5px]" style={{ color: isOverdue ? '#F2685E' : 'var(--on-surface-2)' }}>
                      {daysDiff(p.dueDate)}
                    </div>
                  </div>
                </div>
              </div>

              {/* Partial progress */}
              {p.status === 'PARTIAL' && p.received && (
                <div className="mt-4 space-y-1.5">
                  <div className="flex justify-between text-[12px]">
                    <span style={{ color: 'var(--on-surface-2)' }}>Received: {fmt.inr(p.received, true)}</span>
                    <span style={{ color: 'var(--on-surface-2)' }}>Remaining: {fmt.inr(p.amount - p.received, true)}</span>
                  </div>
                  <div className="h-2 rounded-full overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                    <div className="h-full rounded-full" style={{ width: `${collectedPct}%`, background: '#3ABCF7' }} />
                  </div>
                </div>
              )}

              {/* Collected check */}
              {p.status === 'COLLECTED' && (
                <div className="mt-3 flex items-center gap-2" style={{ color: '#0E8C76' }}>
                  <Icon name="checkCircle" size={16} color="#0E8C76" />
                  <span className="text-[12.5px] font-bold">Payment received in full</span>
                </div>
              )}

              {/* Action buttons */}
              {p.status !== 'COLLECTED' && (
                <div className="flex gap-2 mt-4 pt-4 border-t flex-wrap" style={{ borderColor: 'var(--border)' }}>
                  {/* Call — opens phone dialer */}
                  <a href={`tel:${p.phone}`}
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold no-underline"
                    style={{ background: 'var(--brand-100)', color: 'var(--brand-700)' }}>
                    <Icon name="phone" size={13} color="var(--brand-700)" /> Call
                  </a>

                  {/* WhatsApp — opens WhatsApp chat */}
                  <a href={`https://wa.me/${p.whatsapp}?text=Dear%20${encodeURIComponent(p.donor)}%2C%20This%20is%20a%20gentle%20reminder%20regarding%20your%20pledge%20of%20%E2%82%B9${(p.amount/100000).toFixed(1)}L%20to%20Saksham%20Foundation.%20Kindly%20let%20us%20know%20if%20you%20need%20any%20assistance.%20Thank%20you!`}
                    target="_blank" rel="noreferrer"
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold no-underline"
                    style={{ background: '#DDF5E4', color: '#1FA971' }}>
                    <Icon name="whatsapp" size={13} color="#1FA971" /> WhatsApp
                  </a>

                  {/* Email — opens mail client */}
                  <a href={`mailto:${p.email}?subject=Pledge%20Reminder%20-%20Saksham%20Foundation&body=Dear%20${encodeURIComponent(p.donor)}%2C%0A%0AThis%20is%20a%20gentle%20reminder%20regarding%20your%20pledge%20of%20%E2%82%B9${p.amount.toLocaleString('en-IN')}%20to%20Saksham%20Foundation%20due%20on%20${p.dueDate}.%0A%0AKindly%20arrange%20payment%20at%20your%20earliest%20convenience.%0A%0AWarm%20regards%2C%0ASaksham%20Foundation%20Team`}
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold no-underline"
                    style={{ background: 'var(--sky-100)', color: 'var(--sky-500)' }}>
                    <Icon name="mail" size={13} color="var(--sky-500)" /> Email
                  </a>

                  {/* View details */}
                  <button onClick={() => setViewPledge(p)}
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold"
                    style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
                    <Icon name="eye" size={13} color="var(--on-surface-2)" /> View
                  </button>

                  {/* Mark Collected */}
                  <button onClick={() => markCollected(p.id)}
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold ml-auto"
                    style={{ background: '#0E8C76', color: '#fff' }}>
                    <Icon name="checkCircle" size={13} color="#fff" /> Mark Collected
                  </button>
                </div>
              )}

              {p.status === 'COLLECTED' && (
                <div className="flex gap-2 mt-4 pt-4 border-t" style={{ borderColor: 'var(--border)' }}>
                  <button onClick={() => setViewPledge(p)}
                    className="flex items-center gap-1.5 px-3 h-8 rounded-lg text-[12px] font-bold"
                    style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
                    <Icon name="eye" size={13} color="var(--on-surface-2)" /> View Details
                  </button>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Detail drawer */}
      {viewPledge && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', alignItems: 'flex-end', justifyContent: 'flex-end' }}
          onClick={() => setViewPledge(null)}>
          <div style={{ width: '100%', maxWidth: 440, height: '100vh', background: 'var(--surface)', boxShadow: 'var(--shadow-lg)', overflowY: 'auto', display: 'flex', flexDirection: 'column' }}
            onClick={e => e.stopPropagation()}>
            {/* Drawer header */}
            <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <h2 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: 'var(--on-surface)' }}>Pledge Details</h2>
              <button onClick={() => setViewPledge(null)} style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="x" size={16} color="var(--on-surface-2)" />
              </button>
            </div>

            {/* Donor info */}
            <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 14 }}>
              <Avatar name={viewPledge.donor} size={56} />
              <div>
                <div style={{ fontSize: 17, fontWeight: 700, color: 'var(--on-surface)' }}>{viewPledge.donor}</div>
                <div style={{ fontSize: 13, color: 'var(--on-surface-2)', marginTop: 2 }}>{viewPledge.purpose}</div>
                <Badge variant={STATUS_CONFIG[viewPledge.status].variant}>{STATUS_CONFIG[viewPledge.status].label}</Badge>
              </div>
            </div>

            {/* Details */}
            <div style={{ padding: '20px 24px', flex: 1 }}>
              {[
                { label: 'Pledge Amount',  value: fmt.inr(viewPledge.amount) },
                { label: 'Amount Received', value: viewPledge.status === 'COLLECTED' ? fmt.inr(viewPledge.amount) : viewPledge.received ? fmt.inr(viewPledge.received) : '—' },
                { label: 'Pledged Date',   value: new Date(viewPledge.pledgedDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' }) },
                { label: 'Due Date',       value: new Date(viewPledge.dueDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' }) },
                { label: 'Status',         value: STATUS_CONFIG[viewPledge.status].label },
                { label: 'Mobile',         value: viewPledge.phone },
                { label: 'Email',          value: viewPledge.email },
                { label: 'Notes',          value: viewPledge.notes },
              ].map(row => (
                <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
                  <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--on-surface-2)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{row.label}</span>
                  <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--on-surface)', textAlign: 'right', maxWidth: '60%' }}>{row.value}</span>
                </div>
              ))}
            </div>

            {/* Drawer actions */}
            <div style={{ padding: '16px 24px', borderTop: '1px solid var(--border)', display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
                <a href={`tel:${viewPledge.phone}`} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: '10px 0', borderRadius: 10, background: 'var(--brand-100)', color: 'var(--brand-700)', textDecoration: 'none', fontSize: 13, fontWeight: 700 }}>
                  <Icon name="phone" size={14} color="var(--brand-700)" /> Call
                </a>
                <a href={`https://wa.me/${viewPledge.whatsapp}`} target="_blank" rel="noreferrer" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: '10px 0', borderRadius: 10, background: '#DDF5E4', color: '#1FA971', textDecoration: 'none', fontSize: 13, fontWeight: 700 }}>
                  <Icon name="whatsapp" size={14} color="#1FA971" /> WhatsApp
                </a>
                <a href={`mailto:${viewPledge.email}`} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: '10px 0', borderRadius: 10, background: 'var(--sky-100)', color: 'var(--sky-500)', textDecoration: 'none', fontSize: 13, fontWeight: 700 }}>
                  <Icon name="mail" size={14} color="var(--sky-500)" /> Email
                </a>
              </div>
              {viewPledge.status !== 'COLLECTED' && (
                <button onClick={() => markCollected(viewPledge.id)}
                  style={{ width: '100%', padding: '12px', borderRadius: 10, border: 'none', background: '#0E8C76', color: '#fff', cursor: 'pointer', fontWeight: 700, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
                  <Icon name="checkCircle" size={16} color="#fff" /> Mark as Collected
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div style={{ position: 'fixed', bottom: 24, left: '50%', transform: 'translateX(-50%)', background: '#0E8C76', color: '#fff', padding: '12px 24px', borderRadius: 12, fontWeight: 700, fontSize: 14, zIndex: 2000, boxShadow: '0 8px 32px rgba(14,140,118,0.4)', display: 'flex', alignItems: 'center', gap: 8 }}>
          <Icon name="checkCircle" size={16} color="#fff" /> {toast}
        </div>
      )}
    </div>
  )
}
