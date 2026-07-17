'use client'

import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'
import Link from 'next/link'
import { api } from '@/lib/api'
import { ExpenseVoucher, type VoucherData } from '@/components/ExpenseVoucher'
import { Icon } from '@/components/ui/Icon'

interface ExpenseRecord {
  voucherNo: string
  date: string
  paidTo: string
  purpose: string
  amount: number
  paymentMode: string
  reference?: string
  category?: { label: string } | string
  preparedBy?: string
  approvedBy?: string
  receivedBy?: string
}

function toVoucherData(e: ExpenseRecord): VoucherData {
  return {
    voucherNo: e.voucherNo,
    date: new Date(e.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }),
    paidTo: e.paidTo,
    purpose: e.purpose,
    amount: e.amount,
    paymentMode: e.paymentMode,
    reference: e.reference,
    categoryLabel: typeof e.category === 'string' ? e.category : (e.category?.label ?? ''),
    preparedBy: e.preparedBy,
    approvedBy: e.approvedBy,
    receivedBy: e.receivedBy,
  }
}

export default function ExpenseVoucherPage() {
  const { id } = useParams<{ id: string }>()
  const [data, setData] = useState<VoucherData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function load() {
      try {
        const res = await api.expenses.one(id) as any
        const record: ExpenseRecord = res?.data ?? res
        setData(toVoucherData(record))
      } catch (err: any) {
        setError(err?.message ?? 'Failed to load expense voucher')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [id])

  const handlePrint = () => window.print()

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: 'var(--on-surface-2)' }}>
        Loading...
      </div>
    )
  }

  if (error || !data) {
    return (
      <div className="flex items-center justify-center h-64 text-[14px]" style={{ color: '#e53e3e' }}>
        Error: {error ?? 'Expense not found'}
      </div>
    )
  }

  return (
    <>
      {/* Print controls — hidden when printing */}
      <div className="no-print flex items-center justify-between mb-6">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>
            Expense Voucher
          </h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>
            Voucher #{data.voucherNo}
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={handlePrint}
            className="flex items-center gap-2 px-5 h-10 rounded-xl text-[13px] font-bold text-white"
            style={{ background: 'var(--primary)' }}
          >
            <Icon name="download" size={15} color="#fff" /> Download / Print
          </button>
          <Link
            href="/expenses"
            className="flex items-center gap-2 px-5 h-10 rounded-xl text-[13px] font-bold"
            style={{ background: 'var(--surface-2)', color: 'var(--on-surface)' }}
          >
            ← Back
          </Link>
        </div>
      </div>

      <ExpenseVoucher data={data} />

      {/* Print-only styles */}
      <style>{`
        @media print {
          .no-print { display: none !important; }
          body { background: #fff !important; }
          #voucher-print {
            border: none !important;
            box-shadow: none !important;
            max-width: 100% !important;
          }
        }
      `}</style>
    </>
  )
}
