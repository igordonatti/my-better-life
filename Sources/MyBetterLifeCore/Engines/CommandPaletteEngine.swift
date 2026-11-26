import Foundation

/// Quick actions executable directly from the `⌘K` Command Palette.
public enum PaletteQuickAction: String, CaseIterable, Identifiable, Sendable {
    case goToToday
    case goToTomorrow
    case toggleSplitDay
    case toggleDayWeekMode
    case newBlockNow
    case newNote
    case newGlobalBlock
    case focusCurrentOrSelectedBlock
    case openAgenda
    case openNotes
    case openSettings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .goToToday: return "Ir para Hoje"
        case .goToTomorrow: return "Ir para Amanhã"
        case .toggleSplitDay: return "Abrir / fechar 2 dias lado a lado"
        case .toggleDayWeekMode: return "Alternar visualização Dia / Semana"
        case .newBlockNow: return "Criar novo bloco agora"
        case .newNote: return "Criar nova nota avulsa"
        case .newGlobalBlock: return "Criar novo Bloco Global"
        case .focusCurrentOrSelectedBlock: return "Iniciar Modo Foco no bloco atual"
        case .openAgenda: return "Ir para Agenda"
        case .openNotes: return "Ir para Notas"
        case .openSettings: return "Perfil & Configurações"
        }
    }

    public var subtitle: String {
        switch self {
        case .goToToday: return "Voltar à linha do tempo de hoje"
        case .goToTomorrow: return "Abrir o dia de amanhã na Agenda"
        case .toggleSplitDay: return "Comparar e planejar dois dias na mesma tela"
        case .toggleDayWeekMode: return "Trocar entre visão diária e semanal"
        case .newBlockNow: return "Agendar um bloco no horário atual"
        case .newNote: return "Abrir um documento Markdown em Notas"
        case .newGlobalBlock: return "Criar um documento vivo do Segundo Cérebro"
        case .focusCurrentOrSelectedBlock: return "Ativar timer de foco no bloco em andamento"
        case .openAgenda: return "Linha do tempo diária e semanal"
        case .openNotes: return "Notas avulsas e Blocos Globais"
        case .openSettings: return "Nome do perfil, versão e atualizações"
        }
    }

    public var systemImage: String {
        switch self {
        case .goToToday: return "calendar"
        case .goToTomorrow: return "arrow.right.circle"
        case .toggleSplitDay: return "rectangle.split.2x1"
        case .toggleDayWeekMode: return "calendar.day.timeline.left"
        case .newBlockNow: return "plus.circle"
        case .newNote: return "square.and.pencil"
        case .newGlobalBlock: return "globe"
        case .focusCurrentOrSelectedBlock: return "timer"
        case .openAgenda: return "calendar"
        case .openNotes: return "doc.text"
        case .openSettings: return "gearshape"
        }
    }

    public var shortcutBadge: String? {
        switch self {
        case .newBlockNow: return "⌘N"
        case .openAgenda: return "⌘1"
        case .openNotes: return "⌘2"
        default: return nil
        }
    }

    public var keywords: [String] {
        switch self {
        case .goToToday: return ["hoje", "today", "agora", "dia"]
        case .goToTomorrow: return ["amanha", "tomorrow", "proximo"]
        case .toggleSplitDay: return ["dois", "2 dias", "lado", "split", "dividir"]
        case .toggleDayWeekMode: return ["semana", "week", "dia", "modo"]
        case .newBlockNow: return ["novo", "bloco", "criar", "agendar", "horario"]
        case .newNote: return ["nova", "nota", "markdown", "escrever"]
        case .newGlobalBlock: return ["global", "cerebro", "hub", "novo"]
        case .focusCurrentOrSelectedBlock: return ["foco", "focus", "pomodoro", "timer", "cronometro"]
        case .openAgenda: return ["agenda", "calendario", "timeline"]
        case .openNotes: return ["notas", "notes", "documentos"]
        case .openSettings: return ["perfil", "configuracoes", "ajustes", "preferencias", "versao", "atualizacao", "update", "settings"]
        }
    }
}

