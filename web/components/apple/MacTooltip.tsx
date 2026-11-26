'use client'

import React, { useCallback, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { cn } from '@/lib/utils'

interface MacTooltipProps {
  label: string
  shortcut?: string
  side?: 'top' | 'bottom'
  children: React.ReactNode
  className?: string
}

/**
 * Pure macOS Sequoia floating hover tooltip (zero ShadCN/Radix):
 * - Renders via portal in fixed coordinates so it is never clipped by `overflow-hidden` windows
 * - Supports optional keyboard shortcut cap (e.g. `⌘⇧O`, `⌘K`)
 * - Appears crisply on hover and keyboard focus, flips automatically near viewport edges
 */
export function MacTooltip({
  label,
  shortcut,
  side = 'top',
  children,
  className,
}: MacTooltipProps) {
  const triggerRef = useRef<HTMLSpanElement>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [visible, setVisible] = useState(false)
  const [coords, setCoords] = useState<{ x: number; y: number; resolvedSide: 'top' | 'bottom' } | null>(
    null
  )

  const updatePosition = useCallback(() => {
    const el = triggerRef.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    const resolvedSide: 'top' | 'bottom' =
      side === 'top' && rect.top < 52 ? 'bottom' : side === 'bottom' && window.innerHeight - rect.bottom < 52 ? 'top' : side
    const x = Math.min(Math.max(rect.left + rect.width / 2, 80), window.innerWidth - 80)
    const y = resolvedSide === 'top' ? rect.top - 8 : rect.bottom + 8
    setCoords({ x, y, resolvedSide })
  }, [side])

  const show = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      updatePosition()
      setVisible(true)
    }, 110)
  }, [updatePosition])

  const hide = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current)
    setVisible(false)
  }, [])

  useEffect(() => {
    if (!visible) return
    const onScrollOrResize = () => setVisible(false)
    window.addEventListener('scroll', onScrollOrResize, true)
    window.addEventListener('resize', onScrollOrResize)
    return () => {
      window.removeEventListener('scroll', onScrollOrResize, true)
      window.removeEventListener('resize', onScrollOrResize)
    }
  }, [visible])

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
    }
  }, [])

  return (
    <span
      ref={triggerRef}
      onMouseEnter={show}
      onMouseLeave={hide}
      onFocus={show}
      onBlur={hide}
      onMouseDown={hide}
      className={cn('inline-flex items-center', className)}
    >
      {children}
      {visible &&
        coords &&
        typeof document !== 'undefined' &&
        createPortal(
          <span
            role="tooltip"
            style={{
              left: `${coords.x}px`,
              top: `${coords.y}px`,
              transform:
                coords.resolvedSide === 'top'
                  ? 'translate(-50%, -100%)'
                  : 'translate(-50%, 0)',
            }}
            className="pointer-events-none fixed z-[200] inline-flex max-w-[280px] items-center gap-1.5 whitespace-nowrap rounded-[7px] bg-[#1D1D1F]/95 px-2.5 py-1.5 text-[11.5px] font-medium leading-none text-white shadow-[0_8px_24px_rgba(0,0,0,0.22),0_0_0_0.5px_rgba(255,255,255,0.12)] backdrop-blur-md dark:bg-[#2C2C2E]/95 dark:text-[#F5F5F7]"
          >
            <span>{label}</span>
            {shortcut && (
              <span className="rounded-[4px] bg-white/15 px-1 py-[2px] font-mono text-[10px] font-medium text-white/90">
                {shortcut}
              </span>
            )}
          </span>,
          document.body
        )}
    </span>
  )
}
