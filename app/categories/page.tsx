'use client'
import { useState } from 'react'
import { Icon } from '@/components/ui/Icon'
import { Badge } from '@/components/ui/Badge'

const CATEGORIES = [
  { id: 'c1', name: 'Corporate', color: '#7C6CF0', donors: 142, total: 28500000, description: 'Corporate donors and CSR funds' },
  { id: 'c2', name: 'Individual', color: '#0E8C76', donors: 834, total: 12400000, description: 'Individual philanthropists' },
  { id: 'c3', name: 'Recurring', color: '#F6A723', donors: 267, total: 9600000, description: 'Monthly / annual recurring donors' },
  { id: 'c4', name: 'Education Sponsor', color: '#F2685E', donors: 98, total: 7200000, description: 'Donors who sponsor student education' },
  { id: 'c5', name: 'Health', color: '#3ABCF7', donors: 55, total: 3100000, description: 'Healthcare & medical support donors' },
  { id: 'c6', name: 'Food & Nutrition', color: '#1FA971', donors: 43, total: 2800000, description: 'Food security donors' },
]

function fmt_inr(n: number) {
  if (n >= 10000000) return `₹${(n/10000000).toFixed(1)}Cr`
  if (n >= 100000) return `₹${(n/100000).toFixed(1)}L`
  return `₹${n.toLocaleString('en-IN')}`
}

export default function CategoriesPage() {
  const [cats, setCats] = useState(CATEGORIES)
  const [showForm, setShowForm] = useState(false)
  const [newName, setNewName] = useState('')
  const [newDesc, setNewDesc] = useState('')
  const [newColor, setNewColor] = useState('#0E8C76')

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>Donor Categories</h2>
          <p className="text-[13px]" style={{ color: 'var(--on-surface-2)' }}>Organize and segment your donor base</p>
        </div>
        <button onClick={() => setShowForm(true)}
          className="flex items-center gap-2 px-4 h-10 rounded-xl text-[13px] font-bold text-white"
          style={{ background: 'var(--primary)' }}>
          <Icon name="plus" size={16} color="#fff" /> New Category
        </button>
      </div>

      {showForm && (
        <div className="rounded-2xl border p-5 space-y-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
          <h3 className="font-bold text-[15px]" style={{ color: 'var(--on-surface)' }}>Add Category</h3>
          <div className="grid grid-cols-3 gap-4">
            <div className="col-span-2 space-y-1">
              <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Name</label>
              <input value={newName} onChange={e => setNewName(e.target.value)} placeholder="e.g. Education Sponsor"
                className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none"
                style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
            </div>
            <div className="space-y-1">
              <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Color</label>
              <div className="flex items-center gap-2 h-10 px-3.5 rounded-xl border" style={{ borderColor: 'var(--border)' }}>
                <input type="color" value={newColor} onChange={e => setNewColor(e.target.value)} className="w-7 h-7 rounded-lg cursor-pointer" />
                <span className="text-[13px] font-mono" style={{ color: 'var(--on-surface)' }}>{newColor}</span>
              </div>
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-[11.5px] font-bold uppercase" style={{ color: 'var(--on-surface-2)' }}>Description</label>
            <input value={newDesc} onChange={e => setNewDesc(e.target.value)} placeholder="Short description..."
              className="w-full h-10 px-3.5 rounded-xl border text-[13.5px] bg-transparent outline-none"
              style={{ borderColor: 'var(--border)', color: 'var(--on-surface)' }} />
          </div>
          <div className="flex gap-3 justify-end">
            <button onClick={() => setShowForm(false)} className="px-4 h-9 rounded-xl text-[13px] font-bold" style={{ background: 'var(--surface-2)', color: 'var(--on-surface)' }}>Cancel</button>
            <button onClick={() => {
              if (!newName) return
              setCats(prev => [...prev, { id: `c${Date.now()}`, name: newName, color: newColor, donors: 0, total: 0, description: newDesc }])
              setNewName(''); setNewDesc(''); setNewColor('#0E8C76'); setShowForm(false)
            }} className="px-4 h-9 rounded-xl text-[13px] font-bold text-white" style={{ background: 'var(--primary)' }}>Create Category</button>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {cats.map(c => (
          <div key={c.id} className="rounded-2xl border p-5 space-y-4" style={{ background: 'var(--surface)', borderColor: 'var(--border)' }}>
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: c.color + '22' }}>
                  <div className="w-4 h-4 rounded-full" style={{ background: c.color }} />
                </div>
                <div>
                  <div className="font-bold text-[14.5px]" style={{ color: 'var(--on-surface)' }}>{c.name}</div>
                  <div className="text-[11.5px]" style={{ color: 'var(--on-surface-2)' }}>{c.description}</div>
                </div>
              </div>
              <div className="flex gap-1.5">
                <button className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: 'var(--surface-2)' }}>
                  <Icon name="edit" size={13} color="var(--on-surface-2)" />
                </button>
                <button className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: 'var(--coral-100)' }}>
                  <Icon name="trash" size={13} color="var(--coral-500)" />
                </button>
              </div>
            </div>
            <div className="h-px" style={{ background: 'var(--border)' }} />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-[11px] font-semibold" style={{ color: 'var(--on-surface-2)' }}>Donors</div>
                <div className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>{c.donors.toLocaleString()}</div>
              </div>
              <div>
                <div className="text-[11px] font-semibold" style={{ color: 'var(--on-surface-2)' }}>Total Raised</div>
                <div className="text-[18px] font-bold" style={{ color: 'var(--on-surface)' }}>{fmt_inr(c.total)}</div>
              </div>
            </div>
            <div className="h-1.5 rounded-full overflow-hidden" style={{ background: 'var(--surface-2)' }}>
              <div className="h-full rounded-full" style={{ width: `${Math.min(100, (c.donors / 900) * 100)}%`, background: c.color }} />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
