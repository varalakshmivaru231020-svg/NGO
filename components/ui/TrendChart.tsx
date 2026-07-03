'use client'

interface DataPoint { m: string; v: number }

interface TrendChartProps {
  data: DataPoint[]
  height?: number
  accent?: string
}

export function TrendChart({ data, height = 160, accent = '#0E8C76' }: TrendChartProps) {
  const W = 480; const H = height; const pad = 12
  const max = Math.max(...data.map((d) => d.v)) * 1.15
  const min = 0
  const x = (i: number) => pad + (i * (W - pad * 2)) / (data.length - 1)
  const y = (v: number) => H - 28 - ((v - min) / (max - min)) * (H - 48)
  const pts = data.map((d, i) => [x(i), y(d.v)])
  const line = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ')
  const area = line + ` L${x(data.length - 1)} ${H - 28} L${x(0)} ${H - 28} Z`
  const last = pts[pts.length - 1]

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: 'block', overflow: 'visible' }}>
      <defs>
        <linearGradient id="tf" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={accent} stopOpacity="0.22" />
          <stop offset="1" stopColor={accent} stopOpacity="0" />
        </linearGradient>
      </defs>
      {[0.25, 0.5, 0.75].map((g) => (
        <line key={g} x1={pad} x2={W - pad} y1={28 + g * (H - 56)} y2={28 + g * (H - 56)}
          stroke="var(--border)" strokeWidth="1" strokeDasharray="2 5" />
      ))}
      <path d={area} fill="url(#tf)" />
      <path d={line} fill="none" stroke={accent} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      {pts.map((p, i) => (
        <circle key={i} cx={p[0]} cy={p[1]} r={i === pts.length - 1 ? 5 : 3}
          fill="var(--surface)" stroke={accent} strokeWidth="2.5" />
      ))}
      <circle cx={last[0]} cy={last[1]} r="12" fill={accent} opacity="0.12" />
      {data.map((d, i) => (
        <text key={i} x={x(i)} y={H - 6} textAnchor="middle" fontSize="11" fontWeight="700"
          fill="var(--on-surface-3)" fontFamily="Plus Jakarta Sans">{d.m}</text>
      ))}
    </svg>
  )
}
