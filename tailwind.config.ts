import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Plus Jakarta Sans', 'system-ui', 'sans-serif'],
      },
      colors: {
        brand: {
          900: '#064E40', 800: '#0A6253', 700: '#0B6E5D',
          600: '#0E8C76', 500: '#14A98C', 400: '#34C3A6',
          300: '#6FD7C2', 100: '#D6F3EC', 50: '#EAFBF6',
        },
        amber: { 600: '#E0921A', 500: '#F6A723', 100: '#FFF1D6' },
        coral: { 500: '#F2685E', 100: '#FFE3DF' },
        violet: { 500: '#7C6CF0', 100: '#E7E3FD' },
        sky: { 500: '#2D9CDB', 100: '#DCEFFB' },
      },
      borderRadius: {
        xs: '10px', sm: '14px', md: '18px', lg: '24px', xl: '30px',
      },
      boxShadow: {
        card: '0 4px 16px rgba(13,40,34,0.08)',
        lg: '0 10px 32px rgba(13,40,34,0.12)',
        fab: '0 6px 16px rgba(14,140,118,0.36)',
      },
    },
  },
  plugins: [],
}

export default config
