<h1 align="center">Understand Anything</h1>

<p align="center">
  <strong>Transforme qualquer codebase, knowledge base ou documentação em um knowledge graph interativo que você pode explorar, pesquisar e perguntar.</strong>
  <br />
  <em>Compatível com Claude Code, Codex, Cursor, Copilot, Gemini CLI e muitos outros.</em>
</p>

<p align="center">
  <a href="../README.md">English</a> | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ja-JP.md">日本語</a> | <a href="README.ko-KR.md">한국어</a> | <a href="README.es-ES.md">Español</a> | <a href="README.tr-TR.md">Türkçe</a> | <a href="README.ru-RU.md">Русский</a> | <a href="README.pt-BR.md">Português (Brasil)</a>
</p>

<p align="center">
  <a href="#-início-rápido"><img src="https://img.shields.io/badge/Início_Rápido-blue" alt="Início Rápido" /></a>
  <a href="https://github.com/Lum1104/Understand-Anything/blob/main/LICENSE"><img src="https://img.shields.io/badge/Licença-MIT-yellow" alt="Licença: MIT" /></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-8A2BE2" alt="Claude Code" /></a>
  <a href="#codex"><img src="https://img.shields.io/badge/Codex-000000" alt="Codex" /></a>
  <a href="#vs-code--github-copilot"><img src="https://img.shields.io/badge/Copilot-24292e" alt="Copilot" /></a>
  <a href="#copilot-cli"><img src="https://img.shields.io/badge/Copilot_CLI-24292e" alt="Copilot CLI" /></a>
  <a href="#gemini-cli"><img src="https://img.shields.io/badge/Gemini_CLI-4285F4" alt="Gemini CLI" /></a>
  <a href="#opencode"><img src="https://img.shields.io/badge/OpenCode-38bdf8" alt="OpenCode" /></a>
  <a href="#mistral-vibe-cli"><img src="https://img.shields.io/badge/Vibe_CLI-7c3aed" alt="Vibe CLI" /></a>
  <a href="#kiro"><img src="https://img.shields.io/badge/Kiro-d4a574" alt="Kiro" /></a>
  <a href="https://understand-anything.com"><img src="https://img.shields.io/badge/Página_Inicial-d4a574" alt="Página Inicial" /></a>
  <a href="https://understand-anything.com/demo/"><img src="https://img.shields.io/badge/Demo_Online-00c853" alt="Demo Online" /></a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Understand Anything — transforme qualquer codebase em um knowledge graph interativo" width="800" />
</p>

<p align="center">
  <strong>💬 <a href="https://discord.gg/pydat66RY">Entre na comunidade no Discord &rarr;</a></strong>
  <br />
  <em>Tire dúvidas, mostre o que você está construindo e troque ideia com a comunidade.</em>
</p>

---

**Você acabou de entrar em um time novo. A codebase tem 200 mil linhas. Por onde começar?**

