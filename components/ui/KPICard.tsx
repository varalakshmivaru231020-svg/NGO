import { Icon } from './Icon'

interface KPICardProps {
  label: string
  value: string | number
  icon: string
  tint: string
  bg: string
  delta?: string
  deltaUp?: boolean
  onClick?: () => void
}

export function KPICard({ label, value, icon, tint, bg, delta, deltaUp = true, onClick }: KPICardProps) {
  return (
    <button
      onClick={onClick}
      className="text-left p-4 rounded-2xl border transition-all hover:shadow-lg active:scale-[0.98]"
      style={{ background: 'var(--surface)', borderColor: 'var(--border)', boxShadow: 'var(--shadow-md)' }}
    >
      <div className="flex items-start justify-between mb-3">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: bg }}>
          <Icon name={icon} size={20} color={tint} />
        </div>
        {delta && (
          <span className="flex items-center gap-1 text-[11.5px] font-bold" style={{ color: deltaUp ? 'var(--success)' : 'var(--danger)' }}>
            <Icon name={deltaUp ? 'trendUp' : 'trendDown'} size={13} color={deltaUp ? 'var(--success)' : 'var(--danger)'} />
            {delta}
          </span>
        )}
      </div>
      <div className="text-[22px] font-bold leading-none tracking-tight mb-1.5" style={{ color: 'var(--on-surface)' }}>{value}</div>
      <div className="text-[12px] font-600" style={{ color: 'var(--on-surface-2)' }}>{label}</div>
    </button>
  )
}
