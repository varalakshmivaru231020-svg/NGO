'use client'
import { useState, useEffect } from 'react'
import { Icon } from '@/components/ui/Icon'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { api } from '@/lib/api'

// ─── System notifications ─────────────────────────────────────────────────────
type Notif = { id: string; type: string; title: string; body: string; time: string; read: boolean }

const NOTIF_TYPE: Record<string, { icon: string; color: string; bg: string }> = {
  donation:    { icon: 'wallet',  color: '#0E8C76', bg: 'var(--brand-100)' },
  donor:       { icon: 'users',  color: '#7C6CF0', bg: 'var(--violet-100)' },
  reminder:    { icon: 'bell',   color: '#F6A723', bg: 'var(--amber-100)' },
  achievement: { icon: 'star',   color: '#F2685E', bg: 'var(--coral-100)' },
}

// ─── Birthday reminders ───────────────────────────────────────────────────────
type GreetStatus = 'pending' | 'sent' | 'skipped'

interface BdayReminder {
  id: string; name: string; phone: string; whatsapp: string; email: string
  dob: string; daysUntil: number; status: GreetStatus
}

// ─── Anniversary reminders ────────────────────────────────────────────────────
interface AnnivReminder {
  id: string; name: string; phone: string; whatsapp: string; email: string
  since: string; years: number; daysUntil: number; totalGiven: string; status: GreetStatus
}

function DayChip({ days }: { days: number }) {
  if (days === 0) return <span style={{ padding: '2px 10px', borderRadius: 20, background: '#FEE2E2', color: '#EF4444', fontSize: 11, fontWeight: 700 }}>TODAY</span>
  if (days <= 3) return <span style={{ padding: '2px 10px', borderRadius: 20, background: 'var(--amber-100)', color: '#E0921A', fontSize: 11, fontWeight: 700 }}>In {days}d</span>
  return <span style={{ padding: '2px 10px', borderRadius: 20, background: 'var(--surface-2)', color: 'var(--on-surface-2)', fontSize: 11, fontWeight: 700 }}>In {days}d</span>
}

function GreetButtons({ item, onSend }: { item: BdayReminder | AnnivReminder; onSend: () => void }) {
  if ((item as BdayReminder).status === 'sent') {
    return <span style={{ fontSize: 12, fontWeight: 700, color: '#0E8C76', display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="checkCircle" size={14} color="#0E8C76" /> Greeting Sent</span>
  }
  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      <a href={`https://wa.me/${item.whatsapp}?text=${encodeURIComponent(`Dear ${item.name}, Warm greetings from Saksham Foundation! 🙏`)}`}
        target="_blank" rel="noreferrer"
        onClick={onSend}
        style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '6px 12px', borderRadius: 8, background: '#DDF5E4', color: '#1FA971', textDecoration: 'none', fontSize: 12, fontWeight: 700 }}>
        <Icon name="whatsapp" size={13} color="#1FA971" /> Send via WhatsApp
      </a>
      <a href={`mailto:${item.email}?subject=Warm%20Greetings%20from%20Saksham%20Foundation&body=Dear%20${encodeURIComponent(item.name)}%2C%0A%0AWarm%20greetings%20from%20the%20Saksham%20Foundation%20family!%0A%0AWe%20are%20grateful%20for%20your%20continued%20support.%0A%0AWarm%20regards%2C%0ASaksham%20Foundation`}
        onClick={onSend}
        style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '6px 12px', borderRadius: 8, background: 'var(--sky-100)', color: 'var(--sky-500)', textDecoration: 'none', fontSize: 12, fontWeight: 700 }}>
        <Icon name="mail" size={13} color="var(--sky-500)" /> Send via Email
      </a>
    </div>
  )
}

type Tab = 'notifications' | 'birthdays' | 'anniversaries'

