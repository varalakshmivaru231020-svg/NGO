'use client'
import { useState, useEffect } from 'react'
import { Icon } from '@/components/ui/Icon'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { api } from '@/lib/api'

const SECTIONS = [
  { id: 'profile', label: 'Profile', icon: 'user' },
  { id: 'security', label: 'Security', icon: 'lock' },
  { id: 'notifications', label: 'Notifications', icon: 'bell' },
  { id: 'appearance', label: 'Appearance', icon: 'sun' },
  { id: 'whatsapp', label: 'WhatsApp Business API', icon: 'phone' },
]

export default function SettingsPage() {
  const [section, setSection] = useState('profile')
  const [theme, setTheme] = useState<'light'|'dark'>('light')
  const [emailNotifs, setEmailNotifs] = useState(true)
  const [pushNotifs, setPushNotifs] = useState(true)
  const [birthdayNotifs, setBirthdayNotifs] = useState(true)

  // WhatsApp Business API settings (persisted to the backend)
  const WA_DEFAULT = { storeNumber: '', phoneNumberId: '', apiToken: '', apiUrl: '', apiVersion: '', wabaId: '', businessId: '' }
  const [wa, setWa] = useState(WA_DEFAULT)
  const [waLoading, setWaLoading] = useState(true)
  const [waSaving, setWaSaving] = useState(false)
  const [waMsg, setWaMsg] = useState<string | null>(null)
  const [waErr, setWaErr] = useState<string | null>(null)
  const [showToken, setShowToken] = useState(false)

  // Native-Meta passthrough mode (needs API Version / WABA ID / Business ID)
  // is whatever the configured API URL contains "/api/meta".
  const isMetaMode = wa.apiUrl.toLowerCase().includes('/api/meta')

  useEffect(() => {
    let alive = true
    api.settings.getWhatsapp()
      .then((d: any) => { if (alive) setWa({ ...WA_DEFAULT, ...d }) })
      .catch(() => {})
      .finally(() => { if (alive) setWaLoading(false) })
    return () => { alive = false }
  }, [])

  const setWaField = (k: string, v: string) => setWa(prev => ({ ...prev, [k]: v }))

  const saveWhatsapp = async () => {
    setWaSaving(true); setWaErr(null); setWaMsg(null)
    try {
      const d: any = await api.settings.updateWhatsapp(wa)
      setWa({ ...WA_DEFAULT, ...d })
      setWaMsg('Settings saved.')
    } catch (e: any) {
      setWaErr(e?.message ?? 'Failed to save settings')
    } finally {
      setWaSaving(false)
    }
  }

  const toggleTheme = (t: 'light'|'dark') => {
    setTheme(t)
    document.documentElement.setAttribute('data-theme', t)
  }

  return (
    <div className="flex gap-6">
      {/* Sidebar */}
      <div className="w-52 flex-shrink-0 space-y-1">
        {SECTIONS.map(s => (
          <button key={s.id} onClick={() => setSection(s.id)}
            className="w-full flex items-center gap-3 px-3.5 h-10 rounded-xl text-[13px] font-bold text-left transition-all"
            style={{ background: section === s.id ? 'var(--brand-100)' : 'transparent', color: section === s.id ? 'var(--primary)' : 'var(--on-surface-2)' }}>
            <Icon name={s.icon} size={16} color={section === s.id ? 'var(--primary)' : 'var(--on-surface-3)'} />
            {s.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 max-w-lg">

        {section === 'profile' && (
          <div className="rounded-2xl border p-6 space-y-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Profile Settings</h3>
            <div className="flex items-center gap-4">
              <Avatar name="Admin User" size={64} />
              <div>
                <div className="font-bold" style={{ color: 'var(--on-surface)' }}>Admin User</div>
                <div className="text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>admin@saksham.org</div>
                <Badge variant="violet">ADMIN</Badge>
              </div>
            </div>
            <div className="space-y-3">
              {[
                { label: 'Full Name', value: 'Admin User', type: 'text' },
                { label: 'Email', value: 'admin@saksham.org', type: 'email' },
                { label: 'Phone', value: '+91 98200 00001', type: 'tel' },
              ].map(f => (
                <div key={f.label} className="space-y-1">
                  <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>{f.label}</label>
                  <input defaultValue={f.value} type={f.type}
                    className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                    style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                </div>
              ))}
            </div>
            <button className="px-5 h-10 rounded-xl text-[13px] font-bold text-white" style={{ background: 'var(--primary)' }}>
              Save Changes
            </button>
          </div>
        )}

        {section === 'security' && (
          <div className="rounded-2xl border p-6 space-y-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Change Password</h3>
            <div className="space-y-3">
              {['Current Password', 'New Password', 'Confirm New Password'].map(l => (
                <div key={l} className="space-y-1">
                  <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>{l}</label>
                  <input type="password" placeholder="••••••••"
                    className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none"
                    style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                </div>
              ))}
            </div>
            <div className="p-3 rounded-xl text-[12px]" style={{ background: 'var(--amber-100)', color: '#92710A' }}>
              Passwords are hashed with Argon2. Minimum 8 characters with mixed case and numbers.
            </div>
            <button className="px-5 h-10 rounded-xl text-[13px] font-bold text-white" style={{ background: 'var(--primary)' }}>
              Update Password
            </button>
          </div>
        )}

        {section === 'notifications' && (
          <div className="rounded-2xl border p-6 space-y-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Notification Preferences</h3>
            {[
              { label: 'Email Notifications', sub: 'Receive donation receipts and reports via email', val: emailNotifs, set: setEmailNotifs },
              { label: 'Push Notifications', sub: 'Real-time alerts for donations and reminders', val: pushNotifs, set: setPushNotifs },
              { label: 'Birthday Reminders', sub: 'Auto-remind for donor birthdays each morning', val: birthdayNotifs, set: setBirthdayNotifs },
            ].map(n => (
              <div key={n.label} className="flex items-center justify-between py-3 border-b last:border-b-0" style={{ borderColor: 'var(--border)' }}>
                <div>
                  <div className="font-semibold text-[13.5px]" style={{ color: 'var(--on-surface)' }}>{n.label}</div>
                  <div className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{n.sub}</div>
                </div>
                <button onClick={() => n.set(!n.val)}
                  className="w-11 h-6 rounded-full relative transition-colors flex-shrink-0"
                  style={{ background: n.val ? 'var(--primary)' : 'var(--surface-3)' }}>
                  <div className="absolute w-5 h-5 bg-white rounded-full top-0.5 transition-all shadow-sm"
                    style={{ left: n.val ? '22px' : '2px' }} />
                </button>
              </div>
            ))}
          </div>
        )}

        {section === 'appearance' && (
          <div className="rounded-2xl border p-6 space-y-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Appearance</h3>
            <div>
              <div className="text-[12.5px] font-bold uppercase mb-3" style={{ color: 'var(--on-surface-2)' }}>Theme</div>
              <div className="flex gap-3">
                {(['light', 'dark'] as const).map(t => (
                  <button key={t} onClick={() => toggleTheme(t)}
                    className="flex-1 flex items-center gap-3 p-4 rounded-xl border-2 transition-all"
                    style={{ borderColor: theme === t ? 'var(--primary)' : 'var(--border)', background: 'var(--surface-2)' }}>
                    <Icon name={t === 'light' ? 'sun' : 'moon'} size={20} color={theme === t ? 'var(--primary)' : 'var(--on-surface-2)'} />
                    <div className="text-left">
                      <div className="font-bold text-[13px]" style={{ color: theme === t ? 'var(--primary)' : 'var(--on-surface)' }}>
                        {t === 'light' ? 'Light Mode' : 'Dark Mode'}
                      </div>
                      <div className="text-[11px]" style={{ color: 'var(--on-surface-2)' }}>{t === 'light' ? 'Bright workspace' : 'Easy on the eyes'}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {section === 'whatsapp' && (
          <div className="rounded-2xl border p-6 space-y-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <div>
              <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>WhatsApp Business API</h3>
              <p className="text-[12px] mt-1 leading-relaxed" style={{ color: 'var(--on-surface-2)' }}>
                Auto-sends donation confirmation &amp; receipt messages to donors via BotSyncWA. Requires approved
                templates (donation_received, receipt_generated) in Meta Business Manager.
              </p>
            </div>

            {waLoading ? (
              <div className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Loading…</div>
            ) : (
              <>
                <div className="space-y-3">
                  <div className="space-y-1">
                    <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Store WhatsApp Number</label>
                    <input value={wa.storeNumber} onChange={e => setWaField('storeNumber', e.target.value)} placeholder="919832399399"
                      className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                      style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                    <p className="text-[11px]" style={{ color: 'var(--on-surface-3)' }}>Sender number with country code, no “+”.</p>
                  </div>

                  <div className="space-y-1">
                    <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Phone Number ID</label>
                    <input value={wa.phoneNumberId} onChange={e => setWaField('phoneNumberId', e.target.value)} placeholder="1129335896919323"
                      className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                      style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                  </div>

                  <div className="space-y-1">
                    <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>API Token</label>
                    <div className="relative">
                      <input type={showToken ? 'text' : 'password'} value={wa.apiToken} onChange={e => setWaField('apiToken', e.target.value)} placeholder="••••••••••••••••"
                        className="w-full h-10 pl-3.5 pr-16 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                        style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                      <button type="button" onClick={() => setShowToken(s => !s)}
                        className="absolute right-2 top-1/2 -translate-y-1/2 text-[11px] font-bold px-2 py-1 rounded-lg"
                        style={{ color: 'var(--primary)' }}>
                        {showToken ? 'Hide' : 'Show'}
                      </button>
                    </div>
                  </div>

                  <div className="space-y-1">
                    <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>API URL (optional override)</label>
                    <input value={wa.apiUrl} onChange={e => setWaField('apiUrl', e.target.value)} placeholder="https://crmapp.botsyncwa.com/api/v1/messages"
                      className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                      style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                    <p className="text-[11px]" style={{ color: 'var(--on-surface-3)' }}>
                      {isMetaMode
                        ? 'Native Meta mode detected (URL contains “/api/meta”) — fill in the fields below.'
                        : 'Leave the default for the standard endpoint, or point it at “…/api/meta” to use native Meta mode.'}
                    </p>
                  </div>

                  {isMetaMode && (
                    <>
                      <div className="space-y-1">
                        <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>API Version</label>
                        <input value={wa.apiVersion} onChange={e => setWaField('apiVersion', e.target.value)} placeholder="v19.0"
                          className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                          style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                      </div>

                      <div className="space-y-1">
                        <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>WABA ID</label>
                        <input value={wa.wabaId} onChange={e => setWaField('wabaId', e.target.value)} placeholder="1951565062163055"
                          className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                          style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                      </div>

                      <div className="space-y-1">
                        <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Business ID</label>
                        <input value={wa.businessId} onChange={e => setWaField('businessId', e.target.value)} placeholder="1075079811743037"
                          className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none focus:border-[var(--primary)]"
                          style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
                      </div>
                    </>
                  )}
                </div>

                {waErr && <div className="p-3 rounded-xl text-[12px]" style={{ background: '#FFE3DF', color: '#B23B32' }}>{waErr}</div>}
                {waMsg && <div className="p-3 rounded-xl text-[12px]" style={{ background: 'var(--brand-100)', color: 'var(--primary)' }}>{waMsg}</div>}

                <button onClick={saveWhatsapp} disabled={waSaving}
                  className="px-5 h-10 rounded-xl text-[13px] font-bold text-white disabled:opacity-60"
                  style={{ background: 'var(--primary)' }}>
                  {waSaving ? 'Saving…' : 'Save Changes'}
                </button>
              </>
            )}
          </div>
        )}

      </div>
    </div>
  )
}
