'use client'
import { useState } from 'react'
import { Icon } from '@/components/ui/Icon'
import { TrendChart } from '@/components/ui/TrendChart'
import { DonutChart } from '@/components/ui/DonutChart'
import { fmt } from '@/lib/utils'

const ALL_MONTHLY = [
  { m: 'Jan', v: 2800000, donors: 42 },
  { m: 'Feb', v: 3200000, donors: 51 },
  { m: 'Mar', v: 4100000, donors: 63 },
  { m: 'Apr', v: 3700000, donors: 58 },
  { m: 'May', v: 5600000, donors: 74 },
  { m: 'Jun', v: 7420000, donors: 83 },
]

const DONATION_TYPES = [
  { label: 'General Donation',  value: 38, color: '#0E8C76' },
  { label: 'Child Sponsorship', value: 24, color: '#7C6CF0' },
  { label: 'Education Fund',    value: 19, color: '#F6A723' },
  { label: 'Healthcare',        value: 11, color: '#F2685E' },
  { label: 'Food & Nutrition',  value: 8,  color: '#3ABCF7' },
]

const PAYMENT_MODES = [
  { label: 'Bank Transfer', value: 45, color: '#0E8C76' },
  { label: 'UPI',           value: 32, color: '#7C6CF0' },
  { label: 'Cheque',        value: 14, color: '#F6A723' },
  { label: 'Cash',          value: 9,  color: '#F2685E' },
]

const RETENTION = [
  { year: '2023', donors: 312,  retained: 187 },
  { year: '2024', donors: 856,  retained: 221 },
  { year: '2025', donors: 1104, retained: 287 },
  { year: '2026', donors: 1247, retained: 341 },
]

const TOP_DONORS = [
  { name: 'Rajesh Khanna',  city: 'Mumbai',    total: 845000,  count: 18 },
  { name: 'Meera Nambiar',  city: 'Kochi',     total: 620000,  count: 9  },
  { name: 'Priya Sharma',   city: 'Pune',      total: 412000,  count: 11 },
  { name: 'Arjun Mehta',    city: 'Bengaluru', total: 268000,  count: 7  },
  { name: 'Ananya Patel',   city: 'Ahmedabad', total: 195000,  count: 5  },
]

