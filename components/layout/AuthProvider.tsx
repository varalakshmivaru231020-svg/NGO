'use client'

import { useEffect } from 'react'
import { useRouter, usePathname } from 'next/navigation'
import { setToken, clearToken } from '@/lib/api'
import { SidebarLayout } from './SidebarLayout'

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const pathname = usePathname()

  useEffect(() => {
    const t = typeof window !== 'undefined' ? localStorage.getItem('saksham_token') : null
    if (t) {
      setToken(t)
    } else if (pathname !== '/login') {
      router.replace('/login')
    }
  }, [pathname, router])

  function handleLogout() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('saksham_token')
    }
    clearToken()
    router.replace('/login')
  }

  if (pathname === '/login') {
    return <>{children}</>
  }

  return (
    <SidebarLayout onLogout={handleLogout}>
      {children}
    </SidebarLayout>
  )
}
