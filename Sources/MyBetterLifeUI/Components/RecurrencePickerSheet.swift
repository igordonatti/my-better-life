import SwiftUI
import MyBetterLifeCore

/// Sheet to configure recurrence rules (daily, weekdays, custom weekdays, monthly) for a block.
public struct RecurrencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let initialRule: RecurrenceRuleType?
    public let initialMask: WeekdayMask
    public let onSave: (RecurrenceRuleType?, WeekdayMask) -> Void

    @State private var isEnabled: Bool
    @State private var ruleType: RecurrenceRuleType
    @State private var selectedWeekdays: WeekdayMask

    public init(
        initialRule: RecurrenceRuleType?,
        initialMask: WeekdayMask,
        onSave: @escaping (RecurrenceRuleType?, WeekdayMask) -> Void
    ) {
        self.initialRule = initialRule
        self.initialMask = initialMask
        self.onSave = onSave
        _isEnabled = State(initialValue: initialRule != nil)
        _ruleType = State(initialValue: initialRule ?? .weekdays)
        _selectedWeekdays = State(initialValue: initialMask.isEmpty ? .weekdays : initialMask)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Repetir este bloco", isOn: $isEnabled)
                } footer: {
                    Text("O conteúdo atual vira um template herdado. O que você escrever ou marcar em cada dia ficará salvo apenas naquele dia.")
                }

                if isEnabled {
                    Section("Frequência") {
                        Picker("Regra", selection: $ruleType) {
                            ForEach(RecurrenceRuleType.allCases) { rule in
                                Text(rule.displayName).tag(rule)
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    if ruleType == .weekly {
                        Section("Dias da semana") {
                            HStack(spacing: 6) {
                                ForEach(WeekdayMask.orderedForUI, id: \.calendarWeekday) { entry in
                                    let active = selectedWeekdays.contains(entry.mask)
                                    Button {
                                        if active {
                                            if selectedWeekdays.subtracting(entry.mask) != [] {
                                                selectedWeekdays.remove(entry.mask)
                                            }
                                        } else {
                                            selectedWeekdays.insert(entry.mask)
                                        }
                                    } label: {
                                        Text(entry.shortLabel)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(active ? .white : .primary)
                                            .frame(maxWidth: .infinity, minHeight: 34)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(active ? Color.accentColor : AppTheme.secondarySurface)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(L10n.recurrence)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        onSave(isEnabled ? ruleType : nil, selectedWeekdays)
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 390)
        #endif
    }
}
