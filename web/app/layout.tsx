import type { Metadata } from 'next'
import { AppProviders } from '@/components/providers'
import { CommandPaletteModal } from '@/components/apple/CommandPaletteModal'
import { getLatestRelease } from '@/lib/releases'
import './globals.css'

export const metadata: Metadata = {
  title: 'My Better Life — Native Time-Blocking & Second Brain for macOS & iOS',
  description:
    'Native SwiftUI time-blocking planner & Second Brain for macOS and iOS. Free & open-source local-first app (MIT) with a direct macOS .dmg download.',
  keywords: [
    'time blocking',
    'second brain',
    'macos planner',
    'open source productivity',
    'local first notes',
    'swiftui',
    'mcp server',
    'things 3 alternative',
    'obsidian open core',
  ],
  openGraph: {
    title: 'My Better Life — Time-Blocking meets your Second Brain',
    description:
      'Native local-first planner & Second Brain for macOS and iOS. Free & open source forever under the MIT license.',
    type: 'website',
  },
}

const themeBootScript = `
  try {
    var t = localStorage.getItem('mbl-theme');
    if (t === 'dark') document.documentElement.classList.add('dark');
  } catch (e) {}
`

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Shared by every page (Header on /docs included); cached 5 min via ISR.
  const latestRelease = await getLatestRelease()

  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootScript }} />
      </head>
      <body className="min-h-screen bg-canvas text-label font-sans selection:bg-accent/20 selection:text-accent">
        <AppProviders release={latestRelease}>
          {children}
          <CommandPaletteModal />
        </AppProviders>
      </body>
    </html>
  )
}
