const AV_COLORS = [
  ['#0E8C76', '#0A5E4E'], ['#F6A723', '#E0921A'], ['#7C6CF0', '#5849C0'],
  ['#2D9CDB', '#1E6FA8'], ['#EC5B8B', '#C23D6B'], ['#F2685E', '#C23D31'],
]

function avColor(seed: string): [string, string] {
  let h = 0
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0
  return AV_COLORS[h % AV_COLORS.length] as [string, string]
}

function initials(name: string): string {
  const safe = (name ?? '').toString().trim() || '?'
  const p = safe.split(/\s+/)
  return (p[0][0] + (p[1] ? p[1][0] : '')).toUpperCase()
}

interface AvatarProps {
  name?: string
  size?: number
  img?: string
  square?: boolean
  className?: string
}

export function Avatar({ name, size = 40, img, square = false, className }: AvatarProps) {
  const safeName = (name ?? '').toString().trim() || '?'
  const [c1, c2] = avColor(safeName)
  const borderRadius = square ? `${size * 0.3}px` : '50%'
  return (
    <div
      className={className}
      style={{
        width: size, height: size, borderRadius, flexShrink: 0,
        background: img ? `url(${img}) center/cover` : `linear-gradient(135deg, ${c1}, ${c2})`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff', fontWeight: 800, fontSize: size * 0.36,
        fontFamily: 'inherit',
      }}
    >
      {!img && initials(safeName)}
    </div>
  )
}
