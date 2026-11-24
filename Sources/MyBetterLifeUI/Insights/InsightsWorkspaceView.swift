import SwiftUI
import Charts
import MyBetterLifeCore

/// Native Insights & Productivity Analytics workspace (`⌘3` on macOS, 3rd tab on iOS):
/// - Period selector (`Semana | Mês | 90 dias`) with previous/next period stepping
/// - 4 headline KPI cards (Planned Hours, Completion Rate, Global Blocks Time, Best Routine Streak)
/// - Stacked Daily Hours Bar Chart colored by Category (Apple `Charts`)
/// - Clickable Global Blocks time investment ranking (jump straight to the Second Brain hub in Notes)
/// - Category Donut Chart (`SectorMark`) + percentage breakdown
/// - Recurring Routines Streaks card (`flame.fill`)
public struct InsightsWorkspaceView: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel

    @State private var period: InsightsPeriod = .week
    @State private var periodOffset: Int = 0

    public init(store: PlannerStore, viewModel: PlannerViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var report: InsightsReport {
        InsightsEngine.generate(
            period: period,
            offset: periodOffset,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments
        )
    }

    private var periodRangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "d MMM"
        let startStr = df.string(from: report.startDate)
        let endStr = df.string(from: report.endDate)
        return "\(startStr) – \(endStr)"
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                headerBar
                kpiGrid
                dailyHoursChartCard

                #if os(macOS)
                HStack(alignment: .top, spacing: 16) {
                    globalBlocksCard
                        .frame(maxWidth: .infinity)
                    categoryDistributionCard
                        .frame(maxWidth: .infinity)
                }
                #else
                globalBlocksCard
                categoryDistributionCard
                #endif

                streaksCard
            }
            .padding(20)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvasBackground)
    }

    // MARK: - Header & Period Switcher

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.insightsTab)
                    .font(.title2.weight(.bold))
                Text(periodRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    periodOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if periodOffset != 0 {
                    Button("Atual") {
                        periodOffset = 0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    periodOffset = min(0, periodOffset + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(periodOffset >= 0)
            }

            Picker("Período", selection: $period) {
                ForEach(InsightsPeriod.allCases) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            .onChange(of: period) { _, _ in
                periodOffset = 0
            }
        }
    }

    // MARK: - KPI Cards

    private var kpiGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]
        let completionPct = Int(round(report.completionRate * 100))

        return LazyVGrid(columns: columns, spacing: 12) {
            kpiCard(
                title: "Tempo Planejado",
                value: TimelineMath.formatDuration(minutes: report.totalPlannedMinutes),
                subtitle: "\(TimelineMath.formatDuration(minutes: report.completedMinutes)) concluídos",
                icon: "clock.fill",
                tint: Color(hex: "#3B82F6")
            )
            kpiCard(
                title: "Conclusão",
                value: "\(completionPct)%",
                subtitle: "\(report.completedBlocksCount) de \(report.totalBlocksCount) blocos",
                icon: "checkmark.circle.fill",
                tint: Color(hex: "#10B981")
            )
            kpiCard(
                title: "Blocos Globais",
                value: TimelineMath.formatDuration(minutes: report.globalBlocksMinutes),
                subtitle: "\(report.globalBlockStats.count) projetos ativos",
                icon: "globe",
                tint: Color(hex: "#8B5CF6")
            )
            kpiCard(
                title: "Melhor Sequência",
                value: report.bestCurrentStreak == 1 ? "1 dia" : "\(report.bestCurrentStreak) dias",
                subtitle: "\(report.routineStreaks.count) rotinas recorrentes",
                icon: "flame.fill",
                tint: Color(hex: "#F59E0B")
            )
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.75)
        }
    }

    // MARK: - Daily Hours Stacked Bar Chart

    private var dailyHoursChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Horas por Dia")
                        .font(.headline)
                    Text("Distribuição diária dos blocos planejados por categoria")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if report.totalPlannedMinutes == 0 {
                emptyChartPlaceholder("Ainda não há blocos com horário neste período.")
            } else {
                Chart(report.dailyBreakdown) { entry in
                    BarMark(
                        x: .value("Dia", entry.day, unit: .day),
                        y: .value("Horas", Double(entry.minutes) / 60.0)
                    )
                    .foregroundStyle(Color(hex: entry.colorHex))
                    .cornerRadius(4)
                }
                .chartYAxisLabel("h", alignment: .topTrailing)
                .chartXAxis {
                    if period == .week {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    } else {
                        AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                }
                .frame(height: 210)
            }
        }
        .padding(16)
        .background(AppTheme.secondarySurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.75)
        }
    }

    // MARK: - Global Blocks Time Investment Ranking

    private var globalBlocksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(Color.accentColor)
                Text("Tempo por Bloco Global")
                    .font(.headline)
                Spacer()
            }

            if report.globalBlockStats.isEmpty {
                emptyChartPlaceholder("Vincule blocos da agenda a um Bloco Global para acompanhar quantas horas dedicou a cada projeto.")
            } else {
                let maxMinutes = max(1, report.globalBlockStats.first?.totalMinutes ?? 1)
                VStack(spacing: 10) {
                    ForEach(report.globalBlockStats) { stat in
                        let color = Color(hex: stat.categoryColorHex)
                        Button {
                            viewModel.openGlobalNoteInNotes(stat.note)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(stat.note.title.isEmpty ? L10n.untitledNote : stat.note.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(TimelineMath.formatDuration(minutes: stat.totalMinutes))
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(color)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(color.opacity(0.14))
                                        Capsule()
                                            .fill(color)
                                            .frame(width: max(6, geo.size.width * CGFloat(stat.totalMinutes) / CGFloat(maxMinutes)))
                                    }
                                }
                                .frame(height: 6)

                                HStack {
                                    Text("\(stat.sessionCount) \(stat.sessionCount == 1 ? "sessão" : "sessões") · \(stat.completedSessionCount) concluídas")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Abrir em Notas →")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(color.opacity(0.85))
                                }
                            }
                            .padding(10)
                            .background(AppTheme.canvasBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.secondarySurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.75)
        }
    }

    // MARK: - Category Distribution (Donut Chart)

    private var categoryDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Distribuição por Categoria")
                    .font(.headline)
                Spacer()
            }

            if report.categoryStats.isEmpty {
                emptyChartPlaceholder("Nenhum tempo registrado neste período.")
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Chart(report.categoryStats) { stat in
                        SectorMark(
                            angle: .value("Minutos", stat.totalMinutes),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(Color(hex: stat.colorHex))
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.categoryStats) { stat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: stat.colorHex))
                                    .frame(width: 9, height: 9)
                                Text(stat.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(TimelineMath.formatDuration(minutes: stat.totalMinutes))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                Text("(\(Int(round(stat.share * 100)))%)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(AppTheme.secondarySurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.75)
        }
    }

    // MARK: - Recurring Routine Streaks

    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Consistência & Sequências")
                    .font(.headline)
                Spacer()
                Text("Rotinas recorrentes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if report.routineStreaks.isEmpty {
                emptyChartPlaceholder("Clique com o botão direito em qualquer bloco da agenda para fazê-lo repetir pela semana e acompanhar sua sequência aqui.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(report.routineStreaks) { streak in
                        let color = Color(hex: streak.categoryColorHex)
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(color.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                Image(systemName: streak.currentStreak > 0 ? "flame.fill" : "repeat")
                                    .foregroundStyle(streak.currentStreak > 0 ? .orange : color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(streak.series.title.isEmpty ? L10n.untitledBlock : streak.series.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(streak.completedInPeriod)/\(streak.scheduledInPeriod) no período · Recorde: \(streak.bestStreak)d")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(streak.currentStreak)")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(streak.currentStreak > 0 ? .orange : .secondary)
                                Text("seguidos")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(11)
                        .background(AppTheme.canvasBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.secondarySurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.75)
        }
    }

    private func emptyChartPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 88)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }
}
