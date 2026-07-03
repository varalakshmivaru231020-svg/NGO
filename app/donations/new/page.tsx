'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { api } from '@/lib/api'
import { Icon } from '@/components/ui/Icon'

const PAYMENT_MODES = [
  { value: 'CASH', label: 'Cash' },
  { value: 'UPI', label: 'UPI' },
  { value: 'BANK_TRANSFER', label: 'Bank Transfer' },
  { value: 'CHEQUE', label: 'Cheque' },
  { value: 'PAYMENT_LINK', label: 'Payment Link' },
]

interface Donor { id: string; name: string; city?: string; tier?: string }
interface DonationType { id: string; key: string; label: string }

export default function RecordDonationPage() {
  const router = useRouter()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [donors, setDonors] = useState<Donor[]>([])
  const [donationTypes, setDonationTypes] = useState<DonationType[]>([])
  const [loadingData, setLoadingData] = useState(true)
  const [showDropdown, setShowDropdown] = useState(false)
  const [form, setForm] = useState({
    donorSearch: '',
    selectedDonorId: '',
    selectedDonorName: '',
    typeId: '',
    amount: '',
    paymentMode: 'CASH',
    date: new Date().toISOString().split('T')[0],
    reference: '',
    chequeNo: '',
    bankName: '',
    notes: '',
    taxExemption: false,
  })

  const set = (k: string, v: string | boolean) => setForm(f => ({ ...f, [k]: v }))

  useEffect(() => {
    async function loadData() {
      try {
        const [donorsRes, typesRes] = await Promise.allSettled([
          api.donors.list({ limit: '200' }),
          api.donations.types(),
        ])

        if (donorsRes.status === 'fulfilled') {
          const res = donorsRes.value as any
          const list: Donor[] = Array.isArray(res) ? res : (res.data ?? [])
          setDonors(list)
        }

        if (typesRes.status === 'fulfilled') {
          const res = typesRes.value as any
          const list: DonationType[] = Array.isArray(res) ? res : (res.data ?? res)
          setDonationTypes(list)
          if (list.length > 0) set('typeId', list[0].id)
        }
      } catch (e) {
        console.error('Failed to load form data:', e)
      } finally {
        setLoadingData(false)
      }
    }
    loadData()
  }, [])

  const filteredDonors = donors.filter(d =>
    !form.donorSearch || d.name.toLowerCase().includes(form.donorSearch.toLowerCase())
  )

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    if (!form.selectedDonorId) { setError('Please select a donor from the list below'); return }
    if (!form.typeId) { setError('Please select a donation type'); return }
    const amount = parseInt(form.amount)
    if (!form.amount || isNaN(amount) || amount < 1) { setError('Please enter a valid amount'); return }

    setSaving(true)
    try {
      await api.donations.create({
        donorId: form.selectedDonorId,
        typeId: form.typeId,
        amount,
        paymentMode: form.paymentMode,
        date: form.date,
        reference: form.reference || undefined,
        chequeNo: form.chequeNo || undefined,
        bankName: form.bankName || undefined,
        notes: form.notes || undefined,
        taxExemption: form.taxExemption,
      })
      router.push('/donations')
    } catch (err: any) {
      setError(err?.message ?? 'Failed to record donation. Please try again.')
      setSaving(false)
    }
  }

  if (loadingData) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 300, color: 'var(--on-surface-2)', fontSize: 14 }}>
        Loading form data…
      </div>
    )
  }

  return (
    <div style={{ maxWidth: 720, margin: '0 auto' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
        <button onClick={() => router.back()}
          style={{ background: 'var(--surface-2)', border: 'none', cursor: 'pointer', color: 'var(--on-surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', width: 36, height: 36, borderRadius: 10 }}>
          <Icon name="chevL" size={20} />
        </button>
        <div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--on-surface)' }}>Record Donation</h1>
          <p style={{ margin: 0, fontSize: 13, color: 'var(--on-surface-2)' }}>Log a new donation and generate a receipt</p>
        </div>
      </div>

      {error && (
        <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)', color: '#dc2626', padding: '12px 16px', borderRadius: 12, marginBottom: 16, fontSize: 14, fontWeight: 600 }}>
          {error}
        </div>
      )}

      <form onSubmit={submit}>
        {/* Donor */}
        <div style={card}>
          <h3 style={secTitle}>Donor *</h3>
          {form.selectedDonorName ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderRadius: 12, background: 'var(--brand-100,#d6f3ec)', border: '1.5px solid var(--primary)' }}>
              <Icon name="check" size={16} color="var(--primary)" />
              <span style={{ fontWeight: 700, color: 'var(--primary)', fontSize: 14, flex: 1 }}>{form.selectedDonorName}</span>
              <button type="button"
                onClick={() => { set('selectedDonorId', ''); set('selectedDonorName', ''); set('donorSearch', '') }}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--on-surface-2)', display: 'flex', padding: 4 }}>
                <Icon name="x" size={14} />
              </button>
            </div>
          ) : (
            <div style={{ position: 'relative' }}>
              <input
                value={form.donorSearch}
                onFocus={() => setShowDropdown(true)}
                onChange={e => { set('donorSearch', e.target.value); set('selectedDonorId', ''); setShowDropdown(true) }}
                onBlur={() => setTimeout(() => setShowDropdown(false), 150)}
                placeholder="Search existing donor by name…"
                style={{ ...inp, paddingLeft: 40 }}
              />
              <span style={{ position: 'absolute', top: '50%', left: 12, transform: 'translateY(-50%)', pointerEvents: 'none' }}>
                <Icon name="search" size={16} color="var(--on-surface-3)" />
              </span>
              {showDropdown && (
                <div style={{ position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 50, marginTop: 4, border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden', background: 'var(--surface)', boxShadow: '0 8px 24px rgba(0,0,0,0.12)' }}>
                  {filteredDonors.length === 0 ? (
                    <div style={{ padding: '12px 16px', fontSize: 13, color: 'var(--on-surface-2)' }}>
                      {donors.length === 0 ? 'No donors loaded' : `No donors match "${form.donorSearch}"`}
                    </div>
                  ) : (
                    filteredDonors.slice(0, 8).map(d => (
                      <button key={d.id} type="button"
                        onMouseDown={() => { set('selectedDonorId', d.id); set('selectedDonorName', d.name); set('donorSearch', d.name); setShowDropdown(false) }}
                        style={{ display: 'flex', width: '100%', textAlign: 'left', padding: '10px 16px', background: 'transparent', border: 'none', borderBottom: '1px solid var(--border)', cursor: 'pointer', gap: 10, alignItems: 'center' }}>
                        <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'var(--brand-100,#d6f3ec)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 800, color: 'var(--primary)', flexShrink: 0 }}>
                          {d.name.split(' ').map((p: string) => p[0]).slice(0,2).join('')}
                        </div>
                        <div>
                          <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--on-surface)' }}>{d.name}</div>
                          {d.city && <div style={{ fontSize: 12, color: 'var(--on-surface-2)' }}>{d.city} · {d.tier}</div>}
                        </div>
                      </button>
                    ))
                  )}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Donation Type */}
        <div style={card}>
          <h3 style={secTitle}>Donation Type *</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {donationTypes.map(t => (
              <button key={t.id} type="button"
                onClick={() => set('typeId', t.id)}
                style={{
                  padding: '8px 16px', borderRadius: 10, fontSize: 13, fontWeight: 700, cursor: 'pointer',
                  border: form.typeId === t.id ? '2px solid var(--primary)' : '1.5px solid var(--border)',
                  background: form.typeId === t.id ? 'var(--brand-100,#d6f3ec)' : 'var(--surface-2)',
                  color: form.typeId === t.id ? 'var(--primary)' : 'var(--on-surface-2)',
                }}>
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Details */}
        <div style={card}>
          <h3 style={secTitle}>Donation Details</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
            <Field label="Amount (₹) *">
              <input type="number" value={form.amount} onChange={e => set('amount', e.target.value)}
                required min={1} placeholder="50000" style={inp} />
            </Field>
            <Field label="Date">
              <input type="date" value={form.date} onChange={e => set('date', e.target.value)} style={inp} />
            </Field>
          </div>

          <div style={{ marginBottom: 16 }}>
            <Field label="Payment Mode">
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {PAYMENT_MODES.map(m => (
                  <button key={m.value} type="button"
                    onClick={() => set('paymentMode', m.value)}
                    style={{
                      padding: '7px 14px', borderRadius: 10, fontSize: 13, fontWeight: 600, cursor: 'pointer',
                      border: form.paymentMode === m.value ? '2px solid var(--primary)' : '1.5px solid var(--border)',
                      background: form.paymentMode === m.value ? 'var(--brand-100,#d6f3ec)' : 'var(--surface-2)',
                      color: form.paymentMode === m.value ? 'var(--primary)' : 'var(--on-surface-2)',
                    }}>
                    {m.label}
                  </button>
                ))}
              </div>
            </Field>
          </div>

          {form.paymentMode === 'CHEQUE' && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16, padding: 16, background: 'var(--surface-2)', borderRadius: 10, border: '1px solid var(--border)' }}>
              <Field label="Cheque Number">
                <input value={form.chequeNo} onChange={e => set('chequeNo', e.target.value)} placeholder="123456" style={inp} />
              </Field>
              <Field label="Bank Name">
                <input value={form.bankName} onChange={e => set('bankName', e.target.value)} placeholder="State Bank of India" style={inp} />
              </Field>
            </div>
          )}

          {(form.paymentMode === 'BANK_TRANSFER' || form.paymentMode === 'UPI') && (
            <div style={{ marginBottom: 16 }}>
              <Field label={form.paymentMode === 'UPI' ? 'UPI Transaction ID' : 'Bank Reference / UTR'}>
                <input value={form.reference} onChange={e => set('reference', e.target.value)} placeholder="UTR123456789" style={inp} />
              </Field>
            </div>
          )}

          <div style={{ marginBottom: 16 }}>
            <Field label="Internal Notes">
              <textarea value={form.notes} onChange={e => set('notes', e.target.value)} rows={2}
                placeholder="Any notes about this donation…" style={{ ...inp, resize: 'vertical' }} />
            </Field>
          </div>

          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', userSelect: 'none' }}>
            <input type="checkbox" checked={form.taxExemption} onChange={e => set('taxExemption', e.target.checked)}
              style={{ width: 16, height: 16, accentColor: 'var(--primary)' }} />
            <span style={{ fontSize: 14, color: 'var(--on-surface)', fontWeight: 500 }}>Eligible for 80G tax exemption</span>
          </label>
        </div>

        {/* Amount preview */}
        {form.amount && (
          <div style={{ ...card, borderColor: 'var(--primary)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <p style={{ margin: 0, fontSize: 11, color: 'var(--on-surface-2)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Amount</p>
              <p style={{ margin: 0, fontSize: 30, fontWeight: 800, color: 'var(--primary)' }}>
                ₹{parseInt(form.amount || '0').toLocaleString('en-IN')}
              </p>
            </div>
            {form.taxExemption && (
              <div style={{ padding: '8px 16px', background: 'var(--brand-100,#d6f3ec)', borderRadius: 10, color: 'var(--primary)', fontSize: 13, fontWeight: 700 }}>
                80G Eligible
              </div>
            )}
          </div>
        )}

        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end', paddingBottom: 32 }}>
          <button type="button" onClick={() => router.back()}
            style={{ padding: '10px 24px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>
            Cancel
          </button>
          <button type="submit" disabled={saving}
            style={{ padding: '10px 28px', borderRadius: 10, border: 'none', background: 'var(--primary)', color: '#fff', cursor: saving ? 'not-allowed' : 'pointer', fontWeight: 700, opacity: saving ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: 8 }}>
            {saving ? 'Recording…' : <><Icon name="receipt" size={16} color="#fff" /> Record Donation</>}
          </button>
        </div>
      </form>
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <label style={{ fontSize: 11, fontWeight: 700, color: 'var(--on-surface-2)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
      {children}
    </div>
  )
}

const card: React.CSSProperties = {
  background: 'var(--surface)',
  borderRadius: 16,
  border: '1px solid var(--border)',
  padding: '20px 24px',
  marginBottom: 20,
}

const secTitle: React.CSSProperties = {
  margin: '0 0 16px',
  fontSize: 11, fontWeight: 700,
  color: 'var(--primary)',
  textTransform: 'uppercase',
  letterSpacing: '0.06em',
}

const inp: React.CSSProperties = {
  width: '100%', padding: '9px 12px', borderRadius: 10,
  border: '1.5px solid var(--border)', background: 'var(--surface-2)',
  color: 'var(--on-surface)', fontSize: 14, outline: 'none',
  boxSizing: 'border-box',
}
