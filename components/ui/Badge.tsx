type BadgeVariant = 'green' | 'amber' | 'coral' | 'violet' | 'sky' | 'gray'

const BADGE_STYLES: Record<BadgeVariant, { bg: string; color: string }> = {
  green:  { bg: 'var(--brand-100)',   color: 'var(--brand-800)' },
  amber:  { bg: 'var(--amber-100)',   color: 'var(--amber-600)' },
  coral:  { bg: 'var(--coral-100)',   color: '#C23D31' },
  violet: { bg: 'var(--violet-100)',  color: '#5849C0' },
  sky:    { bg: 'var(--sky-100)',     color: '#1E6FA8' },
  gray:   { bg: 'var(--surface-3)',   color: 'var(--on-surface-2)' },
}

interface BadgeProps {
  variant?: BadgeVariant
  children: React.ReactNode
  className?: string
}

export function Badge({ variant = 'gray', children, className }: BadgeProps) {
  const s = BADGE_STYLES[variant]
  return (
    <span
      className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-[11.5px] font-bold whitespace-nowrap ${className ?? ''}`}
      style={{ background: s.bg, color: s.color }}
    >
      {children}
    </span>
  )
}

export function TierBadge({ tier }: { tier: string }) {
  const map: Record<string, BadgeVariant> = { PLATINUM: 'violet', GOLD: 'amber', SILVER: 'gray' }
  return <Badge variant={map[tier] ?? 'gray'}>{tier}</Badge>
}