O Understand Anything é um [Claude Code Plugin](https://code.claude.com/docs/en/plugins-reference#plugins-reference) que analisa o seu projeto com um pipeline multi-agente, monta um knowledge graph com cada arquivo, função, classe e dependência, e ainda entrega um dashboard interativo para você explorar tudo isso visualmente. Pare de ler código no escuro. Comece a enxergar o todo.

> **A meta não é um grafo que impressiona pela complexidade do seu codebase — é um grafo que, em silêncio, ensina como cada peça se encaixa.**

---

## ✨ Funcionalidades

> [!NOTE]
> **Sem paciência para ler?** Experimente a [demo online](https://understand-anything.com/demo/) na nossa [página inicial](https://understand-anything.com/) — um dashboard totalmente interativo que você pode arrastar, ampliar, pesquisar e explorar direto no navegador.

### Explore o grafo estrutural

Navegue pelo seu codebase como um knowledge graph interativo: cada arquivo, função e classe vira um node clicável, pesquisável e explorável. Selecione qualquer node para ver resumos em linguagem natural, relacionamentos e tours guiados.

### Entenda a lógica de negócio

Mude para a visualização de domínio e veja como o seu código se conecta com os processos de negócio reais — domínios, fluxos e etapas dispostos em um grafo horizontal.

### Analise knowledge bases

Aponte o `/understand-knowledge` para uma [LLM wiki no padrão Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) e receba um knowledge graph com layout force-directed e clustering por comunidade. Um parser determinístico extrai os wikilinks e categorias do `index.md`, e os agentes LLM cuidam do resto: descobrem relações implícitas, extraem entidades e expõem afirmações — transformando a sua wiki em um grafo navegável de ideias interconectadas.

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🧭 Tours Guiados</h3>
      <p>Walkthroughs gerados automaticamente pela arquitetura, ordenados por dependência. Aprenda o codebase na ordem certa.</p>
    </td>
    <td width="50%" valign="top">
      <h3>🔍 Busca Fuzzy e Semântica</h3>
      <p>Encontre qualquer coisa por nome ou por significado. Pesquise "quais partes lidam com auth?" e receba resultados relevantes em todo o grafo.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Análise de Impacto de Diff</h3>
      <p>Veja quais partes do sistema serão afetadas pelas suas alterações antes do commit. Antecipe os efeitos colaterais em todo o codebase.</p>
    </td>
    <td width="50%" valign="top">
      <h3>🎭 UI Adaptada por Persona</h3>
      <p>O dashboard ajusta o nível de detalhe ao seu perfil — dev júnior, PM ou power user.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🏗️ Visualização por Camadas</h3>
      <p>Agrupamento automático por camada arquitetural — API, Service, Data, UI, Utility — com legenda colorida.</p>
    </td>
    <td width="50%" valign="top">
      <h3>📚 Conceitos de Linguagem</h3>
      <p>12 padrões de programação (generics, closures, decorators, etc.) explicados em contexto, onde quer que apareçam.</p>
    </td>
  </tr>
</table>

---

## 🚀 Início Rápido

### 1. Instale o plugin

```bash
/plugin marketplace add Lum1104/Understand-Anything
/plugin install understand-anything
```

### 2. Analise o seu codebase

```bash
/understand
```

Um pipeline multi-agente varre o seu projeto, extrai cada arquivo, função, classe e dependência, e em seguida monta o knowledge graph salvo em `.understand-anything/knowledge-graph.json`.

**Saída localizada:** use `--language` para gerar conteúdo no idioma da sua preferência:

```bash
# Gerar conteúdo em chinês (descrições dos nodes do knowledge graph e UI do Dashboard)
/understand --language zh

# Idiomas suportados: en (padrão), zh, zh-TW, ja, ko, ru, pt-BR
```

O parâmetro `--language` afeta:
- Resumos e descrições dos nodes no knowledge graph
- Labels, botões e tooltips da UI do dashboard
- Explicações dos tours guiados

### 3. Abra o dashboard

```bash
/understand-dashboard
```

Um dashboard web interativo abre com o seu codebase visualizado como um grafo — colorido por camada arquitetural, pesquisável e clicável. Selecione qualquer node para ver o código, os relacionamentos e uma explicação em linguagem natural.

### 4. Continue aprendendo

```bash
# Pergunte qualquer coisa sobre o codebase
/understand-chat How does the payment flow work?

# Analise o impacto das suas alterações atuais
/understand-diff

# Entre fundo em um arquivo ou função específica
/understand-explain src/auth/login.ts

# Gere um guia de onboarding para novos integrantes do time
/understand-onboard

# Extraia o conhecimento de domínio de negócio (domínios, fluxos, etapas)
/understand-domain

# Analise uma knowledge base no padrão Karpathy de LLM wiki
/understand-knowledge ~/path/to/wiki
```

---

## 🌐 Instalação Multi-Plataforma

O Understand-Anything funciona em várias plataformas de coding com IA.

### Claude Code (nativo)

```bash
/plugin marketplace add Lum1104/Understand-Anything
/plugin install understand-anything
```

### Instalação com uma linha (Codex / OpenCode / OpenClaw / Antigravity / Gemini CLI / Pi Agent / Vibe CLI / VS Code Copilot / Hermes / Cline / KIMI CLI / Kiro)

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/Lum1104/Understand-Anything/main/install.sh | bash
# ou pule o prompt informando a plataforma direto:
curl -fsSL https://raw.githubusercontent.com/Lum1104/Understand-Anything/main/install.sh | bash -s codex
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/Lum1104/Understand-Anything/main/install.ps1 | iex
```

O instalador clona o repositório em `~/.understand-anything/repo` e cria os symlinks certos para a plataforma escolhida. Reinicie a CLI ou o IDE depois.

- Valores aceitos para `<platform>`: `gemini`, `codex`, `opencode`, `pi`, `openclaw`, `antigravity`, `vibe`, `vscode`, `hermes`, `cline`, `kimi`, `kiro`
- Atualizar depois: `./install.sh --update`
- Desinstalar: `./install.sh --uninstall <platform>`

### Cursor

O Cursor descobre o plugin automaticamente via `.cursor-plugin/plugin.json` quando este repositório é clonado. Não precisa de instalação manual — basta clonar e abrir no Cursor.

### VS Code + GitHub Copilot

O VS Code com GitHub Copilot (v1.108+) descobre o plugin automaticamente via `.copilot-plugin/plugin.json` quando este repositório é clonado. Não precisa de instalação manual — basta clonar e abrir no VS Code.

Para instalar como skills pessoais (disponíveis em todos os projetos), rode o `install.sh` acima com a plataforma `vscode`.

### Kiro

O Kiro é o IDE/agente de IA da AWS, que lê arquivos `.kiro/steering/*.md` como contexto persistente. Há duas formas de usar o Understand Anything no Kiro:

1. **Auto-discovery (por repositório).** Clone este repositório e abra no Kiro. Ele detecta o `.kiro-plugin/plugin.json` (skills + agents) e o steering file em `.kiro/steering/understand-anything.md` (lido pelo escopo padrão de steering do Kiro) automaticamente.
2. **Instalação global (todos os projetos).** Rode `./install.sh kiro` (ou `./install.ps1 kiro` no Windows). O instalador cria links de cada skill em `~/.kiro/skills/` e copia o steering file para `~/.kiro/steering/understand-anything.md`, de modo que qualquer sessão do Kiro saiba como invocar cada slash command.

> [!IMPORTANT]
> **Limite de confiança.** O steering file molda como o agente interpreta os prompts antes mesmo de você digitar qualquer coisa. A instalação via curl-pipe (`curl -fsSL ... | bash -s kiro`) escreve as skills **e** esse arquivo de comportamento no seu diretório home sem nenhuma verificação de integridade (sem checksum, sem assinatura, sem pin de versão). Para ambientes de maior confiança, prefira o fluxo clone-then-`./install.sh kiro` — assim você pode revisar `.kiro/steering/understand-anything.md` antes que ele seja copiado para `~/.kiro/steering/`.

Dica: veja [`docs/kiro-integration.md`](../docs/kiro-integration.md) para um guia mais detalhado (saída em PT-BR, troubleshooting, desinstalação).

### Copilot CLI

```bash
copilot plugin install Lum1104/Understand-Anything:understand-anything-plugin
```

### Compatibilidade entre Plataformas

| Plataforma | Status | Forma de Instalação |
|----------|--------|----------------|
| Claude Code | ✅ Nativo | Plugin marketplace |
| Cursor | ✅ Suportado | Auto-discovery |
| VS Code + GitHub Copilot | ✅ Suportado | Auto-discovery |
| Copilot CLI | ✅ Suportado | Plugin install |
| Codex | ✅ Suportado | `install.sh codex` |
| OpenCode | ✅ Suportado | `install.sh opencode` |
| OpenClaw | ✅ Suportado | `install.sh openclaw` |
| Antigravity | ✅ Suportado | `install.sh antigravity` |
| Gemini CLI | ✅ Suportado | `install.sh gemini` |
| Pi Agent | ✅ Suportado | `install.sh pi` |
| Vibe CLI | ✅ Suportado | `install.sh vibe` |
| Hermes | ✅ Suportado | `install.sh hermes` |
| Cline | ✅ Suportado | `install.sh cline` |
| KIMI CLI | ✅ Suportado | `install.sh kimi` |
| Kiro | ✅ Suportado | Auto-discovery / `install.sh kiro` |

---

## 📦 Compartilhe o Grafo com o seu Time

O grafo é apenas JSON — **comite uma vez e os colegas pulam o pipeline inteiro**. Excelente para onboarding, revisão de pull request e docs-as-code.

> **Exemplo:** [GoogleCloudPlatform/microservices-demo (fork)](https://github.com/Lum1104/microservices-demo) — referência em Go / Java / Python / Node com o grafo já comitado.

**O que comitar:** tudo dentro de `.understand-anything/`, *exceto* `intermediate/` e `diff-overlay.json` (esses dois são scratch local).

```gitignore
.understand-anything/intermediate/
.understand-anything/diff-overlay.json
```

**Mantenha atualizado:** habilite `/understand --auto-update` — um post-commit hook aplica patches incrementais no grafo, e cada commit chega já com um grafo correspondente. Ou rode `/understand` manualmente antes dos releases.

**Grafos grandes (10 MB+):** versione com **git-lfs**.

```bash
git lfs install
git lfs track ".understand-anything/*.json"
git add .gitattributes .understand-anything/
```

---

## 🔧 Por Baixo dos Panos

### Pipeline Multi-Agente

O comando `/understand` orquestra 5 agentes especializados, e o `/understand-domain` adiciona um sexto:

| Agente | Papel |
|-------|------|
| `project-scanner` | Descobre arquivos, detecta linguagens e frameworks |
| `file-analyzer` | Extrai funções, classes, imports; produz nodes e edges do grafo |
| `architecture-analyzer` | Identifica camadas arquiteturais |
| `tour-builder` | Gera tours de aprendizagem guiados |
| `graph-reviewer` | Valida a completude do grafo e a integridade referencial (roda inline por padrão; use `--review` para uma revisão completa por LLM) |
| `domain-analyzer` | Extrai domínios de negócio, fluxos e etapas de processo (usado por `/understand-domain`) |
| `article-analyzer` | Extrai entidades, afirmações e relações implícitas dos artigos da wiki (usado por `/understand-knowledge`) |

Os file analyzers rodam em paralelo (até 5 simultâneos, lotes de 20–30 arquivos). Suporta atualizações incrementais — só reanalisa os arquivos que mudaram desde a última execução.

---

## 🎥 Comunidade

Walkthrough produzido pela comunidade pelo pessoal da **Better Stack**.

<p align="center">
  <a href="https://www.youtube.com/watch?v=VmIUXVlt7_I"><img src="https://img.youtube.com/vi/VmIUXVlt7_I/maxresdefault.jpg" alt="Walkthrough da comunidade pela Better Stack — assista no YouTube" width="480" /></a>
  <br />
  <em><a href="https://www.youtube.com/watch?v=VmIUXVlt7_I">Assista no YouTube &rarr;</a></em>
</p>

Fez um vídeo, post ou tutorial? Abra uma issue ou um pull request — vamos adorar destacar aqui.

---

## 🤝 Contribuindo

Contribuições são muito bem-vindas! Para começar:

1. Faça o fork do repositório
2. Crie um branch de feature (`git checkout -b feature/my-feature`)
3. Rode os testes (`pnpm --filter @understand-anything/core test`)
4. Faça o commit das suas alterações e abra um pull request

Para mudanças grandes, abra uma issue antes para discutirmos a abordagem.

---

<p align="center">
  <strong>Pare de ler código no escuro. Comece a entender tudo.</strong>
</p>

## Histórico de Stars

<a href="https://www.star-history.com/?repos=Lum1104%2FUnderstand-Anything&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=Lum1104/Understand-Anything&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=Lum1104/Understand-Anything&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=Lum1104/Understand-Anything&type=date&legend=top-left" />
 </picture>
</a>

<p align="center">
  <em>Obrigado a todo mundo que usou e contribuiu — saber que isso poupa tempo das pessoas é o que fez valer a pena construir.</em>
</p>

<p align="center">
  Licença MIT &copy; <a href="https://github.com/Lum1104">Lum1104</a>
</p>