/// Grouping category inside the `⌘K` Command Palette.
public enum PaletteSectionKind: String, Sendable {
    case dates = "Datas"
    case actions = "Ações Rápidas"
    case globalBlocks = "Blocos Globais"
    case inbox = "Inbox"
    case notesAndAgenda = "Notas & Agenda"
}

/// A unified item rendered in the `⌘K` Command Palette.
public struct PaletteItem: Identifiable, Sendable {
    public enum Payload: Sendable {
        case jumpToDate(Date, openSideBySide: Bool)
        case action(PaletteQuickAction)
        case globalBlock(StandaloneNote)
        case inboxItem(InboxItem)
        case searchResult(GlobalSearchResult)
        case quickCaptureInbox(String)
    }

    public let id: String
    public let section: PaletteSectionKind
    public let title: String
    public let subtitle: String
    public let systemImage: String
    public let accentHex: String?
    public let trailingBadge: String?
    public let payload: Payload

    public init(
        id: String,
        section: PaletteSectionKind,
        title: String,
        subtitle: String,
        systemImage: String,
        accentHex: String? = nil,
        trailingBadge: String? = nil,
        payload: Payload
    ) {
        self.id = id
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accentHex = accentHex
        self.trailingBadge = trailingBadge
        self.payload = payload
    }
}

