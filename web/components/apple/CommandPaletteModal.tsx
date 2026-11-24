'use client'

import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  Search,
  BookOpen,
  Compass,
  Sun,
  Moon,
  Languages,
  Github,
  CornerDownLeft,
  Download,
  Sparkles,
  Terminal,
  Layers,
  Globe,
} from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { GITHUB_REPO_URL } from '@/lib/i18n'
import { cn } from '@/lib/utils'

interface PaletteEntry {
  id: string
  section: 'docs' | 'navigate' | 'actions'
  titleEn: string
  titlePt: string
  subtitleEn: string
  subtitlePt: string
  accentHex: string
  icon: React.ReactNode
  run: () => void
}

/**
 * Real Spotlight / macOS `⌘K` Command Palette modeled directly after `CommandPaletteView.swift`.
 * Works across both the Landing Page and Documentation Portal with ↑ ↓ ↵ Esc keyboard navigation.
 */
export function CommandPaletteModal() {
  const router = useRouter()
  const { locale, setLocale, theme, toggleTheme, isPaletteOpen, closePalette, release } = useAppContext()
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const allEntries: PaletteEntry[] = useMemo(
    () => [
      {
        id: 'doc-getting-started',
        section: 'docs',
        titleEn: 'Getting Started',
        titlePt: 'Primeiros Passos',
        subtitleEn: 'Download the macOS .dmg, first launch & building from source',
        subtitlePt: 'Baixe o .dmg para macOS, primeira abertura e compilação do código',
        accentHex: '#3B82F6',
        icon: <BookOpen className="h-4 w-4" />,
        run: () => router.push('/docs/getting-started'),
      },
      {
        id: 'doc-shortcuts',
        section: 'docs',
        titleEn: 'Time-Blocking & Shortcuts',
        titlePt: 'Agenda & Atalhos',
        subtitleEn: '2-day split, multi-select, tear-off windows & ⌘Z Undo',
        subtitlePt: '2 dias lado a lado, seleção múltipla, janelas destacadas e ⌘Z',
        accentHex: '#10B981',
        icon: <Terminal className="h-4 w-4" />,
        run: () => router.push('/docs/shortcuts-and-workflow'),
      },
      {
        id: 'doc-second-brain',
        section: 'docs',
        titleEn: 'Second Brain & Subnotes',
        titlePt: 'Segundo Cérebro & Subnotas',
        subtitleEn: 'Global Blocks, nested parent-child subnotes & [[wikilinks]]',
        subtitlePt: 'Blocos Globais, subnotas aninhadas e [[wikilinks]]',
        accentHex: '#F59E0B',
        icon: <Globe className="h-4 w-4" />,
        run: () => router.push('/docs/second-brain'),
      },
      {
        id: 'doc-open-core',
        section: 'docs',
        titleEn: 'Open-Core Philosophy & Cloud',
        titlePt: 'Modelo Open-Core & Cloud',
        subtitleEn: 'Free forever MIT app & upcoming optional cloud add-ons',
        subtitlePt: 'App MIT grátis para sempre e futuros add-ons de nuvem opcionais',
        accentHex: '#8B5CF6',
        icon: <Sparkles className="h-4 w-4" />,
        run: () => router.push('/docs/open-core-pricing'),
      },
      {
        id: 'doc-architecture',
        section: 'docs',
        titleEn: 'System Architecture',
        titlePt: 'Arquitetura do Sistema',
        subtitleEn: 'Swift 6 + SwiftUI, local-first Core Data & MyBetterLifeCore engines',
        subtitlePt: 'Swift 6 + SwiftUI, Core Data local-first e engines do MyBetterLifeCore',
        accentHex: '#64748B',
        icon: <Layers className="h-4 w-4" />,
        run: () => router.push('/docs/architecture'),
      },
      {
        id: 'nav-home',
        section: 'navigate',
        titleEn: 'Overview & Interactive App',
        titlePt: 'Visão Geral & App Interativo',
        subtitleEn: 'Jump to the home page',
        subtitlePt: 'Voltar para a página inicial',
        accentHex: '#3B82F6',
        icon: <Compass className="h-4 w-4" />,
        run: () => router.push('/'),
      },
      {
        id: 'nav-pricing',
        section: 'navigate',
        titleEn: 'Open-Core (Open Source vs. Cloud Add-Ons)',
        titlePt: 'Open-Core (Open Source vs. Add-Ons Cloud)',
        subtitleEn: 'Free forever local app and upcoming optional cloud add-ons',
        subtitlePt: 'App local grátis para sempre e futuros add-ons de nuvem',
        accentHex: '#8B5CF6',
        icon: <Sparkles className="h-4 w-4" />,
        run: () => router.push('/#open-core'),
      },
      {
        id: 'action-theme',
        section: 'actions',
        titleEn: theme === 'dark' ? 'Switch to Light Appearance' : 'Switch to Dark Appearance',
        titlePt: theme === 'dark' ? 'Mudar para Aparência Clara' : 'Mudar para Aparência Escura',
        subtitleEn: 'Toggle macOS Light / Dark mode',
        subtitlePt: 'Alternar modo Claro / Escuro do macOS',
        accentHex: '#F59E0B',
        icon: theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />,
        run: () => toggleTheme(),
      },
      {
        id: 'action-locale',
        section: 'actions',
        titleEn: locale === 'en' ? 'Switch Language to Português (BR)' : 'Switch Language to English',
        titlePt: locale === 'pt' ? 'Mudar idioma para English' : 'Mudar idioma para Português (BR)',
        subtitleEn: 'Instant bilingual toggle (EN / PT)',
        subtitlePt: 'Troca bilíngue instantânea (EN / PT)',
        accentHex: '#3B82F6',
        icon: <Languages className="h-4 w-4" />,
        run: () => setLocale(locale === 'en' ? 'pt' : 'en'),
      },
      {
        id: 'action-download',
        section: 'actions',
        titleEn: `Download for macOS (v${release.version})`,
        titlePt: `Baixar para macOS (v${release.version})`,
        subtitleEn: 'Latest .dmg from GitHub Releases',
        subtitlePt: 'Último .dmg do GitHub Releases',
        accentHex: '#3B82F6',
        icon: <Download className="h-4 w-4" />,
        run: () => window.open(release.downloadUrl, '_blank', 'noopener,noreferrer'),
      },
      {
        id: 'action-github',
        section: 'actions',
        titleEn: 'Open GitHub Repository',
        titlePt: 'Abrir Repositório no GitHub',
        subtitleEn: 'igordonatti/my-better-life',
        subtitlePt: 'igordonatti/my-better-life',
        accentHex: '#64748B',
        icon: <Github className="h-4 w-4" />,
        run: () => window.open(GITHUB_REPO_URL, '_blank', 'noopener,noreferrer'),
      },
    ],
    [router, theme, toggleTheme, locale, setLocale, release]
  )

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return allEntries
    return allEntries.filter((entry) => {
      const hay = `${entry.titleEn} ${entry.titlePt} ${entry.subtitleEn} ${entry.subtitlePt}`.toLowerCase()
      return hay.includes(q)
    })
  }, [allEntries, query])

  useEffect(() => {
    if (isPaletteOpen) {
      setQuery('')
      setSelectedIndex(0)
      requestAnimationFrame(() => inputRef.current?.focus())
    }
  }, [isPaletteOpen])

  useEffect(() => {
    setSelectedIndex(0)
  }, [query])

  useEffect(() => {
    if (!isPaletteOpen) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        closePalette()
      } else if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIndex((i) => (filtered.length > 0 ? (i + 1) % filtered.length : 0))
      } else if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIndex((i) =>
          filtered.length > 0 ? (i - 1 + filtered.length) % filtered.length : 0
        )
      } else if (e.key === 'Enter' && filtered[selectedIndex]) {
        e.preventDefault()
        filtered[selectedIndex].run()
        closePalette()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [isPaletteOpen, filtered, selectedIndex, closePalette])

  if (!isPaletteOpen) return null

  const sectionLabel = (s: PaletteEntry['section']) => {
    if (s === 'docs') return locale === 'pt' ? 'DOCUMENTAÇÃO' : 'DOCUMENTATION'
    if (s === 'navigate') return locale === 'pt' ? 'NAVEGAR' : 'NAVIGATE'
    return locale === 'pt' ? 'AÇÕES RÁPIDAS' : 'QUICK ACTIONS'
  }

  // Group preserving flat index
  const sections: { section: PaletteEntry['section']; items: { idx: number; entry: PaletteEntry }[] }[] = []
  filtered.forEach((entry, idx) => {
    const group = sections.find((g) => g.section === entry.section)
    if (group) group.items.push({ idx, entry })
    else sections.push({ section: entry.section, items: [{ idx, entry }] })
  })

  return (
    <div
      className="fixed inset-0 z-[100] flex items-start justify-center bg-black/30 px-4 pt-[12vh] backdrop-blur-[3px]"
      onClick={closePalette}
      role="dialog"
      aria-modal="true"
      aria-label="Command Palette"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-[580px] overflow-hidden rounded-[14px] border border-hairline bg-canvas shadow-apple-window dark:shadow-apple-window-dark"
      >
        {/* Spotlight Search Header */}
        <div className="flex items-center gap-3 border-b border-hairline px-4 py-3.5">
          <Search className="h-[18px] w-[18px] shrink-0 text-label-secondary" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={
              locale === 'pt'
                ? 'Buscar documentação, recursos ou ações...'
                : 'Search documentation, features, or actions...'
            }
            className="w-full bg-transparent text-[15px] text-label placeholder:text-label-tertiary focus:outline-none"
          />
          <span className="apple-kbd">esc</span>
        </div>

        {/* Grouped Results List */}
        <div className="max-h-[360px] overflow-y-auto p-2">
          {sections.length === 0 ? (
            <div className="py-10 text-center text-[13px] text-label-secondary">
              {locale === 'pt' ? 'Nenhum resultado encontrado.' : 'No matching results.'}
            </div>
          ) : (
            sections.map((group) => (
              <div key={group.section} className="mb-2 last:mb-0">
                <div className="px-2.5 pb-1 pt-2 text-[10px] font-semibold tracking-[0.06em] text-label-tertiary">
                  {sectionLabel(group.section)}
                </div>
                {group.items.map(({ idx, entry }) => {
                  const selected = idx === selectedIndex
                  return (
                    <button
                      key={entry.id}
                      type="button"
                      onMouseEnter={() => setSelectedIndex(idx)}
                      onClick={() => {
                        entry.run()
                        closePalette()
                      }}
                      className={cn(
                        'flex w-full items-center gap-3 rounded-[8px] px-2.5 py-2 text-left transition-colors',
                        selected ? 'bg-accent text-white' : 'text-label hover:bg-fill'
                      )}
                    >
                      <span
                        style={
                          selected
                            ? undefined
                            : { backgroundColor: `${entry.accentHex}1A`, color: entry.accentHex }
                        }
                        className={cn(
                          'flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px]',
                          selected && 'bg-white/20 text-white'
                        )}
                      >
                        {entry.icon}
                      </span>

                      <div className="min-w-0 flex-1">
                        <div className="truncate text-[13.5px] font-medium leading-tight">
                          {locale === 'pt' ? entry.titlePt : entry.titleEn}
                        </div>
                        <div
                          className={cn(
                            'truncate text-[11.5px]',
                            selected ? 'text-white/80' : 'text-label-secondary'
                          )}
                        >
                          {locale === 'pt' ? entry.subtitlePt : entry.subtitleEn}
                        </div>
                      </div>

                      {selected && <CornerDownLeft className="h-3.5 w-3.5 shrink-0 text-white/85" />}
                    </button>
                  )
                })}
              </div>
            ))
          )}
        </div>

        {/* macOS Keyboard Hints Footer (exact match to CommandPaletteView.swift) */}
        <div className="flex items-center justify-between border-t border-hairline bg-surface-secondary/70 px-4 py-2 text-[11px] text-label-secondary">
          <div className="flex items-center gap-3">
            <span className="inline-flex items-center gap-1">
              <span className="apple-kbd">↑</span>
              <span className="apple-kbd">↓</span>
              {locale === 'pt' ? 'Navegar' : 'Navigate'}
            </span>
            <span className="inline-flex items-center gap-1">
              <span className="apple-kbd">↵</span>
              {locale === 'pt' ? 'Abrir' : 'Open'}
            </span>
          </div>
          <span className="tabular-nums text-label-tertiary">
            {filtered.length} {locale === 'pt' ? 'itens' : 'items'}
          </span>
        </div>
      </div>
    </div>
  )
}
