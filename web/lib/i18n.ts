import type { Locale } from '@/components/providers'

export const GITHUB_REPO_URL = 'https://github.com/igordonatti/my-better-life'

export interface LandingCopy {
  nav: {
    features: string
    pricing: string
    docs: string
    faq: string
    github: string
    download: string
  }
  hero: {
    badge: string
    titlePrefix: string
    titleEmphasis: string
    titleSuffix: string
    subtitle: string
    primaryCta: string
    secondaryCta: string
    metaLine: string
    stats: { value: string; label: string }[]
  }
  showcase: {
    eyebrow: string
    heading: string
    subheading: string
    hint: string
    controls: {
      oneDay: string
      twoDays: string
      focusOn: string
      focusOff: string
      popOutHint: string
    }
  }
  features: {
    eyebrow: string
    heading: string
    subheading: string
    items: {
      tag: string
      title: string
      description: string
      shortcut?: string
      accent: 'blue' | 'emerald' | 'gold' | 'violet'
      spanWide?: boolean
    }[]
  }
  pricing: {
    eyebrow: string
    heading: string
    subheading: string
    philosophy: string
    free: {
      badge: string
      name: string
      tagline: string
      description: string
      features: string[]
    }
    cloud: {
      badge: string
      name: string
      tagline: string
      description: string
      features: { title: string; description: string }[]
    }
  }
  voices: {
    eyebrow: string
    heading: string
    subheading: string
    items: {
      quote: string
      author: string
      role: string
      initials: string
      color: string
    }[]
  }
  faq: {
    eyebrow: string
    heading: string
    subheading: string
    items: { q: string; a: string }[]
  }
  finalCta: {
    badge: string
    heading: string
    subtitle: string
    download: string
    github: string
    docs: string
  }
  gatekeeper: {
    title: string
    body: string
    path: string
  }
  footer: {
    tagline: string
    columns: {
      product: string
      docs: string
      community: string
    }
    rights: string
    license: string
  }
}

