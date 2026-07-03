'use client'

import { useParams } from 'next/navigation'
import { DonationReceipt, type ReceiptData } from '@/components/DonationReceipt'
import { Icon } from '@/components/ui/Icon'

// Sample receipt data — replace with API call: api.donations.receipt(id)
const SAMPLE: ReceiptData = {
  receiptNo: '2026/000001',
  date: 'June 11, 2026',
  mode: 'Bank Transfer',
  gatewayRef: '615776676292',
  donor: {
    name: 'Rajesh Khanna',
    phone: '+91 98201 44521',
    city: 'Mumbai, Maharashtra, India',
    pan: 'ABCPK1234Z',
  },
  items: [
    {
      product: 'General Corpus Donation',
      description:
        'Contribution allocated towards trust operational support, community educational aid, and welfare programs. Clean tax exemption applicable.',
      qty: 1,
      cost: 500000,
    },
  ],
  amountInWords: 'Rupees Five Lakh Only',
  trustPan: 'AATTS6672D',
  reg12AA: 'ITBA/EXM/S/12AA/2018-19/A/10252',
  cert80G: 'AATTS6672DF20221',
  supportEmail: 'donations@sakshamfoundation.org',
}

export default function ReceiptPage() {
  const { id } = useParams<{ id: string }>()

  const handlePrint = () => window.print()

  return (
    <>
      {/* Print controls — hidden when printing */}
      <div className="no-print flex items-center justify-between mb-6">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>
            Donation Receipt
          </h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>
            Receipt #{id}
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
          <a
            href="/donations"
            className="flex items-center gap-2 px-5 h-10 rounded-xl text-[13px] font-bold"
            style={{ background: 'var(--surface-2)', color: 'var(--on-surface)' }}
          >
            ← Back
          </a>
        </div>
      </div>

      <DonationReceipt data={SAMPLE} />

      {/* Print-only styles */}
      <style>{`
        @media print {
          .no-print { display: none !important; }
          body { background: #fff !important; }
          #receipt-print {
            border: none !important;
            box-shadow: none !important;
            max-width: 100% !important;
          }
        }
      `}</style>
    </>
  )
}