// ─── Helper: normalise reminder records from the API ─────────────────────────
function normaliseBirthday(raw: any): BdayReminder {
  return {
    id:        raw.id        ?? raw._id        ?? String(Math.random()),
    name:      raw.name      ?? raw.donorName  ?? '',
    phone:     raw.phone     ?? raw.mobile     ?? '',
    whatsapp:  raw.whatsapp  ?? (raw.phone ?? raw.mobile ?? '').replace(/^\+/, ''),
    email:     raw.email     ?? '',
    dob:       raw.dob       ?? raw.birthDate  ?? raw.date ?? '',
    daysUntil: raw.daysUntil ?? raw.daysLeft   ?? 0,
    status:    raw.status    ?? 'pending',
  }
}

function normaliseAnniversary(raw: any): AnnivReminder {
  return {
    id:         raw.id         ?? raw._id         ?? String(Math.random()),
    name:       raw.name       ?? raw.donorName   ?? '',
    phone:      raw.phone      ?? raw.mobile      ?? '',
    whatsapp:   raw.whatsapp   ?? (raw.phone ?? raw.mobile ?? '').replace(/^\+/, ''),
    email:      raw.email      ?? '',
    since:      raw.since      ?? raw.donorSince  ?? '',
    years:      raw.years      ?? raw.yearCount   ?? 1,
    daysUntil:  raw.daysUntil  ?? raw.daysLeft    ?? 0,
    totalGiven: raw.totalGiven ?? raw.totalAmount ?? '',
    status:     raw.status     ?? 'pending',
  }
}

function normaliseNotif(raw: any): Notif {
  return {
    id:    raw.id    ?? raw._id    ?? String(Math.random()),
    type:  raw.type  ?? 'reminder',
    title: raw.title ?? raw.subject ?? '',
    body:  raw.body  ?? raw.message ?? raw.description ?? '',
    time:  raw.time  ?? raw.createdAt ?? '',
    read:  raw.read  ?? raw.isRead ?? false,
  }
}

