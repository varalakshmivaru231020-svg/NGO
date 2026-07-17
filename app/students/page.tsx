'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Icon } from '@/components/ui/Icon'
import { fmt } from '@/lib/utils'
import { api } from '@/lib/api'

const STATUS_CONFIG: Record<string, { label: string; variant: 'green' | 'violet' | 'gray' | 'coral' }> = {
  ACTIVE: { label: 'Active', variant: 'green' },
  GRADUATED: { label: 'Graduated', variant: 'violet' },
  RELIEVED: { label: 'Relieved', variant: 'gray' },
  DROP_OUT: { label: 'Drop Out', variant: 'coral' },
}

function age(dob: string) {
  const d = new Date(dob); const n = new Date()
  let a = n.getFullYear() - d.getFullYear()
  if (n.getMonth() < d.getMonth() || (n.getMonth() === d.getMonth() && n.getDate() < d.getDate())) a--
  return a
}

export default function StudentsPage() {
  const [search, setSearch] = useState('')
  const [center, setCenter] = useState('All')
  const [status, setStatus] = useState('All')
  const [students, setStudents] = useState<any[]>([])
  const [summary, setSummary] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchData() {
      setLoading(true)
      setError(null)
      try {
        const [listRes, summaryRes] = await Promise.all([
          api.students.list(),
          api.students.summary().catch(() => null),
        ])
        const items = Array.isArray(listRes) ? listRes : ((listRes as any)?.data ?? (listRes as any)?.items ?? [])
        setStudents(items)
        setSummary(summaryRes)
      } catch (err: any) {
        setError(err?.message ?? 'Failed to load students')
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  // Derive stat values: prefer summary API, fall back to computing from list
  const totalStudents = summary?.total ?? students.length
  const activeCount = summary?.active ?? students.filter((s) => s.status === 'ACTIVE').length
  const graduatedCount = summary?.graduated ?? students.filter((s) => s.status === 'GRADUATED').length
  const sponsoredCount = summary?.sponsored ?? students.filter((s) => !!s.sponsor).length

  const filtered = students.filter((s) => {
    const matchSearch = !search || s.name.toLowerCase().includes(search.toLowerCase()) || s.childId.includes(search)
    const matchCenter = center === 'All' || s.center === center
    const matchStatus = status === 'All' || s.status === status
    return matchSearch && matchCenter && matchStatus
  })

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: 'var(--on-surface-2)' }}>
        Loading...
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: '#F2685E' }}>
        Error: {error}
      </div>
    )
  }

  return (
    <div className="space-y-5">
      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Total Students', value: String(totalStudents), icon: 'grad', bg: 'var(--violet-100)', color: '#7C6CF0' },
          { label: 'Active', value: String(activeCount), icon: 'checkCircle', bg: 'var(--brand-100)', color: '#0E8C76' },
          { label: 'Graduated', value: String(graduatedCount), icon: 'star', bg: 'var(--amber-100)', color: '#F6A723' },
          { label: 'Sponsored', value: String(sponsoredCount), icon: 'heart', bg: 'var(--coral-100)', color: '#F2685E' },
        ].map((s) => (
          <div key={s.label} className="rounded-2xl border p-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <div className="w-9 h-9 rounded-xl flex items-center justify-center mb-2" style={{ background: s.bg }}>
              <Icon name={s.icon} size={17} color={s.color} />
            </div>
            <div className="text-[20px] font-bold" style={{ color: 'var(--on-surface)' }}>{s.value}</div>
            <div className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Controls */}
      <div className="flex gap-3 items-center flex-wrap">
        <div className="flex-1 min-w-[200px] flex items-center gap-2 px-3.5 h-10 rounded-xl border" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <Icon name="search" size={16} color="var(--on-surface-3)" />
          <input type="text" placeholder="Search by name or ID..." value={search} onChange={(e) => setSearch(e.target.value)}
            className="flex-1 bg-transparent outline-none text-[13.5px]" style={{ color: 'var(--on-surface)' }} />
        </div>
        {['All', 'Dharavi Centre', 'Hadapsar Centre'].map((c) => (
          <button key={c} onClick={() => setCenter(c)}
            className="px-3.5 h-10 rounded-xl text-[12.5px] font-bold transition-all"
            style={{ background: center === c ? 'var(--primary)' : 'var(--surface)', color: center === c ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
            {c}
          </button>
        ))}
        {['All', 'ACTIVE', 'GRADUATED', 'RELIEVED'].map((s) => (
          <button key={s} onClick={() => setStatus(s)}
            className="px-3.5 h-10 rounded-xl text-[12.5px] font-bold transition-all"
            style={{ background: status === s ? '#7C6CF0' : 'var(--surface)', color: status === s ? '#fff' : 'var(--on-surface-2)', border: '1px solid var(--border)' }}>
            {s}
          </button>
        ))}
        <Link href="/students/new"
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white flex-shrink-0"
          style={{ background: '#7C6CF0' }}>
          <Icon name="plus" size={16} color="#fff" /> Add Student
        </Link>
      </div>

      {/* Cards grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filtered.map((s) => {
          const sc = STATUS_CONFIG[s.status] ?? { label: s.status, variant: 'gray' as const }
          return (
            <div key={s.id} className="rounded-2xl border p-4 space-y-3" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
              <div className="flex items-start gap-3">
                <Avatar name={s.name} size={48} square />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="font-bold text-[14.5px]" style={{ color: 'var(--on-surface)' }}>{s.name}</span>
                    <Badge variant={sc.variant}>{sc.label}</Badge>
                  </div>
                  <div className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{s.childId} · Age {age(s.dob)}</div>
                  <div className="text-[12px]" style={{ color: 'var(--on-surface-2)' }}>{s.center} · Class {s.class}</div>
                </div>
              </div>
              <div className="flex items-center justify-between pt-2 border-t" style={{ borderColor: 'var(--border)' }}>
                {s.sponsor ? (
                  <div className="flex items-center gap-1.5 text-[12px]" style={{ color: 'var(--on-surface-2)' }}>
                    <Icon name="heart" size={13} color="var(--coral-500)" />
                    <span>Sponsored by <strong style={{ color: 'var(--on-surface)' }}>{s.sponsor}</strong></span>
                  </div>
                ) : (
                  <span className="text-[12px]" style={{ color: 'var(--on-surface-3)' }}>No sponsor</span>
                )}
                <button className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: 'var(--surface-2)' }}>
                  <Icon name="chevR" size={14} color="var(--on-surface-2)" />
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
