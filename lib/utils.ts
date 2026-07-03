export const fmt = {
  inr(n: number, compact = false): string {
    if (compact) {
      if (n >= 1e7) return '₹' + (n / 1e7).toFixed(1).replace(/\.0$/, '') + ' Cr'
      if (n >= 1e5) return '₹' + (n / 1e5).toFixed(1).replace(/\.0$/, '') + ' L'
      if (n >= 1e3) return '₹' + (n / 1e3).toFixed(0) + 'K'
      return '₹' + n
    }
    return '₹' + n.toLocaleString('en-IN')
  },
  num(n: number): string {
    return n.toLocaleString('en-IN')
  },
  date(d: string | Date): string {
    const dt = typeof d === 'string' ? new Date(d) : d
    return dt.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  },
  dayMon(d: string | Date): string {
    const dt = typeof d === 'string' ? new Date(d) : d
    return dt.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })
  },
  timeAgo(d: string | Date): string {
    const dt = typeof d === 'string' ? new Date(d) : d
    const diff = Date.now() - dt.getTime()
    const mins = Math.floor(diff / 60000)
    if (mins < 60) return `${mins}m ago`
    const hrs = Math.floor(mins / 60)
    if (hrs < 24) return `${hrs}h ago`
    return fmt.dayMon(dt)
  },
}

export function cn(...classes: (string | undefined | false | null)[]): string {
  return classes.filter(Boolean).join(' ')
}
