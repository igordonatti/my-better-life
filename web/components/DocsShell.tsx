'use client'

import React, { useMemo, useState } from 'react'
import Link from 'next/link'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import {
  Search,
  BookOpen,
  ChevronRight,
  ChevronLeft,
  Github,
  Menu,
  X,
  Terminal,
  Globe,
  Sparkles,
  Layers,
  Copy,
  Check,
  List,
} from 'lucide-react'
import { Header } from '@/components/Header'
import { useAppContext } from '@/components/providers'
import { GITHUB_REPO_URL } from '@/lib/i18n'
import type { ResolvedDocPage } from '@/lib/docs'
import { cn } from '@/lib/utils'

interface DocsShellProps {
  docs: ResolvedDocPage[]
  currentDoc: ResolvedDocPage
}

interface TocHeading {
  id: string
  text: string
  level: 2 | 3
}

function slugifyHeading(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function extractHeadings(markdown: string): TocHeading[] {
  const headings: TocHeading[] = []
  let inCodeFence = false
  for (const rawLine of markdown.split('\n')) {
    const line = rawLine.trim()
    if (line.startsWith('```')) {
      inCodeFence = !inCodeFence
      continue
    }
    if (inCodeFence) continue
    const match = /^(#{2,3})\s+(.+)$/.exec(line)
    if (match) {
      const level = match[1].length as 2 | 3
      const cleanText = match[2]
        .replace(/`([^`]+)`/g, '$1')
        .replace(/\*\*([^*]+)\*\*/g, '$1')
        .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
        .trim()
      if (cleanText) {
        headings.push({
          id: slugifyHeading(cleanText),
          text: cleanText,
          level,
        })
      }
    }
  }
  return headings
}

function getNodeText(node: React.ReactNode): string {
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  if (Array.isArray(node)) return node.map(getNodeText).join('')
  if (React.isValidElement<{ children?: React.ReactNode }>(node)) {
    return getNodeText(node.props.children)
  }
  return ''
}

function docIconForSlug(slug: string): { icon: React.ReactNode; hex: string } {
  switch (slug) {
    case 'getting-started':
      return { icon: <BookOpen className="h-3.5 w-3.5" />, hex: '#3B82F6' }
    case 'shortcuts-and-workflow':
      return { icon: <Terminal className="h-3.5 w-3.5" />, hex: '#10B981' }
    case 'second-brain':
      return { icon: <Globe className="h-3.5 w-3.5" />, hex: '#F59E0B' }
    case 'open-core-pricing':
      return { icon: <Sparkles className="h-3.5 w-3.5" />, hex: '#8B5CF6' }
    case 'architecture':
      return { icon: <Layers className="h-3.5 w-3.5" />, hex: '#64748B' }
    default:
      return { icon: <BookOpen className="h-3.5 w-3.5" />, hex: '#64748B' }
  }
}

function CopyablePre({ children, ...props }: React.ComponentPropsWithoutRef<'pre'>) {
  const [copied, setCopied] = useState(false)
  const rawCode = getNodeText(children)

  const handleCopy = () => {
    if (!rawCode) return
    navigator.clipboard?.writeText(rawCode)
    setCopied(true)
    setTimeout(() => setCopied(false), 1800)
  }

  return (
    <div className="group relative my-5 overflow-hidden rounded-[10px] border border-hairline bg-[#F5F5F7] text-[#1D1D1F] dark:bg-[#161618] dark:text-[#F5F5F7]">
      <button
        type="button"
        onClick={handleCopy}
        aria-label="Copy code"
        className="absolute right-2.5 top-2.5 inline-flex items-center gap-1 rounded-[6px] border border-hairline bg-canvas px-2 py-1 text-[11px] font-medium text-label-secondary shadow-apple-card transition-colors hover:text-label"
      >
        {copied ? (
          <>
            <Check className="h-3 w-3 text-[#10B981]" />
            Copied
          </>
        ) : (
          <>
            <Copy className="h-3 w-3" />
            Copy
          </>
        )}
      </button>
      <pre
        {...props}
        className="!m-0 overflow-x-auto !bg-transparent px-4 py-3.5 pr-20 font-mono text-[13px] leading-[1.65] text-[#1D1D1F] dark:text-[#F5F5F7] [&_code]:!border-0 [&_code]:!bg-transparent [&_code]:!p-0 [&_code]:!text-inherit"
      >
        {children}
      </pre>
    </div>
  )
}

/**
 * Native macOS `NavigationSplitView` Documentation Workspace:
 * - Translucent macOS left sidebar with live search & tinted app icons
 * - Clean centered Apple Developer reading canvas with breadcrumb bar
 * - Right Inspector outline ("On this page") + working ⌘K Command Palette
 */
export function DocsShell({ docs, currentDoc }: DocsShellProps) {
  const { locale, openPalette } = useAppContext()
  const [query, setQuery] = useState('')
  const [mobileNavOpen, setMobileNavOpen] = useState(false)

  const filteredDocs = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return docs
    return docs.filter((d) => {
      const title = d.title[locale].toLowerCase()
      const desc = d.description[locale].toLowerCase()
      const cat = d.category[locale].toLowerCase()
      const body = (locale === 'pt' ? d.markdownPt : d.markdownEn).toLowerCase()
      return title.includes(q) || desc.includes(q) || cat.includes(q) || body.includes(q)
    })
  }, [docs, query, locale])

  const grouped = useMemo(() => {
    const groups: { category: string; items: ResolvedDocPage[] }[] = []
    for (const doc of filteredDocs) {
      const catName = doc.category[locale]
      const existing = groups.find((g) => g.category === catName)
      if (existing) existing.items.push(doc)
      else groups.push({ category: catName, items: [doc] })
    }
    return groups
  }, [filteredDocs, locale])

  const currentIndex = docs.findIndex((d) => d.slug === currentDoc.slug)
  const prevDoc = currentIndex > 0 ? docs[currentIndex - 1] : null
  const nextDoc = currentIndex >= 0 && currentIndex < docs.length - 1 ? docs[currentIndex + 1] : null

  const markdown = locale === 'pt' ? currentDoc.markdownPt : currentDoc.markdownEn
  const tocHeadings = useMemo(() => extractHeadings(markdown), [markdown])

  const sidebarContent = (
    <div className="flex h-full flex-col">
      {/* Recessed macOS Sidebar Search Field */}
      <div className="p-3 pb-2">
        <div className="relative">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-label-tertiary" />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={locale === 'pt' ? 'Filtrar páginas...' : 'Filter pages...'}
            className="h-[30px] w-full rounded-[7px] bg-fill pl-8 pr-10 text-[12.5px] text-label placeholder:text-label-tertiary focus:outline-none focus:ring-2 focus:ring-accent/35"
          />
          <button
            type="button"
            onClick={openPalette}
            title="Command Palette (⌘K)"
            className="apple-kbd absolute right-1.5 top-1/2 -translate-y-1/2"
          >
            ⌘K
          </button>
        </div>
      </div>

      {/* Grouped macOS Sidebar List */}
      <nav className="flex-1 space-y-5 overflow-y-auto px-2.5 py-2" aria-label="Documentation sidebar">
        {grouped.length === 0 ? (
          <p className="px-2.5 py-4 text-[12.5px] text-label-tertiary">
            {locale === 'pt' ? 'Nenhuma página encontrada.' : 'No matching pages.'}
          </p>
        ) : (
          grouped.map((group) => (
            <div key={group.category}>
              <div className="mb-1 px-2.5 text-[10.5px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
                {group.category}
              </div>
              <ul className="space-y-0.5">
                {group.items.map((item) => {
                  const isActive = item.slug === currentDoc.slug
                  const { icon, hex } = docIconForSlug(item.slug)
                  return (
                    <li key={item.slug}>
                      <Link
                        href={`/docs/${item.slug}`}
                        onClick={() => setMobileNavOpen(false)}
                        className={cn(
                          'flex items-center gap-2 rounded-[7px] px-2.5 py-[6px] text-[13px] transition-colors',
                          isActive
                            ? 'bg-accent font-medium text-white'
                            : 'font-normal text-label hover:bg-fill'
                        )}
                      >
                        <span
                          style={isActive ? undefined : { color: hex }}
                          className={cn('shrink-0', isActive && 'text-white')}
                        >
                          {icon}
                        </span>
                        <span className="truncate">{item.title[locale]}</span>
                      </Link>
                    </li>
                  )
                })}
              </ul>
            </div>
          ))
        )}
      </nav>

      {/* Bottom macOS Status Bar (mirrors Sync status footer in app) */}
      <div className="border-t border-hairline px-3.5 py-2.5">
        <div className="flex items-center justify-between text-[11.5px]">
          <span className="inline-flex items-center gap-1.5 font-medium text-label-secondary">
            <span className="h-2 w-2 rounded-full bg-mbl-emerald" />
            {locale === 'pt' ? 'Local-First · Open Source' : 'Local-First · Open Source'}
          </span>
          <Link href="/#open-core" className="font-medium text-accent hover:underline">
            Cloud
          </Link>
        </div>
      </div>
    </div>
  )

  return (
    <div className="min-h-screen bg-canvas text-label">
      <Header fullWidth />

      {/* Mobile Docs Drawer Bar */}
      <div className="apple-toolbar sticky top-[52px] z-30 border-b border-hairline px-4 py-2 lg:hidden">
        <div className="flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={() => setMobileNavOpen((v) => !v)}
            className="inline-flex items-center gap-1.5 rounded-[7px] bg-fill px-2.5 py-1 text-[12.5px] font-medium text-label"
          >
            {mobileNavOpen ? <X className="h-3.5 w-3.5" /> : <Menu className="h-3.5 w-3.5" />}
            {locale === 'pt' ? 'Documentação' : 'Docs'}
          </button>
          <span className="truncate text-[12.5px] text-label-secondary">
            {currentDoc.title[locale]}
          </span>
        </div>
        {mobileNavOpen && (
          <div className="mt-2 max-h-[65vh] overflow-y-auto rounded-[10px] border border-hairline bg-canvas">
            {sidebarContent}
          </div>
        )}
      </div>

      {/* macOS NavigationSplitView 3-Column Layout */}
      <div className="flex min-h-[calc(100vh-52px)]">
        {/* Column 1: Left Translucent Sidebar */}
        <aside className="apple-sidebar sticky top-[52px] hidden h-[calc(100vh-52px)] w-[268px] shrink-0 border-r border-hairline lg:block">
          {sidebarContent}
        </aside>

        {/* Column 2: Center Reading Canvas */}
        <main className="min-w-0 flex-1 bg-canvas">
          {/* App-style Breadcrumb Sub-toolbar */}
          <div className="flex items-center justify-between border-b border-hairline px-6 py-2.5 text-[12px] sm:px-10">
            <div className="flex items-center gap-1.5 text-label-secondary">
              <Link href="/docs" className="hover:text-label">
                {locale === 'pt' ? 'Documentação' : 'Docs'}
              </Link>
              <ChevronRight className="h-3 w-3 opacity-50" />
              <span>{currentDoc.category[locale]}</span>
              <ChevronRight className="h-3 w-3 opacity-50" />
              <span className="truncate font-medium text-label">{currentDoc.title[locale]}</span>
            </div>

            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noreferrer"
              className="hidden items-center gap-1.5 rounded-[6px] px-2 py-1 text-[12px] font-medium text-label-secondary transition-colors hover:bg-fill hover:text-label sm:inline-flex"
            >
              <Github className="h-3.5 w-3.5" />
              GitHub
            </a>
          </div>

          <div className="mx-auto max-w-[740px] px-6 py-10 sm:px-10 sm:py-12">
            {/* Lead description */}
            <p className="mb-8 text-[15.5px] leading-relaxed text-label-secondary">
              {currentDoc.description[locale]}
            </p>

            {/* Clean Apple Developer Documentation Prose */}
            <article
              className={cn(
                'prose prose-slate max-w-none dark:prose-invert',
                'prose-headings:font-display prose-headings:font-semibold prose-headings:tracking-[-0.025em] prose-headings:text-label',
                'prose-h1:mb-4 prose-h1:text-[30px] sm:prose-h1:text-[34px] prose-h1:leading-[1.12]',
                'prose-h2:mt-10 prose-h2:mb-3 prose-h2:border-b prose-h2:border-hairline prose-h2:pb-2 prose-h2:text-[21px] prose-h2:scroll-mt-20',
                'prose-h3:mt-7 prose-h3:mb-2 prose-h3:text-[17px] prose-h3:scroll-mt-20',
                'prose-p:text-[15px] prose-p:leading-[1.68] prose-p:text-label/90',
                'prose-li:text-[15px] prose-li:leading-[1.62] prose-li:text-label/90',
                'prose-strong:font-semibold prose-strong:text-label',
                'prose-a:font-medium prose-a:text-accent prose-a:no-underline hover:prose-a:underline',
                'prose-code:before:content-none prose-code:after:content-none [&_:not(pre)>code]:rounded-[5px] [&_:not(pre)>code]:border [&_:not(pre)>code]:border-hairline [&_:not(pre)>code]:bg-fill [&_:not(pre)>code]:px-1.5 [&_:not(pre)>code]:py-[2px] [&_:not(pre)>code]:font-mono [&_:not(pre)>code]:text-[13px] [&_:not(pre)>code]:font-normal [&_:not(pre)>code]:text-label',
                'prose-blockquote:rounded-[8px] prose-blockquote:border-l-[3.5px] prose-blockquote:border-mbl-blue prose-blockquote:bg-mbl-blue/[0.06] prose-blockquote:px-4 prose-blockquote:py-2 prose-blockquote:not-italic prose-blockquote:text-label-secondary',
                'prose-table:block prose-table:overflow-x-auto prose-table:text-[13.5px] prose-thead:border-b prose-thead:border-hairline prose-th:bg-surface-secondary prose-th:px-3 prose-th:py-2 prose-th:text-left prose-th:font-semibold prose-th:text-label prose-td:border-b prose-td:border-hairline prose-td:px-3 prose-td:py-2'
              )}
            >
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                  pre: CopyablePre,
                  h2: ({ children, ...props }) => {
                    const id = slugifyHeading(getNodeText(children))
                    return (
                      <h2 id={id} {...props}>
                        {children}
                      </h2>
                    )
                  },
                  h3: ({ children, ...props }) => {
                    const id = slugifyHeading(getNodeText(children))
                    return (
                      <h3 id={id} {...props}>
                        {children}
                      </h3>
                    )
                  },
                }}
              >
                {markdown}
              </ReactMarkdown>
            </article>

            {/* Previous / Next macOS Navigation Cards */}
            <div className="mt-14 grid grid-cols-1 gap-3 border-t border-hairline pt-6 sm:grid-cols-2">
              {prevDoc ? (
                <Link
                  href={`/docs/${prevDoc.slug}`}
                  className="group flex flex-col items-start rounded-[10px] border border-hairline bg-surface-secondary/50 px-4 py-3.5 transition-colors hover:bg-fill"
                >
                  <span className="inline-flex items-center gap-1 text-[11px] font-medium text-label-tertiary">
                    <ChevronLeft className="h-3.5 w-3.5 transition-transform group-hover:-translate-x-0.5" />
                    {locale === 'pt' ? 'Anterior' : 'Previous'}
                  </span>
                  <span className="mt-0.5 text-[14px] font-semibold text-label">
                    {prevDoc.title[locale]}
                  </span>
                </Link>
              ) : (
                <div />
              )}

              {nextDoc ? (
                <Link
                  href={`/docs/${nextDoc.slug}`}
                  className="group flex flex-col items-end rounded-[10px] border border-hairline bg-surface-secondary/50 px-4 py-3.5 text-right transition-colors hover:bg-fill"
                >
                  <span className="inline-flex items-center gap-1 text-[11px] font-medium text-label-tertiary">
                    {locale === 'pt' ? 'Próximo' : 'Next'}
                    <ChevronRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
                  </span>
                  <span className="mt-0.5 text-[14px] font-semibold text-label">
                    {nextDoc.title[locale]}
                  </span>
                </Link>
              ) : (
                <div />
              )}
            </div>
          </div>
        </main>

        {/* Column 3: Right Inspector Outline ("On This Page" — matches macOS Inspector pane) */}
        <aside className="sticky top-[52px] hidden h-[calc(100vh-52px)] w-[236px] shrink-0 overflow-y-auto border-l border-hairline bg-canvas px-4 py-6 xl:block">
          <div className="flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
            <List className="h-3.5 w-3.5" />
            {locale === 'pt' ? 'Nesta página' : 'On this page'}
          </div>

          {tocHeadings.length > 0 ? (
            <ul className="mt-3 space-y-1.5 text-[12.5px]">
              {tocHeadings.map((h) => (
                <li key={h.id} className={h.level === 3 ? 'pl-3' : undefined}>
                  <a
                    href={`#${h.id}`}
                    className="block truncate leading-snug text-label-secondary transition-colors hover:text-accent"
                  >
                    {h.text}
                  </a>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-3 text-[12px] text-label-tertiary">
              {locale === 'pt' ? 'Resumo da página' : 'Page overview'}
            </p>
          )}

          {/* Inspector Quick Actions */}
          <div className="mt-8 border-t border-hairline pt-5">
            <div className="text-[11px] font-semibold uppercase tracking-[0.04em] text-label-tertiary">
              {locale === 'pt' ? 'Atalhos' : 'Quick Actions'}
            </div>
            <div className="mt-2.5 space-y-1.5">
              <button
                type="button"
                onClick={openPalette}
                className="flex w-full items-center justify-between rounded-[7px] bg-surface-secondary px-2.5 py-1.5 text-[12px] font-medium text-label transition-colors hover:bg-fill"
              >
                <span>Command Palette</span>
                <span className="apple-kbd">⌘K</span>
              </button>
              <Link
                href="/"
                className="block rounded-[7px] px-2.5 py-1.5 text-[12px] text-label-secondary transition-colors hover:bg-fill hover:text-label"
              >
                {locale === 'pt' ? '← Voltar para Landing Page' : '← Back to Landing Page'}
              </Link>
            </div>
          </div>
        </aside>
      </div>
    </div>
  )
}
