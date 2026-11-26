'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import {
  Calendar,
  FileText,
  BarChart3,
  Inbox,
  Globe,
  Timer,
  Columns2,
  ArrowUpRight,
  Pin,
  ChevronRight,
  ChevronLeft,
  CheckCircle2,
  Circle,
  Pause,
  Play,
  X,
  Plus,
  Link2,
  Search,
  Sparkles,
  Download,
  BookOpen,
  Github,
} from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { GatekeeperNote, useLatestRelease } from '@/components/DownloadCta'
import { SegmentedControl } from '@/components/apple/SegmentedControl'
import { TimelineBlockCard } from '@/components/apple/TimelineBlockCard'
import { MacTooltip } from '@/components/apple/MacTooltip'
import { GITHUB_REPO_URL } from '@/lib/i18n'
import type { LatestReleaseInfo } from '@/lib/releases'
import { cn } from '@/lib/utils'

type CategoryKey = 'all' | 'work' | 'health' | 'study' | 'personal' | 'none'

interface SubnoteItem {
  id: string
  titleEn: string
  titlePt: string
  bodyEn: string
  bodyPt: string
  backlinksCount: number
}

interface DemoBlock {
  id: string
  day: 'today' | 'tomorrow'
  time: string
  titleEn: string
  titlePt: string
  category: Exclude<CategoryKey, 'all'>
  accentHex: string
  isGlobal?: boolean
  isRecurring?: boolean
  previewEn?: string
  previewPt?: string
  checklistEn: string[]
  checklistPt: string[]
  initialChecked: number[]
  subnotes?: SubnoteItem[]
}

const CATEGORIES: { key: Exclude<CategoryKey, 'all'>; nameEn: string; namePt: string; hex: string }[] = [
  { key: 'work', nameEn: 'Work', namePt: 'Trabalho', hex: '#3B82F6' },
  { key: 'health', nameEn: 'Health', namePt: 'Saúde', hex: '#10B981' },
  { key: 'study', nameEn: 'Studies', namePt: 'Estudos', hex: '#F59E0B' },
  { key: 'personal', nameEn: 'Personal', namePt: 'Pessoal', hex: '#8B5CF6' },
  { key: 'none', nameEn: 'Uncategorized', namePt: 'Sem categoria', hex: '#64748B' },
]

const INITIAL_BLOCKS: DemoBlock[] = [
  {
    id: 'run',
    day: 'today',
    time: '07:30 – 08:30',
    titleEn: 'Morning Run & Mobility',
    titlePt: 'Corrida & Mobilidade',
    category: 'health',
    accentHex: '#10B981',
    isRecurring: true,
    checklistEn: ['5 km Zone 2 pace', '10 min shoulder & hip mobility'],
    checklistPt: ['5 km ritmo Zona 2', '10 min mobilidade ombro e quadril'],
    initialChecked: [0, 1],
  },
  {
    id: 'sre',
    day: 'today',
    time: '09:30 – 11:30',
    titleEn: 'SRE Studies',
    titlePt: 'Estudos de SRE',
    category: 'work',
    accentHex: '#3B82F6',
    isGlobal: true,
    isRecurring: true,
    previewEn: 'SLOs, Error Budgets & [[Kubernetes Networking]]',
    previewPt: 'SLOs, Error Budgets e [[Kubernetes Networking]]',
    checklistEn: [
      'Review Golden Signals & burn-rate alerts',
      'Update [[Postmortem Template]] with incident timeline',
      'Lab: configure OpenTelemetry collector pipeline',
    ],
    checklistPt: [
      'Revisar Golden Signals e alertas de burn-rate',
      'Atualizar [[Template de Postmortem]] com linha do tempo',
      'Lab: configurar pipeline do OpenTelemetry Collector',
    ],
    initialChecked: [0, 1],
    subnotes: [
      {
        id: 'k8s',
        titleEn: 'Kubernetes Networking',
        titlePt: 'Kubernetes Networking',
        bodyEn: 'CNI deep dive: Cilium eBPF datapath, kube-proxy replacement, and Service Mesh latency budgets.',
        bodyPt: 'Aprofundamento em CNI: datapath Cilium eBPF, substituição do kube-proxy e budgets de latência.',
        backlinksCount: 3,
      },
      {
        id: 'otel',
        titleEn: 'Observability & Traces',
        titlePt: 'Observabilidade & Traces',
        bodyEn: 'Correlating structured logs, Prometheus exemplars, and distributed traces across Go + Swift clients.',
        bodyPt: 'Correlação de logs estruturados, exemplars no Prometheus e traces distribuídos entre Go e Swift.',
        backlinksCount: 2,
      },
    ],
  },
  {
    id: 'triage',
    day: 'today',
    time: '12:00 – 12:45',
    titleEn: 'Quick Inbox Triage',
    titlePt: 'Triagem rápida da Inbox',
    category: 'none',
    accentHex: '#64748B',
    checklistEn: ['Reply to GitHub PR comments', 'Move 2 backlog items to Wednesday'],
    checklistPt: ['Responder comentários no PR do GitHub', 'Mover 2 itens do backlog para Quarta'],
    initialChecked: [0],
  },
  {
    id: 'swift-study',
    day: 'today',
    time: '14:00 – 15:30',
    titleEn: 'Swift 6 Concurrency Reading',
    titlePt: 'Leitura: Concorrência em Swift 6',
    category: 'study',
    accentHex: '#F59E0B',
    isGlobal: true,
    previewEn: 'Actors, Sendable isolation & Core Data contexts',
    previewPt: 'Actors, isolamento Sendable e contextos Core Data',
    checklistEn: ['Read SE-0414 Region-based Isolation', 'Benchmark SyncEngine delta merge'],
    checklistPt: ['Ler SE-0414 Region-based Isolation', 'Medir benchmark do merge delta no SyncEngine'],
    initialChecked: [],
  },
  {
    id: 'deep-tomorrow',
    day: 'tomorrow',
    time: '09:00 – 11:00',
    titleEn: 'SRE Studies',
    titlePt: 'Estudos de SRE',
    category: 'work',
    accentHex: '#3B82F6',
    isGlobal: true,
    isRecurring: true,
    previewEn: 'Same Global Block — shared living notes',
    previewPt: 'Mesmo Bloco Global — notas vivas compartilhadas',
    checklistEn: ['Run chaos test on staging cluster'],
    checklistPt: ['Executar teste de caos no cluster de staging'],
    initialChecked: [],
  },
  {
    id: 'guitar',
    day: 'tomorrow',
    time: '18:00 – 19:00',
    titleEn: 'Guitar Practice',
    titlePt: 'Estudo de Violão',
    category: 'personal',
    accentHex: '#8B5CF6',
    checklistEn: ['Fingerstyle arpeggios 15 min', 'Practice new chord progression'],
    checklistPt: ['Dedilhado e arpejos 15 min', 'Treinar nova progressão de acordes'],
    initialChecked: [],
  },
]