export const landingCopy: Record<Locale, LandingCopy> = {
  en: {
    nav: {
      features: 'Features',
      pricing: 'Open Core',
      docs: 'Docs',
      faq: 'FAQ',
      github: 'GitHub',
      download: 'Download for macOS',
    },
    hero: {
      badge: 'Free & Open Source · Native macOS & iOS',
      titlePrefix: 'Time-blocking meets your',
      titleEmphasis: 'Second Brain.',
      titleSuffix: 'Local-first, forever.',
      subtitle:
        'Design your day on a tactile native timeline, turn recurring projects into living Global Blocks with nested subnotes, and pop out any note beside your code — zero Electron bloat, zero vendor lock-in.',
      primaryCta: 'Download for macOS',
      secondaryCta: 'Read the Docs',
      metaLine: 'Swift 6 & SwiftUI · Offline Core Data · MIT License',
      stats: [
        { value: '100%', label: 'Free & Open-Source Core' },
        { value: '0ms', label: 'Offline Local-First Latency' },
        { value: 'macOS + iOS', label: 'Native Apple Silicon & iPhone' },
        { value: 'MIT', label: 'Open-Source License' },
      ],
    },
    showcase: {
      eyebrow: 'Interactive Preview',
      heading: 'Feel the rhythm of a native workspace.',
      subheading:
        'Click any time block below, toggle Two Days Side-by-Side, explore nested subnotes inside a Global Block, or trigger Focus Mode right here.',
      hint: 'Interactive mockup — click blocks, subnotes, or toolbar toggles',
      controls: {
        oneDay: '1 Day',
        twoDays: '2 Days Split',
        focusOn: 'Focus Active',
        focusOff: 'Start Focus',
        popOutHint: 'Pop-out Window (⌘⇧O)',
      },
    },
    features: {
      eyebrow: 'Built for Deep Work',
      heading: 'Every detail tuned for thinkers, engineers, and makers.',
      subheading:
        'Stop jumping between a calendar, a notes app, a Pomodoro timer, and a task inbox. My Better Life unifies them into one calm native canvas.',
      items: [
        {
          tag: 'Timeline',
          title: 'Two Days Side-by-Side & Fluid Time-Blocking',
          description:
            'Drag-to-paint 15-minute blocks, resize live, multi-select with ⌘+Click to copy/paste whole schedules, drag days from the mini-calendar to compare two days side-by-side, and undo any deletion with ⌘Z.',
          shortcut: '⌘C · ⌘V · ⌘Z',
          accent: 'blue',
          spanWide: true,
        },
        {
          tag: 'Second Brain',
          title: 'Global Blocks, Subnotes & [[Wikilinks]]',
          description:
            'Promote any recurring study or project (like "SRE Studies") into a Global Block. Nest multi-level subnotes inside it, cite notes with [[ or @, and see automatic Backlinks and every scheduled session.',
          shortcut: '[[ · @',
          accent: 'gold',
        },
        {
          tag: 'Flow',
          title: 'Slack-Style Tear-Off Pop-Out Windows',
          description:
            'Pull any inspector tab right out of the app into an independent floating window with Back/Forward navigation, Always-on-Top pinning, and one-click dock back.',
          shortcut: '⌘⇧O · ⌘W',
          accent: 'violet',
        },
        {
          tag: 'Execution',
          title: 'Draggable Inbox, Focus Mode & macOS Menu Bar',
          description:
            'Capture unscheduled ideas from the Menu Bar anywhere on your Mac, drag Inbox tasks straight onto a timeline hour, and run Focus or Pomodoro timers with live countdowns in your top bar.',
          shortcut: '⌘K',
          accent: 'emerald',
          spanWide: true,
        },
        {
          tag: 'Markdown',
          title: 'Live Markdown Editor & Formatting Shortcuts',
          description:
            'Write clean Markdown with instant live typography, click checkboxes directly in place, and format with ⌘B / ⌃B bold, ⌘I italic, ⌘L checklists, and ⌘↩ to toggle items without leaving the keyboard.',
          shortcut: '⌘B · ⌘I · ⌘↩',
          accent: 'blue',
        },
        {
          tag: 'Keyboard First',
          title: 'Instant ⌘K Command Palette & Smart Reminders',
          description:
            'Jump to natural-language dates ("tomorrow", "friday", "25/11"), launch Focus Mode, search notes, or capture Inbox items without lifting your hands. Native interactive notifications let you Focus, Snooze +15m, or Complete.',
          shortcut: '⌘K · ⌘1–2',
          accent: 'gold',
        },
      ],
    },
    pricing: {
      eyebrow: 'Honest Open-Core Model',
      heading: 'Free and open source forever. Cloud only if you want it.',
      subheading:
        'Inspired by Obsidian: everything that runs on your Mac and iPhone is MIT-licensed and free forever. Optional cloud add-ons will come later.',
      philosophy:
        'Everything local stays free and open source forever. Optional cloud add-ons will only exist to cover server and API infrastructure costs — no local feature will ever move behind a paywall.',
      free: {
        badge: 'Open Source · MIT',
        name: 'My Better Life',
        tagline: 'Free forever',
        description:
          'Everything that runs locally on your Mac and iPhone — no account, no feature paywalls, full data ownership.',
        features: [
          'Native macOS .dmg download · iOS via Xcode (App Store soon)',
          'Time-Blocking, 2-day split & weekly views',
          'Global Blocks, multi-level subnotes & [[wikilinks]]',
          'Tear-off pop-out windows, Focus Mode & Menu Bar',
          '⌘K Command Palette, smart reminders & Markdown shortcuts',
          '100% offline Core Data + Markdown .md export/import',
          'Automatic in-app update notifications',
        ],
      },
      cloud: {
        badge: 'Coming soon',
        name: 'Cloud Add-Ons',
        tagline: 'Optional',
        description:
          'Three optional add-ons are on the roadmap for people who want them. There is nothing to buy or sign up for yet — we will announce them here and on GitHub when they are ready.',
        features: [
          {
            title: 'Cloud sync across devices',
            description: 'Keep your Mac and iPhone in sync (Mac ↔ iPhone).',
          },
          {
            title: 'Managed MCP server for AI agents',
            description: 'Connect Claude, Cursor and other agents to your schedule and notes.',
          },
          {
            title: 'Two-way Google Calendar sync',
            description: 'Bring meetings into your timeline and send time blocks back.',
          },
        ],
      },
    },
    voices: {
      eyebrow: 'Designed for Real Workflows',
      heading: 'How people structure their week with My Better Life.',
      subheading:
        'Built in the open for software engineers, SREs, indie makers, and lifelong learners who care about speed and calm software.',
      items: [
        {
          quote:
            'Having a single Global Block for "SRE Studies" with nested subnotes for Observability and Postmortems — and seeing every study block on my timeline — finally connected my calendar to my notes.',
          author: 'Lucas M.',
          role: 'Site Reliability Engineer',
          initials: 'LM',
          color: '#2563EB',
        },
        {
          quote:
            'Dragging tomorrow next to today in two-day split view and tearing off my meeting notes into a floating always-on-top window feels like native macOS craft at its finest.',
          author: 'Mariana R.',
          role: 'Staff Product Designer',
          initials: 'MR',
          color: '#10B981',
        },
        {
          quote:
            'Because everything lives in local Core Data with plain Markdown export, I could adopt it with zero lock-in — and the whole app is right there on GitHub under MIT.',
          author: 'Rafael C.',
          role: 'Backend & Distributed Systems',
          initials: 'RC',
          color: '#8B5CF6',
        },
        {
          quote:
            'Pressing ⌘K, typing "friday", dragging three Inbox tasks straight into the morning, and watching the Menu Bar countdown keep me honest changed how I finish deep work.',
          author: 'Camila T.',
          role: 'Indie Founder & Researcher',
          initials: 'CT',
          color: '#F59E0B',
        },
      ],
    },
    faq: {
      eyebrow: 'Questions & Answers',
      heading: 'Transparent by default.',
      subheading: 'Everything you need to know about the open-source license, local data, updates, and future cloud add-ons.',
      items: [
        {
          q: 'Is the macOS and iOS app really free and open source?',
          a: 'Yes. The full native app is released under the MIT license. Every local feature — Time-Blocking, 2-day split, Global Blocks, multi-level subnotes, pop-out windows, Focus Mode, Menu Bar and ⌘K Command Palette — is free forever, and you never need an account to use it.',
        },
        {
          q: 'Where is my data stored? Does it work completely offline?',
          a: 'Everything lives locally in Core Data on your device, with instant reads and writes and no internet required. You can export and import standard .md Markdown files at any time, so your notes are never locked in.',
        },
        {
          q: 'Why will Cloud Sync, MCP and Google Calendar be paid add-ons?',
          a: 'Like Obsidian, we only plan to charge for features that need servers running on your behalf: hosting, storage, an always-on MCP endpoint and third-party API maintenance. These add-ons are optional and not available yet — the local app stays complete and free.',
        },
        {
          q: 'How do app updates work?',
          a: 'The app checks GitHub Releases for new versions and shows a notification inside the app when one is available. Download the new .dmg and replace the app in your Applications folder — your local data is stored separately and stays exactly where it is.',
        },
        {
          q: 'macOS says the app cannot be opened. What should I do?',
          a: 'As a free community build, the app is not notarized by Apple yet, so macOS Sequoia may block it on first launch. Drag My Better Life to Applications, try to open it once, then go to System Settings → Privacy & Security and click Open Anyway. After that it opens normally.',
        },
        {
          q: 'Can I build it from source?',
          a: 'Yes. Clone the repository and run make run (or make app) on macOS 15+ with Xcode 16. For iPhone, open MyBetterLife.xcodeproj in Xcode and run it on your device. The Getting Started guide in the Docs walks through every step.',
        },
      ],
    },
    finalCta: {
      badge: 'Free & Open Source',
      heading: 'Own your time. Own your notes.',
      subtitle:
        'Download the native macOS app for free, browse the source on GitHub, or start with the documentation.',
      download: 'Download for macOS',
      github: 'View on GitHub',
      docs: 'Read the Docs',
    },
    gatekeeper: {
      title: 'First launch on macOS',
      body: 'As a free community build, the app is not notarized yet, so macOS Sequoia may ask you to allow it the first time. Open it once, then go to',
      path: 'System Settings → Privacy & Security → Open Anyway',
    },
    footer: {
      tagline: 'Native local-first time-blocking planner & Second Brain for macOS and iOS. Open-core, calm, and fast.',
      columns: {
        product: 'Product',
        docs: 'Documentation',
        community: 'Open Source',
      },
      rights: 'My Better Life · Built with Swift 6 & SwiftUI.',
      license: 'MIT · Local-First',
    },
  },

  pt: {
    nav: {
      features: 'Recursos',
      pricing: 'Open-Core',
      docs: 'Documentação',
      faq: 'FAQ',
      github: 'GitHub',
      download: 'Baixar para macOS',
    },
    hero: {
      badge: 'Grátis & Open Source · Nativo para macOS & iOS',
      titlePrefix: 'Time-blocking unido ao seu',
      titleEmphasis: 'Segundo Cérebro.',
      titleSuffix: 'Local-first, para sempre.',
      subtitle:
        'Planeje seu dia numa linha do tempo nativa super fluida, transforme estudos e projetos em Blocos Globais com subnotas aninhadas e destaque qualquer nota ao lado do seu código — sem Electron, sem ficar refém de nuvem.',
      primaryCta: 'Baixar para macOS',
      secondaryCta: 'Ler Documentação',
      metaLine: 'Swift 6 & SwiftUI · Core Data Offline · Licença MIT',
      stats: [
        { value: '100%', label: 'Core Grátis & Open-Source' },
        { value: '0ms', label: 'Latência Local Offline-First' },
        { value: 'macOS + iOS', label: 'Nativo Apple Silicon & iPhone' },
        { value: 'MIT', label: 'Licença Open Source' },
      ],
    },
    showcase: {
      eyebrow: 'Prévia Interativa',
      heading: 'Sinta a leveza de um workspace nativo.',
      subheading:
        'Clique nos blocos abaixo, alterne entre 1 Dia e 2 Dias Lado a Lado, navegue nas subnotas de um Bloco Global ou ative o Modo Foco direto aqui na página.',
      hint: 'Mockup interativo — clique nos blocos, subnotas ou botões da barra',
      controls: {
        oneDay: '1 Dia',
        twoDays: '2 Dias Lado a Lado',
        focusOn: 'Foco Ativo',
        focusOff: 'Iniciar Foco',
        popOutHint: 'Janela Destacada (⌘⇧O)',
      },
    },
    features: {
      eyebrow: 'Feito para Foco Profundo',
      heading: 'Cada detalhe pensado para engenheiros, criadores e estudantes.',
      subheading:
        'Pare de pular entre calendário, app de notas, timer Pomodoro e lista de tarefas. O My Better Life reúne tudo num único espaço nativo e silencioso.',
      items: [
        {
          tag: 'Linha do Tempo',
          title: '2 Dias Lado a Lado & Time-Blocking Fluido',
          description:
            'Arraste na grade para criar blocos de 15 em 15 min, redimensione ao vivo, selecione vários blocos com ⌘+Clique para copiar/colar rotinas inteiras, abra dois dias lado a lado e desfaça exclusões com ⌘Z.',
          shortcut: '⌘C · ⌘V · ⌘Z',
          accent: 'blue',
          spanWide: true,
        },
        {
          tag: 'Segundo Cérebro',
          title: 'Blocos Globais, Subnotas & [[Wikilinks]]',
          description:
            'Promova qualquer tema (como "Estudos de SRE") a Bloco Global. Crie subnotas em múltiplos níveis dentro dele, cite notas com [[ ou @ e veja Backlinks automáticos e todas as sessões agendadas.',
          shortcut: '[[ · @',
          accent: 'gold',
        },
        {
          tag: 'Fluxo',
          title: 'Janelas Destacadas Estilo Slack (Tear-Off)',
          description:
            'Arraste qualquer aba do painel lateral para fora do aplicativo e transforme em uma janela independente com Voltar/Avançar, fixar "Sempre no topo" e encaixar de volta em 1 clique.',
          shortcut: '⌘⇧O · ⌘W',
          accent: 'violet',
        },
        {
          tag: 'Execução',
          title: 'Inbox Arrastável, Modo Foco & Barra de Menu',
          description:
            'Capture tarefas rápidas pela Barra de Menu de qualquer tela do Mac, arraste itens da Inbox direto para um horário da linha do tempo e acompanhe o cronômetro de foco ou Pomodoro ao vivo no topo da tela.',
          shortcut: '⌘K',
          accent: 'emerald',
          spanWide: true,
        },
        {
          tag: 'Markdown',
          title: 'Editor Markdown ao Vivo & Atalhos de Formatação',
          description:
            'Escreva em Markdown limpo com tipografia ao vivo, clique nos checkboxes direto no texto e formate com ⌘B / ⌃B negrito, ⌘I itálico, ⌘L checklist e ⌘↩ para marcar tarefas sem tirar a mão do teclado.',
          shortcut: '⌘B · ⌘I · ⌘↩',
          accent: 'blue',
        },
        {
          tag: 'Teclado Primeiro',
          title: 'Command Palette ⌘K & Lembretes Inteligentes',
          description:
            'Pule para datas digitando "amanhã", "sexta" ou "25/11", inicie o Modo Foco ou capture na Inbox sem tirar a mão do teclado. Notificações nativas com ações diretas: Iniciar Foco, Adiar 15 min e Concluir.',
          shortcut: '⌘K · ⌘1–2',
          accent: 'gold',
        },
      ],
    },
    pricing: {
      eyebrow: 'Modelo Open-Core Transparente',
      heading: 'Grátis e open source para sempre. Nuvem só se você quiser.',
      subheading:
        'No espírito do Obsidian: tudo o que roda no seu Mac e iPhone tem licença MIT e é gratuito para sempre. Add-ons de nuvem opcionais virão depois.',
      philosophy:
        'Tudo o que é local continua grátis e open source para sempre. Os add-ons de nuvem opcionais existirão apenas para cobrir custos de servidor e APIs — nenhum recurso local vai para trás de um paywall.',
      free: {
        badge: 'Open Source · MIT',
        name: 'My Better Life',
        tagline: 'Grátis para sempre',
        description:
          'Tudo que roda localmente no seu Mac e iPhone — sem conta, sem paywall em recursos locais, com seus dados 100% seus.',
        features: [
          'Download nativo .dmg para macOS · iOS via Xcode (App Store em breve)',
          'Time-Blocking, 2 dias lado a lado e visão semanal',
          'Blocos Globais, subnotas multi-nível e [[wikilinks]]',
          'Janelas destacadas, Modo Foco e Barra de Menu do Mac',
          'Command Palette ⌘K, lembretes nativos e atalhos Markdown',
          '100% offline (Core Data) + exportar/importar Markdown .md',
          'Avisos automáticos de atualização dentro do app',
        ],
      },
      cloud: {
        badge: 'Em breve',
        name: 'Add-Ons Cloud',
        tagline: 'Opcionais',
        description:
          'Três add-ons opcionais estão no roadmap para quem quiser. Ainda não há nada para comprar ou assinar — vamos anunciar aqui e no GitHub quando estiverem prontos.',
        features: [
          {
            title: 'Sincronização em nuvem entre dispositivos',
            description: 'Mantenha Mac e iPhone sempre sincronizados (Mac ↔ iPhone).',
          },
          {
            title: 'Servidor MCP gerenciado para agentes de IA',
            description: 'Conecte Claude, Cursor e outros agentes à sua agenda e às suas notas.',
          },
          {
            title: 'Sincronização bidirecional com Google Calendar',
            description: 'Traga reuniões para sua linha do tempo e envie seus blocos de volta.',
          },
        ],
      },
    },
    voices: {
      eyebrow: 'Feito para Rotinas Reais',
      heading: 'Como o My Better Life transforma o planejamento semanal.',
      subheading:
        'Construído em aberto para devs, SREs, designers e estudantes que valorizam velocidade nativa e clareza mental.',
      items: [
        {
          quote:
            'Ter um único Bloco Global para "Estudos de SRE" com subnotas de Observabilidade e Postmortems — e ver todas as sessões na linha do tempo — finalmente uniu minha agenda às minhas notas.',
          author: 'Lucas M.',
          role: 'Site Reliability Engineer',
          initials: 'LM',
          color: '#2563EB',
        },
        {
          quote:
            'Arrastar amanhã ao lado de hoje na visão de 2 dias e puxar a aba da reunião para uma janela flutuante sempre no topo tem cara de software Apple de primeira linha.',
          author: 'Mariana R.',
          role: 'Staff Product Designer',
          initials: 'MR',
          color: '#10B981',
        },
        {
          quote:
            'Como tudo fica em Core Data local com exportação em Markdown puro, adotei sem medo de ficar preso — e o app inteiro está no GitHub sob licença MIT.',
          author: 'Rafael C.',
          role: 'Engenheiro Backend & Sistemas',
          initials: 'RC',
          color: '#8B5CF6',
        },
        {
          quote:
            'Apertar ⌘K, digitar "sexta", arrastar três tarefas da Inbox para a manhã e acompanhar o timer na Barra de Menu mudou completamente minha consistência em trabalho focado.',
          author: 'Camila T.',
          role: 'Fundadora & Pesquisadora',
          initials: 'CT',
          color: '#F59E0B',
        },
      ],
    },
    faq: {
      eyebrow: 'Perguntas Frequentes',
      heading: 'Transparência desde o dia zero.',
      subheading: 'Tudo sobre a licença open source, privacidade local-first, atualizações e os futuros add-ons de nuvem.',
      items: [
        {
          q: 'O app para macOS e iOS é realmente grátis e open source?',
          a: 'Sim. O app nativo completo é publicado sob a licença MIT. Todo recurso local — Time-Blocking, 2 dias lado a lado, Blocos Globais, subnotas multi-nível, janelas destacadas, Modo Foco, Barra de Menu e Command Palette ⌘K — é grátis para sempre, e você não precisa criar conta para usar.',
        },
        {
          q: 'Onde meus dados ficam salvos? Funciona 100% offline?',
          a: 'Tudo fica salvo localmente em Core Data no seu dispositivo, com leitura e escrita instantâneas e sem precisar de internet. Você pode exportar e importar notas em Markdown (.md) padrão a qualquer momento, sem ficar preso ao app.',
        },
        {
          q: 'Por que Cloud Sync, MCP e Google Calendar serão add-ons pagos?',
          a: 'Seguindo o modelo do Obsidian, só pretendemos cobrar pelos recursos que exigem servidores rodando para você: hospedagem, armazenamento, um endpoint MCP sempre ativo e manutenção de APIs externas. Esses add-ons são opcionais e ainda não estão disponíveis — o app local continua completo e gratuito.',
        },
        {
          q: 'Como funcionam as atualizações do app?',
          a: 'O app consulta o GitHub Releases e mostra um aviso dentro do próprio app quando há uma nova versão. Baixe o novo .dmg e substitua o app na pasta Aplicativos — seus dados locais ficam guardados separadamente e continuam exatamente onde estão.',
        },
        {
          q: 'O macOS diz que o app não pode ser aberto. O que fazer?',
          a: 'Por ser uma build gratuita da comunidade, o app ainda não é notarizado pela Apple, então o macOS Sequoia pode bloqueá-lo na primeira abertura. Arraste o My Better Life para Aplicativos, tente abri-lo uma vez e depois vá em Ajustes do Sistema → Privacidade e Segurança e clique em Abrir Mesmo Assim. Depois disso ele abre normalmente.',
        },
        {
          q: 'Posso compilar a partir do código-fonte?',
          a: 'Pode. Clone o repositório e rode make run (ou make app) no macOS 15+ com Xcode 16. Para iPhone, abra o MyBetterLife.xcodeproj no Xcode e rode no seu aparelho. O guia Primeiros Passos na Documentação mostra cada etapa.',
        },
      ],
    },
    finalCta: {
      badge: 'Grátis & Open Source',
      heading: 'Dono do seu tempo. Dono das suas notas.',
      subtitle:
        'Baixe o app nativo para macOS de graça, explore o código no GitHub ou comece pela documentação.',
      download: 'Baixar para macOS',
      github: 'Ver no GitHub',
      docs: 'Ler Documentação',
    },
    gatekeeper: {
      title: 'Primeira abertura no macOS',
      body: 'Por ser uma build gratuita da comunidade, o app ainda não é notarizado, então o macOS Sequoia pode pedir sua permissão na primeira vez. Abra o app uma vez e depois vá em',
      path: 'Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim',
    },
    footer: {
      tagline: 'Planner de time-blocking e Segundo Cérebro local-first para macOS e iOS. Open-core, nativo e rápido.',
      columns: {
        product: 'Produto',
        docs: 'Documentação',
        community: 'Open Source',
      },
      rights: 'My Better Life · Construído com Swift 6 & SwiftUI.',
      license: 'MIT · Local-First',
    },
  },
}
