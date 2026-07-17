const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api/v1'

let token: string | null = null
export function setToken(t: string) { token = t }
export function getToken() { return token }
export function clearToken() { token = null }

async function request<T>(path: string, opts: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  const t = token ?? (typeof window !== 'undefined' ? localStorage.getItem('saksham_token') : null)
  if (t) headers['Authorization'] = `Bearer ${t}`
  const res = await fetch(`${BASE}${path}`, { ...opts, headers: { ...headers, ...(opts.headers as any) } })
  if (!res.ok) {
    if (res.status === 401 && typeof window !== 'undefined') {
      localStorage.removeItem('saksham_token')
      token = null
      if (!window.location.pathname.includes('/login')) window.location.href = '/admin/login'
    }
    const err = await res.json().catch(() => ({ message: res.statusText }))
    throw new Error(err.message ?? 'Request failed')
  }
  const json = await res.json()
  return json.data ?? json
}

export const api = {
  auth: {
    login: (email: string, password: string) => request('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),
    me: () => request('/auth/me'),
  },
  donors: {
    list: (params?: Record<string, any>) => request(`/donors?${new URLSearchParams(params).toString()}`),
    one: (id: string) => request(`/donors/${id}`),
    create: (data: any) => request('/donors', { method: 'POST', body: JSON.stringify(data) }),
    update: (id: string, data: any) => request(`/donors/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
    summary: () => request('/donors/summary'),
  },
  donations: {
    list: (params?: Record<string, any>) => request(`/donations?${new URLSearchParams(params).toString()}`),
    one: (id: string) => request(`/donations/${id}`),
    create: (data: any) => request('/donations', { method: 'POST', body: JSON.stringify(data) }),
    summary: () => request('/donations/summary'),
    tracker: (range?: string) => request(`/donations/tracker?range=${range ?? 'week'}`),
    types: () => request('/donations/types'),
  },
  expenses: {
    list: (params?: Record<string, any>) => request(`/expenses?${new URLSearchParams(params).toString()}`),
    one: (id: string) => request(`/expenses/${id}`),
    create: (data: any) => request('/expenses', { method: 'POST', body: JSON.stringify(data) }),
    update: (id: string, data: any) => request(`/expenses/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
    summary: () => request('/expenses/summary'),
  },
  expenseCategories: {
    list: () => request('/expenses/categories'),
  },
  students: {
    list: (params?: Record<string, any>) => request(`/students?${new URLSearchParams(params).toString()}`),
    one: (id: string) => request(`/students/${id}`),
    create: (data: any) => request('/students', { method: 'POST', body: JSON.stringify(data) }),
    update: (id: string, data: any) => request(`/students/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
    summary: () => request('/students/summary'),
    centers: () => request('/students/centers'),
  },
  categories: {
    list: () => request('/categories'),
    create: (data: any) => request('/categories', { method: 'POST', body: JSON.stringify(data) }),
    update: (id: string, data: any) => request(`/categories/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
    remove: (id: string) => request(`/categories/${id}`, { method: 'DELETE' }),
  },
  achievements: {
    list: (params?: Record<string, any>) => request(`/achievements?${new URLSearchParams(params).toString()}`),
    create: (data: any) => request('/achievements', { method: 'POST', body: JSON.stringify(data) }),
  },
  reminders: {
    list: () => request('/reminders'),
    today: () => request('/reminders/today'),
    birthdays: () => request('/reminders/birthdays'),
    create: (data: any) => request('/reminders', { method: 'POST', body: JSON.stringify(data) }),
    done: (id: string) => request(`/reminders/${id}/done`, { method: 'PATCH' }),
  },
  offices: {
    list: () => request('/offices'),
    create: (data: any) => request('/offices', { method: 'POST', body: JSON.stringify(data) }),
    update: (id: string, data: any) => request(`/offices/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  },
  reports: {
    overview: () => request('/reports/overview'),
    monthlyTrend: (months?: number) => request(`/reports/monthly-trend?months=${months ?? 12}`),
    donorRetention: () => request('/reports/donor-retention'),
  },
  notifications: {
    list: (unread?: boolean) => request(`/notifications?unread=${unread ?? false}`),
    unreadCount: () => request('/notifications/unread-count'),
    markRead: (id: string) => request(`/notifications/${id}/read`, { method: 'PATCH' }),
    markAllRead: () => request('/notifications/read-all', { method: 'PATCH' }),
  },
  settings: {
    getWhatsapp: () => request('/settings/whatsapp'),
    updateWhatsapp: (data: any) => request('/settings/whatsapp', { method: 'PATCH', body: JSON.stringify(data) }),
  },
}
