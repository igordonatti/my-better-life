import SwiftUI
import MyBetterLifeCore

/// Refined Apple-native translucent time block card with left accent bar,
/// completion toggle, checklist summary, and rich-content preview.
public struct TimelineBlockCard: View {
    public let occurrence: DayOccurrence
    public let height: CGFloat
    public let isSelected: Bool
    public let isCompactWeekStyle: Bool
    public let overrideTimeRangeText: String?
    public let onToggleComplete: () -> Void

    public init(
        occurrence: DayOccurrence,
        height: CGFloat,
        isSelected: Bool,
        isCompactWeekStyle: Bool = false,
        overrideTimeRangeText: String? = nil,
        onToggleComplete: @escaping () -> Void
    ) {
        self.occurrence = occurrence
        self.height = height
        self.isSelected = isSelected
        self.isCompactWeekStyle = isCompactWeekStyle
        self.overrideTimeRangeText = overrideTimeRangeText
        self.onToggleComplete = onToggleComplete
    }

    public var body: some View {
        let accent = Color(hex: occurrence.category?.colorHex ?? AppTheme.defaultAccentHex)
        let summary = occurrence.summary
        let isTiny = height < 34
        let isMedium = height >= 46
        let isTall = height >= 84
        let timeRangeText = overrideTimeRangeText ?? TimelineMath.formatTimeRange(start: occurrence.startDate, end: occurrence.endDate)

        ZStack(alignment: .topLeading) {
            // Translucent surface fill
            RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous)
                .fill(accent.opacity(occurrence.isCompleted ? 0.08 : (isSelected ? 0.22 : 0.14)))
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous)
                        .fill(AppTheme.canvasBackground.opacity(0.88))
                )

            // Crisp left accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(occurrence.isCompleted ? 0.5 : 0.95))
                    .frame(width: AppTheme.accentBarWidth)
                    .padding(.vertical, 3)
                    .padding(.leading, 2)
                Spacer()
            }

            // Content layout adapts smoothly to block height
            VStack(alignment: .leading, spacing: isTiny ? 1 : 3) {
                HStack(alignment: .center, spacing: 5) {
                    if !isCompactWeekStyle {
                        Button(action: onToggleComplete) {
                            Image(systemName: occurrence.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: isTiny ? 12 : 14, weight: .medium))
                                .foregroundStyle(occurrence.isCompleted ? accent : accent.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(occurrence.title.isEmpty ? L10n.untitledBlock : occurrence.title)
                        .font(.system(size: isCompactWeekStyle ? 11 : (isTiny ? 12 : 13), weight: .semibold))
                        .foregroundStyle(occurrence.isCompleted ? .secondary : .primary)
                        .strikethrough(occurrence.isCompleted, color: .secondary)
                        .lineLimit(1)

                    if occurrence.isGlobalLinked {
                        Image(systemName: "globe")
                            .font(.system(size: isCompactWeekStyle ? 9 : 10, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    if occurrence.isRecurring && !isCompactWeekStyle {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.85))
                    }

                    Spacer(minLength: 2)

                    if !isMedium && !isCompactWeekStyle {
                        if let liveTime = overrideTimeRangeText {
                            Text(liveTime)
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(accent)
                        } else {
                            metadataBadges(summary: summary, accent: accent)
                        }
                    }
                }

                if isMedium {
                    HStack(spacing: 6) {
                        Text(timeRangeText)
                            .font(.system(size: isCompactWeekStyle ? 10 : 11, weight: overrideTimeRangeText != nil ? .semibold : .medium).monospacedDigit())
                            .foregroundStyle(overrideTimeRangeText != nil ? accent : .secondary)
                            .lineLimit(1)

                        if !isCompactWeekStyle {
                            Spacer(minLength: 2)
                            metadataBadges(summary: summary, accent: accent)
                        }
                    }
                }

                if isTall && !isCompactWeekStyle && !summary.previewText.isEmpty {
                    Text(summary.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.9))
                        .lineLimit(height > 120 ? 3 : 2)
                        .padding(.top, 2)
                }
            }
            .padding(.leading, AppTheme.accentBarWidth + 8)
            .padding(.trailing, 8)
            .padding(.vertical, isTiny ? 3 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? accent : accent.opacity(0.28),
                    lineWidth: isSelected ? 1.8 : 0.75
                )
        }
        .shadow(
            color: Color.black.opacity(isSelected ? 0.10 : 0.03),
            radius: isSelected ? 6 : 2,
            y: isSelected ? 2 : 1
        )
    }

    @ViewBuilder
    private func metadataBadges(summary: RichNoteSummary, accent: Color) -> some View {
        HStack(spacing: 6) {
            if summary.checklist.hasItems {
                HStack(spacing: 2) {
                    Image(systemName: summary.checklist.isAllCompleted ? "checkmark.square.fill" : "checklist")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(summary.checklist.completed)/\(summary.checklist.total)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(summary.checklist.isAllCompleted ? accent : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(accent.opacity(0.10), in: Capsule())
            }

            if summary.imageCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "photo")
                        .font(.system(size: 10))
                    if summary.imageCount > 1 {
                        Text("\(summary.imageCount)")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .foregroundStyle(.secondary)
            }

            if summary.linkCount > 0 {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
