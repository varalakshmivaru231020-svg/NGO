'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'
import { api } from '@/lib/api'

const MODE_BADGE: Record<string, { label: string; variant: 'green' | 'sky' | 'amber' | 'gray' | 'violet' }> = {
  UPI: { label: 'UPI', variant: 'green' },
  BANK_TRANSFER: { label: 'Bank', variant: 'sky' },
  CASH: { label: 'Cash', variant: 'amber' },
  CHEQUE: { label: 'Cheque', variant: 'violet' },
  CARD: { label: 'Card', variant: 'sky' },
}

const CATEGORY_FILTERS = ['All', 'Salaries', 'Utilities', 'Maintenance', 'Program & Welfare', 'Administrative', 'Transport', 'Miscellaneous']

interface ExpenseCategoryRef { id: string; key: string; label: string }

interface Expense {
  id: string
  voucherNo: string
  paidTo: string
  purpose: string
  category?: ExpenseCategoryRef | string
  amount: number
  paymentMode: string
  status: string
  date: string
}

interface ExpenseSummary {
  today?: { amount: number; count: number }
  month?: { amount: number; count: number }
  year?: { amount: number; count: number }
}

function categoryLabel(c: Expense['category']): string {
  if (!c) return '—'
  return typeof c === 'string' ? c : c.label
}

export default function ExpensesPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [expenses, setExpenses] = useState<Expense[]>([])
  const [summary, setSummary] = useState<ExpenseSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchData() {
      setLoading(true)
      setError(null)
      try {
        const [listRes, summaryRes] = await Promise.allSettled([
          api.expenses.list(),
          api.expenses.summary(),
        ])

        if (listRes.status === 'fulfilled') {
          const res = listRes.value as any
          const items: Expense[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
          setExpenses(items)
        } else {
          throw new Error((listRes.reason as Error)?.message ?? 'Failed to load expenses')
        }

        if (summaryRes.status === 'fulfilled') {
          setSummary(summaryRes.value as ExpenseSummary)
        }
        // summary failure is non-fatal — stats will fall back to computed values
      } catch (err: any) {
        setError(err?.message ?? 'Failed to load expenses')
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  const filtered = expenses.filter((e) => {
    const matchSearch = !search || e.paidTo.toLowerCase().includes(search.toLowerCase()) || e.voucherNo.includes(search)
    const matchCategory = filter === 'All' || categoryLabel(e.category) === filter
    return matchSearch && matchCategory
  })

  const totalAmount = filtered.reduce((s, e) => s + e.amount, 0)

  const monthTotal = summary?.month?.amount ?? expenses.reduce((s, e) => s + e.amount, 0)
  const yearTotal = summary?.year?.amount ?? 0
  const monthCount = summary?.month?.count ?? expenses.length
  const todayTotal = summary?.today?.amount ?? 0
  const todayCount = summary?.today?.count ?? 0

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: 'var(--on-surface-2)' }}>
        Loading...
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: '#e53e3e' }}>
        Error: {error}
      </div>
    )
  }

  return (
    <div className="space-y-5">
      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Paid Out This Month', value: fmt.inr(monthTotal, true), icon: 'trendDown', bg: 'linear-gradient(135deg, #C2410C, #F97316)', text: '#fff', sub: fmt.inr(yearTotal, true) + ' this year' },
          { label: 'Expenses Count', value: String(monthCount), icon: 'receipt', bg: 'var(--surface)', text: 'var(--on-surface)', sub: `${filtered.length} shown` },
          { label: 'Paid Out Today', value: fmt.inr(todayTotal, true), icon: 'rupee', bg: 'var(--surface)', text: 'var(--on-surface)', sub: `${todayCount} vouchers` },
        ].map((s, i) => (
          <div key={i} className="rounded-2xl border p-4" style={{ background: s.bg, borderColor: 'var(--border)', boxShadow: 'var(--shadow-md)' }}>
            <div className="text-[11.5px] font-semibold mb-1" style={{ color: i === 0 ? 'rgba(255,255,255,0.8)' : 'var(--on-surface-2)' }}>{s.label}</div>
            <div className="text-[22px] font-bold" style={{ color: s.text }}>{s.value}</div>
            <div className="text-[11.5px] mt-1" style={{ color: i === 0 ? 'rgba(255,255,255,0.65)' : 'var(--on-surface-3)' }}>{s.sub}</div>
          </div>
        ))}
      </div>

      {/* Controls */}
      <div className="flex gap-3 items-center flex-wrap">
        <div className="flex-1 min-w-[200px] flex items-center gap-2 px-3.5 h-10 rounded-xl border" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <Icon name="search" size={16} color="var(--on-surface-3)" />
          <input type="text" placeholder="Search by payee or voucher no..." value={search} onChange={(e) => setSearch(e.target.value)}
            className="flex-1 bg-transparent outline-none text-[13.5px]" style={{ color: 'var(--on-surface)' }} />
        </div>
        <div className="flex gap-1.5 flex-wrap">
          {CATEGORY_FILTERS.map((t) => (
            <button key={t} onClick={() => setFilter(t)}
              className="px-3 h-10 rounded-xl text-[12px] font-bold transition-all"
              style={{ background: filter === t ? 'var(--primary)' : 'var(--surface)', color: filter === t ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
              {t}
            </button>
          ))}
        </div>
        <Link href="/expenses/new"
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white flex-shrink-0"
          style={{ background: 'var(--primary)' }}>
          <Icon name="plus" size={16} color="#fff" /> Record Expense
        </Link>
      </div>

      {/* Table */}
      <div className="rounded-2xl border overflow-hidden" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
        <div className="flex items-center justify-between px-5 py-3 border-b" style={{ borderColor: 'var(--border)', background: 'var(--surface-2)' }}>
          <span className="text-[12px] font-semibold" style={{ color: 'var(--on-surface-2)' }}>{filtered.length} expenses · {fmt.inr(totalAmount, true)} total</span>
        </div>
        <table className="w-full">
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              {['Voucher No', 'Paid To', 'Category', 'Amount', 'Mode', 'Date', 'Status', ''].map((h) => (
                <th key={h} className="px-4 py-3 text-left text-[11.5px] font-bold uppercase tracking-wide" style={{ color: 'var(--on-surface-2)' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((e) => {
              const mb = MODE_BADGE[e.paymentMode] ?? { label: e.paymentMode, variant: 'gray' as const }
              return (
                <tr key={e.id} className="transition-colors hover:bg-[var(--surface-2)]" style={{ borderBottom: '1px solid var(--border)' }}>
                  <td className="px-4 py-3 text-[12.5px] font-mono font-bold" style={{ color: 'var(--primary)' }}>{e.voucherNo}</td>
                  <td className="px-4 py-3 text-[13px] font-semibold" style={{ color: 'var(--on-surface)' }}>{e.paidTo}</td>
                  <td className="px-4 py-3 text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{categoryLabel(e.category)}</td>
                  <td className="px-4 py-3 text-[14px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(e.amount, true)}</td>
                  <td className="px-4 py-3"><Badge variant={mb.variant}>{mb.label}</Badge></td>
                  <td className="px-4 py-3 text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{fmt.dayMon(e.date)}</td>
                  <td className="px-4 py-3"><Badge variant="green">{e.status === 'COMPLETED' ? 'Completed' : e.status}</Badge></td>
                  <td className="px-4 py-3">
                    <Link href={`/expenses/${e.id}/voucher`}
                      className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold"
                      style={{ background: 'var(--brand-100)', color: 'var(--brand-700)' }}>
                      <Icon name="receipt" size={12} color="var(--brand-700)" /> Voucher
                    </Link>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
