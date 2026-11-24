'use client'

import React, { useState } from 'react'
import {
  ChevronDown,
  ChevronRight,
  FileText,
  Globe,
  RotateCcw,
  Trash2,
  Flame,
  Search,
  Timer,
  Plus,
  CheckCircle2,
  Circle,
  Link2,
} from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { TimelineBlockCard } from '@/components/apple/TimelineBlockCard'
import { cn } from '@/lib/utils'

export function FeatureShowcase() {
  const { locale, openPalette } = useAppContext()

  // Interactive Undo demo state (Band 1)
  const [deletedBlock, setDeletedBlock] = useState(false)

  // Interactive Subnotes Tree state (Band 2)
  const [expandedRoot, setExpandedRoot] = useState(true)
  const [expandedK8s, setExpandedK8s] = useState(true)
  const [selectedNode, setSelectedNode] = useState<'root' | 'k8s' | 'net' | 'otel'>('net')

  // Interactive Menu Bar quick capture state (Band 3)
  const [menuInboxInput, setMenuInboxInput] = useState('')
  const [menuItems, setMenuItems] = useState<string[]>([
    'Revisar SLOs de produção',
    'Escrever release notes v1.2',
  ])

  const handleAddMenuInbox = (e: React.FormEvent) => {
    e.preventDefault()
    const trimmed = menuInboxInput.trim()
    if (!trimmed) return
    setMenuItems((prev) => [trimmed, ...prev.slice(0, 3)])
    setMenuInboxInput('')
  }

  return (
    <div id="features">
      {/* Band 1: Time-Blocking, Multi-Select & Lossless Undo (Surface Secondary) */}
      <section className="border-t border-hairline bg-surface-secondary py-20 sm:py-24">
        <div className="mx-auto grid max-w-[1080px] grid-cols-1 items-center gap-12 px-4 sm:px-6 lg:grid-cols-12">
          <div className="lg:col-span-5">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-mbl-blue">
              {locale === 'pt' ? 'Linha do Tempo Nativa' : 'Native Timeline'}
            </p>
            <h2 className="mt-2 font-display text-[28px] font-semibold leading-[1.14] tracking-[-0.028em] text-label sm:text-[34px]">
              {locale === 'pt'
                ? 'Planeje em segundos. Copie rotinas. Desfaça sem medo.'
                : 'Plan in seconds. Copy routines. Undo without fear.'}
            </h2>
            <p className="mt-4 text-[15.5px] leading-[1.6] text-label-secondary">
              {locale === 'pt'
                ? 'Arraste para criar blocos de 15 em 15 minutos, compare 2 dias lado a lado, selecione múltiplos blocos com ⌘+Clique para copiar com ⌘C/⌘V e restaure qualquer exclusão com ⌘Z — incluindo séries recorrentes e notas.'
                : 'Drag to paint 15-minute blocks, compare two days side-by-side, multi-select with ⌘+Click to copy/paste whole schedules, and restore any accidental deletion with ⌘Z — recurring series and notes included.'}
            </p>
            <div className="mt-5 flex flex-wrap items-center gap-2 text-[12px] text-label-secondary">
              <span className="apple-kbd">⌘C</span>
              <span className="apple-kbd">⌘V</span>
              <span className="apple-kbd">⌘A</span>
              <span className="apple-kbd">⌘Z</span>
              <span className="ml-1 text-label-tertiary">
                {locale === 'pt' ? 'Atalhos nativos no macOS' : 'Native macOS shortcuts'}
              </span>
            </div>
          </div>

          <div className="lg:col-span-7">
            <div className="rounded-[14px] border border-hairline bg-canvas p-5 shadow-apple-card">
              <div className="mb-3 flex items-center justify-between text-[12px] text-label-secondary">
                <span className="font-semibold text-label">
                  {locale === 'pt' ? 'Experimente apagar e desfazer' : 'Try deleting and undoing'}
                </span>
                {!deletedBlock ? (
                  <button
                    type="button"
                    onClick={() => setDeletedBlock(true)}
                    className="inline-flex items-center gap-1 rounded-[6px] bg-fill px-2.5 py-1 text-[11.5px] font-medium text-mbl-red transition-colors hover:bg-fill-strong"
                  >
                    <Trash2 className="h-3 w-3" />
                    {locale === 'pt' ? 'Simular ⌫ Apagar' : 'Simulate ⌫ Delete'}
                  </button>
                ) : (
                  <span className="text-[11.5px] text-label-tertiary">
                    {locale === 'pt' ? 'Bloco removido' : 'Block deleted'}
                  </span>
                )}
              </div>

              <div className="space-y-2.5">
                <TimelineBlockCard
                  title={locale === 'pt' ? 'Arquitetura Backend Go' : 'Go Backend Architecture'}
                  timeRange="09:00 – 10:30"
                  accentHex="#3B82F6"
                  isSelected
                  isRecurring
                  checklist={{ completed: 2, total: 3 }}
                />

                {!deletedBlock ? (
                  <TimelineBlockCard
                    title={locale === 'pt' ? 'Revisão de PRs & Inbox' : 'PR Review & Inbox'}
                    timeRange="11:00 – 11:45"
                    accentHex="#64748B"
                    checklist={{ completed: 1, total: 2 }}
                  />
                ) : (
                  <div className="flex h-[58px] items-center justify-center rounded-[8px] border border-dashed border-hairline text-[12.5px] text-label-tertiary">
                    {locale === 'pt' ? 'Horário livre · 11:00 – 11:45' : 'Open slot · 11:00 – 11:45'}
                  </div>
                )}

                <TimelineBlockCard
                  title={locale === 'pt' ? 'Treino de Força' : 'Strength Training'}
                  timeRange="12:30 – 13:30"
                  accentHex="#10B981"
                  isRecurring
                />
              </div>

              {/* Exact floating Undo Toast pill matching MyBetterLifeRootView.swift */}
              <div className="mt-4 flex min-h-[38px] items-center justify-center">
                {deletedBlock ? (
                  <div className="inline-flex items-center gap-3 rounded-full border border-hairline bg-surface-secondary px-4 py-1.5 text-[12.5px] shadow-apple-popover">
                    <span className="text-label">
                      {locale === 'pt'
                        ? '"Revisão de PRs & Inbox" excluído'
                        : '"PR Review & Inbox" deleted'}
                    </span>
                    <button
                      type="button"
                      onClick={() => setDeletedBlock(false)}
                      className="inline-flex items-center gap-1 font-semibold text-accent hover:underline"
                    >
                      <RotateCcw className="h-3.5 w-3.5" />
                      {locale === 'pt' ? 'Desfazer' : 'Undo'}
                      <span className="apple-kbd ml-0.5">⌘Z</span>
                    </button>
                  </div>
                ) : (
                  <span className="text-[11.5px] text-label-tertiary">
                    {locale === 'pt'
                      ? 'Editar título, categoria ou lembrete em séries recorrentes propaga automaticamente.'
                      : 'Editing title, category, or reminder on recurring series propagates automatically.'}
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Band 2: Second Brain — Global Blocks, Multi-Level Subnotes & [[Wikilinks]] (Canvas) */}
      <section className="border-t border-hairline bg-canvas py-20 sm:py-24">
        <div className="mx-auto grid max-w-[1080px] grid-cols-1 items-center gap-12 px-4 sm:px-6 lg:grid-cols-12">
          <div className="order-2 lg:order-1 lg:col-span-7">
            <div className="overflow-hidden rounded-[14px] border border-hairline bg-canvas shadow-apple-card">
              {/* Top Breadcrumb Bar */}
              <div className="flex items-center justify-between border-b border-hairline bg-surface-secondary/70 px-4 py-2.5 text-[12px]">
                <div className="flex items-center gap-1 text-label-secondary">
                  <Globe className="h-3.5 w-3.5 text-mbl-blue" />
                  <span className="font-medium text-label">
                    {locale === 'pt' ? 'Estudos de SRE' : 'SRE Studies'}
                  </span>
                  {(selectedNode === 'k8s' || selectedNode === 'net') && (
                    <>
                      <ChevronRight className="h-3 w-3 opacity-50" />
                      <span className={selectedNode === 'k8s' ? 'font-medium text-label' : ''}>
                        Kubernetes
                      </span>
                    </>
                  )}
                  {selectedNode === 'net' && (
                    <>
                      <ChevronRight className="h-3 w-3 opacity-50" />
                      <span className="font-medium text-label">Networking & eBPF</span>
                    </>
                  )}
                  {selectedNode === 'otel' && (
                    <>
                      <ChevronRight className="h-3 w-3 opacity-50" />
                      <span className="font-medium text-label">
                        {locale === 'pt' ? 'Observabilidade' : 'Observability'}
                      </span>
                    </>
                  )}
                </div>
                <span className="inline-flex items-center gap-1 rounded-full bg-mbl-amber/15 px-2 py-0.5 text-[10.5px] font-semibold text-mbl-amber">
                  <Link2 className="h-3 w-3" /> 4 backlinks
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-12">
                {/* Interactive Tree */}
                <div className="border-b border-hairline bg-surface-secondary/40 p-3 sm:col-span-5 sm:border-b-0 sm:border-r">
                  <button
                    type="button"
                    onClick={() => {
                      setExpandedRoot((v) => !v)
                      setSelectedNode('root')
                    }}
                    className={cn(
                      'flex w-full items-center gap-1.5 rounded-[7px] px-2 py-1.5 text-left text-[12.5px] font-semibold',
                      selectedNode === 'root' ? 'bg-accent text-white' : 'text-label hover:bg-fill'
                    )}
                  >
                    {expandedRoot ? (
                      <ChevronDown className="h-3.5 w-3.5 shrink-0" />
                    ) : (
                      <ChevronRight className="h-3.5 w-3.5 shrink-0" />
                    )}
                    <Globe className="h-3.5 w-3.5 shrink-0" />
                    <span className="truncate">{locale === 'pt' ? 'Estudos de SRE' : 'SRE Studies'}</span>
                  </button>

                  {expandedRoot && (
                    <div className="mt-0.5 space-y-0.5 pl-4">
                      <button
                        type="button"
                        onClick={() => {
                          setExpandedK8s((v) => !v)
                          setSelectedNode('k8s')
                        }}
                        className={cn(
                          'flex w-full items-center gap-1.5 rounded-[7px] px-2 py-1.5 text-left text-[12.5px] font-medium',
                          selectedNode === 'k8s'
                            ? 'bg-accent text-white'
                            : 'text-label-secondary hover:bg-fill hover:text-label'
                        )}
                      >
                        {expandedK8s ? (
                          <ChevronDown className="h-3.5 w-3.5 shrink-0" />
                        ) : (
                          <ChevronRight className="h-3.5 w-3.5 shrink-0" />
                        )}
                        <FileText className="h-3.5 w-3.5 shrink-0" />
                        <span>Kubernetes</span>
                      </button>

                      {expandedK8s && (
                        <div className="pl-5">
                          <button
                            type="button"
                            onClick={() => setSelectedNode('net')}
                            className={cn(
                              'flex w-full items-center gap-1.5 rounded-[7px] px-2 py-1.5 text-left text-[12.5px] font-medium',
                              selectedNode === 'net'
                                ? 'bg-accent text-white'
                                : 'text-label-secondary hover:bg-fill hover:text-label'
                            )}
                          >
                            <FileText className="h-3.5 w-3.5 shrink-0" />
                            <span className="truncate">Networking & eBPF</span>
                          </button>
                        </div>
                      )}

                      <button
                        type="button"
                        onClick={() => setSelectedNode('otel')}
                        className={cn(
                          'flex w-full items-center gap-1.5 rounded-[7px] px-2 py-1.5 text-left text-[12.5px] font-medium',
                          selectedNode === 'otel'
                            ? 'bg-accent text-white'
                            : 'text-label-secondary hover:bg-fill hover:text-label'
                        )}
                      >
                        <FileText className="h-3.5 w-3.5 shrink-0" />
                        <span className="truncate">
                          {locale === 'pt' ? 'Observabilidade' : 'Observability'}
                        </span>
                      </button>
                    </div>
                  )}
                </div>

                {/* Inline Citation Preview */}
                <div className="p-4 sm:col-span-7">
                  <div className="text-[11px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                    {locale === 'pt' ? 'Citação & Criação Inline' : 'Inline Citation & Creation'}
                  </div>
                  <p className="mt-2 font-mono text-[12.5px] leading-relaxed text-label">
                    {locale === 'pt' ? 'Revisar ' : 'Review '}
                    <span className="rounded-[5px] bg-mbl-blue/12 px-1.5 py-0.5 font-sans font-semibold text-mbl-blue">
                      [[Kubernetes]]
                    </span>{' '}
                    {locale === 'pt' ? 'e atualizar ' : 'and update '}
                    <span className="rounded-[5px] bg-mbl-amber/15 px-1.5 py-0.5 font-sans font-semibold text-mbl-amber">
                      @Observabilidade
                    </span>
                  </p>
                  <div className="mt-3 rounded-[9px] border border-hairline bg-surface-secondary/70 p-2.5 text-[12px]">
                    <div className="flex items-center justify-between rounded-[6px] bg-accent px-2.5 py-1.5 font-medium text-white">
                      <span className="inline-flex items-center gap-1.5">
                        <Plus className="h-3.5 w-3.5" />
                        {locale === 'pt'
                          ? 'Criar subnota "Alertas SLO"'
                          : 'Create subnote "SLO Alerts"'}
                      </span>
                      <span className="font-mono text-[10px] opacity-80">↵</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="order-1 lg:order-2 lg:col-span-5">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-mbl-amber">
              {locale === 'pt' ? 'Segundo Cérebro' : 'Second Brain'}
            </p>
            <h2 className="mt-2 font-display text-[28px] font-semibold leading-[1.14] tracking-[-0.028em] text-label sm:text-[34px]">
              {locale === 'pt'
                ? 'Blocos Globais com subnotas em múltiplos níveis.'
                : 'Global Blocks with multi-level nested subnotes.'}
            </h2>
            <p className="mt-4 text-[15.5px] leading-[1.6] text-label-secondary">
              {locale === 'pt'
                ? 'Agende o mesmo tema em vários dias sem duplicar anotações. Crie subnotas ilimitadas dentro de uma nota pai, cite qualquer página digitando [[ ou @ e navegue por breadcrumbs e backlinks automáticos.'
                : 'Schedule the same project across multiple days without duplicating notes. Nest unlimited subnotes inside a parent note, cite any page with [[ or @, and navigate effortlessly via breadcrumbs and backlinks.'}
            </p>
          </div>
        </div>
      </section>

      {/* Band 3: Menu Bar, Focus Mode & Tear-Off Windows (Surface Secondary) */}
      <section className="border-t border-hairline bg-surface-secondary py-20 sm:py-24">
        <div className="mx-auto grid max-w-[1080px] grid-cols-1 items-center gap-12 px-4 sm:px-6 lg:grid-cols-12">
          <div className="lg:col-span-5">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-mbl-emerald">
              {locale === 'pt' ? 'Execução & Barra de Menu' : 'Execution & Menu Bar'}
            </p>
            <h2 className="mt-2 font-display text-[28px] font-semibold leading-[1.14] tracking-[-0.028em] text-label sm:text-[34px]">
              {locale === 'pt'
                ? 'Sempre à mão na Barra de Menu do macOS.'
                : 'Always one click away in your macOS Menu Bar.'}
            </h2>
            <p className="mt-4 text-[15.5px] leading-[1.6] text-label-secondary">
              {locale === 'pt'
                ? 'Acompanhe o bloco atual e o cronômetro de foco no topo da tela, capture tarefas rápidas na Inbox de qualquer aplicativo e arraste abas para fora da janela principal para mantê-las flutuando ao lado do seu código.'
                : 'See your active block and Focus countdown in your top bar, capture unscheduled tasks into your Inbox from any screen, and tear off note tabs into floating Always-on-Top windows.'}
            </p>
          </div>

          <div className="lg:col-span-7">
            {/* Exact MacMenuBarView.swift Popover Replica */}
            <div className="mx-auto max-w-[360px]">
              {/* Simulated macOS Menu Bar Pill */}
              <div className="mb-2 flex justify-end">
                <span className="inline-flex items-center gap-2 rounded-[6px] border border-hairline bg-canvas px-2.5 py-1 text-[11.5px] font-medium text-label shadow-apple-card">
                  <span className="h-2 w-2 rounded-full bg-mbl-blue" />
                  <span className="tabular-nums font-semibold">24:18</span>
                  <span className="text-label-secondary">
                    {locale === 'pt' ? 'Estudos de SRE' : 'SRE Studies'}
                  </span>
                </span>
              </div>

              <div className="overflow-hidden rounded-[12px] border border-hairline bg-canvas p-3.5 shadow-apple-popover">
                <div className="flex items-center justify-between border-b border-hairline pb-2.5">
                  <div className="flex items-center gap-2">
                    <Timer className="h-4 w-4 text-mbl-blue" />
                    <div>
                      <div className="text-[12.5px] font-semibold text-label">
                        {locale === 'pt' ? 'Estudos de SRE' : 'SRE Studies'}
                      </div>
                      <div className="tabular-nums text-[11px] text-label-secondary">
                        09:30 – 11:30 · {locale === 'pt' ? 'Foco ativo' : 'Focus active'}
                      </div>
                    </div>
                  </div>
                  <span className="tabular-nums rounded-full bg-mbl-blue/12 px-2 py-0.5 text-[12px] font-semibold text-mbl-blue">
                    24:18
                  </span>
                </div>

                {/* Live Quick Inbox Capture */}
                <form onSubmit={handleAddMenuInbox} className="mt-3 flex items-center gap-1.5">
                  <input
                    type="text"
                    value={menuInboxInput}
                    onChange={(e) => setMenuInboxInput(e.target.value)}
                    placeholder={
                      locale === 'pt' ? 'Capturar rápido na Inbox...' : 'Quick capture to Inbox...'
                    }
                    className="h-[30px] flex-1 rounded-[7px] border border-hairline bg-surface-secondary px-2.5 text-[12px] text-label placeholder:text-label-tertiary focus:border-accent focus:outline-none"
                  />
                  <button
                    type="submit"
                    aria-label="Add to Inbox"
                    className="apple-btn-primary h-[30px] w-[30px] shrink-0 !rounded-[7px]"
                  >
                    <Plus className="h-3.5 w-3.5" />
                  </button>
                </form>

                <div className="mt-3 space-y-1.5">
                  {menuItems.map((item, idx) => (
                    <div
                      key={`${item}-${idx}`}
                      className="flex items-center gap-2 rounded-[7px] bg-surface-secondary/70 px-2.5 py-1.5 text-[12px] text-label"
                    >
                      {idx === 0 && menuItems.length > 2 ? (
                        <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-mbl-emerald" />
                      ) : (
                        <Circle className="h-3.5 w-3.5 shrink-0 text-label-tertiary" />
                      )}
                      <span className="truncate">{item}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Band 4: Insights, Streaks & Live ⌘K Command Palette (Canvas) */}
      <section className="border-t border-hairline bg-canvas py-20 sm:py-24">
        <div className="mx-auto grid max-w-[1080px] grid-cols-1 items-center gap-12 px-4 sm:px-6 lg:grid-cols-12">
          <div className="order-2 lg:order-1 lg:col-span-7">
            <div className="rounded-[14px] border border-hairline bg-canvas p-5 shadow-apple-card">
              <div className="flex items-center justify-between border-b border-hairline pb-3">
                <div>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                    {locale === 'pt' ? 'Insights · Últimos 7 dias' : 'Insights · Last 7 days'}
                  </div>
                  <div className="mt-0.5 tabular-nums text-[22px] font-semibold tracking-[-0.02em] text-label">
                    36.5h{' '}
                    <span className="text-[13px] font-normal text-label-secondary">
                      {locale === 'pt' ? 'planejadas & concluídas' : 'planned & completed'}
                    </span>
                  </div>
                </div>
                <div className="inline-flex items-center gap-1.5 rounded-full bg-mbl-amber/15 px-3 py-1 text-[12px] font-semibold text-mbl-amber">
                  <Flame className="h-3.5 w-3.5" />
                  <span className="tabular-nums">
                    14 {locale === 'pt' ? 'dias de sequência' : 'day streak'}
                  </span>
                </div>
              </div>

              {/* Apple Charts-style Horizontal Bars */}
              <div className="mt-4 space-y-3.5">
                {[
                  {
                    name: locale === 'pt' ? 'Produto & Engenharia' : 'Product & Engineering',
                    hours: '18.0h',
                    pct: '100%',
                    hex: '#3B82F6',
                  },
                  {
                    name: locale === 'pt' ? 'Estudos de SRE (Global)' : 'SRE Studies (Global)',
                    hours: '12.5h',
                    pct: '69%',
                    hex: '#F59E0B',
                  },
                  {
                    name: locale === 'pt' ? 'Saúde & Corrida' : 'Health & Running',
                    hours: '6.0h',
                    pct: '34%',
                    hex: '#10B981',
                  },
                ].map((row) => (
                  <div key={row.name}>
                    <div className="mb-1 flex items-center justify-between text-[12.5px]">
                      <span className="font-medium text-label">{row.name}</span>
                      <span className="tabular-nums font-semibold text-label-secondary">
                        {row.hours}
                      </span>
                    </div>
                    <div className="h-[7px] w-full overflow-hidden rounded-full bg-fill">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{ width: row.pct, backgroundColor: row.hex }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="order-1 lg:order-2 lg:col-span-5">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-mbl-violet">
              {locale === 'pt' ? 'Clareza & Velocidade' : 'Clarity & Speed'}
            </p>
            <h2 className="mt-2 font-display text-[28px] font-semibold leading-[1.14] tracking-[-0.028em] text-label sm:text-[34px]">
              {locale === 'pt'
                ? 'Veja onde seu tempo realmente vai. Navegue tudo com ⌘K.'
                : 'See where your hours go. Jump anywhere with ⌘K.'}
            </h2>
            <p className="mt-4 text-[15.5px] leading-[1.6] text-label-secondary">
              {locale === 'pt'
                ? 'Acompanhe horas investidas em cada Bloco Global e sequências nas suas rotinas recorrentes com Apple Charts. E use a Command Palette ⌘K para pular datas, buscar notas ou agir sem tirar as mãos do teclado.'
                : 'Track hours invested across every Global Block and category with native Apple Charts — plus routine streaks. And jump to any date, note, or action via the ⌘K Command Palette.'}
            </p>

            <button
              type="button"
              onClick={openPalette}
              className="apple-btn-secondary mt-6 h-[36px] px-4 text-[13.5px]"
            >
              <Search className="h-3.5 w-3.5" />
              {locale === 'pt' ? 'Testar Command Palette aqui' : 'Try Command Palette right now'}
              <span className="apple-kbd ml-1">⌘K</span>
            </button>
          </div>
        </div>
      </section>
    </div>
  )
}
