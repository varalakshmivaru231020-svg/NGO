const PATHS: Record<string, string> = {
  home: 'M3 11.5 12 4l9 7.5M5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  users: 'M16 19v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 17.5V19M9.5 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM20 19v-1.5a3.5 3.5 0 0 0-2.6-3.4M15 4.2a3.5 3.5 0 0 1 0 6.6',
  user: 'M19 20v-1a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v1M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  gift: 'M20 12v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8M3 7h18v5H3zM12 21V7M12 7S11 3 8.5 3 6 6 8 7m4 0s1-4 3.5-4S18 6 16 7',
  grad: 'M3 9l9-4 9 4-9 4-9-4zM7 11v5c0 1 2.2 2.5 5 2.5s5-1.5 5-2.5v-5M21 9v5',
  bell: 'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3',
  plus: 'M12 5v14M5 12h14',
  x: 'M6 6l12 12M18 6L6 18',
  chevR: 'M9 6l6 6-6 6',
  chevL: 'M15 6l-6 6 6 6',
  chevD: 'M6 9l6 6 6-6',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.1A1.6 1.6 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 3 14H3a2 2 0 0 1 0-4h.1A1.6 1.6 0 0 0 4.6 7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.6 1.6 0 0 0 10 4.6V4a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 .9 2.5h.1a2 2 0 0 1 0 4h-.1z',
  phone: 'M21 16.5v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 1 4.2 2 2 0 0 1 3 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L7 9.8a16 16 0 0 0 6 6l1.2-1.2a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z',
  mail: 'M3 6h18v12H3zM3 7l9 6 9-6',
  whatsapp: 'M3 21l1.7-5A8 8 0 1 1 8 19.3L3 21z',
  calendar: 'M7 3v3M17 3v3M3 9h18M4 6h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z',
  cake: 'M4 20h16M5 20v-7a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7M3 16c1.2 0 1.2 1 2.4 1s1.2-1 2.4-1 1.2 1 2.4 1 1.2-1 2.4-1 1.2 1 2.4 1 1.2-1 2.4-1M12 8V5M12 4.5a.5.5 0 1 0 0-1 .5.5 0 0 0 0 1z',
  trophy: 'M7 4h10v4a5 5 0 0 1-10 0V4zM7 5H4v2a3 3 0 0 0 3 3M17 5h3v2a3 3 0 0 1-3 3M9 18h6M10 14v4M14 14v4M8 21h8',
  building: 'M4 21V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16M15 21V9h4a1 1 0 0 1 1 1v11M7 8h2M7 12h2M7 16h2M19 13h-1M19 17h-1M3 21h18',
  chart: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  wallet: 'M3 7a1 1 0 0 1 1-1h13a1 1 0 0 1 1 1v2M3 7v11a1 1 0 0 0 1 1h15a1 1 0 0 0 1-1v-3M21 11h-5a2 2 0 0 0 0 4h5v-4zM3 7l13-3v3',
  trendUp: 'M3 17l6-6 4 4 8-8M15 7h6v6',
  trendDown: 'M3 7l6 6 4-4 8 8M15 17h6v-6',
  download: 'M12 3v12M7 11l5 5 5-5M5 21h14',
  edit: 'M14 4l6 6M4 20l1-4L16 5l3 3L8 19l-4 1z',
  check: 'M5 12l5 5L20 6',
  checkCircle: 'M9 12l2 2 4-4M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
  filter: 'M3 5h18l-7 8v5l-4 2v-7L3 5z',
  star: 'M12 3l2.6 5.5 6 .8-4.4 4.1 1.1 6-5.3-2.9L6.7 19.5l1.1-6L3.4 9.3l6-.8L12 3z',
  clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  refresh: 'M21 12a9 9 0 1 1-3-6.7L21 8M21 4v4h-4',
  logout: 'M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
  dots: 'M12 6h.01M12 12h.01M12 18h.01',
  arrowR: 'M5 12h14M13 6l6 6-6 6',
  qr: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2v2h-2zM14 18h2v2h-2zM18 18h2v2h-2z',
  location: 'M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11zM12 13a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  rupee: 'M7 4h10M7 9h10M16 4c0 4-3.5 5-7 5 3 0 6 1 6 5l-4 5M7 9h3',
  eye: 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  share: 'M16 6l-4-4-4 4M12 2v13M5 12v7a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-7',
  send: 'M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z',
  menu: 'M3 6h18M3 12h18M3 18h18',
  lock: 'M7 11V7a5 5 0 0 1 10 0v4M5 11h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1zM12 16a1 1 0 1 0 0-2 1 1 0 0 0 0 2z',
  sun: 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4',
  moon: 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z',
  mapPin: 'M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11zM12 13a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  trash: 'M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6',
  receipt: 'M5 2h14a1 1 0 0 1 1 1v17l-3-2-2 2-2-2-2 2-2-2-3 2V3a1 1 0 0 1 1-1zM9 7h6M9 11h6M9 15h4',
  heart: 'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.7l1 1 7.8 7.8 7.8-7.7 1-1a5.5 5.5 0 0 0 0-7.8z',
}

interface IconProps {
  name: string
  size?: number
  color?: string
  strokeWidth?: number
  className?: string
}

export function Icon({ name, size = 20, color = 'currentColor', strokeWidth = 2, className }: IconProps) {
  const d = PATHS[name]
  if (!d) return null
  return (
    <svg
      width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round"
      className={className} style={{ display: 'block', flexShrink: 0 }}
    >
      <path d={d} fill="none" />
    </svg>
  )
}
