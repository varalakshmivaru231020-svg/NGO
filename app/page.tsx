'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { KPICard } from '@/components/ui/KPICard'
import { TrendChart } from '@/components/ui/TrendChart'
import { DonutChart } from '@/components/ui/DonutChart'
import { Avatar } from '@/components/ui/Avatar'
import { Badge, TierBadge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'

// Sample data matching the design (replace with api.donations.summary() etc.)
const MONTHLY = [
  { m: 'Jul', v: 380000 }, { m: 'Aug', v: 420000 }, { m: 'Sep', v: 310000 },
  { m: 'Oct', v: 560000 }, { m: 'Nov', v: 490000 }, { m: 'Dec', v: 640000 },
  { m: 'Jan', v: 520000 }, { m: 'Feb', v: 710000 }, { m: 'Mar', v: 480000 },
  { m: 'Apr', v: 820000 }, { m: 'May', v: 590000 }, { m: 'Jun', v: 742000 },
]

const DONUT_DATA = [
  { label: 'Education', value: 42, color: '#0E8C76' },
  { label: 'General', value: 28, color: '#F6A723' },
  { label: 'Healthcare', value: 18, color: '#7C6CF0' },
  { label: 'Food', value: 12, color: '#2D9CDB' },
]

const RECENT_DONORS = [
  { name: 'Rajesh Khanna', city: 'Mumbai', tier: 'PLATINUM', amount: 500000, date: '2026-05-28' },
  { name: 'Meera Nambiar', city: 'Kochi', tier: 'PLATINUM', amount: 300000, date: '2026-06-12' },
  { name: 'Priya Sharma', city: 'Pune', tier: 'GOLD', amount: 150000, date: '2026-06-01' },
  { name: 'Ananya Patel', city: 'Ahmedabad', tier: 'GOLD', amount: 75000, date: '2026-06-08' },
  { name: 'Arjun Mehta', city: 'Bengaluru', tier: 'GOLD', amount: 100000, date: '2026-05-15' },
]

export default function DashboardPage() {
  const [period, setPeriod] = useState<'7D' | '1M' | '3M' | '1Y'>('1Y')

  return (
    <div className="space-y-6">
      {/* Welcome banner */}
      <div
        className="rounded-3xl p-6 text-white relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, var(--brand-700) 0%, var(--brand-500) 100%)' }}
      >
        <div className="absolute top-0 right-0 w-64 h-64 rounded-full opacity-10"
          style={{ background: 'white', transform: 'translate(30%, -30%)' }} />
        <div className="relative z-10">
          <p className="text-white/80 text-[13px] font-semibold mb-1">Good morning,</p>
          <h2 className="text-2xl font-bold mb-4">Farhan Ansari</h2>
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-white/15 rounded-2xl p-3.5">
              <div className="text-white/80 text-[11.5px] font-semibold mb-1">Today's Donations</div>
              <div className="text-[22px] font-bold">{fmt.inr(120000, true)}</div>
            </div>
            <div className="bg-white/15 rounded-2xl p-3.5">
              <div className="text-white/80 text-[11.5px] font-semibold mb-1">This Month</div>
              <div className="text-[22px] font-bold">{fmt.inr(7420000, true)}</div>
            </div>
            <div className="bg-white/15 rounded-2xl p-3.5">
              <div className="text-white/80 text-[11.5px] font-semibold mb-1">This Year</div>
              <div className="text-[22px] font-bold">{fmt.inr(56100000, true)}</div>
            </div>
          </div>
        </div>
      </div>

      {/* KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KPICard label="Total Donors" value="1,247" icon="users" tint="#0E8C76" bg="var(--brand-100)" delta="+12" />
        <KPICard label="Total Raised" value={fmt.inr(56100000, true)} icon="wallet" tint="#F6A723" bg="var(--amber-100)" delta="+8%" />
        <KPICard label="Active Students" value="312" icon="grad" tint="#7C6CF0" bg="var(--violet-100)" delta="+5" />
        <KPICard label="Donor Retention" value="78%" icon="refresh" tint="#2D9CDB" bg="var(--sky-100)" delta="+3%" />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Trend chart */}
        <div className="lg:col-span-2 rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Donation Trend</h3>
              <p className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>Monthly collection overview</p>
            </div>
            <div className="flex gap-1">
              {(['7D', '1M', '3M', '1Y'] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => setPeriod(p)}
                  className="px-3 py-1 rounded-lg text-[12px] font-bold transition-all"
                  style={{
                    background: period === p ? 'var(--primary)' : 'var(--surface-2)',
                    color: period === p ? '#fff' : 'var(--on-surface-2)',
                  }}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
          <TrendChart data={MONTHLY} height={200} />
        </div>

        {/* Donut chart */}
        <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <h3 className="font-bold text-[15px] mb-1" style={{ color: 'var(--on-surface)' }}>Donation by Type</h3>
          <p className="text-[12px] mb-4" style={{ color: 'var(--on-surface-2)' }}>This year breakdown</p>
          <div className="flex justify-center mb-4">
            <DonutChart data={DONUT_DATA} size={160} thickness={26} centerLabel="100%" centerSub="₹56.1L" />
          </div>
          <div className="space-y-2">
            {DONUT_DATA.map((d) => (
              <div key={d.label} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: d.color }} />
                  <span className="text-[12.5px] font-medium" style={{ color: 'var(--on-surface-2)' }}>{d.label}</span>
                </div>
                <span className="text-[12.5px] font-bold" style={{ color: 'var(--on-surface)' }}>{d.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent donations + top donors */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Recent donations table */}
        <div className="rounded-2xl border overflow-hidden" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <div className="flex items-center justify-between px-5 py-4 border-b" style={{ borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Recent Donations</h3>
            <Link href="/donations" className="text-[12.5px] font-bold flex items-center gap-1" style={{ color: 'var(--primary)' }}>
              View all <Icon name="chevR" size={14} />
            </Link>
          </div>
          <div className="divide-y" style={{ borderColor: 'var(--border)' }}>
            {RECENT_DONORS.map((d, i) => (
              <div key={i} className="flex items-center gap-3 px-5 py-3.5">
                <Avatar name={d.name} size={38} />
                <div className="min-w-0 flex-1">
                  <div className="text-[13.5px] font-bold truncate" style={{ color: 'var(--on-surface)' }}>{d.name}</div>
                  <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.city}</div>
                </div>
                <div className="text-right">
                  <div className="text-[13.5px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt.inr(d.amount, true)}</div>
                  <div className="text-[11px]" style={{ color: 'var(--on-surface-3)' }}>{fmt.dayMon(d.date)}</div>
                </div>
                <TierBadge tier={d.tier} />
              </div>
            ))}
          </div>
        </div>

        {/* Today's summary */}
        <div className="space-y-4">
          <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px] mb-4" style={{ color: 'var(--on-surface)' }}>Today's Reminders</h3>
            {[
              { title: 'Birthday: Rajesh Khanna', type: 'BIRTHDAY', icon: 'cake', color: '#F6A723' },
              { title: 'Follow-up: Priya Sharma', type: 'FOLLOW_UP', icon: 'phone', color: '#0E8C76' },
              { title: 'Quarterly Report Prep', type: 'CUSTOM', icon: 'calendar', color: '#7C6CF0' },
            ].map((r, i) => (
              <div key={i} className="flex items-center gap-3 py-2.5">
                <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0"
                  style={{ background: r.color + '20' }}>
                  <Icon name={r.icon} size={16} color={r.color} />
                </div>
                <span className="text-[13px] font-medium flex-1" style={{ color: 'var(--on-surface)' }}>{r.title}</span>
                <Badge variant="gray">{r.type.replace('_', ' ')}</Badge>
              </div>
            ))}
          </div>

          <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <h3 className="font-bold text-[15px] mb-3" style={{ color: 'var(--on-surface)' }}>Students by Centre</h3>
            {[
              { name: 'Dharavi Centre', count: 186, pct: 60 },
              { name: 'Hadapsar Centre', count: 126, pct: 40 },
            ].map((c) => (
              <div key={c.name} className="mb-3">
                <div className="flex justify-between text-[12.5px] mb-1.5">
                  <span className="font-semibold" style={{ color: 'var(--on-surface)' }}>{c.name}</span>
                  <span className="font-bold" style={{ color: 'var(--on-surface-2)' }}>{c.count}</span>
                </div>
                <div className="h-2 rounded-full overflow-hidden" style={{ background: 'var(--surface-3)' }}>
                  <div className="h-full rounded-full" style={{ width: `${c.pct}%`, background: 'linear-gradient(90deg, var(--brand-500), var(--brand-700))' }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
