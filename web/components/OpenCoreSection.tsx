'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { Check, ChevronDown, Cloud, Download, Github, BookOpen, RefreshCw, Smartphone, Bot, CalendarDays } from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { GatekeeperNote, useLatestRelease } from '@/components/DownloadCta'
import { landingCopy, GITHUB_REPO_URL } from '@/lib/i18n'
import type { LatestReleaseInfo } from '@/lib/releases'
import { cn } from '@/lib/utils'

const CLOUD_ICONS = [Smartphone, Bot, CalendarDays]

interface OpenCoreSectionProps {
  release?: LatestReleaseInfo
}

export function OpenCoreSection({ release: releaseProp }: OpenCoreSectionProps) {
  const { locale } = useAppContext()
  const release = useLatestRelease(releaseProp)
  const copy = landingCopy[locale]
  const [openFaq, setOpenFaq] = useState<number | null>(0)

  return (
    <>
      {/* Open-Core Model (Obsidian Philosophy — Apple Inset Sheet Cards) */}
      <section id="open-core" className="border-t border-hairline bg-surface-secondary py-20 sm:py-24">
        <div className="mx-auto max-w-[1000px] px-4 sm:px-6">
          <div className="mx-auto max-w-[640px] text-center">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-accent">
              {copy.pricing.eyebrow}
            </p>
            <h2 className="mt-2 font-display text-[30px] font-semibold leading-[1.12] tracking-[-0.028em] text-label sm:text-[40px]">
              {copy.pricing.heading}
            </h2>
            <p className="mt-4 text-[16px] leading-[1.55] text-label-secondary">
              {copy.pricing.subheading}
            </p>
          </div>

          <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-2">
            {/* Open Source · MIT — free forever */}
            <div className="flex flex-col rounded-[16px] border-[1.5px] border-accent/45 bg-canvas p-7 shadow-apple-card">
              <div className="flex items-center justify-between">
                <span className="text-[15px] font-semibold text-label">
                  {copy.pricing.free.name}
                </span>
                <span className="rounded-full bg-mbl-emerald/12 px-2.5 py-0.5 text-[11px] font-semibold text-mbl-emerald">
                  {copy.pricing.free.badge}
                </span>
              </div>

              <p className="mt-4 font-display text-[30px] font-semibold leading-none tracking-[-0.03em] text-label">
                {copy.pricing.free.tagline}
              </p>

              <p className="mt-3 text-[14px] leading-relaxed text-label-secondary">
                {copy.pricing.free.description}
              </p>

              <ul className="mt-6 flex-1 space-y-2.5 border-t border-hairline pt-5 text-[13.5px] text-label">
                {copy.pricing.free.features.map((feat) => (
                  <li key={feat} className="flex items-start gap-2.5">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-mbl-emerald" />
                    <span>{feat}</span>
                  </li>
                ))}
              </ul>

              <div className="mt-7 flex flex-wrap gap-2.5">
                <a
                  href={release.downloadUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="apple-btn-primary h-[38px] flex-1 px-4 text-[13.5px]"
                >
                  <Download className="h-3.5 w-3.5" />
                  {copy.finalCta.download}
                </a>
                <a
                  href={GITHUB_REPO_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="apple-btn-secondary h-[38px] px-4 text-[13.5px]"
                >
                  <Github className="h-3.5 w-3.5" />
                  GitHub
                </a>
              </div>
            </div>

            {/* Cloud Add-Ons — coming soon (no prices, no checkout, no waitlist) */}
            <div className="flex flex-col rounded-[16px] border border-hairline bg-canvas p-7 shadow-apple-card">
              <div className="flex items-center justify-between">
                <span className="inline-flex items-center gap-1.5 text-[15px] font-semibold text-label">
                  <Cloud className="h-4 w-4 text-accent" />
                  {copy.pricing.cloud.name}
                </span>
                <span className="rounded-full bg-mbl-amber/15 px-2.5 py-0.5 text-[11px] font-semibold text-mbl-amber">
                  {copy.pricing.cloud.badge}
                </span>
              </div>

              <p className="mt-4 font-display text-[30px] font-semibold leading-none tracking-[-0.03em] text-label">
                {copy.pricing.cloud.tagline}
              </p>

              <p className="mt-3 text-[14px] leading-relaxed text-label-secondary">
                {copy.pricing.cloud.description}
              </p>

              <ul className="mt-6 flex-1 space-y-4 border-t border-hairline pt-5">
                {copy.pricing.cloud.features.map((feat, idx) => {
                  const Icon = CLOUD_ICONS[idx] ?? Cloud
                  return (
                    <li key={feat.title} className="flex items-start gap-3">
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] bg-accent/10 text-accent">
                        <Icon className="h-3.5 w-3.5" />
                      </span>
                      <span>
                        <span className="block text-[13.5px] font-medium text-label">{feat.title}</span>
                        <span className="block text-[12.5px] leading-relaxed text-label-secondary">
                          {feat.description}
                        </span>
                      </span>
                    </li>
                  )
                })}
              </ul>

              <Link
                href="/docs/open-core-pricing"
                className="apple-btn-secondary mt-7 h-[38px] w-full px-4 text-[13.5px]"
              >
                {locale === 'pt' ? 'Entenda o modelo Open-Core' : 'How Open-Core works'}
              </Link>
            </div>
          </div>

          {/* Philosophy note (native macOS callout style) */}
          <div className="mt-6 flex items-start gap-3 rounded-[12px] border border-hairline bg-canvas px-5 py-4">
            <RefreshCw className="mt-0.5 h-4 w-4 shrink-0 text-label-secondary" />
            <p className="text-[13.5px] leading-relaxed text-label-secondary">
              {copy.pricing.philosophy}
            </p>
          </div>
        </div>
      </section>

      {/* Apple Settings Inset Grouped FAQ (Zero Radix Accordion) */}
      <section id="faq" className="border-t border-hairline bg-canvas py-20 sm:py-24">
        <div className="mx-auto max-w-[760px] px-4 sm:px-6">
          <div className="text-center">
            <p className="text-[12px] font-semibold uppercase tracking-[0.06em] text-label-tertiary">
              {copy.faq.eyebrow}
            </p>
            <h2 className="mt-2 font-display text-[28px] font-semibold tracking-[-0.025em] text-label sm:text-[34px]">
              {copy.faq.heading}
            </h2>
          </div>

          <div className="mt-10 overflow-hidden rounded-[12px] border border-hairline bg-surface-secondary/50 divide-y divide-hairline">
            {copy.faq.items.map((item, idx) => {
              const isOpen = openFaq === idx
              return (
                <div key={item.q}>
                  <button
                    type="button"
                    aria-expanded={isOpen}
                    onClick={() => setOpenFaq(isOpen ? null : idx)}
                    className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left text-[15px] font-medium text-label transition-colors hover:bg-fill/40"
                  >
                    <span>{item.q}</span>
                    <ChevronDown
                      className={cn(
                        'h-4 w-4 shrink-0 text-label-tertiary transition-transform duration-200',
                        isOpen && 'rotate-180 text-label'
                      )}
                    />
                  </button>
                  {isOpen && (
                    <div className="px-5 pb-4 text-[14px] leading-[1.6] text-label-secondary">
                      {item.a}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      </section>

      {/* Calm Minimalist Download Banner */}
      <section id="download" className="border-t border-hairline bg-surface-secondary py-20">
        <div className="mx-auto max-w-[620px] px-4 text-center sm:px-6">
          <h2 className="font-display text-[30px] font-semibold tracking-[-0.028em] text-label sm:text-[36px]">
            {copy.finalCta.heading}
          </h2>
          <p className="mt-3 text-[15.5px] leading-relaxed text-label-secondary">
            {copy.finalCta.subtitle}
          </p>

          <div className="mt-7 flex flex-wrap items-center justify-center gap-2.5">
            <a
              href={release.downloadUrl}
              target="_blank"
              rel="noreferrer"
              className="apple-btn-primary h-[40px] px-5 text-[14px]"
            >
              <Download className="h-4 w-4" />
              {copy.finalCta.download} (v{release.version})
            </a>
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noreferrer"
              className="apple-btn-secondary h-[40px] px-5 text-[14px]"
            >
              <Github className="h-4 w-4" />
              {copy.finalCta.github}
            </a>
            <Link href="/docs/getting-started" className="apple-btn-secondary h-[40px] px-5 text-[14px]">
              <BookOpen className="h-4 w-4" />
              {copy.finalCta.docs}
            </Link>
          </div>

          <GatekeeperNote className="mx-auto mt-6 max-w-[520px]" />
        </div>
      </section>
    </>
  )
}