export default function ReportsPage() {
  const [period, setPeriod] = useState('6M')

  const monthly = period === '3M' ? ALL_MONTHLY.slice(-3) : ALL_MONTHLY

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Reports & Analytics</h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Overview of Saksham Foundation impact</p>
        </div>
        <div className="flex gap-2 items-center">
          {['3M', '6M', '1Y', 'All'].map(p => (
            <button key={p} onClick={() => setPeriod(p)}
              className="px-3.5 h-9 rounded-xl text-[12.5px] font-bold transition-all"
              style={{ background: period === p ? 'var(--primary)' : 'var(--surface)', color: period === p ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
              {p}
            </button>
          ))}
          <button onClick={() => window.print()}
            className="flex items-center gap-1.5 px-4 h-9 rounded-xl text-[13px] font-bold"
            style={{ background: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--on-surface)' }}>
            <Icon name="download" size={15} /> Export
          </button>
        </div>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: 'Total Raised (All Time)', value: fmt.inr(56100000, true), delta: '+18.4% YoY',    up: true },
          { label: 'Total Donors',            value: '1,247',                 delta: '+143 this year', up: true },
          { label: 'Active Students',         value: '289',                   delta: '23 sponsored',  up: true },
          { label: 'Donor Retention',         value: '74.3%',                 delta: '+2.1% vs last year', up: true },
        ].map((k, i) => (
          <div key={i} className="rounded-2xl border p-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <div className="text-[11.5px] font-semibold mb-1" style={{ color: 'var(--on-surface-2)' }}>{k.label}</div>
            <div className="text-[22px] font-bold mb-1" style={{ color: 'var(--on-surface)' }}>{k.value}</div>
            <div className="flex items-center gap-1 text-[11.5px] font-semibold" style={{ color: k.up ? '#0E8C76' : '#F2685E' }}>
              <Icon name={k.up ? 'trendUp' : 'trendDown'} size={12} color={k.up ? '#0E8C76' : '#F2685E'} />
              {k.delta}
            </div>
          </div>
        ))}
      </div>

      {/* Trend + Donut */}
      <div className="grid grid-cols-3 gap-5">
        <div className="col-span-2 rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <div className="mb-4">
            <h3 className="font-bold text-[14px]" style={{ color: 'var(--on-surface)' }}>Donation Trend</h3>
            <p className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>Monthly collection (₹)</p>
          </div>
          <TrendChart data={monthly} height={180} />
        </div>
        <div className="rounded-2xl border p-5 flex flex-col" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <h3 className="font-bold text-[14px] mb-1" style={{ color: 'var(--on-surface)' }}>By Donation Type</h3>
          <p className="text-[11.5px] mb-4" style={{ color: 'var(--on-surface-2)' }}>Distribution across purposes</p>
          <div className="flex flex-col items-center gap-4 flex-1">
            <DonutChart data={DONATION_TYPES} centerLabel="Types" centerSub="5 active" />
            <div className="space-y-1.5 w-full">
              {DONATION_TYPES.map(t => (
                <div key={t.label} className="flex items-center gap-2 text-[12px]">
                  <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: t.color }} />
                  <span style={{ color: 'var(--on-surface-2)', flex: 1 }}>{t.label}</span>
                  <span className="font-bold" style={{ color: 'var(--on-surface)' }}>{t.value}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Payment Modes + Retention */}
      <div className="grid grid-cols-2 gap-5">
        <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <h3 className="font-bold text-[14px] mb-4" style={{ color: 'var(--on-surface)' }}>Payment Modes</h3>
          <div className="space-y-3">
            {PAYMENT_MODES.map(pm => (
              <div key={pm.label}>
                <div className="flex justify-between text-[12.5px] mb-1">
                  <span style={{ color: 'var(--on-surface)' }}>{pm.label}</span>
                  <span className="font-bold" style={{ color: 'var(--on-surface)' }}>{pm.value}%</span>
                </div>
                <div className="h-2 rounded-full overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                  <div className="h-full rounded-full transition-all" style={{ width: `${pm.value}%`, background: pm.color }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <h3 className="font-bold text-[14px] mb-4" style={{ color: 'var(--on-surface)' }}>Donor Retention YoY</h3>
          <div className="space-y-4">
            {RETENTION.map(r => {
              const pct = Math.round((r.retained / r.donors) * 100)
              return (
                <div key={r.year} className="space-y-1">
                  <div className="flex justify-between text-[12.5px]">
                    <span className="font-semibold" style={{ color: 'var(--on-surface)' }}>{r.year}</span>
                    <span style={{ color: 'var(--on-surface-2)' }}>{r.retained} / {r.donors} · <strong style={{ color: 'var(--on-surface)' }}>{pct}%</strong></span>
                  </div>
                  <div className="h-2 rounded-full overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                    <div className="h-full rounded-full" style={{ width: `${pct}%`, background: 'linear-gradient(90deg, #0B6E5D, #14A98C)' }} />
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>

      {/* Top Donors */}
      <div className="rounded-2xl border p-5" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
        <h3 className="font-bold text-[14px] mb-4" style={{ color: 'var(--on-surface)' }}>Top Donors This Year</h3>
        <div className="space-y-2">
          {TOP_DONORS.map((d, i) => (
            <div key={d.name} className="flex items-center gap-3 p-3 rounded-xl" style={{ background: 'var(--surface-2)' }}>
              <div className="w-7 h-7 rounded-full flex items-center justify-center text-[12px] font-bold text-white flex-shrink-0"
                style={{ background: ['#0E8C76','#7C6CF0','#F6A723','#3ABCF7','#F2685E'][i] }}>
                {i + 1}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-[13px]" style={{ color: 'var(--on-surface)' }}>{d.name}</div>
                <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{d.city} · {d.count} donations</div>
              </div>
              <div className="text-right">
                <div className="font-bold text-[14px]" style={{ color: 'var(--on-surface)' }}>{fmt.inr(d.total, true)}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
