import SwiftUI
import MyBetterLifeCore

/// Live current-time red indicator line positioned accurately on Today's timeline.
public struct CurrentTimeIndicator: View {
    public let hourHeight: CGFloat
    public let showDot: Bool

    public init(hourHeight: CGFloat, showDot: Bool = true) {
        self.hourHeight = hourHeight
        self.showDot = showDot
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
            let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let yOffset = CGFloat(TimelineMath.yPosition(forMinute: minutes, hourHeight: Double(hourHeight)))

            HStack(spacing: 0) {
                if showDot {
                    Circle()
                        .fill(AppTheme.nowIndicatorColor)
                        .frame(width: 9, height: 9)
                        .offset(x: -4.5)
                }
                Rectangle()
                    .fill(AppTheme.nowIndicatorColor)
                    .frame(height: 1.5)
            }
            .offset(y: yOffset - 4.5)
            .allowsHitTesting(false)
        }
    }
}
