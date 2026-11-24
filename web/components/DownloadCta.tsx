'use client'

import React from 'react'
import { ShieldCheck } from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { landingCopy } from '@/lib/i18n'
import type { LatestReleaseInfo } from '@/lib/releases'
import { cn } from '@/lib/utils'

/** Prefers the release passed by a Server Component, falling back to the layout-provided one. */
export function useLatestRelease(release?: LatestReleaseInfo): LatestReleaseInfo {
  const { release: contextRelease } = useAppContext()
  return release ?? contextRelease
}

/** Calm macOS-style callout explaining the one-time Gatekeeper "Open Anyway" step. */
export function GatekeeperNote({ className }: { className?: string }) {
  const { locale } = useAppContext()
  const copy = landingCopy[locale].gatekeeper

  return (
    <div
      className={cn(
        'flex items-start gap-3 rounded-[12px] border border-hairline bg-canvas px-4 py-3 text-left',
        className
      )}
    >
      <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-accent" aria-hidden="true" />
      <p className="text-[12.5px] leading-[1.55] text-label-secondary">
        <span className="font-semibold text-label">{copy.title}.</span> {copy.body}{' '}
        <span className="font-medium text-label">{copy.path}</span>.
      </p>
    </div>
  )
}
