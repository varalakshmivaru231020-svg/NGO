'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Logo } from '@/components/ui/Logo'

const NAV_GROUPS = [
  {
    title: 'Main',
    items: [
      { href: '/', label: 'Dashboard', icon: 'home' },
    ],
  },
  {
    title: 'Management',
    items: [
      { href: '/donors', label: 'Donors', icon: 'users' },
      { href: '/donations', label: 'Donations', icon: 'wallet' },
      { href: '/expenses', label: 'Expenses', icon: 'receipt' },
      { href: '/students', label: 'Students', icon: 'grad' },
      { href: '/categories', label: 'Donor Categories', icon: 'grid' },
      { href: '/achievements', label: 'Achievements', icon: 'trophy' },
      { href: '/reminders', label: 'Reminders', icon: 'cake' },
      { href: '/offices', label: 'Offices', icon: 'building' },
    ],
  },
  {
    title: 'Insights',
    items: [
      { href: '/tracker', label: 'Donation Tracker', icon: 'clock' },
      { href: '/reports', label: 'Reports', icon: 'chart' },
    ],
  },
  {
    title: 'System',
    items: [
      { href: '/notifications', label: 'Notifications', icon: 'bell' },
      { href: '/settings', label: 'Settings', icon: 'settings' },
    ],
  },
]

const ICON_PATHS: Record<string, string> = {
  home: 'M3 11.5 12 4l9 7.5M5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9',
  users: 'M16 19v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 17.5V19M9.5 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM20 19v-1.5a3.5 3.5 0 0 0-2.6-3.4M15 4.2a3.5 3.5 0 0 1 0 6.6',
  wallet: 'M3 7a1 1 0 0 1 1-1h13a1 1 0 0 1 1 1v2M3 7v11a1 1 0 0 0 1 1h15a1 1 0 0 0 1-1v-3M21 11h-5a2 2 0 0 0 0 4h5v-4zM3 7l13-3v3',
  receipt: 'M5 2h14a1 1 0 0 1 1 1v17l-3-2-2 2-2-2-2 2-2-2-3 2V3a1 1 0 0 1 1-1zM9 7h6M9 11h6M9 15h4',
  grad: 'M3 9l9-4 9 4-9 4-9-4zM7 11v5c0 1 2.2 2.5 5 2.5s5-1.5 5-2.5v-5M21 9v5',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  trophy: 'M7 4h10v4a5 5 0 0 1-10 0V4zM7 5H4v2a3 3 0 0 0 3 3M17 5h3v2a3 3 0 0 1-3 3M9 18h6M10 14v4M14 14v4M8 21h8',
  cake: 'M4 20h16M5 20v-7a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7M3 16c1.2 0 1.2 1 2.4 1s1.2-1 2.4-1 1.2 1 2.4 1 1.2-1 2.4-1 1.2 1 2.4 1 1.2-1 2.4-1M12 8V5M12 4.5a.5.5 0 1 0 0-1 .5.5 0 0 0 0 1z',
  building: 'M4 21V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16M15 21V9h4a1 1 0 0 1 1 1v11M7 8h2M7 12h2M7 16h2M19 13h-1M19 17h-1M3 21h18',
  clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  chart: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  bell: 'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.1A1.6 1.6 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 3 14H3a2 2 0 0 1 0-4h.1A1.6 1.6 0 0 0 4.6 7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.6 1.6 0 0 0 10 4.6V4a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 .9 2.5h.1a2 2 0 0 1 0 4h-.1z',
  menu: 'M3 6h18M3 12h18M3 18h18',
  x: 'M6 6l12 12M18 6L6 18',
  logout: 'M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
}

function NavIcon({ name, size = 18 }: { name: string; size?: number }) {
  const d = ICON_PATHS[name]
  if (!d) return null
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d={d} fill="none" />
    </svg>
  )
}

