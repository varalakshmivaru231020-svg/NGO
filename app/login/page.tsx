'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { api, setToken } from '@/lib/api'
import { Logo } from '@/components/ui/Logo'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      const result = await api.auth.login(email, password) as any
      const t: string = result.accessToken
      if (!t) throw new Error('No access token received')
      localStorage.setItem('saksham_token', t)
      setToken(t)
      router.replace('/')
    } catch (err: any) {
      setError(err?.message ?? 'Login failed. Please check your credentials.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-4"
      style={{ background: 'var(--bg)' }}
    >
      <div
        className="w-full max-w-sm rounded-2xl overflow-hidden shadow-2xl"
        style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
      >
        {/* Teal gradient header */}
        <div
          className="px-8 py-8 flex flex-col items-center gap-3"
          style={{
            background: 'linear-gradient(135deg, var(--brand-600, #0d9488) 0%, var(--brand-400, #2dd4bf) 100%)',
          }}
        >
          <Logo size={52} />
          <div className="text-center">
            <div className="text-white font-bold text-xl leading-tight">Saksham Foundation</div>
            <div className="text-white/70 text-xs tracking-widest uppercase mt-0.5">Admin Panel</div>
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="px-8 py-8 flex flex-col gap-5">
          <div>
            <label
              htmlFor="email"
              className="block text-xs font-semibold mb-1.5 uppercase tracking-wider"
              style={{ color: 'var(--on-surface-2)' }}
            >
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              required
              placeholder="admin@saksham.org"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl px-4 py-2.5 text-sm outline-none transition-all"
              style={{
                background: 'var(--surface-2)',
                color: 'var(--on-surface)',
                border: '1.5px solid var(--border)',
              }}
            />
          </div>

          <div>
            <label
              htmlFor="password"
              className="block text-xs font-semibold mb-1.5 uppercase tracking-wider"
              style={{ color: 'var(--on-surface-2)' }}
            >
              Password
            </label>
            <div className="relative">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                autoComplete="current-password"
                required
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-xl px-4 py-2.5 text-sm outline-none transition-all pr-11"
                style={{
                  background: 'var(--surface-2)',
                  color: 'var(--on-surface)',
                  border: '1.5px solid var(--border)',
                }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center justify-center"
                style={{ color: 'var(--on-surface-2)' }}
                tabIndex={-1}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? (
                  <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19M1 1l22 22" />
                  </svg>
                ) : (
                  <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M1 12S5 4 12 4s11 8 11 8-4 8-11 8S1 12 1 12z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                )}
              </button>
            </div>
          </div>

          {error && (
            <div
              className="rounded-xl px-4 py-3 text-sm"
              style={{ background: 'rgba(239,68,68,0.1)', color: '#ef4444', border: '1px solid rgba(239,68,68,0.2)' }}
            >
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-xl py-3 font-bold text-sm text-white transition-all disabled:opacity-60 disabled:cursor-not-allowed"
            style={{
              background: 'linear-gradient(135deg, var(--brand-600, #0d9488) 0%, var(--brand-400, #2dd4bf) 100%)',
            }}
          >
            {loading ? 'Signing in…' : 'Sign In'}
          </button>

          <p className="text-center text-xs" style={{ color: 'var(--on-surface-2)' }}>
            Default: <span className="font-mono">admin@saksham.org</span> / <span className="font-mono">Admin@1234</span>
          </p>
        </form>
      </div>
    </div>
  )
}
