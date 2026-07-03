'use client'

import { useState, useEffect } from 'react'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'
import { api } from '@/lib/api'

const MODE_BADGE: Record<string, { label: string; variant: 'green' | 'sky' | 'amber' | 'gray' | 'violet' }> = {
  UPI: { label: 'UPI', variant: 'green' },
  BANK_TRANSFER: { label: 'Bank', variant: 'sky' },
  CASH: { label: 'Cash', variant: 'amber' },
  CHEQUE: { label: 'Cheque', variant: 'violet' },
  ONLINE: { label: 'Online', variant: 'sky' },
}

interface Donation {
  id: string
  receiptNo: string
  donor: string
  type: string
  amount: number
  mode: string
  status: string
  date: string
}

interface DonationSummary {
  collectedThisMonth?: number
  collectedThisYear?: number
  donationsCount?: number
  donationsThisWeek?: number
  averageGift?: number
  uniqueDonors?: number
}

export default function DonationsPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [donations, setDonations] = useState<Donation[]>([])
  const [summary, setSummary] = useState<DonationSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const types = ['All', 'General Donation', 'Education Fund', 'Healthcare', 'Food & Nutrition', 'Child Sponsorship']

  useEffect(() => {
    async function fetchData() {
      setLoading(true)
      setError(null)
      try {
        const [listRes, summaryRes] = await Promise.allSettled([
          api.donations.list(),
          api.donations.summary(),
        ])

        if (listRes.status === 'fulfilled') {
          const res = listRes.value as any
          const items: Donation[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
          setDonations(items)
        } else {
          throw new Error((listRes.reason as Error)?.message ?? 'Failed to load donations')
        }

        if (summaryRes.status === 'fulfilled') {
          setSummary(summaryRes.value as DonationSummary)
        }
        // summary failure is non-fatal — stats will fall back to computed values
      } catch (err: any) {
        setError(err?.message ?? 'Failed to load donations')
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  const filtered = donations.filter((d) => {
    const matchSearch = !search || d.donor.toLowerCase().includes(search.toLowerCase()) || d.receiptNo.includes(search)
    const matchType = filter === 'All' || d.type === filter
    return matchSearch && matchType
  })

  const totalAmount = filtered.reduce((s, d) => s + d.amount, 0)

  // Stats: prefer API summary values, fall back to computing from list
  const collectedThisMonth = summary?.collectedThisMonth ?? donations.reduce((s, d) => s + d.amount, 0)
  const collectedThisYear = summary?.collectedThisYear ?? 0
  const donationsCount = summary?.donationsCount ?? donations.length
  const donationsThisWeek = summary?.donationsThisWeek ?? 0
  const averageGift = summary?.averageGift ?? (donations.length > 0 ? Math.round(donations.reduce((s, d) => s + d.amount, 0) / donations.length) : 0)
  const uniqueDonors = summary?.uniqueDonors ?? new Set(donations.map((d) => d.donor)).size

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
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: 'Collected This Month', value: fmt.inr(collectedThisMonth, true), icon: 'wallet', bg: 'linear-gradient(135deg, #0B6E5D, #14A98C)', text: '#fff', sub: fmt.inr(collectedThisYear, true) + ' this year' },
          { label: 'Donations Count', value: String(donationsCount), icon: 'receipt', bg: 'var(--surface)', text: 'var(--on-surface)', sub: `${donationsThisWeek} this week` },
          { label: 'Average Gift', value: fmt.inr(averageGift, true), icon: 'trendUp', bg: 'var(--surface)', text: 'var(--on-surface)', sub: '+4% vs last month' },
          { label: 'Unique Donors', value: String(uniqueDonors), icon: 'users', bg: 'var(--surface)', text: 'var(--on-surface)', sub: 'this month' },
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
          <input type="text" placeholder="Search by donor or receipt..." value={search} onChange={(e) => setSearch(e.target.value)}
            className="flex-1 bg-transparent outline-none text-[13.5px]" style={{ color: 'var(--on-surface)' }} />
        </div>
        <div className="flex gap-1.5 flex-wrap">
          {types.map((t) => (
            <button key={t} onClick={() => setFilter(t)}
              className="px-3 h-10 rounded-xl text-[12px] font-bold transition-all"
              style={{ background: filter === t ? 'var(--primary)' : 'var(--surface)', color: filter === t ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
              {t}
            </button>
          ))}
        </div>
        <a href="/donations/new"
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white flex-shrink-0"
          style={{ background: 'var(--primary)' }}>
          <Icon name="plus" size={16} color="#fff" /> Record Donation
        </a>
      </div>

      {/* Table */}
      <div className="rounded-2xl border overflow-hidden" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
        <div className="flex items-center justify-between px-5 py-3 border-b" style={{ borderColor: 'var(--border)', background: 'var(--surface-2)' }}>
          <span className="text-[12px] font-semibold" style={{ color: 'var(--on-surface-2)' }}>{filtered.length} donations · {fmt.inr(totalAmount, true)} total</span>
          <button className="flex items-center gap-1.5 text-[12.5px] font-bold" style={{ color: 'var(--primary)' }}>
            <Icon name="download" size={14} /> Export
          </button>
        </div>
        <table className="w-full">
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              {['Receipt No', 'Donor', 'Type', 'Amount', 'Mode', 'Date', 'Status', ''].map((h) => (
                <th key={h} className="px-4 py-3 text-left text-[11.5px] font-bold uppercase tracking-wide" style={{ color: 'var(--on-surface-2)' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((d) => {
              const mb = MODE_BADGE[d.mode] ?? { label: d.mode, variant: 'gray' as const }
              return (
                <tr key={d.id} className="transition-colors hover:bg-[var(--surface-2)]" style={{ borderBottom: '1px solid var(--border)' }}>
                  <td className="px-4 py-3 text-[12.5px] font-mono font-bold" style={{ color: 'var(--primary)' }}>{d.receiptNo}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <Avatar name={d.donor} size={30} />
                      <span className="text-[13px] font-semibold" style={{ color: 'var(--on-surface)' }}>{d.donor}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.type}</td>
                  <td className="px-4 py-3 text-[14px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(d.amount, true)}</td>
                  <td className="px-4 py-3"><Badge variant={mb.variant}>{mb.label}</Badge></td>
                  <td className="px-4 py-3 text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{fmt.dayMon(d.date)}</td>
                  <td className="px-4 py-3"><Badge variant="green">Completed</Badge></td>
                  <td className="px-4 py-3">
                    <a href={`/donations/${d.id}/receipt`}
                      className="flex items-center gap-1.5 px-3 h-7 rounded-lg text-[12px] font-bold"
                      style={{ background: 'var(--brand-100)', color: 'var(--brand-700)' }}>
                      <Icon name="receipt" size={12} color="var(--brand-700)" /> Receipt
                    </a>
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