export function SidebarLayout({ children, onLogout }: { children: React.ReactNode; onLogout?: () => void }) {
  const pathname = usePathname()
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  const isActive = (href: string) =>
    href === '/' ? pathname === '/' : pathname.startsWith(href)

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: 'var(--bg)' }}>
      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 bg-black/50 lg:hidden" onClick={() => setMobileOpen(false)} />
      )}

      {/* Sidebar */}
      <aside
        className={`
          fixed inset-y-0 left-0 z-50 flex flex-col transition-all duration-300
          lg:relative lg:translate-x-0
          ${mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
          ${collapsed ? 'w-[72px]' : 'w-[240px]'}
        `}
        style={{ background: 'var(--sidebar-bg)' }}
      >
        {/* Logo */}
        <div className="flex items-center gap-3 px-4 py-5 border-b border-white/10">
          <Logo size={36} />
          {!collapsed && (
            <div>
              <div className="text-white font-bold text-[15px] leading-tight">Saksham</div>
              <div className="text-[10px] font-bold tracking-widest uppercase" style={{ color: 'var(--brand-400)' }}>Foundation</div>
            </div>
          )}
          <button
            className="ml-auto hidden lg:flex items-center justify-center w-7 h-7 rounded-lg transition-colors"
            style={{ color: 'rgba(255,255,255,0.5)' }}
            onClick={() => setCollapsed(!collapsed)}
          >
            <NavIcon name="menu" size={16} />
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto py-3 px-2">
          {NAV_GROUPS.map((group) => (
            <div key={group.title} className="mb-4">
              {!collapsed && (
                <div className="px-3 mb-1 text-[10.5px] font-bold uppercase tracking-widest" style={{ color: 'rgba(255,255,255,0.35)' }}>
                  {group.title}
                </div>
              )}
              {group.items.map((item) => {
                const active = isActive(item.href)
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`
                      flex items-center gap-3 px-3 py-2.5 rounded-xl mb-0.5 transition-all
                      ${active ? 'font-bold' : 'font-medium'}
                    `}
                    style={{
                      background: active ? 'var(--sidebar-active)' : 'transparent',
                      color: active ? 'var(--sidebar-active-text)' : 'var(--sidebar-text)',
                    }}
                    title={collapsed ? item.label : undefined}
                  >
                    <span className="flex-shrink-0">
                      <NavIcon name={item.icon} size={18} />
                    </span>
                    {!collapsed && <span className="text-[13.5px] truncate">{item.label}</span>}
                  </Link>
                )
              })}
            </div>
          ))}
        </nav>

        {/* Footer */}
        <div className="p-3 border-t border-white/10">
          <div className={`flex items-center gap-3 px-2 py-2 rounded-xl ${collapsed ? 'justify-center' : ''}`}>
            <div className="w-8 h-8 rounded-full bg-brand-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">FA</div>
            {!collapsed && (
              <div className="min-w-0 flex-1">
                <div className="text-white text-[12.5px] font-bold truncate">Farhan Ansari</div>
                <div className="text-[10.5px] truncate" style={{ color: 'rgba(255,255,255,0.45)' }}>Super Admin</div>
              </div>
            )}
            {!collapsed && (
              <button
                onClick={onLogout}
                className="ml-auto flex items-center gap-1 text-xs rounded-lg px-1 py-1 transition-colors hover:bg-white/10"
                style={{ color: 'rgba(255,255,255,0.5)' }}
                title="Logout"
              >
                <NavIcon name="logout" size={14} />
                <span>Logout</span>
              </button>
            )}
          </div>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top bar */}
        <header className="flex items-center gap-4 px-6 py-4 border-b" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <button
            className="lg:hidden flex items-center justify-center w-9 h-9 rounded-xl transition-colors"
            style={{ background: 'var(--surface-2)', color: 'var(--on-surface)' }}
            onClick={() => setMobileOpen(true)}
          >
            <NavIcon name="menu" size={18} />
          </button>

          <div className="flex-1 min-w-0">
            <h1 className="text-[17px] font-bold truncate" style={{ color: 'var(--on-surface)' }}>
              {NAV_GROUPS.flatMap(g => g.items).find(i => isActive(i.href))?.label ?? 'Dashboard'}
            </h1>
          </div>

          <div className="flex items-center gap-2">
            <button className="relative w-9 h-9 rounded-xl flex items-center justify-center transition-colors"
              style={{ background: 'var(--surface-2)', color: 'var(--on-surface-2)' }}>
              <NavIcon name="bell" size={17} />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-coral-500" style={{ background: 'var(--coral-500)' }} />
            </button>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
