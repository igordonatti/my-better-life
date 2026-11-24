import Foundation

/// Populates helpful default categories and a clean starter day on very first launch.
@MainActor
public enum SampleDataSeeder {
    public static func seedIfNeeded(in store: PlannerStore) {
        guard store.categories.isEmpty && store.blocks.isEmpty && store.seriesList.isEmpty else {
            return
        }

        let trabalho = BlockCategory(name: "Trabalho", colorHex: "#3B82F6", symbolName: "briefcase.fill", sortOrder: 0)
        let saude = BlockCategory(name: "Saúde", colorHex: "#10B981", symbolName: "heart.fill", sortOrder: 1)
        let pessoal = BlockCategory(name: "Pessoal", colorHex: "#8B5CF6", symbolName: "person.fill", sortOrder: 2)
        let estudos = BlockCategory(name: "Estudos", colorHex: "#F59E0B", symbolName: "book.fill", sortOrder: 3)

        store.upsertCategory(trabalho)
        store.upsertCategory(saude)
        store.upsertCategory(pessoal)
        store.upsertCategory(estudos)

        let today = Calendar.current.startOfDay(for: Date())

        // Morning block (07:30 - 08:30)
        let morningBlock = TimeBlock(
            title: "Rotina Matinal & Treino",
            startDate: TimelineMath.date(on: today, minuteOfDay: 7 * 60 + 30),
            endDate: TimelineMath.date(on: today, minuteOfDay: 8 * 60 + 30),
            noteMarkdown: """
            # Energia para o dia
            - [ ] 500ml de água ao acordar
            - [ ] 30 min de treino ou caminhada
            - [ ] Revisar prioridades do dia no **My Better Life**
            """,
            categoryID: saude.id
        )
        store.upsertBlock(morningBlock)

        // All-day focus banner
        let allDayFocus = TimeBlock(
            title: "Foco do dia: construir com clareza",
            startDate: today,
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today,
            isAllDay: true,
            noteMarkdown: "Defina **1 a 3 entregas essenciais** que fariam hoje valer a pena.",
            categoryID: pessoal.id
        )
        store.upsertBlock(allDayFocus)

        // Deep work block (09:30 - 11:30)
        let deepWork = TimeBlock(
            title: "Bloco de Foco Profundo",
            startDate: TimelineMath.date(on: today, minuteOfDay: 9 * 60 + 30),
            endDate: TimelineMath.date(on: today, minuteOfDay: 11 * 60 + 30),
            noteMarkdown: """
            ## Objetivo da sessão
            Avançar na tarefa de maior impacto sem distrações.

            - [x] Organizar ambiente e silenciar notificações
            - [ ] Finalizar primeira entrega
            - [ ] Anotar próximos passos antes de encerrar

            Referência rápida: [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
            """,
            categoryID: trabalho.id
        )
        store.upsertBlock(deepWork)

        // Afternoon reading/study block (15:00 - 16:00)
        let studyBlock = TimeBlock(
            title: "Leitura & Anotações",
            startDate: TimelineMath.date(on: today, minuteOfDay: 15 * 60),
            endDate: TimelineMath.date(on: today, minuteOfDay: 16 * 60),
            noteMarkdown: """
            ## Ideias principais
            Escreva aqui resumos, links ou cole capturas de tela com **⌘V**.
            - [ ] Ler 1 capítulo
            - [ ] Registrar 3 insights práticos
            """,
            categoryID: estudos.id
        )
        store.upsertBlock(studyBlock)

        // Starter pinned To-do / Quick Note
        let starterNote = StandaloneNote(
            title: "To-do & Notas Rápidas",
            noteMarkdown: """
            # Caixa de entrada pessoal
            Use esta nota fixada para capturar tarefas soltas e ideias rápidas em **Markdown**.

            - [ ] Revisar prioridades da semana
            - [ ] Organizar ideias de projetos
            - [ ] Capturar links e referências úteis
            """,
            isPinned: true,
            categoryID: pessoal.id
        )
        store.upsertNote(starterNote)
    }
}
