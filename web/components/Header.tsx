'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { usePathname } from 'next/navigation'
import { Search, Sun, Moon, Menu, X, Github, Download } from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { SegmentedControl } from '@/components/apple/SegmentedControl'
import { useLatestRelease } from '@/components/DownloadCta'
import { GITHUB_REPO_URL } from '@/lib/i18n'
import type { LatestReleaseInfo } from '@/lib/releases'
import { cn } from '@/lib/utils'

interface HeaderProps {
  /** Compact full-width mode used by the macOS NavigationSplitView Docs workspace */
  fullWidth?: boolean
  /** Latest GitHub Release; falls back to the layout-provided release (e.g. on /docs). */
  release?: LatestReleaseInfo
}

export function Header({ fullWidth = false, release: releaseProp }: HeaderProps) {
  const pathname = usePathname()
  const { locale, setLocale, theme, toggleTheme, openPalette } = useAppContext()
  const [mobileOpen, setMobileOpen] = useState(false)
  const release = useLatestRelease(releaseProp)
  const downloadLabel = locale === 'pt' ? 'Baixar para macOS' : 'Download for macOS'

  const isDocs = pathname?.startsWith('/docs')

  const navLinks = [
    { href: '/#overview', label: locale === 'pt' ? 'Visão Geral' : 'Overview', active: pathname === '/' },
    { href: '/#features', label: locale === 'pt' ? 'Recursos' : 'Features', active: false },
    { href: '/#open-core', label: 'Open-Core', active: false },
    { href: '/docs', label: locale === 'pt' ? 'Documentação' : 'Docs', active: Boolean(isDocs) },
  ]

  return (
    <header className="apple-toolbar sticky top-0 z-40 h-[52px] w-full border-b border-hairline">
      <div
        className={cn(
          'mx-auto flex h-full items-center justify-between px-4 sm:px-6',
          fullWidth ? 'max-w-none' : 'max-w-[1080px]'
        )}
      >
        {/* Brand mark */}
        <Link href="/" className="group flex items-center gap-2.5">
          <Image
            src="/images/app-icon.png"
            alt="My Better Life"
            width={28}
            height={28}
            priority
            className="h-7 w-7 rounded-[7px] shadow-[0_1px_4px_rgba(0,0,0,0.16)] transition-transform duration-150 group-hover:scale-[1.04]"
          />
          <span className="text-[14.5px] font-semibold tracking-[-0.015em] text-label">
            My Better Life
          </span>
        </Link>

        {/* Center Navigation (macOS calm minimal links) */}
        <nav className="hidden items-center gap-6 md:flex" aria-label="Main navigation">
          {navLinks.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'text-[13px] font-medium transition-colors',
                item.active ? 'text-accent' : 'text-label-secondary hover:text-label'
              )}
            >
              {item.label}
            </Link>
          ))}
        </nav>

        {/* Right macOS Toolbar Controls */}
        <div className="hidden items-center gap-2 md:flex">
          {/* Native ⌘K Search Trigger */}
          <button
            type="button"
            onClick={openPalette}
            className="inline-flex h-[28px] items-center gap-2 rounded-[7px] bg-fill px-2.5 text-[12px] text-label-secondary transition-colors hover:bg-fill-strong hover:text-label"
            aria-label={locale === 'pt' ? 'Abrir Command Palette (⌘K)' : 'Open Command Palette (⌘K)'}
          >
            <Search className="h-3.5 w-3.5" />
            <span className="hidden lg:inline">
              {locale === 'pt' ? 'Buscar' : 'Search'}
            </span>
            <span className="apple-kbd">⌘K</span>
          </button>

          {/* Native macOS EN | PT Segmented Control */}
          <SegmentedControl
            size="xs"
            ariaLabel="Language"
            value={locale}
            onChange={setLocale}
            options={[
              { value: 'en', label: 'EN' },
              { value: 'pt', label: 'PT' },
            ]}
          />

          {/* Appearance Toggle */}
          <button
            type="button"
            onClick={toggleTheme}
            aria-label={theme === 'dark' ? 'Switch to light appearance' : 'Switch to dark appearance'}
            className="flex h-[28px] w-[28px] items-center justify-center rounded-[7px] text-label-secondary transition-colors hover:bg-fill hover:text-label"
          >
            {theme === 'dark' ? (
              <Sun className="h-[15px] w-[15px] text-mbl-amber" />
            ) : (
              <Moon className="h-[15px] w-[15px]" />
            )}
          </button>

          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub"
            className="flex h-[28px] w-[28px] items-center justify-center rounded-[7px] text-label-secondary transition-colors hover:bg-fill hover:text-label"
          >
            <Github className="h-[15px] w-[15px]" />
          </a>

          <a
            href={release.downloadUrl}
            target="_blank"
            rel="noreferrer"
            title={`${downloadLabel} · v${release.version}`}
            className="apple-btn-primary h-[28px] px-3 text-[12.5px]"
          >
            <Download className="h-3.5 w-3.5" />
            <span className="lg:hidden">{locale === 'pt' ? 'Baixar' : 'Download'}</span>
            <span className="hidden lg:inline">{downloadLabel}</span>
            <span className="hidden opacity-75 lg:inline">v{release.version}</span>
          </a>
        </div>

        {/* Mobile Controls */}
        <div className="flex items-center gap-1 md:hidden">
          <button
            type="button"
            onClick={openPalette}
            aria-label="Search"
            className="flex h-8 w-8 items-center justify-center rounded-[7px] text-label-secondary hover:bg-fill"
          >
            <Search className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={toggleTheme}
            aria-label="Toggle appearance"
            className="flex h-8 w-8 items-center justify-center rounded-[7px] text-label-secondary hover:bg-fill"
          >
            {theme === 'dark' ? (
              <Sun className="h-4 w-4 text-mbl-amber" />
            ) : (
              <Moon className="h-4 w-4" />
            )}
          </button>
          <button
            type="button"
            onClick={() => setMobileOpen((v) => !v)}
            aria-label="Menu"
            className="flex h-8 w-8 items-center justify-center rounded-[7px] text-label-secondary hover:bg-fill"
          >
            {mobileOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
          </button>
        </div>
      </div>

      {/* Mobile Dropdown Sheet */}
      {mobileOpen && (
        <div className="apple-toolbar border-b border-hairline px-4 py-4 md:hidden">
          <div className="flex flex-col gap-2.5">
            {navLinks.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className={cn(
                  'rounded-[8px] px-2.5 py-1.5 text-[14px] font-medium',
                  item.active ? 'bg-accent/10 text-accent' : 'text-label'
                )}
              >
                {item.label}
              </Link>
            ))}
            <div className="mt-2 flex items-center justify-between border-t border-hairline pt-3">
              <SegmentedControl
                size="sm"
                value={locale}
                onChange={setLocale}
                options={[
                  { value: 'en', label: 'English' },
                  { value: 'pt', label: 'Português' },
                ]}
              />
              <a
                href={release.downloadUrl}
                target="_blank"
                rel="noreferrer"
                onClick={() => setMobileOpen(false)}
                className="apple-btn-primary h-[30px] px-3.5 text-[13px]"
              >
                <Download className="h-3.5 w-3.5" />
                {locale === 'pt' ? 'Baixar' : 'Download'} v{release.version}
              </a>
            </div>
          </div>
        </div>
      )}
    </header>
  )
}
