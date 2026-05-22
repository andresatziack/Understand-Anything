# Understand Anything — Plano de Design e Implementação

## Contexto

Ferramentas de IA para programação tornaram a escrita de código fácil, mas entender código continua difícil. Desenvolvedores juniores, não-programadores (PMs, designers) e até mesmo devs experientes trabalhando em linguagens não familiares têm dificuldade para compreender codebases que não escreveram — ou que a IA escreveu para eles. A única entidade que "entende" o código é a própria IA.

**Understand Anything** preenche essa lacuna: uma ferramenta open-source que combina inteligência de LLM com análise estática para produzir um dashboard interativo e multi-persona para entender qualquer codebase. Ela roda como uma skill do Claude Code (aproveitando a sessão ativa) e serve um dashboard web rico.

---

## Arquitetura: Monorepo com Core Compartilhado

```
understand-anything/
├── packages/
│   ├── core/              # Shared analysis engine
│   │   ├── analyzer/      # LLM + tree-sitter analysis
│   │   ├── graph/         # Knowledge graph builder & schema
│   │   ├── plugins/       # Plugin system for language analyzers
│   │   └── persistence/   # JSON read/write, staleness detection
│   ├── skill/             # Claude Code skill (5 commands)
│   └── dashboard/         # React + TypeScript multi-panel workspace
├── plugins/               # Built-in language analyzer plugins
│   └── tree-sitter/       # Tree-sitter based multi-language analyzer
├── docs/
│   └── plans/
├── package.json           # Monorepo root (pnpm workspaces)
├── tsconfig.json
└── .gitignore
```

**Decisões-chave:**
- **Monorepo** (pnpm workspaces) — skill e dashboard compartilham o engine de análise core
- **Intercâmbio JSON** — o knowledge graph é um arquivo JSON, legível tanto pela skill quanto pelo dashboard
- **Commitável + auto-sync** — o grafo persiste em `.understand-anything/`, pode ser commitado no git, auto-detecta staleness via git diff

---

## Schema do Knowledge Graph

```typescript
interface KnowledgeGraph {
  version: string;
  project: ProjectMeta;
  nodes: GraphNode[];
  edges: GraphEdge[];
  layers: Layer[];
  tour: TourStep[];
}

interface ProjectMeta {
  name: string;
  languages: string[];
  frameworks: string[];
  description: string;           // LLM-generated project summary
  analyzedAt: string;            // ISO timestamp
  gitCommitHash: string;         // For staleness detection
}

interface GraphNode {
  id: string;
  type: "file" | "function" | "class" | "module" | "concept";
  name: string;
  filePath?: string;
  lineRange?: [number, number];
  summary: string;               // Plain-English description
  tags: string[];                // Searchable tags
  complexity: "simple" | "moderate" | "complex";
  languageNotes?: string;        // Language-specific explanations
}

interface GraphEdge {
  source: string;
  target: string;
  type: EdgeType;
  direction: "forward" | "backward" | "bidirectional";
  description?: string;
  weight: number;                // 0-1 importance
}

type EdgeType =
  // Structural
  | "imports" | "exports" | "contains" | "inherits" | "implements"
  // Behavioral
  | "calls" | "subscribes" | "publishes" | "middleware"
  // Data flow
  | "reads_from" | "writes_to" | "transforms" | "validates"
  // Dependencies
  | "depends_on" | "tested_by" | "configures"
  // Semantic
  | "related" | "similar_to";

interface Layer {
  id: string;
  name: string;                  // e.g., "API Layer", "Data Layer"
  description: string;
  nodeIds: string[];
}

interface TourStep {
  order: number;
  title: string;
  description: string;           // Markdown explanation
  nodeIds: string[];             // Nodes to highlight
  languageLesson?: string;       // Optional language concept explanation
}
```

---

## Dashboard: Workspace Multi-Painel (React + TypeScript)

```
┌─────────────────────────────────────────────────────────┐
│  🔍 Natural Language Search: "communication layer"      │
├──────────────────────┬──────────────────────────────────┤
│                      │                                  │
│   GRAPH VIEW         │   CODE VIEWER                    │
│   (React Flow)       │   (Monaco Editor, read-only)     │
│                      │                                  │
│   Interactive node   │   Source code + syntax highlight  │
│   graph. Click to    │   LLM annotations inline.        │
│   select. Search     │                                  │
│   highlights.        │                                  │
├──────────────────────┼──────────────────────────────────┤
│                      │                                  │
│   CHAT PANEL         │   LEARN PANEL                    │
│                      │                                  │
│   Context-aware Q&A  │   Tour mode + Contextual mode    │
│   about selected     │   Language lessons in context     │
│   nodes / project.   │   of YOUR code.                  │
│                      │                                  │
└──────────────────────┴──────────────────────────────────┘
```

**Stack técnica:**
- React 18 + TypeScript + Vite
- React Flow — visualização de grafo (feito para grafos de nós, melhor que D3 puro para isso)
- Monaco Editor — code viewer com syntax highlighting (o mesmo do VS Code)
- TailwindCSS — estilização
- Zustand — gerenciamento de estado (leve, sem boilerplate)

**Modos de persona:**
- Não-técnico: nós conceituais de alto nível, code viewer escondido, learn panel expandido
- Junior dev: todos os painéis, learn panel proeminente, indicadores de complexidade
- Dev experiente: code viewer proeminente, chat panel para deep dives

