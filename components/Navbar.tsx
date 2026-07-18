'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'

const NAV = [
  { href: '/',         label: 'Home' },
  { href: '/about',   label: 'About Us' },
  { href: '/programs', label: 'Programs' },
  { href: '/impact',  label: 'Impact' },
  { href: '/contact', label: 'Contact' },
]

export function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const fn = () => setScrolled(window.scrollY > 40)
    window.addEventListener('scroll', fn)
    return () => window.removeEventListener('scroll', fn)
  }, [])

  return (
    <nav style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
      background: scrolled ? 'rgba(255,255,255,0.97)' : 'transparent',
      backdropFilter: scrolled ? 'blur(12px)' : 'none',
      borderBottom: scrolled ? '1px solid var(--border)' : 'none',
      transition: 'all 0.3s',
    }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', height: 72, gap: 32 }}>
        {/* Logo */}
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: 'var(--brand)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M12 2L3 7v5c0 5.25 3.75 10.15 9 11.35C17.25 22.15 21 17.25 21 12V7L12 2z" fill="white" opacity=".9"/><path d="M9 12l2 2 4-4" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div>
            <div style={{ fontSize: 16, fontWeight: 800, color: scrolled ? 'var(--text)' : '#fff', lineHeight: 1 }}>Saksham</div>
            <div style={{ fontSize: 9, fontWeight: 700, color: scrolled ? 'var(--brand)' : 'rgba(255,255,255,0.7)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>Foundation</div>
          </div>
        </Link>

        {/* Desktop nav */}
        <div style={{ display: 'flex', gap: 4, flex: 1, justifyContent: 'center' }} className="hidden md:flex">
          {NAV.map(n => (
            <Link key={n.href} href={n.href}
              style={{ padding: '7px 16px', borderRadius: 99, fontSize: 14, fontWeight: 600, color: scrolled ? 'var(--text)' : 'rgba(255,255,255,0.9)', transition: 'all 0.15s' }}
              onMouseEnter={e => { (e.target as HTMLElement).style.background = scrolled ? 'var(--bg)' : 'rgba(255,255,255,0.15)' }}
              onMouseLeave={e => { (e.target as HTMLElement).style.background = 'transparent' }}>
              {n.label}
            </Link>
          ))}
        </div>

        {/* CTA */}
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginLeft: 'auto' }}>
          <Link href="/donate" className="btn-primary" style={{ padding: '10px 22px', fontSize: 14, boxShadow: scrolled ? '0 4px 20px rgba(14,140,118,0.3)' : 'none' }}>
            Donate Now
          </Link>
          {/* Hamburger */}
          <button onClick={() => setOpen(!open)} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: 5, padding: 4 }} className="md:hidden">
            {[0,1,2].map(i => <span key={i} style={{ width: 24, height: 2, background: scrolled ? 'var(--text)' : '#fff', borderRadius: 2, display: 'block', transition: 'all 0.2s', transform: open && i===0 ? 'rotate(45deg) translateY(7px)' : open && i===2 ? 'rotate(-45deg) translateY(-7px)' : 'none', opacity: open && i===1 ? 0 : 1 }} />)}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {open && (
        <div style={{ background: '#fff', borderTop: '1px solid var(--border)', padding: '16px 24px 20px' }}>
          {NAV.map(n => (
            <Link key={n.href} href={n.href} onClick={() => setOpen(false)}
              style={{ display: 'block', padding: '10px 0', fontSize: 15, fontWeight: 600, color: 'var(--text)', borderBottom: '1px solid var(--border)' }}>
              {n.label}
            </Link>
          ))}
          <Link href="/donate" className="btn-primary" onClick={() => setOpen(false)} style={{ marginTop: 16, width: '100%', justifyContent: 'center' }}>
            Donate Now
          </Link>
        </div>
      )}
    </nav>
  )
}