export default function NotificationsPage() {
  const [tab, setTab] = useState<Tab>('notifications')

  // ── System notifications state ──
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [notifsLoading, setNotifsLoading] = useState(true)
  const [notifsError, setNotifsError] = useState('')

  // ── Birthday state ──
  const [birthdays, setBirthdays] = useState<BdayReminder[]>([])
  const [bdaysLoading, setBdaysLoading] = useState(true)
  const [bdaysError, setBdaysError] = useState('')

  // ── Anniversary state ──
  const [anniversaries, setAnniversaries] = useState<AnnivReminder[]>([])
  const [annivLoading, setAnnivLoading] = useState(true)
  const [annivError, setAnnivError] = useState('')

  const [toast, setToast] = useState('')

  // ── Fetch system notifications ──
  useEffect(() => {
    setNotifsLoading(true)
    setNotifsError('')
    api.notifications.list()
      .then((res: any) => {
        const items: any[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
        setNotifs(items.map(normaliseNotif))
      })
      .catch((err: Error) => setNotifsError(err.message ?? 'Failed to load notifications'))
      .finally(() => setNotifsLoading(false))
  }, [])

  // ── Fetch birthday reminders ──
  useEffect(() => {
    setBdaysLoading(true)
    setBdaysError('')
    api.reminders.birthdays()
      .then((res: any) => {
        const items: any[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
        setBirthdays(items.map(normaliseBirthday))
      })
      .catch((err: Error) => setBdaysError(err.message ?? 'Failed to load birthday reminders'))
      .finally(() => setBdaysLoading(false))
  }, [])

  // ── Fetch anniversary reminders (filter type='anniversary' from reminders list) ──
  useEffect(() => {
    setAnnivLoading(true)
    setAnnivError('')
    api.reminders.list()
      .then((res: any) => {
        const items: any[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
        const annivItems = items.filter((r: any) => r.type === 'anniversary' || r.reminderType === 'anniversary')
        setAnniversaries(annivItems.map(normaliseAnniversary))
      })
      .catch((err: Error) => setAnnivError(err.message ?? 'Failed to load anniversary reminders'))
      .finally(() => setAnnivLoading(false))
  }, [])

  const unread = notifs.filter(n => !n.read).length
  const pendingBdays = birthdays.filter(b => b.status === 'pending').length
  const pendingAnnivs = anniversaries.filter(a => a.status === 'pending').length

  const markRead = (id: string) => {
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, read: true } : n))
    api.notifications.markRead(id).catch(() => {/* best-effort */})
  }
  const markAllRead = () => {
    setNotifs(prev => prev.map(n => ({ ...n, read: true })))
    api.notifications.markAllRead().catch(() => {/* best-effort */})
  }

  const sendBday = (id: string) => {
    setBirthdays(bs => bs.map(b => b.id === id ? { ...b, status: 'sent' } : b))
    showToast('Birthday greeting sent!')
  }
  const sendAnniv = (id: string) => {
    setAnniversaries(as => as.map(a => a.id === id ? { ...a, status: 'sent' } : a))
    showToast('Anniversary greeting sent!')
  }

  const showToast = (msg: string) => {
    setToast(msg); setTimeout(() => setToast(''), 2500)
  }

  return (
    <div style={{ maxWidth: 720 }}>
      {/* Page header */}
      <div style={{ marginBottom: 20 }}>
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: 'var(--on-surface)' }}>Notifications & Reminders</h2>
        <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--on-surface-2)' }}>
          System alerts · Birthday & Anniversary greetings auto-triggered daily at 8 AM
        </p>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {([
          { key: 'notifications', label: 'System', badge: unread },
          { key: 'birthdays',    label: 'Birthdays', badge: pendingBdays },
          { key: 'anniversaries', label: 'Anniversaries', badge: pendingAnnivs },
        ] as const).map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 18px', borderRadius: 12, border: '1px solid var(--border)', background: tab === t.key ? 'var(--primary)' : 'var(--surface)', color: tab === t.key ? '#fff' : 'var(--on-surface-2)', fontWeight: 700, fontSize: 13, cursor: 'pointer' }}>
            {t.label}
            {t.badge > 0 && (
              <span style={{ background: tab === t.key ? 'rgba(255,255,255,0.25)' : '#F2685E', color: '#fff', borderRadius: 99, padding: '1px 7px', fontSize: 11, fontWeight: 800 }}>{t.badge}</span>
            )}
          </button>
        ))}
      </div>

      {/* ── System Notifications ── */}
      {tab === 'notifications' && (
        <div>
          {notifsLoading ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>Loading...</div>
          ) : notifsError ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: '#EF4444', fontSize: 14 }}>{notifsError}</div>
          ) : (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                <span style={{ fontSize: 13, color: 'var(--on-surface-2)' }}>{unread} unread</span>
                {unread > 0 && (
                  <button onClick={markAllRead} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 700, color: 'var(--primary)' }}>
                    Mark all as read
                  </button>
                )}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {notifs.map(n => {
                  const tc = NOTIF_TYPE[n.type] ?? NOTIF_TYPE['reminder']
                  return (
                    <div key={n.id} onClick={() => markRead(n.id)}
                      style={{ display: 'flex', alignItems: 'flex-start', gap: 14, padding: '14px 16px', borderRadius: 16, border: `1px solid ${n.read ? 'var(--border)' : 'var(--brand-300)'}`, background: n.read ? 'var(--surface)' : 'var(--brand-50)', cursor: 'pointer', transition: 'all 0.15s' }}>
                      <div style={{ width: 40, height: 40, borderRadius: 12, background: tc.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                        <Icon name={tc.icon} size={18} color={tc.color} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                          <span style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--on-surface)' }}>{n.title}</span>
                          <span style={{ fontSize: 11.5, color: 'var(--on-surface-3)', flexShrink: 0 }}>{n.time}</span>
                        </div>
                        <div style={{ fontSize: 12.5, color: 'var(--on-surface-2)', marginTop: 2 }}>{n.body}</div>
                      </div>
                      {!n.read && <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--primary)', flexShrink: 0, marginTop: 6 }} />}
                    </div>
                  )
                })}
                {notifs.length === 0 && (
                  <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>No notifications</div>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* ── Birthday Reminders ── */}
      {tab === 'birthdays' && (
        <div>
          <div style={{ padding: '12px 16px', background: 'var(--amber-100)', borderRadius: 12, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
            <Icon name="cake" size={16} color="#E0921A" />
            <span style={{ fontSize: 13, fontWeight: 600, color: '#92600A' }}>
              Greetings are auto-sent via WhatsApp at 8:00 AM on each donor&apos;s birthday. You can also send manually below.
            </span>
          </div>
          {bdaysLoading ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>Loading...</div>
          ) : bdaysError ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: '#EF4444', fontSize: 14 }}>{bdaysError}</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {birthdays.sort((a, b) => a.daysUntil - b.daysUntil).map(b => (
                <div key={b.id} style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 16, padding: '16px 20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
                    <Avatar name={b.name} size={44} />
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--on-surface)' }}>{b.name}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 3 }}>
                        <Icon name="cake" size={13} color="var(--on-surface-3)" />
                        <span style={{ fontSize: 12.5, color: 'var(--on-surface-2)' }}>Birthday: {b.dob}</span>
                        <DayChip days={b.daysUntil} />
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <a href={`tel:${b.phone}`} style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--brand-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Icon name="phone" size={14} color="var(--brand-700)" />
                      </a>
                      <a href={`mailto:${b.email}`} style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--sky-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Icon name="mail" size={14} color="var(--sky-500)" />
                      </a>
                    </div>
                  </div>
                  <div style={{ paddingTop: 10, borderTop: '1px solid var(--border)' }}>
                    <GreetButtons item={b} onSend={() => sendBday(b.id)} />
                  </div>
                </div>
              ))}
              {birthdays.length === 0 && (
                <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>No upcoming birthdays</div>
              )}
            </div>
          )}
        </div>
      )}

      {/* ── Anniversary Reminders ── */}
      {tab === 'anniversaries' && (
        <div>
          <div style={{ padding: '12px 16px', background: 'var(--violet-100)', borderRadius: 12, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
            <Icon name="heart" size={16} color="#7C6CF0" />
            <span style={{ fontSize: 13, fontWeight: 600, color: '#4C3FA8' }}>
              Donation anniversary greetings are auto-sent on the anniversary of a donor&apos;s first donation. Send manually below.
            </span>
          </div>
          {annivLoading ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>Loading...</div>
          ) : annivError ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: '#EF4444', fontSize: 14 }}>{annivError}</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {anniversaries.sort((a, b) => a.daysUntil - b.daysUntil).map(a => (
                <div key={a.id} style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 16, padding: '16px 20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
                    <Avatar name={a.name} size={44} />
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--on-surface)' }}>{a.name}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 3, flexWrap: 'wrap' }}>
                        <Icon name="heart" size={13} color="var(--on-surface-3)" />
                        <span style={{ fontSize: 12.5, color: 'var(--on-surface-2)' }}>Donor since {a.since} · {a.years} year{a.years > 1 ? 's' : ''}</span>
                        <DayChip days={a.daysUntil} />
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--primary)', fontWeight: 700, marginTop: 4 }}>Total given: {a.totalGiven}</div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <a href={`tel:${a.phone}`} style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--brand-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Icon name="phone" size={14} color="var(--brand-700)" />
                      </a>
                      <a href={`mailto:${a.email}`} style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--sky-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Icon name="mail" size={14} color="var(--sky-500)" />
                      </a>
                    </div>
                  </div>
                  <div style={{ paddingTop: 10, borderTop: '1px solid var(--border)' }}>
                    <GreetButtons item={a} onSend={() => sendAnniv(a.id)} />
                  </div>
                </div>
              ))}
              {anniversaries.length === 0 && (
                <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--on-surface-2)', fontSize: 14 }}>No upcoming anniversaries</div>
              )}
            </div>
          )}
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
