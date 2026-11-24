import type { Config } from 'tailwindcss'
import typography from '@tailwindcss/typography'

const config: Config = {
  darkMode: 'class',
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './lib/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          '"SF Pro Text"',
          '"SF Pro Display"',
          '"Helvetica Neue"',
          'system-ui',
          'sans-serif',
        ],
        display: [
          '-apple-system',
          'BlinkMacSystemFont',
          '"SF Pro Display"',
          '"SF Pro Text"',
          '"Helvetica Neue"',
          'system-ui',
          'sans-serif',
        ],
        mono: [
          '"SF Mono"',
          'ui-monospace',
          'SFMono-Regular',
          'Menlo',
          'Monaco',
          'Consolas',
          'monospace',
        ],
      },
      colors: {
        /* Apple macOS Sequoia + My Better Life semantic tokens */
        canvas: 'var(--mbl-canvas)',
        surface: 'var(--mbl-surface)',
        'surface-secondary': 'var(--mbl-surface-secondary)',
        sidebar: 'var(--mbl-sidebar)',
        fill: 'var(--mbl-fill)',
        'fill-strong': 'var(--mbl-fill-strong)',
        hairline: 'var(--mbl-hairline)',
        label: 'var(--mbl-label)',
        'label-secondary': 'var(--mbl-label-secondary)',
        'label-tertiary': 'var(--mbl-label-tertiary)',
        accent: 'var(--mbl-accent)',
        'accent-hover': 'var(--mbl-accent-hover)',
        /* Real My Better Life BlockCategory.curatedPalette */
        'mbl-blue': '#3B82F6',
        'mbl-emerald': '#10B981',
        'mbl-amber': '#F59E0B',
        'mbl-violet': '#8B5CF6',
        'mbl-slate': '#64748B',
        'mbl-red': '#EF4444',
      },
      borderRadius: {
        block: '8px',
        sheet: '14px',
        window: '16px',
      },
      boxShadow: {
        'apple-window':
          '0 24px 60px -15px rgba(0, 0, 0, 0.16), 0 0 0 0.5px rgba(0, 0, 0, 0.10)',
        'apple-window-dark':
          '0 28px 70px -15px rgba(0, 0, 0, 0.72), 0 0 0 0.5px rgba(255, 255, 255, 0.14)',
        'apple-popover':
          '0 14px 38px -8px rgba(0, 0, 0, 0.18), 0 0 0 0.5px rgba(0, 0, 0, 0.08)',
        'apple-thumb': '0 1px 3px rgba(0, 0, 0, 0.12), 0 1px 1px rgba(0, 0, 0, 0.06)',
        'apple-card': '0 1px 2px rgba(0, 0, 0, 0.04), 0 0 0 0.5px rgba(0, 0, 0, 0.06)',
      },
    },
  },
  plugins: [typography],
}

export default config
