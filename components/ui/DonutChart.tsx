'use client'

interface DonutSegment { label: string; value: number; color: string }

interface DonutChartProps {
  data: DonutSegment[]
  size?: number
  thickness?: number
  centerLabel?: string
  centerSub?: string
}

export function DonutChart({ data, size = 160, thickness = 28, centerLabel, centerSub }: DonutChartProps) {
  const r = (size - thickness) / 2
  const C = 2 * Math.PI * r
  const total = data.reduce((s, d) => s + d.value, 0)
  let acc = 0
  return (
    <svg viewBox={`0 0 ${size} ${size}`} width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--surface-3)" strokeWidth={thickness} />
      {data.map((d, i) => {
        const frac = d.value / total
        const dash = `${(frac * C).toFixed(2)} ${C.toFixed(2)}`
        const off = -acc * C
        acc += frac
        return (
          <circle key={i} cx={size / 2} cy={size / 2} r={r} fill="none"
            stroke={d.color} strokeWidth={thickness} strokeDasharray={dash}
            strokeDashoffset={off} strokeLinecap="round" />
        )
      })}
      {centerLabel && (
        <g style={{ transform: 'rotate(90deg)', transformOrigin: 'center' }}>
          <text x={size / 2} y={size / 2 - 2} textAnchor="middle" fontSize="20" fontWeight="800"
            fill="var(--on-surface)" fontFamily="Plus Jakarta Sans">{centerLabel}</text>
          {centerSub && <text x={size / 2} y={size / 2 + 16} textAnchor="middle" fontSize="11" fontWeight="600"
            fill="var(--on-surface-2)" fontFamily="Plus Jakarta Sans">{centerSub}</text>}
        </g>
      )}
    </svg>
  )
}
