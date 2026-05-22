# Atualização do Design da Homepage — 2026-03-29

## Objetivo

Atualizar a homepage Astro (`homepage/`) para refletir os recursos adicionados nas releases v1.2.0, v1.3.0 e v2.0.0. A estrutura/layout do README e da homepage permanecem inalterados.

## Escopo

Três áreas a atualizar:

### 1. Seção de Features — Expandir de 3 para 6 Cards

Atual (3 cards):
- Interactive Knowledge Graph
- Plain-English Summaries
- Guided Tours

Atualizado (6 cards, 2 linhas de 3):

| # | Título | Ícone | Descrição |
|---|-------|------|-------------|
| 1 | Interactive Knowledge Graph | `◈` | Visualize arquivos, funções e dependências como um grafo explorável com drill-down hierárquico e layout inteligente. |
| 2 | Beyond Code Analysis | `⬡` | Analise seu projeto inteiro — Dockerfiles, Terraform, SQL, Markdown e mais de 26 tipos de arquivo mapeados em um único grafo unificado. |
| 3 | Smart Filtering & Search | `⊘` | Filtre por tipo de nó, complexidade, camada ou categoria de aresta. Busca fuzzy e semântica para encontrar qualquer coisa instantaneamente. |
| 4 | Export & Share | `⎙` | Exporte seu knowledge graph como PNG, SVG ou JSON filtrado de alta qualidade — pronto para docs, apresentações ou análise adicional. |
| 5 | Dependency Path Finder | `⟿` | Encontre o caminho mais curto entre quaisquer dois componentes. Entenda como partes do seu sistema se conectam de relance. |
| 6 | Guided Tours & Onboarding | `⟐` | Walkthroughs gerados por IA que ensinam o codebase passo a passo, além de guias de onboarding para novos membros do time. |

### 2. Seção de Instalação

Atualizar a nota de "apenas Claude Code" para multi-plataforma:
- Antes: "Works with Claude Code — Anthropic's official CLI for Claude."
- Depois: "Works with Claude Code, Codex, OpenCode, Gemini CLI, and more."

### 3. Footer

Atualizar tagline:
- Antes: "Built as a Claude Code plugin"
- Depois: "Built for AI coding assistants"

## Arquivos a Modificar

- `homepage/src/components/Features.astro` — substituir 3 cards por 6
- `homepage/src/components/Install.astro` — atualizar nota de plataforma
- `homepage/src/components/Footer.astro` — atualizar tagline

## Fora do Escopo

- Atualizações no README.md
- Seção de showcase / screenshot
- Componente Nav
- Seção Hero
- Mudanças de layout / estrutura global de CSS
