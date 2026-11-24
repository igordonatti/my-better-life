# My Better Life

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

App open-source de organização temporal e notas Markdown para **macOS (15+)** e **iPhone (iOS 18+)**, feito em **Swift 6 & SwiftUI**. É **100% local-first**: funciona offline, sem conta, sem login e sem servidor. Seus dados ficam no seu dispositivo (Core Data).

---

## Principais funcionalidades

- **Visão de Dia interativa (timeline 24h):**
  - Arraste na grade para criar um bloco (snap de 15 min), mova blocos e redimensione pelas bordas com o horário atualizado em tempo real.
  - **Dois dias lado a lado no Mac:** arraste um dia do mini-calendário para a timeline (ou clique com o botão direito → *"Abrir ao lado"*).
  - Blocos sobrepostos em colunas automáticas, seção **"Dia inteiro"**, linha do horário atual, navegação por teclado (`←` / `→`) e exclusão rápida com `⌫`.
- **Visão de Semana** (segunda a domingo) com criação direta por coluna.
- **Editor Markdown vivo + abas no Mac:** vários blocos abertos ao mesmo tempo; títulos, negrito, itálico, listas, checklists `- [ ]` clicáveis, links e imagens via `⌘V` ou arrastar; alternância `MD` ↔ `Formatado` (`⌘E`).
- **Notas (`.md`) e Segundo Cérebro:** notas avulsas fixáveis, notas da Agenda, Blocos Globais com `[[wikilinks]]` e backlinks, filtros por origem/dia/categoria e importação/exportação de arquivos `.md`.
- **Inbox, Modo Foco e Insights:** captura rápida (também pela barra de menus do Mac), timer de foco, lembretes locais e estatísticas de tempo por categoria e Bloco Global.
- **Command Palette (`⌘K`):** busca global, saltos de data em português ("amanhã", "sexta", "+3", "05/12") e ações rápidas.
- **Perfil local e avisos de atualização:** seu nome fica só no dispositivo; o app consulta o GitHub Releases e mostra um aviso discreto quando existe uma versão nova (detalhes abaixo).

---

## Download (macOS)

1. Baixe o arquivo `MyBetterLife-vX.Y.Z-macOS.dmg` na página de [Releases](https://github.com/igordonatti/my-better-life/releases/latest).
2. Abra o `.dmg` e arraste **My Better Life** para **Aplicativos**.

> **Gatekeeper:** o app usa assinatura *ad-hoc* (não notarizada pela Apple). Na primeira abertura, clique com o botão direito no app → **Abrir** → **Abrir**. Outra opção é ir em **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim**.

---

## Compilar a partir do código-fonte

Requisitos: macOS 15+ com Xcode 16+ (ou Command Line Tools com Swift 6).

```bash
make run      # compila e abre o app no Mac (swift run)
make test     # roda os testes unitários (Swift Testing)
make build    # build de debug
make app      # gera ".build/My Better Life.app" (release)
make dmg      # gera .build/MyBetterLife-v1.0.0-macOS.dmg (assinatura ad-hoc + atalho para /Applications)
```

A versão do pacote segue SemVer e pode ser definida na hora de empacotar:

```bash
make dmg VERSION=1.2.0 BUILD_NUMBER=7
```

### iPhone / Simulador iOS

Abra o [MyBetterLife.xcodeproj](MyBetterLife.xcodeproj) no Xcode 16+ (ou gere o projeto com `xcodegen` a partir do [project.yml](project.yml)), escolha seu Team em **Signing & Capabilities** e pressione `⌘R`.

---

## Avisos de atualização

- Alguns segundos após abrir o app, e depois a cada 6 horas, ele consulta `GET https://api.github.com/repos/igordonatti/my-better-life/releases/latest`.
- A consulta usa `ETag` / `If-None-Match`. Quando a resposta é `304 Not Modified`, o app reaproveita a release salva e a consulta não gasta o limite de requisições da API do GitHub.
- Se houver uma versão SemVer maior que a instalada, aparece o aviso **"Atualização disponível"** logo acima do cartão de perfil, na barra lateral. Pela janela de atualização você pode baixar o `.dmg`, abrir a release no GitHub, deixar para depois ou **ignorar esta versão**.
- As verificações automáticas não mostram erros (por exemplo, quando você está offline ou ainda não há release publicada). Em **Perfil & Configurações → Verificar atualizações**, a verificação manual informa o resultado.
- Nenhum dado pessoal é enviado: a requisição leva só o cabeçalho `User-Agent: MyBetterLife/<versão>`.

### Publicando uma release

1. Atualize `CFBundleShortVersionString` em `App/Info.plist` e `MARKETING_VERSION` em `project.yml`.
2. Gere o instalador com `make dmg VERSION=X.Y.Z BUILD_NUMBER=N`.
3. Crie uma release no GitHub com a tag `vX.Y.Z` e anexe o `.dmg`. O app dá preferência a anexos `.dmg`; depois tenta `.zip` e, por último, a página da release.

---

## Open-Core

O núcleo, publicado neste repositório, é e continuará sendo **open-source (MIT)**, completo e utilizável offline, sem conta.

Recursos futuros como **sincronização em nuvem entre dispositivos**, **servidor MCP** e **integração com Google Calendar** poderão ser oferecidos como **complementos gerenciados e opcionais**. Eles se conectam ao app pelo protocolo `CloudExtensionProvider` (em `Sources/MyBetterLifeCore/Extensions/`). Sem nenhum complemento instalado, o app usa o modo local padrão e não faz nenhuma chamada de rede além da verificação de atualizações.

---

## Estrutura

```
App/                      # Entrada do app multiplataforma (Xcode), Info.plist e ícones
Sources/MyBetterLifeCore/ # Modelos, persistência Core Data, engines, perfil local e atualizações
Sources/MyBetterLifeUI/   # Interface SwiftUI (Agenda, Notas, Insights, Configurações)
Sources/MyBetterLifeMacApp/ # Executável macOS para `swift run` / `make app`
Tests/                    # Testes unitários (Swift Testing)
web/                      # Landing page e portal de documentação (Next.js)
```

## Licença

[MIT](LICENSE) © 2026 Igor Donatti
