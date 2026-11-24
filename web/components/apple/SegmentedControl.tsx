'use client'

import React from 'react'
import { cn } from '@/lib/utils'

export interface SegmentedOption<T extends string> {
  value: T
  label: React.ReactNode
  ariaLabel?: string
}

interface SegmentedControlProps<T extends string> {
  options: SegmentedOption<T>[]
  value: T
  onChange: (value: T) => void
  size?: 'xs' | 'sm' | 'md'
  className?: string
  ariaLabel?: string
}

/**
 * Pure macOS Sequoia segmented control (zero ShadCN):
 * recessed translucent track + crisp elevated thumb.
 */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  size = 'sm',
  className,
  ariaLabel,
}: SegmentedControlProps<T>) {
  const padClass =
    size === 'xs'
      ? 'px-2 py-0.5 text-[11px]'
      : size === 'sm'
        ? 'px-2.5 py-1 text-xs'
        : 'px-3.5 py-1.5 text-[13px]'

  return (
    <div
      role="tablist"
      aria-label={ariaLabel}
      className={cn(
        'inline-flex items-center rounded-[8px] bg-fill p-[2px]',
        className
      )}
    >
      {options.map((opt) => {
        const active = opt.value === value
        return (
          <button
            key={opt.value}
            type="button"
            role="tab"
            aria-selected={active}
            aria-label={opt.ariaLabel}
            onClick={() => onChange(opt.value)}
            className={cn(
              'inline-flex items-center justify-center gap-1.5 rounded-[6px] font-medium transition-all duration-150 select-none',
              padClass,
              active
                ? 'bg-canvas text-label shadow-apple-thumb dark:bg-[#3A3A3C]'
                : 'text-label-secondary hover:text-label'
            )}
          >
            {opt.label}
          </button>
        )
      })}
    </div>
  )
}
