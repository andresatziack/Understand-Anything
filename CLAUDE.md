# Understand Anything

## Visão Geral do Projeto
Uma ferramenta open-source que combina inteligência de LLM com análise estática para gerar dashboards interativos voltados a entender codebases.

## Pré-requisitos
- Node.js >= 22 (desenvolvido na v24)
- pnpm >= 10 (fixado pelo campo `packageManager` no `package.json` da raiz)

## Arquitetura
- **Monorepo** com pnpm workspaces
- **understand-anything-plugin/** — plugin do Claude Code com todo o código-fonte:
  - **packages/core** — engine de análise compartilhada (types, persistence, tree-sitter, search, schema, tours, plugins)
  - **packages/dashboard** — dashboard web em React + TypeScript (React Flow, Zustand, TailwindCSS v4)
  - **src/** — fonte TypeScript das skills `/understand-chat`, `/understand-diff`, `/understand-explain`, `/understand-onboard`
  - **skills/** — definições de skill (`/understand`, `/understand-dashboard`, etc.)
  - **agents/** — definições de agentes (project-scanner, file-analyzer, architecture-analyzer, tour-builder, graph-reviewer)

## Dashboard
- Tema dark luxury: pretos profundos (#0a0a0a), tons de dourado/âmbar (#d4a574), tipografia DM Serif Display
- Layout focado no grafo: 75% de grafo + sidebar direita de 360px
- Sem ChatPanel ou Monaco Editor
- Abas da sidebar: `Info` (ProjectOverview por padrão → NodeInfo quando um node é selecionado → LearnPanel na persona Learn, composing) e `Files` (FileExplorer em árvore montada a partir do grafo estrutural)
- Visualizador de código: source viewer baseado em prism-react-renderer que sobe a partir do rodapé ao clicar em um node de arquivo; um botão de expandir promove o viewer para um modal em tela cheia. O conteúdo do arquivo vem do endpoint `/file-content.json` do dev server, protegido por access token e por uma allowlist de paths derivada do grafo
- Validação de schema ao carregar o grafo, com banner de erro

## Pipeline de Agentes
- Os agentes gravam resultados intermediários em disco no diretório `.understand-anything/intermediate/` (esses resultados não voltam ao contexto)
- Modelos dos agentes: todos definidos como `inherit` para compatibilidade entre plataformas (Claude Code, Cursor, opencode, etc.)
- `/understand` dispara automaticamente `/understand-dashboard` ao terminar
- Os arquivos intermediários são limpos depois que o grafo é montado

## Comandos Principais
- `pnpm install` — instala todas as dependências
- `pnpm --filter @understand-anything/core build` — faz o build do pacote core
- `pnpm --filter @understand-anything/core test` — roda os testes do core
- `pnpm --filter @understand-anything/skill build` — faz o build do pacote do plugin
- `pnpm --filter @understand-anything/skill test` — roda os testes do plugin
- `pnpm --filter @understand-anything/dashboard build` — faz o build do dashboard
- `pnpm dev:dashboard` — inicia o dev server do dashboard
- `pnpm lint` — roda o ESLint em todo o projeto

## Convenções
- TypeScript em strict mode em todo lugar
- Vitest para testes
- Módulos ESM (`"type": "module"`)
- O JSON do knowledge graph fica no diretório `.understand-anything/` dos projetos analisados
- O core usa subpath exports (`./search`, `./types`, `./schema`) para evitar puxar módulos do Node.js para o browser

## Pegadinhas
- **tree-sitter**: usa `web-tree-sitter` (WASM) em vez do `tree-sitter` nativo — os bindings nativos quebram em darwin/arm64 + Node 24
- **Imports do Dashboard**: o dashboard só pode importar dos subpath exports browser-safe do core (`./search`, `./types`, `./schema`), nunca pelo entry point principal, que arrasta módulos do Node.js junto

## Scripts
- `scripts/generate-large-graph.mjs` — gera um knowledge graph fictício para testes de performance (ex.: layout de grafos grandes). Escreve em `.understand-anything/knowledge-graph.json`. Uso: `node scripts/generate-large-graph.mjs [nodeCount]` (padrão: 3000 nodes). Não faz parte do pipeline de produção.

## Versionamento
Ao subir alterações para o remote, atualize a versão em **todos os cinco** arquivos abaixo (eles precisam permanecer em sincronia):
- `understand-anything-plugin/package.json` → campo `"version"`
- `understand-anything-plugin/.claude-plugin/plugin.json` → campo `"version"`
- `.claude-plugin/plugin.json` → campo `"version"`
- `.cursor-plugin/plugin.json` → campo `"version"`
- `.copilot-plugin/plugin.json` → campo `"version"`

Observação: `.claude-plugin/marketplace.json` **não** carrega versão — o entry em `plugins[]` aceita apenas `name` e `source`, e adicionar outros campos quebra a validação de schema do marketplace.

## Testando Alterações Locais do Plugin

O Claude Code mantém um cache dos plugins instalados em `~/.claude/plugins/cache/understand-anything/understand-anything/<version>/`. Symlinks não funcionam porque as ferramentas Search/Glob do Claude não conseguem segui-los. Para testar alterações locais:

1. **Faça o build dos pacotes:**
   ```bash
   pnpm --filter @understand-anything/core build
   pnpm --filter @understand-anything/skill build
   ```

2. **Descubra qual versão está instalada** (precisa bater com a que o marketplace serve no momento):
   ```bash
   ls ~/.claude/plugins/cache/understand-anything/understand-anything/
   ```

3. **Copie o seu plugin local para dentro do cache**, substituindo `<VERSION>` pela versão do passo 2:
   ```bash
   rm -rf ~/.claude/plugins/cache/understand-anything/understand-anything/<VERSION>
   cp -R ./understand-anything-plugin ~/.claude/plugins/cache/understand-anything/understand-anything/<VERSION>
   ```

4. **Inicie uma sessão nova do Claude Code** (sessões existentes mantêm os prompts antigos no contexto).

5. **Rode `/understand --full`** no projeto-alvo para validar.

**Re-sincronizar após novas alterações:**
```bash
pnpm --filter @understand-anything/core build && \
cp -R ./understand-anything-plugin/* ~/.claude/plugins/cache/understand-anything/understand-anything/<VERSION>/
```

**Para voltar ao upstream:** desinstale e reinstale o plugin pelo marketplace — ele repopula o cache a partir do repositório upstream.
