# Suporte Multi-Plataforma para Skills — Design Simplificado

**Data**: 2026-03-18
**Status**: Aprovado
**Objetivo**: Fazer com que as skills do Understand-Anything funcionem em Codex, OpenClaw, OpenCode e Cursor sem nenhum passo de build — os mesmos arquivos em todos os lugares.

## Princípios de Design

Segue o padrão do [obra/superpowers](https://github.com/obra/superpowers):
1. **Mesmos arquivos, todas as plataformas** — sem markers de template, sem passo de build, sem variantes específicas por plataforma
2. **`model: inherit`** — agentes usam o modelo da sessão pai, tornando-os agnósticos de plataforma
3. **Instalação dirigida por IA** — arquivos `.{platform}/INSTALL.md` que o agente de IA lê e executa
4. **Skills self-contained** — templates de prompt do pipeline ficam dentro do diretório da skill, não em uma pasta `agents/` separada

## Mudança 1: Mover Agentes do Pipeline Para Dentro da Skill

Os 5 agentes do pipeline (project-scanner, file-analyzer, architecture-analyzer, tour-builder, graph-reviewer) são usados exclusivamente pela skill `/understand`. Eles se tornam templates de prompt co-localizados com a skill:

**Antes:**
```
agents/
  project-scanner.md          # agent definition
  file-analyzer.md
  architecture-analyzer.md
  tour-builder.md
  graph-reviewer.md
skills/understand/
  SKILL.md                    # dispatches named agents
```

**Depois:**
```
skills/understand/
  SKILL.md                           # dispatches subagents using templates
  project-scanner-prompt.md          # prompt template (no agent frontmatter)
  file-analyzer-prompt.md
  architecture-analyzer-prompt.md
  tour-builder-prompt.md
  graph-reviewer-prompt.md
```

Os arquivos de template de prompt mantêm o conteúdo completo de instruções mas removem o frontmatter de agente (`name`, `tools`, `model`). O dispatch do `SKILL.md` muda de "Dispatch the **project-scanner** agent" para "Dispatch a subagent using the template at `./project-scanner-prompt.md`".

### Custo de Contexto

Ler templates pela sessão principal adiciona ~11K tokens no total (~5,5% de um contexto de 200K). Isso é sequencial (um template por vez), e a compressão de contexto recupera o conteúdo anterior. Trade-off aceitável pela portabilidade.

## Mudança 2: Novo Agente Registrado — knowledge-graph-guide

Criar um agente reutilizável que qualquer skill ou usuário pode invocar para trabalhar com knowledge graphs:

```yaml
# agents/knowledge-graph-guide.md
---
name: knowledge-graph-guide
description: |
  Use this agent when users need help understanding, querying, or working
  with an Understand-Anything knowledge graph. Guides users through graph
  structure, node/edge relationships, layer architecture, tours, and
  dashboard usage.
model: inherit
---
```

Esse agente conhece:
- O schema JSON do KnowledgeGraph (nodes, edges, layers, tours)
- Os 5 tipos de nó e 18 tipos de edge
- Como navegar e consultar o grafo
- Como usar o dashboard interativo
- Como interpretar camadas arquiteturais e guided tours

## Mudança 3: Arquivos de Instalação por Plataforma

Cada plataforma ganha um `INSTALL.md` que o agente de IA pode buscar e seguir:

| Arquivo | Plataforma | Mecanismo de Instalação |
|------|----------|-------------------|
| `.codex/INSTALL.md` | Codex | `git clone` + symlink para `~/.agents/skills/` |
| `.opencode/INSTALL.md` | OpenCode | Plugin config em `opencode.json` |
| `.openclaw/INSTALL.md` | OpenClaw | `git clone` + symlink para `~/.openclaw/skills/` |
| `.cursor/INSTALL.md` | Cursor | `git clone` + symlink para `.cursor/plugins/` |

O usuário diz ao agente uma linha:
```
Fetch and follow instructions from https://raw.githubusercontent.com/Lum1104/Understand-Anything/refs/heads/main/understand-anything-plugin/.codex/INSTALL.md
```

O agente executa o clone + symlink/config automaticamente.

## Mudança 4: Atualização do README

Adicionar uma seção "Multi-Platform Installation" ao README.md com one-liner por plataforma.

## Resumo de Arquivos

| Ação | Arquivos |
|--------|-------|
| Deletar | `agents/project-scanner.md`, `agents/file-analyzer.md`, `agents/architecture-analyzer.md`, `agents/tour-builder.md`, `agents/graph-reviewer.md` |
| Criar | `skills/understand/project-scanner-prompt.md`, `skills/understand/file-analyzer-prompt.md`, `skills/understand/architecture-analyzer-prompt.md`, `skills/understand/tour-builder-prompt.md`, `skills/understand/graph-reviewer-prompt.md` |
| Criar | `agents/knowledge-graph-guide.md` |
| Criar | `.codex/INSTALL.md`, `.opencode/INSTALL.md`, `.openclaw/INSTALL.md`, `.cursor/INSTALL.md` |
| Modificar | `skills/understand/SKILL.md` (referências de dispatch) |
| Modificar | `README.md` (seção multi-plataforma) |

## O Que Não Precisamos

- ~~`platforms/platform-config.json`~~ — mesmos arquivos em todos os lugares
- ~~`platforms/build.mjs`~~ — sem passo de build
- ~~markers de template `{{MARKER}}`~~ — sem templating
- ~~`scripts/install-*.sh`~~ — agente de IA segue o INSTALL.md
- ~~`dist-platforms/`~~ — sem saída gerada

## Compatibilidade de Plataformas

| Plataforma | Método de Instalação | Descoberta de Agente | Descoberta de Skill |
|----------|---------------|-----------------|-----------------|
| Claude Code | Marketplace (existente) | diretório `agents/` | diretório `skills/` |
| Codex | INSTALL.md → symlink | N/A (templates dentro da skill) | `~/.agents/skills/` |
| OpenCode | INSTALL.md → plugin config | N/A (templates dentro da skill) | Plugin auto-registra |
| OpenClaw | INSTALL.md → symlink | N/A (templates dentro da skill) | `~/.openclaw/skills/` |
| Cursor | INSTALL.md → symlink | diretório `agents/` | `.cursor/plugins/` |
