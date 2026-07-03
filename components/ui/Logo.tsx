export function Logo({ size = 36 }: { size?: number }) {
  const r = size * 0.28
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ display: 'block', flexShrink: 0 }}>
      <defs>
        <linearGradient id="logo-bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#19B89A" />
          <stop offset="0.55" stopColor="#0E8C76" />
          <stop offset="1" stopColor="#0A5E4E" />
        </linearGradient>
        <linearGradient id="logo-pet" x1="0.5" y1="0" x2="0.5" y2="1">
          <stop offset="0" stopColor="#FFFFFF" />
          <stop offset="1" stopColor="#E6FFF7" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="96" height="96" rx={r * 100 / size} fill="url(#logo-bg)" />
      <path d="M2 50 Q50 8 98 50 V20 Q60 2 2 30 Z" fill="#fff" opacity="0.07" />
      <g fill="url(#logo-pet)">
        <path d="M50 30c6 8 6 17 0 25c-6-8-6-17 0-25z" />
        <path d="M50 33c2 9 0 17-7 22c-2-9 0-15 7-22z" transform="rotate(-34 50 55)" />
        <path d="M50 33c2 9 0 17-7 22c-2-9 0-15 7-22z" transform="rotate(34 50 55) scale(-1,1) translate(-100,0)" />
        <path d="M50 36c1 8-2 14-9 18c-1-8 2-13 9-18z" transform="rotate(-60 50 56)" opacity="0.92" />
        <path d="M50 36c1 8-2 14-9 18c-1-8 2-13 9-18z" transform="rotate(60 50 56) scale(-1,1) translate(-100,0)" opacity="0.92" />
      </g>
      <path d="M26 60c7 11 41 11 48 0c1 7-6 16-24 16S25 67 26 60z" fill="#fff" opacity="0.95" />
    </svg>
  )
}
