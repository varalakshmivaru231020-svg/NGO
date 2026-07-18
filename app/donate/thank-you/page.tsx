import Link from 'next/link'

// This page is where Razorpay's hosted checkout redirects the donor's
// browser back to after they complete (or abandon) payment. Any query
// params on this URL are NOT trustworthy (an attacker could craft a fake
// success link) — the webhook (server-to-server, signature-verified) is the
// sole source of truth for whether a donation actually happened. This page
// is purely an informational landing page: no reads, no writes, no "status"
// claims based on the URL.
export default function DonateThankYouPage() {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)', padding: '100px 24px' }}>
      <div style={{ background: '#fff', borderRadius: 24, border: '1px solid var(--border)', padding: 48, maxWidth: 520, textAlign: 'center', boxShadow: '0 8px 40px rgba(13,31,27,0.08)' }}>
        <div style={{ width: 80, height: 80, borderRadius: '50%', background: '#EAFBF6', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px', fontSize: 36 }}>🙏</div>
        <h2 style={{ fontSize: 26, fontWeight: 800, marginBottom: 12 }}>Thank You for Your Donation!</h2>
        <p style={{ color: 'var(--muted)', lineHeight: 1.8, marginBottom: 8 }}>
          We're processing your donation now. Once it's confirmed, you'll receive an 80G tax receipt via WhatsApp and email.
        </p>
        <p style={{ color: 'var(--muted)', lineHeight: 1.8, marginBottom: 24 }}>
          If you closed the payment page before finishing, no charge was made — feel free to try again anytime.
        </p>
        <div style={{ background: 'var(--bg)', borderRadius: 14, padding: '16px 20px', marginBottom: 28, fontSize: 14, color: 'var(--text)' }}>
          Your generosity <strong>makes a real difference</strong>. Thank you for being part of Saksham.
        </div>
        <Link href="/" className="btn-primary">← Back to Home</Link>
      </div>
    </div>
  )
}
