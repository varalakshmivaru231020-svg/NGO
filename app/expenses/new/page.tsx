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
  { value: 'CARD', label: 'Card' },
]

interface ExpenseCategory { id: string; key: string; label: string }

export default function RecordExpensePage() {
  const router = useRouter()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [categories, setCategories] = useState<ExpenseCategory[]>([])
  const [loadingData, setLoadingData] = useState(true)
  const [form, setForm] = useState({
    categoryId: '',
    paidTo: '',
    purpose: '',
    amount: '',
    paymentMode: 'CASH',
    date: new Date().toISOString().split('T')[0],
    reference: '',
    chequeNo: '',
    bankName: '',
    preparedBy: '',
    receivedBy: '',
    notes: '',
  })

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }))

  useEffect(() => {
    async function loadData() {
      try {
        const res = await api.expenseCategories.list() as any
        const list: ExpenseCategory[] = Array.isArray(res) ? res : (res.data ?? res)
        setCategories(list)
        if (list.length > 0) set('categoryId', list[0].id)
      } catch (e) {
        console.error('Failed to load expense categories:', e)
      } finally {
        setLoadingData(false)
      }
    }
    loadData()
  }, [])

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    if (!form.categoryId) { setError('Please select a category'); return }
    if (!form.paidTo.trim()) { setError('Please enter who this was paid to'); return }
    if (!form.purpose.trim()) { setError('Please describe what this expense was for'); return }
    const amount = parseInt(form.amount)
    if (!form.amount || isNaN(amount) || amount < 1) { setError('Please enter a valid amount'); return }

    setSaving(true)
    try {
      await api.expenses.create({
        categoryId: form.categoryId,
        paidTo: form.paidTo.trim(),
        purpose: form.purpose.trim(),
        amount,
        paymentMode: form.paymentMode,
        date: form.date,
        reference: form.reference || undefined,
        chequeNo: form.chequeNo || undefined,
        bankName: form.bankName || undefined,
        preparedBy: form.preparedBy || undefined,
        receivedBy: form.receivedBy || undefined,
        notes: form.notes || undefined,
      })
      router.push('/expenses')
    } catch (err: any) {
      setError(err?.message ?? 'Failed to record expense. Please try again.')
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
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--on-surface)' }}>Record Expense</h1>
          <p style={{ margin: 0, fontSize: 13, color: 'var(--on-surface-2)' }}>Log a payment voucher for an outgoing expense</p>
        </div>
      </div>

      {error && (
        <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)', color: '#dc2626', padding: '12px 16px', borderRadius: 12, marginBottom: 16, fontSize: 14, fontWeight: 600 }}>
          {error}
        </div>
      )}

      <form onSubmit={submit}>
        {/* Category */}
        <div style={card}>
          <h3 style={secTitle}>Category *</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {categories.map(c => (
              <button key={c.id} type="button"
                onClick={() => set('categoryId', c.id)}
                style={{
                  padding: '8px 16px', borderRadius: 10, fontSize: 13, fontWeight: 700, cursor: 'pointer',
                  border: form.categoryId === c.id ? '2px solid var(--primary)' : '1.5px solid var(--border)',
                  background: form.categoryId === c.id ? 'var(--brand-100,#d6f3ec)' : 'var(--surface-2)',
                  color: form.categoryId === c.id ? 'var(--primary)' : 'var(--on-surface-2)',
                }}>
                {c.label}
              </button>
            ))}
          </div>
        </div>

        {/* Voucher details */}
        <div style={card}>
          <h3 style={secTitle}>Voucher Details</h3>
          <div style={{ marginBottom: 16 }}>
            <Field label="Paid To *">
              <input value={form.paidTo} onChange={e => set('paidTo', e.target.value)}
                placeholder="Vendor / staff / payee name" style={inp} />
            </Field>
          </div>
          <div style={{ marginBottom: 16 }}>
            <Field label="Being Paid Towards *">
              <textarea value={form.purpose} onChange={e => set('purpose', e.target.value)} rows={2}
                placeholder="What is this payment for?" style={{ ...inp, resize: 'vertical' }} />
            </Field>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
            <Field label="Amount (₹) *">
              <input type="number" value={form.amount} onChange={e => set('amount', e.target.value)}
                required min={1} placeholder="5000" style={inp} />
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
        </div>

        {/* Signatures */}
        <div style={card}>
          <h3 style={secTitle}>Prepared / Received</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
            <Field label="Prepared By">
              <input value={form.preparedBy} onChange={e => set('preparedBy', e.target.value)} placeholder="Your name" style={inp} />
            </Field>
            <Field label="Received By">
              <input value={form.receivedBy} onChange={e => set('receivedBy', e.target.value)} placeholder="Payee's name" style={inp} />
            </Field>
          </div>
          <Field label="Internal Notes">
            <textarea value={form.notes} onChange={e => set('notes', e.target.value)} rows={2}
              placeholder="Any notes about this expense…" style={{ ...inp, resize: 'vertical' }} />
          </Field>
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
          </div>
        )}

        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end', paddingBottom: 32 }}>
          <button type="button" onClick={() => router.back()}
            style={{ padding: '10px 24px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--on-surface)', cursor: 'pointer', fontWeight: 600 }}>
            Cancel
          </button>
          <button type="submit" disabled={saving}
            style={{ padding: '10px 28px', borderRadius: 10, border: 'none', background: 'var(--primary)', color: '#fff', cursor: saving ? 'not-allowed' : 'pointer', fontWeight: 700, opacity: saving ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: 8 }}>
            {saving ? 'Recording…' : <><Icon name="receipt" size={16} color="#fff" /> Record Expense</>}
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