**Busca em linguagem natural:**
- Pesquisa contra os campos `tags`, `summary` e `name` dos nós
- Usa similaridade por embedding se disponível, com fallback para keyword matching
- Destaca nós correspondentes no grafo, filtra a lista

---

## Comandos da Skill do Claude Code

| Comando | Descrição |
|---------|-------------|
| `/understand` | Análise completa (ou atualização incremental se o grafo já existir) + abre o dashboard |
| `/understand-chat "<query>"` | Q&A no terminal usando o knowledge graph |
| `/understand-diff` | Analisa o PR/diff atual — explica mudanças, áreas afetadas, riscos |
| `/understand-explain <path>` | Explicação aprofundada de um arquivo ou função específica |
| `/understand-onboard` | Gera um guia estruturado de onboarding para novos membros do time |

**Estratégia de LLM:**
- Dentro do Claude Code → usa a sessão ativa do Claude (custo extra zero)
- Dashboard standalone → usuários fornecem chave da Claude API para recursos de chat
- Navegação no grafo, busca e modo learn funcionam offline (dados pré-gerados)

---

## Persistência e Detecção de Staleness

```
.understand-anything/
├── knowledge-graph.json       # The full graph (committable)
├── meta.json                  # Analysis metadata
│   {
│     "lastAnalyzedAt": "2026-03-14T...",
│     "gitCommitHash": "abc123",
│     "version": "1.0.0",
│     "analyzedFiles": 47
│   }
├── cache/                     # Per-file analysis cache
│   ├── src__index.ts.json
│   └── src__auth__login.ts.json
└── tours/
    └── default-tour.json
```

**Fluxo de auto-sync:**
1. Skill inicia → lê `meta.json` → obtém o último hash de commit analisado
2. Roda `git diff <last-hash>..HEAD --name-only` → obtém arquivos alterados
3. Se nenhuma mudança → serve o grafo existente
4. Se houver mudanças → re-analisa apenas os arquivos alterados → faz merge no grafo existente → atualiza meta

---

## Sistema de Plugins

```typescript
interface AnalyzerPlugin {
  name: string;
  languages: string[];
  analyzeFile(filePath: string, content: string): StructuralAnalysis;
  resolveImports(filePath: string, content: string): ImportResolution[];
  extractCallGraph?(filePath: string, content: string): CallGraphEntry[];
}
```

**Dia 1: plugin tree-sitter** — usa `node-tree-sitter` com gramáticas de linguagens para:
- TypeScript/JavaScript, Python, Go, Java, Rust, C/C++
- Extrai: limites de função/classe, statements de import/export, call sites
- Combinado com análise de LLM para entendimento semântico

**Futuro: plugins da comunidade** para análise profunda específica de cada linguagem.

---

## Fases de Implementação

### Fase 1: Fundação (MVP)
1. Scaffolding do projeto — monorepo, config TypeScript, setup de build
2. Core: Schema do knowledge graph + persistência JSON
3. Core: Engine de análise por LLM (análise arquivo a arquivo usando prompts)
4. Core: Integração com tree-sitter para análise estrutural
5. Skill: comando `/understand` — analisa + persiste o grafo
6. Dashboard: app React básico que lê e renderiza o grafo
7. Dashboard: graph view com React Flow
8. Dashboard: code viewer com Monaco Editor

### Fase 2: Inteligência
9. Busca em linguagem natural pelos nós do grafo
10. Skill: `/understand-chat` — Q&A no terminal
11. Dashboard: chat panel com Q&A context-aware
12. Detecção de staleness + atualizações incrementais
13. Auto-detecção de camadas (agrupar nós em camadas lógicas)

### Fase 3: Modo Learn
14. Geração de tour — walkthrough guiado do projeto
15. Explicações contextuais — clique para explicar
16. Lições específicas de linguagem no contexto do código do usuário
17. Modos de persona (não-técnico / junior / experiente)

### Fase 4: Avançado
18. Skill: `/understand-diff` — análise de PR/diff
19. Skill: `/understand-explain` — deep-dive em arquivos específicos
20. Skill: `/understand-onboard` — geração de guia de onboarding
21. Sistema de plugins da comunidade
22. Busca semântica baseada em embeddings (melhoria opcional)

---

## Verificação

### Como testar end-to-end:
1. **Análise da skill**: Rode `/understand` em um projeto de exemplo → verifique se `.understand-anything/knowledge-graph.json` é gerado com o schema correto
2. **Atualização incremental**: Modifique um arquivo → rode `/understand` novamente → verifique que apenas o arquivo alterado é re-analisado
3. **Dashboard**: Abra `http://localhost:5173` → verifique que o grafo renderiza, os nós são clicáveis, a busca funciona
4. **Chat**: Faça uma pergunta no chat panel → verifique que retorna uma resposta relevante usando o knowledge graph
5. **Modo learn**: Inicie o tour → verifique que ele percorre o projeto passo a passo
6. **Tree-sitter**: Analise um arquivo TypeScript → verifique que limites de função e relações de import batem com o código real

### Projetos de teste para validar:
- Um projeto pequeno em TypeScript (a própria ferramenta)
- Uma API Python Flask/Django
- Um microsserviço em Go
- Um monorepo com múltiplas linguagens
