'use client'

import React from 'react'
import { CheckCircle2, Circle, Globe, Repeat, CheckSquare } from 'lucide-react'
import { useAppContext } from '@/components/providers'
import { MacTooltip } from '@/components/apple/MacTooltip'
import { cn } from '@/lib/utils'

export interface TimelineBlockCardProps {
  title: string
  timeRange: string
  accentHex: string
  preview?: string
  isCompleted?: boolean
  isSelected?: boolean
  isGlobal?: boolean
  isRecurring?: boolean
  checklist?: { completed: number; total: number }
  compact?: boolean
  onSelect?: () => void
  onToggleComplete?: () => void
  className?: string
}

/**
 * Pixel-faithful web counterpart to SwiftUI's `TimelineBlockCard.swift`:
 * - Continuous 8px corner radius
 * - Translucent accent tint over window canvas
 * - Crisp 3.5px vertical left accent bar
 * - Circular completion button + globe/repeat glyphs + tabular time & checklist pill
 */
export function TimelineBlockCard({
  title,
  timeRange,
  accentHex,
  preview,
  isCompleted = false,
  isSelected = false,
  isGlobal = false,
  isRecurring = false,
  checklist,
  compact = false,
  onSelect,
  onToggleComplete,
  className,
}: TimelineBlockCardProps) {
  const { locale } = useAppContext()
  const fillOpacity = isCompleted ? '14' : isSelected ? '33' : '21' // ~8% / 20% / 13%
  const borderColor = isSelected ? accentHex : `${accentHex}47` // 100% vs 28%
  const allChecked = checklist ? checklist.completed === checklist.total && checklist.total > 0 : false

  return (
    <div
      role={onSelect ? 'button' : undefined}
      tabIndex={onSelect ? 0 : undefined}
      onClick={onSelect}
      onKeyDown={
        onSelect
          ? (e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault()
                onSelect()
              }
            }
          : undefined
      }
      style={{
        backgroundColor: `${accentHex}${fillOpacity}`,
        borderColor,
        borderWidth: isSelected ? '1.6px' : '0.8px',
        boxShadow: isSelected
          ? '0 4px 12px rgba(0, 0, 0, 0.08)'
          : '0 1px 2px rgba(0, 0, 0, 0.03)',
      }}
      className={cn(
        'group relative w-full overflow-hidden rounded-[8px] text-left transition-all duration-150',
        onSelect && 'cursor-pointer',
        compact ? 'py-1.5 pl-3 pr-2' : 'py-2 pl-3.5 pr-2.5',
        className
      )}
    >
      {/* Crisp 3.5px left accent bar (AppTheme.accentBarWidth) */}
      <span
        aria-hidden="true"
        style={{
          backgroundColor: accentHex,
          opacity: isCompleted ? 0.5 : 0.95,
        }}
        className="absolute bottom-[3px] left-[2px] top-[3px] w-[3.5px] rounded-[2px]"
      />

      {/* Row 1: Checkbox + Title + Glyphs */}
      <div className="flex items-center gap-1.5">
        {onToggleComplete ? (
          <MacTooltip
            label={
              isCompleted
                ? locale === 'pt'
                  ? 'Marcar como pendente'
                  : 'Mark as incomplete'
                : locale === 'pt'
                  ? 'Marcar como concluído'
                  : 'Mark as completed'
            }
          >
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation()
                onToggleComplete()
              }}
              aria-label={isCompleted ? 'Mark incomplete' : 'Mark complete'}
              className="shrink-0 transition-transform active:scale-90"
              style={{ color: accentHex }}
            >
              {isCompleted ? (
                <CheckCircle2 className="h-[14px] w-[14px]" />
              ) : (
                <Circle className="h-[14px] w-[14px] opacity-85" />
              )}
            </button>
          </MacTooltip>
        ) : (
          <span className="shrink-0" style={{ color: accentHex }}>
            {isCompleted ? (
              <CheckCircle2 className="h-[14px] w-[14px]" />
            ) : (
              <Circle className="h-[14px] w-[14px] opacity-85" />
            )}
          </span>
        )}

        <span
          className={cn(
            'truncate text-[13px] font-semibold leading-tight',
            isCompleted ? 'text-label-secondary line-through' : 'text-label'
          )}
        >
          {title}
        </span>

        {isGlobal && (
          <MacTooltip
            label={
              locale === 'pt'
                ? 'Bloco Global (notas compartilhadas)'
                : 'Global Block (shared living notes)'
            }
          >
            <Globe
              className="h-[11px] w-[11px] shrink-0"
              style={{ color: accentHex }}
            />
          </MacTooltip>
        )}
        {isRecurring && (
          <MacTooltip
            label={
              locale === 'pt'
                ? 'Bloco recorrente na semana'
                : 'Recurring weekly series'
            }
          >
            <Repeat
              className="h-[10px] w-[10px] shrink-0 opacity-85"
              style={{ color: accentHex }}
            />
          </MacTooltip>
        )}
      </div>

      {/* Row 2: Tabular time range + checklist badge */}
      <div className="mt-0.5 flex items-center justify-between gap-2 pl-[20px]">
        <span className="tabular-nums text-[11px] font-medium text-label-secondary">
          {timeRange}
        </span>

        {checklist && checklist.total > 0 && (
          <span
            style={{
              backgroundColor: `${accentHex}1A`,
              color: allChecked ? accentHex : undefined,
            }}
            className={cn(
              'inline-flex items-center gap-1 rounded-full px-1.5 py-[1px] tabular-nums text-[10px] font-semibold',
              !allChecked && 'text-label-secondary'
            )}
          >
            <CheckSquare className="h-2.5 w-2.5" />
            {checklist.completed}/{checklist.total}
          </span>
        )}
      </div>

      {/* Row 3: Optional preview text (for tall blocks) */}
      {preview && !compact && (
        <p className="mt-1 line-clamp-1 pl-[20px] text-[11.5px] leading-snug text-label-secondary/90">
          {preview}
        </p>
      )}
    </div>
  )
}