/// Pure, fast engine powering the `⌘K` Command Palette:
/// - Portuguese natural-language date jump parsing ("hoje", "amanha", "sexta", "25/11", "+3")
/// - Fuzzy / diacritic-insensitive quick actions
/// - Prioritized Global Blocks, Inbox tasks, Standalone Notes, and Timeline Blocks
public enum CommandPaletteEngine {
    public static func results(
        query: String,
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote],
        inboxItems: [InboxItem],
        categories: [BlockCategory],
        referenceDate: Date = Date(),
        includeSplitDayOption: Bool = true,
        calendar: Calendar = .current
    ) -> [PaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        // Empty query -> curated landing palette (quick actions + recent global blocks + pending inbox)
        if trimmed.isEmpty {
            var items: [PaletteItem] = []

            let featuredActions: [PaletteQuickAction] = [
                .focusCurrentOrSelectedBlock,
                .newBlockNow,
                .goToToday,
                .toggleSplitDay,
                .newGlobalBlock,
                .openNotes,
                .openSettings
            ]
            for action in featuredActions {
                if action == .toggleSplitDay && !includeSplitDayOption { continue }
                items.append(PaletteItem(
                    id: "action-\(action.id)",
                    section: .actions,
                    title: action.title,
                    subtitle: action.subtitle,
                    systemImage: action.systemImage,
                    trailingBadge: action.shortcutBadge,
                    payload: .action(action)
                ))
            }

            let topGlobals = notes
                .filter { $0.isGlobal }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(5)
            for global in topGlobals {
                items.append(PaletteItem(
                    id: "global-\(global.id.uuidString)",
                    section: .globalBlocks,
                    title: global.title.isEmpty ? "Bloco Global sem título" : global.title,
                    subtitle: "Documento vivo do Segundo Cérebro",
                    systemImage: "globe",
                    accentHex: global.categoryID.flatMap { categoryByID[$0]?.colorHex },
                    trailingBadge: "Global",
                    payload: .globalBlock(global)
                ))
            }

            let pendingInbox = inboxItems
                .filter { !$0.isCompleted }
                .prefix(4)
            for task in pendingInbox {
                items.append(PaletteItem(
                    id: "inbox-\(task.id.uuidString)",
                    section: .inbox,
                    title: task.title,
                    subtitle: "Agendar tarefa da Inbox hoje",
                    systemImage: "tray",
                    accentHex: task.categoryID.flatMap { categoryByID[$0]?.colorHex },
                    trailingBadge: TimelineMath.formatDuration(minutes: task.estimatedMinutes),
                    payload: .inboxItem(task)
                ))
            }

            return items
        }

        var items: [PaletteItem] = []
        let tokens = fold(trimmed)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        // 1. Natural language date parsing
        if let parsedDate = parseDateIntent(trimmed, referenceDate: referenceDate, calendar: calendar) {
            let formatted = formatDateLong(parsedDate)
            items.append(PaletteItem(
                id: "date-jump-\(Int(parsedDate.timeIntervalSince1970))",
                section: .dates,
                title: "Ir para \(formatted)",
                subtitle: "Abrir esta data na Agenda",
                systemImage: "calendar",
                trailingBadge: "Data",
                payload: .jumpToDate(parsedDate, openSideBySide: false)
            ))
            if includeSplitDayOption {
                items.append(PaletteItem(
                    id: "date-split-\(Int(parsedDate.timeIntervalSince1970))",
                    section: .dates,
                    title: "Abrir \(formatted) ao lado",
                    subtitle: "Visualizar em 2 dias lado a lado",
                    systemImage: "rectangle.split.2x1",
                    trailingBadge: "2 dias",
                    payload: .jumpToDate(parsedDate, openSideBySide: true)
                ))
            }
        }

        // 2. Quick Actions matching tokens
        for action in PaletteQuickAction.allCases {
            if action == .toggleSplitDay && !includeSplitDayOption { continue }
            let haystack = fold(action.title + " " + action.subtitle + " " + action.keywords.joined(separator: " "))
            if tokens.allSatisfy({ haystack.contains($0) }) {
                items.append(PaletteItem(
                    id: "action-\(action.id)",
                    section: .actions,
                    title: action.title,
                    subtitle: action.subtitle,
                    systemImage: action.systemImage,
                    trailingBadge: action.shortcutBadge,
                    payload: .action(action)
                ))
            }
        }

        // 3. Global Blocks matching tokens (prioritized above normal notes)
        let matchingGlobals = notes.filter { note in
            guard note.isGlobal else { return false }
            let haystack = fold(note.title + " " + note.plainTextIndex)
            return tokens.allSatisfy { haystack.contains($0) }
        }
        let globalIDs = Set(matchingGlobals.map(\.id))
        for global in matchingGlobals.prefix(8) {
            items.append(PaletteItem(
                id: "global-\(global.id.uuidString)",
                section: .globalBlocks,
                title: global.title.isEmpty ? "Bloco Global sem título" : global.title,
                subtitle: global.plainTextIndex.isEmpty ? "Documento vivo do Segundo Cérebro" : String(global.plainTextIndex.prefix(90)),
                systemImage: "globe",
                accentHex: global.categoryID.flatMap { categoryByID[$0]?.colorHex },
                trailingBadge: "Global",
                payload: .globalBlock(global)
            ))
        }

        // 4. Inbox items matching tokens
        for task in inboxItems where !task.isCompleted {
            let haystack = fold(task.title + " " + task.noteMarkdown)
            if tokens.allSatisfy({ haystack.contains($0) }) {
                items.append(PaletteItem(
                    id: "inbox-\(task.id.uuidString)",
                    section: .inbox,
                    title: task.title,
                    subtitle: "Agendar tarefa da Inbox hoje",
                    systemImage: "tray",
                    accentHex: task.categoryID.flatMap { categoryByID[$0]?.colorHex },
                    trailingBadge: TimelineMath.formatDuration(minutes: task.estimatedMinutes),
                    payload: .inboxItem(task)
                ))
            }
        }

        // 5. General search across notes & timeline blocks (excluding already-listed global blocks)
        let searchHits = SearchEngine.search(
            query: trimmed,
            blocks: blocks,
            seriesList: seriesList,
            notes: notes.filter { !globalIDs.contains($0.id) },
            categories: categories,
            referenceDate: referenceDate,
            calendar: calendar
        )
        for hit in searchHits.prefix(15) {
            let icon = hit.note != nil ? "doc.text" : (hit.isRecurringTemplate ? "repeat" : "calendar.badge.clock")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "pt_BR")
            dateFormatter.dateFormat = "d MMM"
            items.append(PaletteItem(
                id: "hit-\(hit.id)",
                section: .notesAndAgenda,
                title: hit.title,
                subtitle: hit.snippet.isEmpty ? (hit.note != nil ? "Nota avulsa" : "Bloco na Agenda") : hit.snippet,
                systemImage: icon,
                accentHex: hit.category?.colorHex,
                trailingBadge: dateFormatter.string(from: hit.targetDate),
                payload: .searchResult(hit)
            ))
        }

        // 6. Always offer instant Inbox capture for the typed text at the bottom
        items.append(PaletteItem(
            id: "quick-inbox-\(trimmed)",
            section: .inbox,
            title: "Capturar \"\(trimmed)\" na Inbox",
            subtitle: "Salvar como tarefa rápida para agendar depois",
            systemImage: "tray.and.arrow.down",
            trailingBadge: "Inbox",
            payload: .quickCaptureInbox(trimmed)
        ))

        return items
    }

    /// Parses common Portuguese natural-language date intents into start-of-day dates.
    public static func parseDateIntent(
        _ rawQuery: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let folded = fold(rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !folded.isEmpty else { return nil }
        let today = calendar.startOfDay(for: referenceDate)

        // Exact keywords
        switch folded {
        case "hoje", "today":
            return today
        case "amanha", "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "depois de amanha":
            return calendar.date(byAdding: .day, value: 2, to: today)
        case "ontem", "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: today)
        default:
            break
        }

        // Relative day offset: "+3", "-2", "+7d"
        let cleanedOffset = folded.hasSuffix("d") ? String(folded.dropLast()) : folded
        if (cleanedOffset.hasPrefix("+") || cleanedOffset.hasPrefix("-")),
           let delta = Int(cleanedOffset), abs(delta) <= 365 {
            return calendar.date(byAdding: .day, value: delta, to: today)
        }

        // Weekday names (optional "prox" / "proxima" / "proximo" prefix)
        var weekdayQuery = folded
        for prefix in ["proxima ", "proximo ", "prox "] {
            if weekdayQuery.hasPrefix(prefix) {
                weekdayQuery = String(weekdayQuery.dropFirst(prefix.count))
            }
        }
        let weekdayMap: [String: Int] = [
            "domingo": 1, "dom": 1,
            "segunda": 2, "segunda-feira": 2, "seg": 2,
            "terca": 3, "terca-feira": 3, "ter": 3,
            "quarta": 4, "quarta-feira": 4, "qua": 4,
            "quinta": 5, "quinta-feira": 5, "qui": 5,
            "sexta": 6, "sexta-feira": 6, "sex": 6,
            "sabado": 7, "sab": 7
        ]
        if let targetWeekday = weekdayMap[weekdayQuery] {
            let currentWeekday = calendar.component(.weekday, from: today)
            var diff = targetWeekday - currentWeekday
            if diff <= 0 { diff += 7 }
            return calendar.date(byAdding: .day, value: diff, to: today)
        }

        // Short numeric date: "dd/MM" or "dd/MM/yyyy"
        let parts = folded.split(separator: "/").map(String.init)
        if parts.count == 2 || parts.count == 3,
           let day = Int(parts[0]), let month = Int(parts[1]),
           (1...31).contains(day), (1...12).contains(month) {
            let currentYear = calendar.component(.year, from: today)
            let year: Int
            if parts.count == 3, let parsedYear = Int(parts[2]) {
                year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
            } else {
                year = currentYear
            }
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            if let candidate = calendar.date(from: comps),
               calendar.component(.day, from: candidate) == day,
               calendar.component(.month, from: candidate) == month {
                return calendar.startOfDay(for: candidate)
            }
        }

        return nil
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func formatDateLong(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "EEE, d 'de' MMM"
        return df.string(from: date).capitalized
    }
}