const MINI_CAL_DAYS = [
  null, null, null, null, null, null, 1,
  2, 3, 4, 5, 6, 7, 8,
  9, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29,
]
const ACTIVE_DOT_DAYS = new Set([3, 5, 10, 12, 17, 19, 24, 25, 26, 28])

export function MacAppShowcase({ release: releaseProp }: { release?: LatestReleaseInfo }) {
  const { locale, openPalette } = useAppContext()
  const release = useLatestRelease(releaseProp)
  const [splitMode, setSplitMode] = useState<'one' | 'two'>('one')
  const [selectedId, setSelectedId] = useState<string>('sre')
  const [categoryFilter, setCategoryFilter] = useState<CategoryKey>('all')
  const [completedBlocks, setCompletedBlocks] = useState<Record<string, boolean>>({ run: true })
  const [checkedItems, setCheckedItems] = useState<Record<string, number[]>>(() => {
    const map: Record<string, number[]> = {}
    for (const b of INITIAL_BLOCKS) map[b.id] = [...b.initialChecked]
    return map
  })
  const [activeSubnoteId, setActiveSubnoteId] = useState<string | null>(null)
  const [focusActive, setFocusActive] = useState<boolean>(true)
  const [focusPaused, setFocusPaused] = useState<boolean>(false)
  const [focusMinutes, setFocusMinutes] = useState<number>(24)
  const [poppedOut, setPoppedOut] = useState<boolean>(false)
  const [pinnedOnTop, setPinnedOnTop] = useState<boolean>(true)

  const selectedBlock = INITIAL_BLOCKS.find((b) => b.id === selectedId) ?? INITIAL_BLOCKS[1]
  const activeSubnote = selectedBlock.subnotes?.find((s) => s.id === activeSubnoteId) ?? null

  const toggleBlockDone = (id: string) => {
    setCompletedBlocks((prev) => ({ ...prev, [id]: !prev[id] }))
  }

  const toggleChecklistItem = (blockId: string, idx: number) => {
    setCheckedItems((prev) => {
      const current = prev[blockId] ?? []
      const exists = current.includes(idx)
      return {
        ...prev,
        [blockId]: exists ? current.filter((i) => i !== idx) : [...current, idx],
      }
    })
  }

  const visibleToday = INITIAL_BLOCKS.filter(
    (b) => b.day === 'today' && (categoryFilter === 'all' || b.category === categoryFilter)
  )
  const visibleTomorrow = INITIAL_BLOCKS.filter(
    (b) => b.day === 'tomorrow' && (categoryFilter === 'all' || b.category === categoryFilter)
  )

  return (
    <section id="overview" className="bg-canvas pb-20 pt-14 sm:pb-28 sm:pt-20">
      <div className="mx-auto max-w-[1080px] px-4 sm:px-6">
        {/* Things 3 / Apple.com Calm Editorial Hero */}
        <div className="mx-auto flex max-w-[680px] flex-col items-center text-center">
          <div className="mb-6">
            <Image
              src="/images/app-icon.png"
              alt="My Better Life macOS Icon"
              width={80}
              height={80}
              priority
              className="h-[76px] w-[76px] rounded-[18px] shadow-[0_14px_32px_-6px_rgba(0,0,0,0.22),0_2px_6px_rgba(0,0,0,0.1)]"
            />
          </div>

          <h1 className="font-display text-[38px] font-semibold leading-[1.06] tracking-[-0.032em] text-label sm:text-[54px]">
            {locale === 'pt' ? (
              <>
                Time-blocking unido ao seu{' '}
                <span className="text-accent">Segundo Cérebro.</span>
              </>
            ) : (
              <>
                Time-blocking meets your{' '}
                <span className="text-accent">Second Brain.</span>
              </>
            )}
          </h1>

          <p className="mt-5 max-w-[580px] text-[17px] leading-[1.52] text-label-secondary sm:text-[19px]">
            {locale === 'pt'
              ? 'Um aplicativo nativo em SwiftUI para macOS e iOS que une linha do tempo, Blocos Globais com subnotas aninhadas e janelas destacadas. 100% local-first e open source.'
              : 'A native SwiftUI app for macOS and iOS uniting tactile time-blocking, Global Blocks with nested subnotes, and tear-off windows. 100% local-first and open source.'}
          </p>

          {/* Clean Apple CTA pair */}
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <a
              href={release.downloadUrl}
              target="_blank"
              rel="noreferrer"
              className="apple-btn-primary h-[42px] px-6 text-[15px]"
            >
              <Download className="h-4 w-4" />
              {locale === 'pt' ? 'Baixar para macOS' : 'Download for macOS'}
              <span className="text-[13px] opacity-75">v{release.version}</span>
            </a>
            <Link
              href="/docs/getting-started"
              className="apple-btn-secondary h-[42px] px-6 text-[15px]"
            >
              <BookOpen className="h-4 w-4" />
              {locale === 'pt' ? 'Documentação' : 'Docs'}
            </Link>
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noreferrer"
              className="apple-btn-secondary h-[42px] px-6 text-[15px]"
            >
              <Github className="h-4 w-4" />
              GitHub
            </a>
          </div>

          <p className="mt-4 text-[12.5px] text-label-tertiary">
            {locale === 'pt'
              ? 'macOS 15+ · Apple Silicon · iOS 18+ via Xcode · Core Data offline · Grátis & Open Source (MIT)'
              : 'macOS 15+ · Apple Silicon · iOS 18+ via Xcode · Offline Core Data · Free & Open Source (MIT)'}
          </p>

          <GatekeeperNote className="mt-5 max-w-[520px]" />
        </div>

        {/* Interactive App Controls Strip (matching macOS toolbar semantics) */}
        <div className="mt-14 mb-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-[12.5px] font-medium text-label-secondary">
            {locale === 'pt'
              ? 'Prévia interativa — clique nos blocos, filtre categorias, marque checklists ou teste ⌘K'
              : 'Interactive preview — click blocks, filter categories, check off items, or press ⌘K'}
          </p>

          <div className="flex flex-wrap items-center gap-2">
            <MacTooltip
              label={
                locale === 'pt'
                  ? 'Alternar entre 1 Dia ou 2 Dias lado a lado'
                  : 'Switch between 1 Day or 2 Days side-by-side'
              }
            >
              <SegmentedControl
                size="sm"
                ariaLabel="Day layout"
                value={splitMode}
                onChange={setSplitMode}
                options={[
                  { value: 'one', label: locale === 'pt' ? '1 Dia' : '1 Day' },
                  {
                    value: 'two',
                    label: (
                      <span className="inline-flex items-center gap-1">
                        <Columns2 className="h-3.5 w-3.5" />
                        {locale === 'pt' ? '2 Dias' : '2 Days'}
                      </span>
                    ),
                  },
                ]}
              />
            </MacTooltip>

            <MacTooltip
              label={
                locale === 'pt'
                  ? 'Ativar ou encerrar cronômetro de Modo Foco'
                  : 'Toggle Focus Mode countdown banner'
              }
            >
              <button
                type="button"
                onClick={() => setFocusActive((v) => !v)}
                className={cn(
                  'inline-flex h-[28px] items-center gap-1.5 rounded-[7px] px-2.5 text-[12px] font-medium transition-colors',
                  focusActive
                    ? 'bg-accent/12 text-accent'
                    : 'bg-fill text-label-secondary hover:text-label'
                )}
              >
                <Timer className="h-3.5 w-3.5" />
                {focusActive
                  ? locale === 'pt'
                    ? 'Foco Ativo'
                    : 'Focus On'
                  : locale === 'pt'
                    ? 'Modo Foco'
                    : 'Focus Mode'}
              </button>
            </MacTooltip>

            <MacTooltip
              label={
                locale === 'pt'
                  ? 'Destacar nota em janela flutuante independente'
                  : 'Pop out note into an independent floating window'
              }
              shortcut="⌘⇧O"
            >
              <button
                type="button"
                onClick={() => setPoppedOut((v) => !v)}
                className={cn(
                  'inline-flex h-[28px] items-center gap-1.5 rounded-[7px] px-2.5 text-[12px] font-medium transition-colors',
                  poppedOut
                    ? 'bg-mbl-amber/15 text-mbl-amber'
                    : 'bg-fill text-label-secondary hover:text-label'
                )}
              >
                <ArrowUpRight className="h-3.5 w-3.5" />
                {locale === 'pt' ? 'Destacar Aba' : 'Pop-Out'}
              </button>
            </MacTooltip>
          </div>
        </div>

        {/* Authentic macOS Sequoia Application Window */}
        <div className="relative">
          <div className="overflow-hidden rounded-[14px] border border-hairline bg-canvas shadow-apple-window dark:shadow-apple-window-dark">
            {/* macOS Window Titlebar */}
            <div className="flex h-[42px] items-center justify-between border-b border-hairline bg-surface-secondary/90 px-4">
              <div className="flex items-center gap-2">
                <span className="h-[11px] w-[11px] rounded-full bg-[#FF5F56] ring-1 ring-inset ring-black/10" />
                <span className="h-[11px] w-[11px] rounded-full bg-[#FFBD2E] ring-1 ring-inset ring-black/10" />
                <span className="h-[11px] w-[11px] rounded-full bg-[#27C93F] ring-1 ring-inset ring-black/10" />
                <span className="ml-3 hidden text-[12.5px] font-semibold text-label-secondary sm:inline">
                  My Better Life
                </span>
              </div>

              <div className="flex items-center gap-2">
                <MacTooltip
                  label={
                    locale === 'pt'
                      ? 'Abrir Command Palette para buscar e navegar'
                      : 'Open Command Palette to search and jump'
                  }
                  shortcut="⌘K"
                >
                  <button
                    type="button"
                    onClick={openPalette}
                    className="inline-flex h-[26px] items-center gap-2 rounded-[6px] border border-hairline bg-canvas px-2.5 text-[11.5px] text-label-secondary transition-colors hover:text-label"
                  >
                    <Search className="h-3 w-3" />
                    <span className="hidden sm:inline">
                      {locale === 'pt' ? 'Command Palette...' : 'Command Palette...'}
                    </span>
                    <span className="apple-kbd">⌘K</span>
                  </button>
                </MacTooltip>
              </div>
            </div>

            {/* FocusActiveBannerView.swift faithful replica */}
            {focusActive && (
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-hairline bg-canvas px-4 py-2">
                <div className="flex items-center gap-2.5">
                  <span
                    className="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[10px] font-bold tracking-[0.05em]"
                    style={{
                      backgroundColor: `${selectedBlock.accentHex}22`,
                      color: selectedBlock.accentHex,
                    }}
                  >
                    <span
                      className="h-2 w-2 rounded-full"
                      style={{ backgroundColor: focusPaused ? '#F59E0B' : selectedBlock.accentHex }}
                    />
                    {locale === 'pt' ? 'FOCO' : 'FOCUS'}
                  </span>
                  <span className="truncate text-[13px] font-semibold text-label">
                    {locale === 'pt' ? selectedBlock.titlePt : selectedBlock.titleEn}
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  <span className="tabular-nums text-[15px] font-bold text-label">
                    {String(focusMinutes).padStart(2, '0')}:18
                  </span>

                  <MacTooltip
                    label={
                      focusPaused
                        ? locale === 'pt'
                          ? 'Retomar cronômetro de foco'
                          : 'Resume focus timer'
                        : locale === 'pt'
                          ? 'Pausar cronômetro de foco'
                          : 'Pause focus timer'
                    }
                  >
                    <button
                      type="button"
                      onClick={() => setFocusPaused((p) => !p)}
                      aria-label={focusPaused ? 'Resume' : 'Pause'}
                      className="flex h-[26px] w-[26px] items-center justify-center rounded-full bg-fill text-label transition-colors hover:bg-fill-strong"
                    >
                      {focusPaused ? <Play className="h-3 w-3" /> : <Pause className="h-3 w-3" />}
                    </button>
                  </MacTooltip>

                  <MacTooltip
                    label={
                      locale === 'pt'
                        ? 'Estender bloco e timer em 15 minutos'
                        : 'Extend block & timer by 15 minutes'
                    }
                  >
                    <button
                      type="button"
                      onClick={() => setFocusMinutes((m) => m + 15)}
                      className="rounded-full bg-fill px-2.5 py-1 text-[11.5px] font-semibold text-label transition-colors hover:bg-fill-strong"
                    >
                      +15 min
                    </button>
                  </MacTooltip>

                  <MacTooltip
                    label={
                      locale === 'pt'
                        ? 'Marcar bloco como concluído e encerrar foco'
                        : 'Complete active block and finish focus'
                    }
                  >
                    <button
                      type="button"
                      onClick={() => {
                        toggleBlockDone(selectedBlock.id)
                        setFocusActive(false)
                      }}
                      style={{ backgroundColor: selectedBlock.accentHex }}
                      className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold text-white transition-opacity hover:opacity-90"
                    >
                      {locale === 'pt' ? 'Concluir' : 'Done'}
                    </button>
                  </MacTooltip>

                  <MacTooltip label={locale === 'pt' ? 'Encerrar Modo Foco' : 'Stop Focus Mode'}>
                    <button
                      type="button"
                      onClick={() => setFocusActive(false)}
                      aria-label="Close focus banner"
                      className="flex h-6 w-6 items-center justify-center rounded-full text-label-secondary hover:bg-fill"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  </MacTooltip>
                </div>
              </div>
            )}

            {/* 3-Column macOS NavigationSplitView */}
            <div className="grid min-h-[510px] grid-cols-1 lg:grid-cols-12">
              {/* Column 1: Translucent macOS Sidebar */}
              <aside className="apple-sidebar hidden border-r border-hairline p-3 lg:col-span-3 lg:flex lg:flex-col">
                {/* Workspace Switcher */}
                <div className="space-y-0.5">
                  <div className="flex items-center gap-2 rounded-[7px] bg-accent/12 px-2.5 py-1.5 text-[13px] font-semibold text-accent">
                    <Calendar className="h-[15px] w-[15px]" />
                    <span>Agenda</span>
                    <span className="ml-auto font-mono text-[10px] opacity-70">⌘1</span>
                  </div>
                  <div className="flex items-center gap-2 rounded-[7px] px-2.5 py-1.5 text-[13px] font-medium text-label-secondary">
                    <FileText className="h-[15px] w-[15px]" />
                    <span>{locale === 'pt' ? 'Notas' : 'Notes'}</span>
                    <span className="ml-auto font-mono text-[10px] opacity-60">⌘2</span>
                  </div>
                  <div className="flex items-center gap-2 rounded-[7px] px-2.5 py-1.5 text-[13px] font-medium text-label-secondary">
                    <BarChart3 className="h-[15px] w-[15px]" />
                    <span>Insights</span>
                    <span className="ml-auto font-mono text-[10px] opacity-60">⌘3</span>
                  </div>
                </div>

                {/* Mini Month Calendar (MiniMonthCalendarView.swift) */}
                <div className="mt-4 rounded-[9px] border border-hairline bg-canvas/70 p-2.5">
                  <div className="mb-1.5 flex items-center justify-between px-0.5 text-[11px] font-semibold text-label">
                    <span>{locale === 'pt' ? 'Novembro de 2026' : 'November 2026'}</span>
                    <span className="text-[10px] font-medium text-accent">
                      {locale === 'pt' ? 'Hoje' : 'Today'}
                    </span>
                  </div>
                  <div className="grid grid-cols-7 gap-y-0.5 text-center text-[9.5px] font-medium text-label-tertiary">
                    {(locale === 'pt' ? ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'] : ['S', 'M', 'T', 'W', 'T', 'F', 'S']).map(
                      (d, i) => (
                        <span key={i}>{d}</span>
                      )
                    )}
                  </div>
                  <div className="mt-1 grid grid-cols-7 gap-y-0.5 text-center tabular-nums text-[10.5px]">
                    {MINI_CAL_DAYS.map((day, idx) => {
                      if (!day) return <span key={idx} />
                      const isToday = day === 24
                      const hasDot = ACTIVE_DOT_DAYS.has(day)
                      return (
                        <div key={idx} className="flex flex-col items-center">
                          <span
                            className={cn(
                              'flex h-[20px] w-[20px] items-center justify-center rounded-full',
                              isToday
                                ? 'bg-accent font-semibold text-white'
                                : 'text-label-secondary'
                            )}
                          >
                            {day}
                          </span>
                          <span
                            className={cn(
                              'mt-[1px] h-[3px] w-[3px] rounded-full',
                              hasDot ? (isToday ? 'bg-accent' : 'bg-label-tertiary/70') : 'bg-transparent'
                            )}
                          />
                        </div>
                      )
                    })}
                  </div>
                </div>

                {/* Inbox */}
                <div className="mt-4">
                  <div className="mb-1.5 flex items-center justify-between px-1.5 text-[10.5px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                    <span className="inline-flex items-center gap-1">
                      <Inbox className="h-3 w-3" /> Inbox
                    </span>
                    <span className="tabular-nums">2</span>
                  </div>
                  <div className="space-y-1 text-[12px]">
                    <div className="flex items-center justify-between rounded-[7px] bg-canvas/80 px-2 py-1.5 shadow-apple-card">
                      <span className="truncate font-medium text-label">
                        {locale === 'pt' ? 'Revisar alertas OTel' : 'Review OTel alerts'}
                      </span>
                      <span className="tabular-nums text-[10.5px] text-label-tertiary">30m</span>
                    </div>
                    <div className="flex items-center justify-between rounded-[7px] bg-canvas/80 px-2 py-1.5 shadow-apple-card">
                      <span className="truncate font-medium text-label">
                        {locale === 'pt' ? 'Publicar release v1.2' : 'Ship release v1.2'}
                      </span>
                      <span className="tabular-nums text-[10.5px] text-label-tertiary">1h</span>
                    </div>
                  </div>
                </div>

                {/* Global Blocks */}
                <div className="mt-4">
                  <div className="mb-1.5 px-1.5 text-[10.5px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                    {locale === 'pt' ? 'Blocos Globais' : 'Global Blocks'}
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedId('sre')
                      setActiveSubnoteId(null)
                      setCategoryFilter('all')
                    }}
                    className="flex w-full items-center gap-2 rounded-[7px] bg-mbl-blue/10 px-2 py-1.5 text-left text-[12.5px] font-medium text-mbl-blue transition-colors hover:bg-mbl-blue/15"
                  >
                    <Globe className="h-3.5 w-3.5 shrink-0" />
                    <span className="truncate">{locale === 'pt' ? 'Estudos de SRE' : 'SRE Studies'}</span>
                    <span className="ml-auto tabular-nums text-[11px] opacity-80">4</span>
                  </button>
                </div>

                {/* Categories (interactive filter using exact BlockCategory palette!) */}
                <div className="mt-4">
                  <div className="mb-1.5 flex items-center justify-between px-1.5 text-[10.5px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                    <span>{locale === 'pt' ? 'Categorias' : 'Categories'}</span>
                    {categoryFilter !== 'all' && (
                      <button
                        type="button"
                        onClick={() => setCategoryFilter('all')}
                        className="text-[10px] font-medium normal-case text-accent hover:underline"
                      >
                        {locale === 'pt' ? 'Limpar' : 'All'}
                      </button>
                    )}
                  </div>
                  <div className="space-y-0.5">
                    {CATEGORIES.map((cat) => {
                      const active = categoryFilter === cat.key
                      return (
                        <button
                          key={cat.key}
                          type="button"
                          onClick={() => setCategoryFilter(active ? 'all' : cat.key)}
                          className={cn(
                            'flex w-full items-center gap-2 rounded-[6px] px-2 py-1 text-left text-[12px] transition-colors',
                            active
                              ? 'bg-fill-strong font-semibold text-label'
                              : 'text-label-secondary hover:bg-fill hover:text-label'
                          )}
                        >
                          <span
                            className="h-2.5 w-2.5 shrink-0 rounded-full"
                            style={{ backgroundColor: cat.hex }}
                          />
                          <span className="truncate">{locale === 'pt' ? cat.namePt : cat.nameEn}</span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              </aside>

              {/* Column 2: Native Day Timeline (1 Day or 2 Days Split) */}
              <div
                className={cn(
                  'border-b border-hairline bg-canvas p-4 lg:border-b-0 lg:border-r',
                  splitMode === 'two' ? 'lg:col-span-5' : 'lg:col-span-5'
                )}
              >
                <div
                  className={cn(
                    'grid gap-4',
                    splitMode === 'two' ? 'grid-cols-1 sm:grid-cols-2' : 'grid-cols-1'
                  )}
                >
                  {/* Today Column */}
                  <div>
                    <div className="mb-3 flex items-baseline justify-between border-b border-hairline pb-2">
                      <div>
                        <div className="text-[10.5px] font-semibold uppercase tracking-[0.04em] text-accent">
                          {locale === 'pt' ? 'TERÇA-FEIRA · HOJE' : 'TUESDAY · TODAY'}
                        </div>
                        <div className="text-[17px] font-semibold tracking-[-0.02em] text-label">
                          {locale === 'pt' ? '24 de Nov' : 'Nov 24'}
                        </div>
                      </div>
                      <span className="tabular-nums text-[11.5px] text-label-tertiary">
                        {visibleToday.length} {locale === 'pt' ? 'blocos' : 'blocks'}
                      </span>
                    </div>

                    <div className="relative space-y-2.5">
                      {visibleToday.map((block, index) => {
                        const checked = checkedItems[block.id] ?? []
                        const total =
                          locale === 'pt' ? block.checklistPt.length : block.checklistEn.length
                        return (
                          <React.Fragment key={block.id}>
                            {/* Crisp Red Now Indicator (#EF4444) right around 10:42 */}
                            {index === 2 && (
                              <div className="relative flex items-center py-0.5" aria-hidden="true">
                                <span className="tabular-nums mr-1.5 rounded-[4px] bg-mbl-red px-1 py-[1px] text-[9.5px] font-semibold text-white">
                                  10:42
                                </span>
                                <span className="h-[7px] w-[7px] rounded-full bg-mbl-red" />
                                <span className="h-[1.5px] flex-1 bg-mbl-red" />
                              </div>
                            )}

                            <TimelineBlockCard
                              title={locale === 'pt' ? block.titlePt : block.titleEn}
                              timeRange={block.time}
                              accentHex={block.accentHex}
                              preview={locale === 'pt' ? block.previewPt : block.previewEn}
                              isCompleted={Boolean(completedBlocks[block.id])}
                              isSelected={selectedId === block.id}
                              isGlobal={block.isGlobal}
                              isRecurring={block.isRecurring}
                              checklist={{ completed: checked.length, total }}
                              compact={splitMode === 'two'}
                              onSelect={() => {
                                setSelectedId(block.id)
                                setActiveSubnoteId(null)
                              }}
                              onToggleComplete={() => toggleBlockDone(block.id)}
                            />
                          </React.Fragment>
                        )
                      })}
                    </div>
                  </div>

                  {/* Tomorrow Column (when 2 Days Split is active) */}
                  {splitMode === 'two' && (
                    <div className="border-t border-hairline pt-4 sm:border-l sm:border-t-0 sm:pl-4 sm:pt-0">
                      <div className="mb-3 flex items-baseline justify-between border-b border-hairline pb-2">
                        <div>
                          <div className="text-[10.5px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                            {locale === 'pt' ? 'QUARTA-FEIRA' : 'WEDNESDAY'}
                          </div>
                          <div className="text-[17px] font-semibold tracking-[-0.02em] text-label">
                            {locale === 'pt' ? '25 de Nov' : 'Nov 25'}
                          </div>
                        </div>
                        <span className="tabular-nums text-[11.5px] text-label-tertiary">
                          {visibleTomorrow.length}
                        </span>
                      </div>

                      <div className="space-y-2.5">
                        {visibleTomorrow.map((block) => {
                          const checked = checkedItems[block.id] ?? []
                          const total =
                            locale === 'pt' ? block.checklistPt.length : block.checklistEn.length
                          return (
                            <TimelineBlockCard
                              key={block.id}
                              title={locale === 'pt' ? block.titlePt : block.titleEn}
                              timeRange={block.time}
                              accentHex={block.accentHex}
                              preview={locale === 'pt' ? block.previewPt : block.previewEn}
                              isCompleted={Boolean(completedBlocks[block.id])}
                              isSelected={selectedId === block.id}
                              isGlobal={block.isGlobal}
                              isRecurring={block.isRecurring}
                              checklist={{ completed: checked.length, total }}
                              compact
                              onSelect={() => {
                                setSelectedId(block.id)
                                setActiveSubnoteId(null)
                              }}
                              onToggleComplete={() => toggleBlockDone(block.id)}
                            />
                          )
                        })}
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Column 3: Right Inspector (Tabs + Breadcrumbs + Live Markdown/Checklist + Subnotes) */}
              <div className="flex flex-col bg-canvas lg:col-span-4">
                {/* Inspector Tab Strip (drag-to-tear-off / ⌘W / ⌘⇧O) */}
                <div className="flex items-center justify-between border-b border-hairline bg-surface-secondary/60 px-3 py-1.5">
                  <div className="flex items-center gap-1 overflow-x-auto">
                    <span className="inline-flex items-center gap-1.5 rounded-[6px] bg-canvas px-2.5 py-1 text-[11.5px] font-medium text-label shadow-apple-card">
                      <span
                        className="h-2 w-2 rounded-full"
                        style={{ backgroundColor: selectedBlock.accentHex }}
                      />
                      <span className="max-w-[130px] truncate">
                        {locale === 'pt' ? selectedBlock.titlePt : selectedBlock.titleEn}
                      </span>
                    </span>
                  </div>

                  <MacTooltip
                    label={
                      locale === 'pt'
                        ? 'Abrir em janela flutuante destacada'
                        : 'Pop out into floating window'
                    }
                    shortcut="⌘⇧O"
                  >
                    <button
                      type="button"
                      onClick={() => setPoppedOut((v) => !v)}
                      aria-label={
                        locale === 'pt'
                          ? 'Abrir em janela flutuante destacada'
                          : 'Pop out into floating window'
                      }
                      className="flex h-6 w-6 items-center justify-center rounded-[5px] text-label-secondary transition-colors hover:bg-fill hover:text-label"
                    >
                      <ArrowUpRight className="h-3.5 w-3.5" />
                    </button>
                  </MacTooltip>
                </div>

                {/* Inspector Body */}
                <div className="flex-1 p-4">
                  {/* Breadcrumb when inside a Subnote */}
                  {activeSubnote ? (
                    <div className="mb-3 flex items-center gap-1 text-[11.5px] text-label-secondary">
                      <button
                        type="button"
                        onClick={() => setActiveSubnoteId(null)}
                        className="inline-flex items-center gap-0.5 font-medium text-accent hover:underline"
                      >
                        <ChevronLeft className="h-3.5 w-3.5" />
                        {locale === 'pt' ? selectedBlock.titlePt : selectedBlock.titleEn}
                      </button>
                      <ChevronRight className="h-3 w-3 opacity-50" />
                      <span className="truncate font-medium text-label">
                        {locale === 'pt' ? activeSubnote.titlePt : activeSubnote.titleEn}
                      </span>
                    </div>
                  ) : (
                    <div className="mb-2 flex flex-wrap items-center gap-1.5">
                      {selectedBlock.isGlobal && (
                        <span
                          className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10.5px] font-semibold"
                          style={{
                            backgroundColor: `${selectedBlock.accentHex}1A`,
                            color: selectedBlock.accentHex,
                          }}
                        >
                          <Globe className="h-3 w-3" />
                          {locale === 'pt' ? 'Bloco Global' : 'Global Block'}
                        </span>
                      )}
                      <span className="tabular-nums text-[11.5px] text-label-secondary">
                        {selectedBlock.time}
                      </span>
                    </div>
                  )}

                  {/* Note Title */}
                  <h3 className="text-[18px] font-semibold tracking-[-0.02em] text-label">
                    {activeSubnote
                      ? locale === 'pt'
                        ? activeSubnote.titlePt
                        : activeSubnote.titleEn
                      : locale === 'pt'
                        ? selectedBlock.titlePt
                        : selectedBlock.titleEn}
                  </h3>

                  {activeSubnote ? (
                    <div className="mt-3 space-y-4">
                      <p className="text-[13.5px] leading-relaxed text-label-secondary">
                        {locale === 'pt' ? activeSubnote.bodyPt : activeSubnote.bodyEn}
                      </p>
                      <div className="flex items-center gap-2 rounded-[8px] bg-surface-secondary px-3 py-2 text-[12px] text-label-secondary">
                        <Link2 className="h-3.5 w-3.5 text-accent" />
                        <span>
                          {activeSubnote.backlinksCount}{' '}
                          {locale === 'pt' ? 'backlinks conectados' : 'connected backlinks'}
                        </span>
                      </div>
                    </div>
                  ) : (
                    <>
                      {/* Interactive Checklists */}
                      <div className="mt-4 space-y-2">
                        {(locale === 'pt' ? selectedBlock.checklistPt : selectedBlock.checklistEn).map(
                          (item, idx) => {
                            const isChecked = (checkedItems[selectedBlock.id] ?? []).includes(idx)
                            return (
                              <button
                                key={idx}
                                type="button"
                                onClick={() => toggleChecklistItem(selectedBlock.id, idx)}
                                className="flex w-full items-start gap-2 rounded-[7px] px-1.5 py-1 text-left text-[13px] transition-colors hover:bg-fill/60"
                              >
                                {isChecked ? (
                                  <CheckCircle2
                                    className="mt-0.5 h-4 w-4 shrink-0"
                                    style={{ color: selectedBlock.accentHex }}
                                  />
                                ) : (
                                  <Circle className="mt-0.5 h-4 w-4 shrink-0 text-label-tertiary" />
                                )}
                                <span
                                  className={cn(
                                    'leading-snug',
                                    isChecked ? 'text-label-tertiary line-through' : 'text-label'
                                  )}
                                >
                                  {item}
                                </span>
                              </button>
                            )
                          }
                        )}
                      </div>

                      {/* Nested Subnotes (Parent-Child Hierarchy) */}
                      {selectedBlock.subnotes && selectedBlock.subnotes.length > 0 && (
                        <div className="mt-5 border-t border-hairline pt-4">
                          <div className="mb-2 flex items-center justify-between">
                            <span className="text-[11px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                              {locale === 'pt' ? 'Subnotas' : 'Subnotes'}
                            </span>
                            <span className="inline-flex items-center gap-0.5 text-[11px] font-medium text-accent">
                              <Plus className="h-3 w-3" />
                              {locale === 'pt' ? 'Subnota' : 'Subnote'}
                            </span>
                          </div>
                          <div className="space-y-1">
                            {selectedBlock.subnotes.map((sub) => (
                              <button
                                key={sub.id}
                                type="button"
                                onClick={() => setActiveSubnoteId(sub.id)}
                                className="flex w-full items-center justify-between rounded-[7px] bg-surface-secondary px-2.5 py-2 text-left text-[12.5px] font-medium text-label transition-colors hover:bg-fill"
                              >
                                <span className="flex items-center gap-2 truncate">
                                  <FileText className="h-3.5 w-3.5 shrink-0 text-label-secondary" />
                                  <span className="truncate">
                                    {locale === 'pt' ? sub.titlePt : sub.titleEn}
                                  </span>
                                </span>
                                <ChevronRight className="h-3.5 w-3.5 shrink-0 text-label-tertiary" />
                              </button>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Quick Hint */}
                      <div className="mt-5 flex items-center gap-2 rounded-[8px] bg-surface-secondary/80 px-2.5 py-2 text-[11.5px] text-label-secondary">
                        <Sparkles className="h-3.5 w-3.5 shrink-0 text-mbl-amber" />
                        <span>
                          {locale === 'pt'
                            ? 'Digite [[ ou @ para citar ou criar subnotas inline'
                            : 'Type [[ or @ to cite or create nested subnotes inline'}
                        </span>
                      </div>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Floating Slack-Style Detached Pop-Out Window (DetachedEditorWindowView.swift) */}
          {poppedOut && (
            <div className="mt-4 w-full overflow-hidden rounded-[12px] border border-hairline bg-canvas shadow-apple-popover lg:absolute lg:-bottom-6 lg:right-6 lg:mt-0 lg:w-[320px]">
              <div className="flex h-[34px] items-center justify-between border-b border-hairline bg-surface-secondary px-3">
                <div className="flex items-center gap-1.5">
                  <MacTooltip
                    label={locale === 'pt' ? 'Fechar janela destacada' : 'Close detached window'}
                    shortcut="⌘W"
                  >
                    <button
                      type="button"
                      onClick={() => setPoppedOut(false)}
                      aria-label="Close detached window"
                      className="h-2.5 w-2.5 rounded-full bg-[#FF5F56]"
                    />
                  </MacTooltip>
                  <span className="h-2.5 w-2.5 rounded-full bg-[#FFBD2E]" />
                  <span className="h-2.5 w-2.5 rounded-full bg-[#27C93F]" />
                  <span className="ml-2 text-[11px] font-medium text-label-secondary">
                    {locale === 'pt' ? 'Janela Destacada' : 'Detached Window'}
                  </span>
                </div>
                <div className="flex items-center gap-1.5">
                  <MacTooltip
                    label={
                      pinnedOnTop
                        ? locale === 'pt'
                          ? 'Desafixar do topo da tela'
                          : 'Unpin from always on top'
                        : locale === 'pt'
                          ? 'Fixar janela flutuando sempre no topo'
                          : 'Pin window always on top'
                    }
                  >
                    <button
                      type="button"
                      onClick={() => setPinnedOnTop((v) => !v)}
                      className={cn(
                        'inline-flex items-center gap-1 rounded-[5px] px-1.5 py-0.5 text-[10.5px] font-medium',
                        pinnedOnTop
                          ? 'bg-accent/15 text-accent'
                          : 'text-label-secondary hover:bg-fill'
                      )}
                    >
                      <Pin className="h-2.5 w-2.5" />
                      {locale === 'pt' ? 'Topo' : 'Pin'}
                    </button>
                  </MacTooltip>
                  <MacTooltip
                    label={
                      locale === 'pt'
                        ? 'Encaixar de volta na janela principal'
                        : 'Dock back into the main app window'
                    }
                  >
                    <button
                      type="button"
                      onClick={() => setPoppedOut(false)}
                      className="rounded-[5px] bg-fill px-1.5 py-0.5 text-[10.5px] font-medium text-label hover:bg-fill-strong"
                    >
                      {locale === 'pt' ? 'Encaixar' : 'Dock'}
                    </button>
                  </MacTooltip>
                </div>
              </div>
              <div className="p-3.5">
                <div className="flex items-center gap-1.5 text-[11px] font-medium text-mbl-blue">
                  <Globe className="h-3 w-3" />
                  <span>{locale === 'pt' ? selectedBlock.titlePt : selectedBlock.titleEn}</span>
                </div>
                <p className="mt-1.5 text-[12px] leading-relaxed text-label-secondary">
                  {locale === 'pt'
                    ? 'Mantenha suas checklists, runbooks e subnotas flutuando acima do terminal ou do Xcode com histórico ←/→.'
                    : 'Keep checklists, runbooks, and subnotes floating beside Xcode or your terminal with ←/→ navigation history.'}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  )
}
