'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Avatar } from '@/components/ui/Avatar'
import { Badge, TierBadge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'
import { api } from '@/lib/api'

const TIER_OPTIONS = ['All', 'PLATINUM', 'GOLD', 'SILVER']

type Donor = {
  id: string
  name: string
  mobile: string
  email: string
  city: string
  tier: string
  total: number
  count: number
  last: string
  cats: string[]
}

type Summary = {
  total?: number
  platinum?: number
  gold?: number
  silver?: number
}

export default function DonorsPage() {
  const [search, setSearch] = useState('')
  const [tier, setTier] = useState('All')
  const [selected, setSelected] = useState<string | null>(null)

  const [donors, setDonors] = useState<Donor[]>([])
  const [summary, setSummary] = useState<Summary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchData() {
      setLoading(true)
      setError(null)
      try {
        const [listRes, summaryRes] = await Promise.allSettled([
          api.donors.list() as Promise<any>,
          api.donors.summary() as Promise<any>,
        ])

        if (listRes.status === 'fulfilled') {
          const res = listRes.value
          const items: any[] = Array.isArray(res) ? res : (res.data ?? res.items ?? [])
          const mapped: Donor[] = items.map((d: any) => ({
            id: d.id ?? d._id ?? '',
            name: d.name ?? d.fullName ?? '',
            mobile: d.mobile ?? d.phone ?? d.phoneNumber ?? '',
            email: d.email ?? '',
            city: d.city ?? d.location ?? '',
            tier: (d.tier ?? d.donorTier ?? 'SILVER').toUpperCase(),
            total: d.total ?? d.totalDonated ?? d.totalAmount ?? 0,
            count: d.count ?? d.donationCount ?? d.donations ?? 0,
            last: d.last ?? d.lastGift ?? d.lastDonation ?? d.lastDonatedAt ?? '',
            cats: Array.isArray(d.cats) ? d.cats : (Array.isArray(d.categories) ? d.categories : []),
          }))
          setDonors(mapped)
        } else {
          throw new Error((listRes.reason as Error)?.message ?? 'Failed to load donors')
        }

        if (summaryRes.status === 'fulfilled') {
          const s = summaryRes.value as any
          setSummary({
            total: s.total ?? s.totalDonors ?? undefined,
            platinum: s.platinum ?? s.PLATINUM ?? undefined,
            gold: s.gold ?? s.GOLD ?? undefined,
            silver: s.silver ?? s.SILVER ?? undefined,
          })
        }
        // summary failure is non-fatal — we fall back to computed counts
      } catch (err: any) {
        setError(err?.message ?? 'Something went wrong')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [])

  // Compute stats: prefer API summary, fall back to counts from the list
  const stats = {
    total: summary?.total ?? donors.length,
    platinum: summary?.platinum ?? donors.filter((d) => d.tier === 'PLATINUM').length,
    gold: summary?.gold ?? donors.filter((d) => d.tier === 'GOLD').length,
    silver: summary?.silver ?? donors.filter((d) => d.tier === 'SILVER').length,
  }

  const filtered = donors.filter((d) => {
    const matchSearch = !search || d.name.toLowerCase().includes(search.toLowerCase()) || d.mobile.includes(search)
    const matchTier = tier === 'All' || d.tier === tier
    return matchSearch && matchTier
  })

  const donor = donors.find((d) => d.id === selected)

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full" style={{ color: 'var(--on-surface-2)' }}>
        <div className="text-[14px]">Loading...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="rounded-2xl border p-6 text-center" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <div className="text-[14px] font-semibold mb-1" style={{ color: 'var(--on-surface)' }}>Failed to load donors</div>
          <div className="text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{error}</div>
        </div>
      </div>
    )
  }

  return (
    <div className="flex gap-5 h-full">
      {/* List panel */}
      <div className="flex-1 min-w-0 space-y-4">
        {/* Stats row */}
        <div className="grid grid-cols-4 gap-3">
          {[
            { label: 'Total', value: stats.total.toLocaleString(), color: '#0E8C76', bg: 'var(--brand-100)' },
            { label: 'Platinum', value: stats.platinum.toLocaleString(), color: '#7C6CF0', bg: 'var(--violet-100)' },
            { label: 'Gold', value: stats.gold.toLocaleString(), color: '#F6A723', bg: 'var(--amber-100)' },
            { label: 'Silver', value: stats.silver.toLocaleString(), color: '#93A29F', bg: 'var(--surface-3)' },
          ].map((s) => (
            <div key={s.label} className="rounded-2xl border p-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
              <div className="w-8 h-8 rounded-xl flex items-center justify-center mb-2" style={{ background: s.bg }}>
                <Icon name="users" size={16} color={s.color} />
              </div>
              <div className="text-[20px] font-bold" style={{ color: 'var(--on-surface)' }}>{s.value}</div>
              <div className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Controls */}
        <div className="flex gap-3 items-center">
          <div className="flex-1 flex items-center gap-2 px-3.5 h-10 rounded-xl border" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <Icon name="search" size={16} color="var(--on-surface-3)" />
            <input
              type="text" placeholder="Search donors..." value={search} onChange={(e) => setSearch(e.target.value)}
              className="flex-1 bg-transparent outline-none text-[13.5px]"
              style={{ color: 'var(--on-surface)' }}
            />
          </div>
          <div className="flex gap-1.5">
            {TIER_OPTIONS.map((t) => (
              <button key={t} onClick={() => setTier(t)}
                className="px-3.5 h-10 rounded-xl text-[12.5px] font-bold transition-all"
                style={{ background: tier === t ? 'var(--primary)' : 'var(--surface)', color: tier === t ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
                {t}
              </button>
            ))}
          </div>
          <Link href="/donors/new"
            className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white"
            style={{ background: 'var(--primary)' }}>
            <Icon name="plus" size={16} color="#fff" /> Add Donor
          </Link>
        </div>

        {/* Table */}
        <div className="rounded-2xl border overflow-hidden" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <table className="w-full">
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface-2)' }}>
                {['Donor', 'Contact', 'Tier', 'Total Donated', 'Last Gift', 'Actions'].map((h) => (
                  <th key={h} className="px-4 py-3 text-left text-[11.5px] font-bold uppercase tracking-wide" style={{ color: 'var(--on-surface-2)' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-[13px]" style={{ color: 'var(--on-surface-2)' }}>
                    No donors found
                  </td>
                </tr>
              ) : (
                filtered.map((d) => (
                  <tr key={d.id}
                    onClick={() => setSelected(d.id === selected ? null : d.id)}
                    className="transition-colors cursor-pointer"
                    style={{ borderBottom: '1px solid var(--border)', background: selected === d.id ? 'var(--brand-50)' : 'transparent' }}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar name={d.name} size={36} />
                        <div>
                          <div className="text-[13.5px] font-bold" style={{ color: 'var(--on-surface)' }}>{d.name}</div>
                          <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.city}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-[12.5px]" style={{ color: 'var(--on-surface)' }}>{d.mobile}</div>
                      <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.email}</div>
                    </td>
                    <td className="px-4 py-3"><TierBadge tier={d.tier} /></td>
                    <td className="px-4 py-3">
                      <div className="text-[13.5px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(d.total, true)}</div>
                      <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.count} donations</div>
                    </td>
                    <td className="px-4 py-3 text-[12.5px]" style={{ color: 'var(--on-surface-2)' }}>{fmt.dayMon(d.last)}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2">
                        <button className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: 'var(--brand-100)' }}>
                          <Icon name="phone" size={14} color="var(--brand-700)" />
                        </button>
                        <button className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: '#DDF5E4' }}>
                          <Icon name="whatsapp" size={14} color="#1FA971" />
                        </button>
                        <button className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: 'var(--sky-100)' }}>
                          <Icon name="mail" size={14} color="var(--sky-500)" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Detail panel */}
      {donor && (
        <div className="w-80 flex-shrink-0 rounded-2xl border p-5 space-y-4 h-fit sticky top-0" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <div className="flex items-center justify-between">
            <h3 className="font-bold" style={{ color: 'var(--on-surface)' }}>Donor Details</h3>
            <button onClick={() => setSelected(null)}>
              <Icon name="x" size={18} color="var(--on-surface-2)" />
            </button>
          </div>
          <div className="text-center py-4">
            <Avatar name={donor.name} size={72} className="mx-auto mb-3" />
            <div className="font-bold text-[17px]" style={{ color: 'var(--on-surface)' }}>{donor.name}</div>
            <div className="text-[12.5px] mb-2" style={{ color: 'var(--on-surface-2)' }}>{donor.city}</div>
            <TierBadge tier={donor.tier} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-xl p-3" style={{ background: 'var(--surface-2)' }}>
              <div className="text-[11px] font-semibold mb-0.5" style={{ color: 'var(--on-surface-2)' }}>Total Donated</div>
              <div className="text-[16px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(donor.total, true)}</div>
            </div>
            <div className="rounded-xl p-3" style={{ background: 'var(--surface-2)' }}>
              <div className="text-[11px] font-semibold mb-0.5" style={{ color: 'var(--on-surface-2)' }}>Donations</div>
              <div className="text-[16px] font-bold" style={{ color: 'var(--on-surface)' }}>{donor.count}</div>
            </div>
          </div>
          <div className="space-y-2.5">
            <div className="flex items-center gap-2 text-[12.5px]">
              <Icon name="phone" size={14} color="var(--on-surface-3)" />
              <span style={{ color: 'var(--on-surface)' }}>{donor.mobile}</span>
            </div>
            <div className="flex items-center gap-2 text-[12.5px]">
              <Icon name="mail" size={14} color="var(--on-surface-3)" />
              <span style={{ color: 'var(--on-surface)' }}>{donor.email}</span>
            </div>
          </div>
          <div>
            <div className="text-[11px] font-bold uppercase mb-2" style={{ color: 'var(--on-surface-3)' }}>Categories</div>
            <div className="flex flex-wrap gap-1.5">
              {donor.cats.map((c) => <Badge key={c} variant="green">{c}</Badge>)}
            </div>
          </div>
          <div className="grid grid-cols-3 gap-2 pt-2">
            {[
              { icon: 'phone', label: 'Call', bg: 'var(--brand-100)', c: 'var(--brand-700)' },
              { icon: 'whatsapp', label: 'WhatsApp', bg: '#DDF5E4', c: '#1FA971' },
              { icon: 'mail', label: 'Email', bg: 'var(--sky-100)', c: 'var(--sky-500)' },
            ].map((a) => (
              <button key={a.label} className="flex flex-col items-center gap-1.5 py-2.5 rounded-xl"
                style={{ background: a.bg }}>
                <Icon name={a.icon} size={18} color={a.c} />
                <span className="text-[10.5px] font-bold" style={{ color: a.c }}>{a.label}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
