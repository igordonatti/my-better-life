'use client'

import React from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useAppContext } from '@/components/providers'
import { GITHUB_REPO_URL } from '@/lib/i18n'

export function Footer() {
  const { locale, release } = useAppContext()

  return (
    <footer className="border-t border-hairline bg-surface-secondary">
      <div className="mx-auto max-w-[1080px] px-4 py-12 sm:px-6">
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2 md:grid-cols-4">
          {/* Brand */}
          <div className="space-y-3">
            <Link href="/" className="inline-flex items-center gap-2">
              <Image
                src="/images/app-icon.png"
                alt="My Better Life"
                width={24}
                height={24}
                className="h-6 w-6 rounded-[6px]"
              />
              <span className="text-[14px] font-semibold tracking-[-0.015em] text-label">
                My Better Life
              </span>
            </Link>
            <p className="text-[12.5px] leading-relaxed text-label-secondary">
              {locale === 'pt'
                ? 'Planner de time-blocking e Segundo Cérebro nativo em SwiftUI para macOS e iOS. Local-first e open-core.'
                : 'Native SwiftUI time-blocking planner & Second Brain for macOS and iOS. Local-first and open-core.'}
            </p>
          </div>

          {/* Product */}
          <div>
            <h3 className="text-[12px] font-semibold text-label">
              {locale === 'pt' ? 'Aplicativo' : 'Application'}
            </h3>
            <ul className="mt-2.5 space-y-2 text-[12.5px] text-label-secondary">
              <li>
                <Link href="/#overview" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Prévia Interativa' : 'Interactive Preview'}
                </Link>
              </li>
              <li>
                <Link href="/#features" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Recursos Nativos' : 'Native Features'}
                </Link>
              </li>
              <li>
                <Link href="/#open-core" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Open-Core & Cloud' : 'Open-Core & Cloud'}
                </Link>
              </li>
              <li>
                <Link href="/#faq" className="transition-colors hover:text-label">
                  FAQ
                </Link>
              </li>
            </ul>
          </div>

          {/* Documentation */}
          <div>
            <h3 className="text-[12px] font-semibold text-label">
              {locale === 'pt' ? 'Documentação' : 'Documentation'}
            </h3>
            <ul className="mt-2.5 space-y-2 text-[12.5px] text-label-secondary">
              <li>
                <Link href="/docs/getting-started" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Primeiros Passos' : 'Getting Started'}
                </Link>
              </li>
              <li>
                <Link href="/docs/shortcuts-and-workflow" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Agenda & Atalhos' : 'Shortcuts & Workflow'}
                </Link>
              </li>
              <li>
                <Link href="/docs/second-brain" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Segundo Cérebro' : 'Second Brain & Subnotes'}
                </Link>
              </li>
              <li>
                <Link href="/docs/open-core-pricing" className="transition-colors hover:text-label">
                  {locale === 'pt' ? 'Modelo Open-Core' : 'Open-Core Model'}
                </Link>
              </li>
            </ul>
          </div>

          {/* Engineering */}
          <div>
            <h3 className="text-[12px] font-semibold text-label">
              {locale === 'pt' ? 'Engenharia' : 'Engineering'}
            </h3>
            <ul className="mt-2.5 space-y-2 text-[12.5px] text-label-secondary">
              <li>
                <Link href="/docs/architecture" className="transition-colors hover:text-label">
                  ARCHITECTURE.md
                </Link>
              </li>
              <li>
                <a
                  href={release.releasePageUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="transition-colors hover:text-label"
                >
                  {`GitHub Releases · v${release.version}`}
                </a>
              </li>
              <li>
                <a
                  href={GITHUB_REPO_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="transition-colors hover:text-label"
                >
                  GitHub Repository
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 flex flex-col items-start justify-between gap-2 border-t border-hairline pt-6 text-[12px] text-label-tertiary sm:flex-row sm:items-center">
          <span>My Better Life · Swift 6 & SwiftUI · MIT License</span>
          <span>
            {locale === 'pt'
              ? 'Pressione ⌘K em qualquer tela para abrir a Command Palette'
              : 'Press ⌘K anywhere to open the Command Palette'}
          </span>
        </div>
      </div>
    </footer>
  )
}
