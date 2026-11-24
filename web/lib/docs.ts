// Public documentation is fully inline so the Vercel build (Root Directory = `web`)
// never reads files outside this directory.

export interface DocPageMeta {
  slug: string
  category: { en: string; pt: string }
  title: { en: string; pt: string }
  description: { en: string; pt: string }
  badge?: string
  contentEn: string
  contentPt: string
}

export interface ResolvedDocPage {
  slug: string
  category: { en: string; pt: string }
  title: { en: string; pt: string }
  description: { en: string; pt: string }
  badge?: string
  markdownEn: string
  markdownPt: string
}

const RELEASES_URL = 'https://github.com/igordonatti/my-better-life/releases/latest'

const DOC_PAGES: DocPageMeta[] = [
  {
    slug: 'getting-started',
    category: { en: 'Start Here', pt: 'Comece Aqui' },
    title: { en: 'Getting Started', pt: 'Primeiros Passos' },
    description: {
      en: 'Download the macOS app, open it on first launch, stay up to date, or build from source.',
      pt: 'Baixe o app para macOS, abra na primeira vez, mantenha-o atualizado ou compile do código-fonte.',
    },
    contentEn: `# Getting Started with My Better Life

**My Better Life** is a native **Swift 6 + SwiftUI** time-blocking planner and Second Brain for **macOS 15+** and **iOS 18+**. Everything works 100% locally and offline via Core Data — no account or subscription required. The app is free and open source under the **MIT license**.

## 1. Download for macOS

1. Open the [latest release on GitHub](${RELEASES_URL}).
2. Download \`MyBetterLife-vX.Y.Z-macOS.dmg\` (Apple Silicon, macOS 15 Sequoia or newer).
3. Open the \`.dmg\` and drag **My Better Life** into the **Applications** folder.

> Each release also ships a \`SHA256SUMS.txt\` file. To verify your download, run \`shasum -a 256 MyBetterLife-*.dmg\` and compare the result.

## 2. First launch (macOS Gatekeeper)

As a free community build, the app is ad-hoc signed but **not notarized by Apple yet**, so macOS Sequoia may say it cannot verify the developer the first time you open it. This is expected:

1. Open **My Better Life** from Applications once and dismiss the warning.
2. Go to **System Settings → Privacy & Security**.
3. Scroll to the **Security** section and click **Open Anyway** next to *My Better Life*, then confirm.

After that, the app opens normally. Notarized Developer ID builds are planned for a future release.

## 3. Staying up to date

My Better Life checks **GitHub Releases** for new versions and shows a notification inside the app when an update is available. To update:

1. Download the new \`.dmg\` from the notification (or from the Releases page).
2. Replace the app in **Applications** with the new version.

Your data lives in a separate local Core Data store, so updating never touches your blocks, notes, or subnotes.

## 4. Build from source on macOS

Requirements: **macOS 15+** and **Xcode 16+** (or a Swift 6 toolchain).

\`\`\`bash
git clone https://github.com/igordonatti/my-better-life.git
cd my-better-life

# Build & run directly from the terminal (with app icon & Menu Bar)
make run

# Or package a standalone clickable .app bundle
make app
open ".build/My Better Life.app"

# Run the Swift test suite
make test
\`\`\`

> **Tip:** Drag \`.build/My Better Life.app\` into \`/Applications\` to enable native interactive notifications (*Start Focus*, *Snooze 15m*, *Complete*) and pin it to your Dock.

## 5. Run on iPhone (iOS 18+)

The iOS app is not on the App Store yet (coming soon), but you can install it from source:

1. Open \`MyBetterLife.xcodeproj\` in Xcode.
2. Select your Apple Developer Team in **Signing & Capabilities**.
3. Choose your iPhone or a Simulator and press \`⌘R\`.
`,
    contentPt: `# Primeiros Passos com o My Better Life

O **My Better Life** é um planner de **Time-Blocking** e **Segundo Cérebro** nativo em **Swift 6 + SwiftUI** para **macOS 15+** e **iOS 18+**. Tudo funciona 100% local e offline via Core Data — sem criar conta e sem assinatura. O app é gratuito e open source sob a **licença MIT**.

## 1. Baixar para macOS

1. Abra a [última versão no GitHub](${RELEASES_URL}).
2. Baixe o arquivo \`MyBetterLife-vX.Y.Z-macOS.dmg\` (Apple Silicon, macOS 15 Sequoia ou superior).
3. Abra o \`.dmg\` e arraste o **My Better Life** para a pasta **Aplicativos**.

> Cada versão também inclui um arquivo \`SHA256SUMS.txt\`. Para conferir o download, rode \`shasum -a 256 MyBetterLife-*.dmg\` e compare o resultado.

## 2. Primeira abertura (Gatekeeper do macOS)

Por ser uma build gratuita da comunidade, o app tem assinatura ad-hoc mas **ainda não é notarizado pela Apple**, então o macOS Sequoia pode avisar que não consegue verificar o desenvolvedor na primeira vez. Isso é esperado:

1. Abra o **My Better Life** em Aplicativos uma vez e feche o aviso.
2. Vá em **Ajustes do Sistema → Privacidade e Segurança**.
3. Role até a seção **Segurança** e clique em **Abrir Mesmo Assim** ao lado de *My Better Life*, depois confirme.

Depois disso, o app abre normalmente. Builds notarizadas com Developer ID estão planejadas para uma versão futura.

## 3. Mantendo o app atualizado

O My Better Life consulta o **GitHub Releases** e mostra um aviso dentro do app quando há uma nova versão. Para atualizar:

1. Baixe o novo \`.dmg\` pelo aviso (ou pela página de Releases).
2. Substitua o app em **Aplicativos** pela nova versão.

Seus dados ficam num armazenamento Core Data local separado, então atualizar nunca mexe nos seus blocos, notas ou subnotas.

## 4. Compilar do código-fonte no macOS

Requisitos: **macOS 15+** e **Xcode 16+** (ou toolchain Swift 6).

\`\`\`bash
git clone https://github.com/igordonatti/my-better-life.git
cd my-better-life

# Compilar e abrir direto pelo terminal (com ícone nativo e Barra de Menu)
make run

# Ou empacotar um .app clicável
make app
open ".build/My Better Life.app"

# Rodar os testes Swift
make test
\`\`\`

> **Dica:** Arraste \`.build/My Better Life.app\` para \`/Applications\` para habilitar notificações interativas nativas (*Iniciar Foco*, *Adiar 15 min*, *Concluir*) e fixar no Dock.

## 5. Rodar no iPhone (iOS 18+)

O app para iOS ainda não está na App Store (em breve), mas você pode instalar a partir do código:

1. Abra \`MyBetterLife.xcodeproj\` no Xcode.
2. Selecione seu Apple Developer Team em **Signing & Capabilities**.
3. Escolha seu iPhone ou um Simulador e pressione \`⌘R\`.
`,
  },
  {
    slug: 'shortcuts-and-workflow',
    category: { en: 'Product Guide', pt: 'Guia de Uso' },
    title: { en: 'Time-Blocking & Shortcuts', pt: 'Agenda & Atalhos' },
    description: {
      en: 'Master 2-day split view, multi-select copy/paste, tear-off pop-out windows, Focus Mode, and Undo.',
      pt: 'Domine 2 dias lado a lado, seleção múltipla, janelas destacadas, Modo Foco e Desfazer.',
    },
    contentEn: `# Time-Blocking, Multi-Select & Keyboard Shortcuts

My Better Life is designed to feel effortless whether you prefer the mouse or never leave the keyboard.

## Essential Keyboard Shortcuts (macOS)

| Shortcut | Action |
| :--- | :--- |
| \`⌘K\` | Open **Command Palette** (jump to dates like \`"tomorrow"\`, \`"friday"\`, \`"25/11"\`, run actions, search notes) |
| \`⌘1\` / \`⌘2\` / \`⌘3\` | Switch between **Agenda**, **Notes**, and **Insights** |
| \`⌘N\` | Create a new time block at the current hour (or a new note in Notes) |
| \`←\` / \`→\` | Step to the previous or next day (or week in Week view) |
| \`⌘ + Click\` / \`⇧ + Click\` | Multi-select multiple blocks on the timeline |
| \`⌘A\` | Select all blocks on the active day |
| \`⌘C\` / \`⌘V\` | Copy and paste 1 or multiple blocks (including notes, images & Global links) |
| \`⌫\` | Delete selected block(s) or note |
| \`⌘Z\` / \`⌃Z\` | **Undo deletion** (restores blocks, recurring series, notes, subnotes & images!) |
| \`⌘W\` | Close the active block tab in the right-hand inspector (or close a popped-out window) |
| \`⌘⇧O\` | Pop out the active block or note into an independent floating window |
| \`⌘E\` | Toggle live Markdown editor ↔ Formatted preview |

## Two Days Side-by-Side

Drag any date from the **Mini-Calendar** onto the Day Timeline (or click the split toolbar button) to plan two days side-by-side. You can even copy blocks from Monday and paste directly onto Tuesday!

## Slack-Style Tear-Off Windows

- **Drag any tab** out of the right-hand inspector bar to detach it into a standalone macOS window right where you release the cursor.
- Navigate subnotes and \`[[wikilinks]]\` inside the detached window with **← / →** history.
- Pin **"Always on Top"** to keep checklists floating over your terminal or browser, or click **"Dock"** to bring it back into the main app.

## Smart Recurring Blocks

- Right-click any block → **Repeat** (*Weekdays*, *Daily*, or custom weekdays).
- Editing **title, category, or reminder** automatically propagates to the whole series.
- Moving, resizing, or deleting lets you choose **Only this day**, **This and future**, or **Entire series** — preserving past history and habit streaks.
`,
    contentPt: `# Time-Blocking, Seleção Múltipla e Atalhos

O My Better Life foi construído para ser super rápido tanto no mouse quanto no teclado.

## Principais Atalhos no macOS

| Atalho | Ação |
| :--- | :--- |
| \`⌘K\` | Abrir **Command Palette** (pular para datas como \`"amanhã"\`, \`"sexta"\`, \`"25/11"\`, ações rápidas e busca) |
| \`⌘1\` / \`⌘2\` / \`⌘3\` | Alternar entre **Agenda**, **Notas** e **Insights** |
| \`⌘N\` | Criar novo bloco no horário atual (ou nova nota em Notas) |
| \`←\` / \`→\` | Avançar ou voltar um dia (ou semana na visão semanal) |
| \`⌘ + Clique\` / \`⇧ + Clique\` | Selecionar múltiplos blocos na linha do tempo |
| \`⌘A\` | Selecionar todos os blocos do dia ativo |
| \`⌘C\` / \`⌘V\` | Copiar e colar 1 ou vários blocos (preservando notas, imagens e Blocos Globais) |
| \`⌫\` | Apagar bloco(s) ou nota selecionada |
| \`⌘Z\` / \`⌃Z\` | **Desfazer exclusão** (restaura blocos, séries recorrentes, notas, subnotas e imagens!) |
| \`⌘W\` | Fechar a aba ativa do painel lateral direito (ou fechar uma janela destacada) |
| \`⌘⇧O\` | Destacar o bloco ou nota atual em uma janela independente |
| \`⌘E\` | Alternar entre edição Markdown ao vivo ↔ Visualização formatada |

## 2 Dias Lado a Lado

Arraste qualquer data do **Mini-Calendário** sobre a linha do tempo (ou clique no ícone de dividir tela na toolbar) para planejar dois dias simultaneamente. Você pode selecionar vários blocos de segunda e colar direto na terça!

## Janelas Destacadas Estilo Slack (Tear-Off)

- **Arraste qualquer aba** do painel lateral direito para fora da janela principal para soltá-la como uma janela independente na posição do mouse.
- Navegue por subnotas e \`[[wikilinks]]\` ali dentro com histórico **← / →**.
- Clique em **Fixar** para manter sempre no topo acima do terminal/navegador, ou **Encaixar** para trazer de volta para o app principal.

## Recorrência Inteligente

- Clique com o botão direito em qualquer bloco → **Repetir pela semana**.
- Alterar **título, categoria ou lembrete** propaga automaticamente para toda a série.
- Mover, redimensionar ou apagar pergunta o escopo: **Só este dia**, **Este e futuros** ou **Toda a série** — preservando seu histórico e sequências (streaks) passadas.
`,
  },
  {
    slug: 'second-brain',
    category: { en: 'Product Guide', pt: 'Guia de Uso' },
    title: { en: 'Second Brain & Subnotes', pt: 'Segundo Cérebro & Subnotas' },
    description: {
      en: 'Turn recurring topics into Global Blocks, nest multi-level subnotes, and link ideas with [[ or @.',
      pt: 'Transforme temas em Blocos Globais, aninhe subnotas em vários níveis e cite notas com [[ ou @.',
    },
    contentEn: `# Second Brain: Global Blocks, Subnotes & Citations

Most planners force a split between *when you work* and *what you learn*. My Better Life bridges both with **Global Blocks** and **Multi-Level Subnotes**.

## What is a Global Block?

A **Global Block** is a single living Markdown document that you can schedule on your timeline across as many days as you want.

- Example: Create a Global Block called **"SRE Studies"**.
- Drag it from the sidebar onto Monday 09:00 and Wednesday 14:00.
- Both timeline blocks open the **exact same living document**, and the **Insights** tab automatically tracks total hours invested in *"SRE Studies"*.

## Nested Parent-Child Subnotes (Notion-Style)

Any note or Global Block can contain unlimited nested subnotes (e.g., \`SRE Studies › Kubernetes › Networking\`):

1. Click **\`+ Subnote\`** inside any note (or right-click a note in the list → **New subnote here**).
2. Type \`[[\` or \`@\` inline while writing to cite any existing note **or** click **\`+ Create subnote "…"\`** to spawn a child page right under the current parent note.
3. Navigate effortlessly via clickable **Breadcrumbs** at the top and collapsible \`▸ / ▾\` trees in the Notes list.
4. Drag and drop any note onto another note to reorganize your hierarchy — deleting a parent note safely promotes its children one level up so nothing is ever lost.
`,
    contentPt: `# Segundo Cérebro: Blocos Globais, Subnotas e Citações

A maioria dos apps separa *quando você trabalha* de *o que você aprende*. O My Better Life une os dois mundos com **Blocos Globais** e **Subnotas Multi-Nível**.

## O que é um Bloco Global?

Um **Bloco Global** é um documento Markdown vivo único que você pode agendar em quantos dias quiser na sua agenda.

- Exemplo: crie um Bloco Global **"Estudos de SRE"**.
- Arraste-o da barra lateral para Segunda às 09:00 e Quarta às 14:00.
- Os dois blocos abrem o **mesmo documento vivo**, e a aba **Insights** contabiliza automaticamente quantas horas você dedicou a *"Estudos de SRE"*.

## Subnotas Aninhadas (Estilo Notion)

Qualquer nota ou Bloco Global pode conter subnotas em múltiplos níveis (ex.: \`Estudos de SRE › Kubernetes › Networking\`):

1. Clique em **\`+ Subnota\`** no topo da nota (ou botão direito na lista → **Nova subnota aqui**).
2. Enquanto escreve, digite \`[[\` ou \`@\` para **citar qualquer nota existente** ou clicar em **\`+ Criar subnota "…"\`** e já criar a página filha vinculada ali mesmo.
3. Navegue rapidamente pelo **Breadcrumb** clicável no topo e pela árvore expansível \`▸ / ▾\` na aba Notas.
4. Arraste uma nota em cima de outra para reorganizar a hierarquia — e ao apagar uma nota pai, suas subnotas são promovidas automaticamente para o nível acima (e tudo pode ser desfeito com \`⌘Z\`).
`,
  },
  {
    slug: 'open-core-pricing',
    category: { en: 'Open Source & Cloud', pt: 'Open Source & Cloud' },
    title: { en: 'Open-Core Philosophy & Cloud', pt: 'Modelo Open-Core & Cloud' },
    description: {
      en: 'What stays free & open source forever, and which optional cloud add-ons are coming.',
      pt: 'O que é grátis e open source para sempre e quais add-ons de nuvem opcionais estão por vir.',
    },
    badge: 'Open Core',
    contentEn: `# Open-Core Philosophy & Cloud Add-Ons

My Better Life follows the **Obsidian open-core principle**: software that runs on your own devices should belong to you and remain free and open source forever.

## Free forever · Open Source (MIT)

- The complete native **macOS** app (direct \`.dmg\` download) and **iOS** app (build with Xcode today; App Store coming soon)
- Offline-first **Core Data** storage and standard \`.md\` Markdown export/import
- Time-Blocking, 2 Days Side-by-Side, Weekly View and Recurring Series
- Global Blocks, multi-level Subnotes, \`[[wikilinks]]\` and Backlinks
- Tear-off Pop-Out Windows, Focus Mode, Menu Bar, \`⌘K\` Palette, Insights & Streaks
- Automatic in-app update notifications via GitHub Releases

No account is required, and no local feature will ever move behind a paywall.

## Cloud Add-Ons (coming soon)

Some features only make sense with servers running on your behalf. These are planned as **optional** paid add-ons whose only purpose is to cover real server and API infrastructure costs:

| Add-On | Status | Why it will be paid |
| :--- | :--- | :--- |
| **Cloud sync across devices (Mac ↔ iPhone)** | Coming soon | Hosted database, realtime relay and attachment storage |
| **Managed MCP server for AI agents** | Coming soon | Always-on authenticated endpoint for Claude, Cursor and other agents |
| **Two-way Google Calendar sync** | Coming soon | OAuth verification, webhooks and background sync workers |

There are no prices, checkout or sign-ups yet. Add-ons will be announced on this site and in the GitHub repository when they are ready — and the local app will keep working exactly the same without them.
`,
    contentPt: `# Filosofia Open-Core & Add-Ons Cloud

O My Better Life segue o mesmo princípio **open-core do Obsidian**: tudo o que roda nos seus próprios dispositivos pertence a você e permanece gratuito e open source para sempre.

## Grátis para sempre · Open Source (MIT)

- App nativo completo para **macOS** (download direto do \`.dmg\`) e **iOS** (compile pelo Xcode hoje; App Store em breve)
- Armazenamento offline-first em **Core Data** + exportar/importar Markdown \`.md\`
- Time-Blocking, 2 Dias Lado a Lado, Visão Semanal e Recorrência Inteligente
- Blocos Globais, Subnotas Multi-Nível, \`[[wikilinks]]\` e Backlinks
- Janelas Destacadas, Modo Foco, Barra de Menu, Command Palette \`⌘K\`, Insights e Sequências
- Avisos automáticos de atualização dentro do app via GitHub Releases

Não é preciso criar conta, e nenhum recurso local vai para trás de um paywall.

## Add-Ons Cloud (em breve)

Alguns recursos só fazem sentido com servidores rodando para você. Eles estão planejados como add-ons pagos **opcionais**, com o único objetivo de cobrir custos reais de servidor e APIs:

| Add-On | Status | Por que será pago |
| :--- | :--- | :--- |
| **Sincronização em nuvem entre dispositivos (Mac ↔ iPhone)** | Em breve | Banco de dados hospedado, relay em tempo real e armazenamento de anexos |
| **Servidor MCP gerenciado para agentes de IA** | Em breve | Endpoint autenticado sempre ativo para Claude, Cursor e outros agentes |
| **Sincronização bidirecional com Google Calendar** | Em breve | Verificação OAuth, webhooks e workers de sincronização |

Ainda não há preços, checkout nem cadastro. Os add-ons serão anunciados neste site e no repositório do GitHub quando estiverem prontos — e o app local continua funcionando exatamente igual sem eles.
`,
  },
  {
    slug: 'architecture',
    category: { en: 'Engineering', pt: 'Engenharia' },
    title: { en: 'System Architecture', pt: 'Arquitetura do Sistema' },
    description: {
      en: 'Swift 6 + SwiftUI, local-first Core Data, MyBetterLifeCore engines and extension points.',
      pt: 'Swift 6 + SwiftUI, Core Data local-first, engines do MyBetterLifeCore e pontos de extensão.',
    },
    contentEn: `# System Architecture

My Better Life is a **local-first native app**. Everything you see runs on your device; there is no required server.

## Stack

| Layer | Technology |
| :--- | :--- |
| UI | **SwiftUI** (macOS 15+ & iOS 18+), native windows, Menu Bar extra and notifications |
| Language | **Swift 6** with strict concurrency |
| Storage | **Core Data** — offline-first, instant reads and writes |
| Packaging | **Swift Package Manager** + Xcode project for iOS |
| Distribution | Ad-hoc signed \`.dmg\` built by GitHub Actions and published to **GitHub Releases** |

## Package layout

\`\`\`text
Sources/
├── MyBetterLifeCore/     # Pure Swift domain engines (no UI)
├── MyBetterLifeUI/       # Shared SwiftUI views for macOS & iOS
└── MyBetterLifeMacApp/   # macOS app target (windows, Menu Bar, commands)
App/                      # iOS / Xcode app entry point & assets
Tests/MyBetterLifeCoreTests/
\`\`\`

## \`MyBetterLifeCore\` engines

The core library holds the app's logic as plain, testable Swift:

- **Timeline & overlap layout** — positions time blocks and resolves overlapping blocks side by side.
- **Recurrence** — expands recurring series and applies *only this day / this and future / entire series* edits.
- **Second Brain** — Global Blocks, multi-level subnotes, \`[[wikilinks]]\`, backlinks and hierarchy moves.
- **Insights** — hours per Global Block and category, plus habit streaks.
- **Natural-language dates** — powers \`⌘K\` jumps such as *"tomorrow"*, *"friday"* or *"25/11"*.
The SwiftUI layer (\`MyBetterLifeUI\`) observes these engines, persists through Core Data, and handles standard \`.md\` Markdown import/export, so the same logic drives both macOS and iOS.

## Extension points for future add-ons

Optional cloud add-ons (sync, managed MCP, Google Calendar) plug in through **Swift protocols** defined in the open-source core. The local app ships with local-only implementations, so it is fully functional on its own, and any future add-on is an opt-in implementation of those protocols — never a requirement.

## Update checker

A few seconds after launch (and then every 6 hours), the app asks the public **GitHub Releases API** for the latest version, compares it with the installed \`CFBundleShortVersionString\`, and shows a notification inside the app when a newer \`.dmg\` is available. No personal data is sent.

## Release pipeline

Pushing a \`vX.Y.Z\` tag runs a GitHub Actions workflow on macOS that runs \`swift test\`, builds in release mode, packages and ad-hoc signs \`My Better Life.app\`, wraps it in a \`.dmg\` with an \`/Applications\` shortcut, and publishes it with a \`SHA256SUMS.txt\` file to GitHub Releases.
`,
    contentPt: `# Arquitetura do Sistema

O My Better Life é um **app nativo local-first**. Tudo o que você vê roda no seu dispositivo; nenhum servidor é obrigatório.

## Stack

| Camada | Tecnologia |
| :--- | :--- |
| Interface | **SwiftUI** (macOS 15+ e iOS 18+), janelas nativas, Barra de Menu e notificações |
| Linguagem | **Swift 6** com concorrência estrita |
| Armazenamento | **Core Data** — offline-first, leitura e escrita instantâneas |
| Empacotamento | **Swift Package Manager** + projeto Xcode para iOS |
| Distribuição | \`.dmg\` com assinatura ad-hoc gerado pelo GitHub Actions e publicado no **GitHub Releases** |

## Estrutura dos pacotes

\`\`\`text
Sources/
├── MyBetterLifeCore/     # Engines de domínio em Swift puro (sem UI)
├── MyBetterLifeUI/       # Views SwiftUI compartilhadas entre macOS e iOS
└── MyBetterLifeMacApp/   # Target do app macOS (janelas, Barra de Menu, comandos)
App/                      # Ponto de entrada e assets do app iOS / Xcode
Tests/MyBetterLifeCoreTests/
\`\`\`

## Engines do \`MyBetterLifeCore\`

A biblioteca core concentra a lógica do app em Swift simples e testável:

- **Linha do tempo e sobreposição** — posiciona os blocos e organiza blocos sobrepostos lado a lado.
- **Recorrência** — expande séries recorrentes e aplica edições *só este dia / este e futuros / toda a série*.
- **Segundo Cérebro** — Blocos Globais, subnotas multi-nível, \`[[wikilinks]]\`, backlinks e reorganização da hierarquia.
- **Insights** — horas por Bloco Global e categoria, além de sequências de hábitos.
- **Datas em linguagem natural** — alimenta os saltos do \`⌘K\` como *"amanhã"*, *"sexta"* ou *"25/11"*.
A camada SwiftUI (\`MyBetterLifeUI\`) observa essas engines, persiste via Core Data e cuida de importar/exportar Markdown \`.md\` padrão, então a mesma lógica roda no macOS e no iOS.

## Pontos de extensão para futuros add-ons

Os add-ons de nuvem opcionais (sync, MCP gerenciado, Google Calendar) se conectam por meio de **protocolos Swift** definidos no core open source. O app local vem com implementações apenas locais, então funciona completo sozinho, e qualquer add-on futuro é uma implementação opcional desses protocolos — nunca um requisito.

## Verificador de atualizações

Alguns segundos após abrir (e depois a cada 6 horas), o app consulta a **API pública do GitHub Releases**, compara a última versão com o \`CFBundleShortVersionString\` instalado e mostra um aviso dentro do app quando há um \`.dmg\` mais novo. Nenhum dado pessoal é enviado.

## Pipeline de release

Ao enviar uma tag \`vX.Y.Z\`, um workflow do GitHub Actions no macOS roda \`swift test\`, compila em modo release, empacota e assina (ad-hoc) o \`My Better Life.app\`, gera um \`.dmg\` com atalho para \`/Applications\` e publica tudo com um arquivo \`SHA256SUMS.txt\` no GitHub Releases.
`,
  },
]

export function getAllDocs(): ResolvedDocPage[] {
  return DOC_PAGES.map((doc) => ({
    slug: doc.slug,
    category: doc.category,
    title: doc.title,
    description: doc.description,
    badge: doc.badge,
    markdownEn: doc.contentEn,
    markdownPt: doc.contentPt,
  }))
}

export function getDocBySlug(slug: string): ResolvedDocPage | undefined {
  return getAllDocs().find((d) => d.slug === slug)
}
