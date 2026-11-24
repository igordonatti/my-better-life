import SwiftUI

/// Refined Apple-native visual system inspired by Things 3 & Apple Calendar.
public enum AppTheme {
    public static let ptBRLocale = Locale(identifier: "pt_BR")

    /// Neutral slate gray used for uncategorized blocks & notes (distinct from Trabalho blue `#3B82F6`).
    public static let defaultAccentHex = "#64748B"
    public static let hourHeight: CGFloat = 64
    public static let weekHourHeight: CGFloat = 52
    public static let timeGutterWidth: CGFloat = 80
    public static let blockCornerRadius: CGFloat = 8
    public static let accentBarWidth: CGFloat = 3.5

    // MARK: - Adaptive Surfaces
    public static var canvasBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    public static var secondarySurface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    public static var tertiarySurface: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }

    public static var hairline: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor).opacity(0.65)
        #else
        Color(uiColor: .separator).opacity(0.55)
        #endif
    }

    public static var halfHourHairline: Color {
        hairline.opacity(0.32)
    }

    public static var subtleLabel: Color {
        Color.secondary
    }

    public static let nowIndicatorColor = Color(hex: "#EF4444")

    // MARK: - Date Formatters (PT-BR)
    public static func dayHeaderWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).localizedCapitalized
    }

    public static func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
    }

    public static func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    public static func monthYearTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "MMMM 'de' yyyy"
        return capitalizeFirstLetter(formatter.string(from: date))
    }

    public static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "d 'de' MMM"
        return formatter.string(from: date)
    }

    public static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ptBRLocale
        formatter.dateFormat = "EEE, d 'de' MMM 'de' yyyy"
        return capitalizeFirstLetter(formatter.string(from: date))
    }

    private static func capitalizeFirstLetter(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.uppercased() + string.dropFirst()
    }
}

public extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
        } else {
            r = 0.23
            g = 0.51
            b = 0.96
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
