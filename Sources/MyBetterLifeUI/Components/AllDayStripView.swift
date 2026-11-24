import SwiftUI
import MyBetterLifeCore
#if os(macOS)
import AppKit
#endif

/// All-day banner strip displayed at the top of the Day Timeline (like Google/Apple Calendar).
public struct AllDayStripView: View {
    public let occurrences: [DayOccurrence]
    public let selectedItem: SelectedItemRef?
    public let selectedItems: Set<SelectedItemRef>
    public let globalNotes: [StandaloneNote]
    public let canPaste: Bool
    public let onSelect: (DayOccurrence, _ additive: Bool) -> Void
    public let onToggleComplete: (DayOccurrence) -> Void
    public let onAddAllDay: () -> Void
    public let onOpenInNewWindow: ((DayOccurrence) -> Void)?
    public let onCopy: ((DayOccurrence) -> Void)?
    public let onPaste: (() -> Void)?
    public let onQuickRecurrence: ((DayOccurrence, RecurrenceRuleType?, WeekdayMask) -> Void)?
    public let onOpenCustomRecurrence: ((DayOccurrence) -> Void)?
    public let onPromoteToGlobal: ((DayOccurrence) -> Void)?
    public let onLinkToGlobal: ((DayOccurrence, StandaloneNote) -> Void)?
    public let onUnlinkGlobal: ((DayOccurrence) -> Void)?
    public let onDelete: ((DayOccurrence) -> Void)?

    public init(
        occurrences: [DayOccurrence],
        selectedItem: SelectedItemRef?,
        selectedItems: Set<SelectedItemRef> = [],
        globalNotes: [StandaloneNote] = [],
        canPaste: Bool = false,
        onSelect: @escaping (DayOccurrence, _ additive: Bool) -> Void,
        onToggleComplete: @escaping (DayOccurrence) -> Void,
        onAddAllDay: @escaping () -> Void,
        onOpenInNewWindow: ((DayOccurrence) -> Void)? = nil,
        onCopy: ((DayOccurrence) -> Void)? = nil,
        onPaste: (() -> Void)? = nil,
        onQuickRecurrence: ((DayOccurrence, RecurrenceRuleType?, WeekdayMask) -> Void)? = nil,
        onOpenCustomRecurrence: ((DayOccurrence) -> Void)? = nil,
        onPromoteToGlobal: ((DayOccurrence) -> Void)? = nil,
        onLinkToGlobal: ((DayOccurrence, StandaloneNote) -> Void)? = nil,
        onUnlinkGlobal: ((DayOccurrence) -> Void)? = nil,
        onDelete: ((DayOccurrence) -> Void)? = nil
    ) {
        self.occurrences = occurrences
        self.selectedItem = selectedItem
        self.selectedItems = selectedItems
        self.globalNotes = globalNotes
        self.canPaste = canPaste
        self.onSelect = onSelect
        self.onToggleComplete = onToggleComplete
        self.onAddAllDay = onAddAllDay
        self.onOpenInNewWindow = onOpenInNewWindow
        self.onCopy = onCopy
        self.onPaste = onPaste
        self.onQuickRecurrence = onQuickRecurrence
        self.onOpenCustomRecurrence = onOpenCustomRecurrence
        self.onPromoteToGlobal = onPromoteToGlobal
        self.onLinkToGlobal = onLinkToGlobal
        self.onUnlinkGlobal = onUnlinkGlobal
        self.onDelete = onDelete
    }

    public var body: some View {
        let isMultiRow = occurrences.count > 1

        HStack(alignment: isMultiRow ? .top : .center, spacing: 0) {
            Text(L10n.allDay)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .padding(.top, isMultiRow ? 6 : 0)
                .frame(width: AppTheme.timeGutterWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(occurrences) { occ in
                    allDayPill(for: occ)
                }

                if occurrences.isEmpty {
                    Button(action: onAddAllDay) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.caption2.weight(.semibold))
                            Text("Adicionar bloco de dia inteiro")
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !occurrences.isEmpty {
                Button(action: onAddAllDay) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.75))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .padding(.top, isMultiRow ? 4 : 0)
                .help("Adicionar bloco de dia inteiro")
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(AppTheme.secondarySurface.opacity(0.45))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }

    private func allDayPill(for occ: DayOccurrence) -> some View {
        let accent = Color(hex: occ.category?.colorHex ?? AppTheme.defaultAccentHex)
        let isSelected = isOccurrenceSelected(occ)
        let summary = occ.summary

        return HStack(spacing: 6) {
            Button {
                onToggleComplete(occ)
            } label: {
                Image(systemName: occ.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(occ.isCompleted ? accent : accent.opacity(0.8))
            }
            .buttonStyle(.plain)

            Text(occ.title.isEmpty ? L10n.untitledBlock : occ.title)
                .font(.caption.weight(.semibold))
                .strikethrough(occ.isCompleted, color: .secondary)
                .foregroundStyle(occ.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            if occ.isGlobalLinked {
                Image(systemName: "globe")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
            }
            if occ.isRecurring {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.85))
            }

            Spacer(minLength: 4)

            if summary.checklist.hasItems {
                Label("\(summary.checklist.completed)/\(summary.checklist.total)", systemImage: "checklist")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if summary.imageCount > 0 {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(occ.isCompleted ? 0.08 : 0.16))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(accent, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(macOS)
            let mods = NSEvent.modifierFlags
            let additive = mods.contains(.command) || mods.contains(.shift)
            #else
            let additive = false
            #endif
            onSelect(occ, additive)
        }
        .contextMenu {
            BlockContextMenuContent(
                occurrence: occ,
                globalNotes: globalNotes,
                selectedCount: isSelected ? max(1, selectedItems.count) : 1,
                canPaste: canPaste,
                onToggleComplete: { onToggleComplete(occ) },
                onOpenInNewWindow: onOpenInNewWindow.map { handler in { handler(occ) } },
                onCopy: { onCopy?(occ) },
                onPaste: onPaste,
                onQuickRecurrence: { rule, mask in onQuickRecurrence?(occ, rule, mask) },
                onOpenCustomRecurrence: { onOpenCustomRecurrence?(occ) },
                onPromoteToGlobal: { onPromoteToGlobal?(occ) },
                onLinkToGlobal: { global in onLinkToGlobal?(occ, global) },
                onUnlinkGlobal: { onUnlinkGlobal?(occ) },
                onDelete: { onDelete?(occ) }
            )
        }
    }

    private func isOccurrenceSelected(_ occ: DayOccurrence) -> Bool {
        if let block = occ.block {
            let ref = SelectedItemRef.block(block.id)
            return selectedItem == ref || selectedItems.contains(ref)
        }
        if let series = occ.series {
            let ref = SelectedItemRef.virtualOccurrence(seriesID: series.id, dayStart: occ.dayStart)
            if selectedItems.contains(ref) { return true }
            if case .virtualOccurrence(let sID, let dStart) = selectedItem {
                return sID == series.id && Calendar.current.isDate(occ.dayStart, inSameDayAs: dStart)
            }
        }
        return false
    }
}
