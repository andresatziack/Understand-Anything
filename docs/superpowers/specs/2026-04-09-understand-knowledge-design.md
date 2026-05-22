# /understand-knowledge — Design do Plugin de Personal Knowledge Base

## Visão Geral

Uma nova skill `/understand-knowledge` dentro do plugin Understand Anything existente que aceita qualquer pasta de notas markdown e produz um knowledge graph interativo visualizado no dashboard existente.

Inspirado pelo padrão LLM Wiki de Andrej Karpathy — onde um LLM compila e mantém um wiki estruturado a partir de fontes brutas — este plugin vai além ao adicionar descoberta de relacionamentos tipados e visualização interativa de grafo que ferramentas como Obsidian e Logseq não conseguem fornecer.

### Objetivos

- Aceitar qualquer knowledge base baseada em markdown (Obsidian vault, Logseq graph, Dendron workspace, Foam, LLM wiki estilo Karpathy, Zettelkasten ou markdown puro)
- Auto-detectar o formato e adaptar o parsing
- Usar análise por LLM para descobrir relacionamentos implícitos além dos links explícitos
- Produzir um knowledge graph com nós e arestas tipados
- Visualizar no dashboard existente com layout, sidebar e modo de leitura específicos para knowledge

### Não-Objetivos

- Sync em tempo real com a ferramenta de knowledge base (Obsidian, Logseq, etc.)
- Substituir a ferramenta PKM existente do usuário — esta é uma camada de visualização/análise por cima
- Suportar formatos não-markdown (PDFs, bookmarks) na v1

---

## Extensões de Schema

### Novos Tipos de Nó (5)

Adicionados à union `NodeType` existente (atualmente 16 tipos):

```typescript
export type NodeType =
  // existing (16)
  | "file" | "function" | "class" | "module" | "concept"
  | "config" | "document" | "service" | "table" | "endpoint"
  | "pipeline" | "schema" | "resource"
  | "domain" | "flow" | "step"
  // knowledge (5 new → 21 total)
  | "article" | "entity" | "topic" | "claim" | "source";
```

| Tipo | O que representa | Exemplo |
|------|-------------------|---------|
| `article` | Uma página de wiki/nota — a unidade primária de conteúdo | "LLM Knowledge Bases.md" |
| `entity` | Uma coisa nomeada: pessoa, ferramenta, paper, org, projeto | "Andrej Karpathy", "Obsidian" |
| `topic` | Um cluster temático agrupando artigos relacionados | "Personal Knowledge Management" |
| `claim` | Uma asserção, insight ou takeaway específico | "RAG loses context at chunk boundaries" |
| `source` | Material bruto/de referência a partir do qual artigos são compilados | URL de paper, referência a PDF bruto |

### Novos Tipos de Aresta (6)

Adicionados à union `EdgeType` existente (atualmente 29 tipos):

```typescript
export type EdgeType =
  // existing (29)
  | ...
  // knowledge (6 new → 35 total)
  | "cites" | "contradicts" | "builds_on"
  | "exemplifies" | "categorized_under" | "authored_by";
```

| Tipo | Direção | Significado |
|------|-----------|---------|
| `cites` | article → source | Referencia ou se baseia em |
| `contradicts` | claim → claim | Conflita ou discorda de |
| `builds_on` | article → article | Estende, refina ou aprofunda |
| `exemplifies` | entity → concept/topic | É um exemplo concreto de |
| `categorized_under` | article/entity → topic | Pertence a este tema |
| `authored_by` | article → entity | Escrito ou criado por |

### Nova Interface de Metadata

```typescript
export interface KnowledgeMeta {
  format?: "obsidian" | "logseq" | "dendron" | "foam" | "karpathy" | "zettelkasten" | "plain";
  wikilinks?: string[];
  backlinks?: string[];
  frontmatter?: Record<string, unknown>;
  sourceUrl?: string;
  confidence?: number; // 0-1, for LLM-inferred relationships
}
```

Adicionada como um campo opcional em `GraphNode`:

```typescript
export interface GraphNode {
  // ...existing fields
  knowledgeMeta?: KnowledgeMeta;
}
```

### Flag de Kind no Nível do Grafo

```typescript
export interface KnowledgeGraph {
  version: string;
  kind: "codebase" | "knowledge"; // NEW
  project: ProjectMeta;
  nodes: GraphNode[];
  edges: GraphEdge[];
  layers: Layer[];
  tour: TourStep[];
}
```

O campo `kind` diz ao dashboard qual layout, sidebar e estilo visual usar. Por compatibilidade retroativa, grafos sem o campo `kind` defaultam para `"codebase"`.

---

## Detecção de Formato e Format Guides

### Lógica de Auto-Detecção

Escaneia o diretório alvo por arquivos/padrões de assinatura. Ordem de prioridade (primeiro match vence):

| Prioridade | Sinal | Formato Detectado |
|----------|--------|----------------|
| 1 | Diretório `.obsidian/` | Obsidian |
| 2 | Diretórios `logseq/` + `pages/` | Logseq |
| 3 | `.dendron.yml` ou `*.schema.yml` | Dendron |
| 4 | `.foam/` ou `.vscode/foam.json` | Foam |
| 5 | `raw/` + `wiki/` + `index.md` | Karpathy |
| 6 | `[[wikilinks]]` + prefixos de ID únicos em filenames | Zettelkasten |
| 7 | Fallback | Markdown puro |

### Format Guides

Localizados em `skills/understand-knowledge/formats/`. Cada guia diz aos agentes LLM como parsear aquele formato:

```
skills/understand-knowledge/
  SKILL.md
  formats/
    obsidian.md        — [[wikilinks]], [[note|alias]], [[note#heading]],
                         #tags, YAML frontmatter, .obsidian/ config,
                         dataview annotations, canvas files
    logseq.md          — block-based outliner, ((block-refs)),
                         journals/YYYY_MM_DD.md, pages/,
                         property:: value syntax, TODO/DONE states
    dendron.md         — dot-delimited hierarchy (a.b.c.md),
                         .schema.yml for structure validation,
                         cross-vault links, refactoring rules
    foam.md            — [[wikilinks]] + link reference definitions
                         at file bottom, .foam/config, placeholder links
    karpathy.md        — raw/ → wiki/ pipeline, index.md master map,
                         log.md append-only record, _meta/ state,
                         LLM-maintained cross-references
    zettelkasten.md    — atomic notes, unique ID prefixes (timestamps),
                         typed semantic links, one idea per note
    plain.md           — standard [markdown](links), folder hierarchy,
                         heading structure, no special conventions
```

Cada format guide cobre:
- Como parsear links (wikilinks vs padrão vs block refs)
- Onde a metadata vive (frontmatter vs propriedades inline vs propriedades de bloco)
- O que a estrutura de pastas significa (journals/ = notas diárias, pages/ = notas permanentes)
- Quais convenções respeitar vs o que inferir

### Processo de Autoria do Format Guide

Os format guides devem ser embasados em pesquisa. Durante a implementação, o agente que constrói cada format guide deve:
1. Ler a documentação oficial daquele formato (Obsidian Help, docs do Logseq, wiki do Dendron, docs do Foam, etc.)
2. Estudar exemplos do mundo real da estrutura daquele formato
3. Escrever o guia com base em comportamento verificado, não em suposições

---

## Pipeline de Agentes

```
knowledge-scanner → format-detector → article-analyzer → relationship-builder → graph-reviewer
```

### Definições dos Agentes

| Agente | Input | Output | Modelo |
|-------|-------|--------|-------|
| `knowledge-scanner` | Caminho do diretório alvo | Manifesto de arquivos: todos os `.md` com paths, tamanhos, preview das primeiras 20 linhas | `inherit` |
| `format-detector` | Manifesto de arquivos + estrutura de diretórios | Formato detectado + hints de parsing específicos do formato | `inherit` |
| `article-analyzer` | Arquivo `.md` individual + format guide | Nós por arquivo (article, entities, claims) + arestas explícitas (wikilinks, tags) | `inherit` |
| `relationship-builder` | Todos os resultados por arquivo | Arestas implícitas cross-arquivo (builds_on, contradicts, categorized_under) + clustering de tópicos + camadas | `inherit` |
| `graph-reviewer` | Grafo montado | Grafo validado — entidades dedupedadas, edge weights consistentes, detecção de órfãos | `inherit` |

### Diferenças-Chave em Relação ao Pipeline de Codebase

- **Sem tree-sitter** — o parsing de markdown é mais simples, em sua maioria regex + interpretação por LLM
- **format-detector** substitui a detecção de framework — escolhe o format guide certo
- **article-analyzer** substitui o file-analyzer — extrai conceitos de conhecimento em vez de estrutura de código
- **relationship-builder** é o step pesado de LLM — descobre conexões implícitas entre arquivos que links explícitos perdem
- **graph-reviewer** permanece similar — valida o grafo montado por consistência

### Arquivos Intermediários

Mesmo padrão da análise de codebase:

```
.understand-anything/intermediate/
  knowledge-manifest.json      — scanner output
  format-detection.json        — detected format + hints
  article-*.json               — per-file analysis
  relationships.json           — cross-file edges
  knowledge-graph.json         — final assembled graph
```

Os arquivos intermediários são limpos após a montagem do grafo (igual ao fluxo de codebase).

### Modo Incremental (`--ingest`)

Quando o usuário roda `/understand-knowledge --ingest path/to/new-source.md`:

1. **knowledge-scanner** — roda apenas no(s) novo(s) arquivo(s)
2. **format-detector** — pulado (formato já conhecido do scan inicial)
3. **article-analyzer** — processa apenas arquivos novos/alterados
4. **relationship-builder** — roda nos novos nós contra o grafo existente, encontra conexões com o que já está lá
5. **graph-reviewer** — valida o resultado mesclado

Os nós existentes são preservados; apenas nós/arestas novos são adicionados ou atualizados.

---

## Mudanças no Dashboard

Todas as mudanças têm escopo nos grafos com `"kind": "knowledge"`.

### Layout de Fluxo Vertical

- Default para layout vertical top-down (como a domain/business flow view existente)
- Tópicos no topo → artigos no meio → entities/claims/sources na base
- Lê como uma hierarquia de conhecimento: temas amplos descem para especificidades
- O usuário ainda pode trocar para layout horizontal ou force-directed via controles

### Sidebar de Knowledge

Substitui o NodeInfo quando um knowledge graph é carregado:

| Seleção | Sidebar Mostra |
|-----------|---------------|
| Nada selecionado | ProjectOverview: formato detectado, total de articles/entities/topics/claims/sources |
| Nó article | Título, resumo, tags, metadata do frontmatter, lista de backlinks (clicáveis), links de saída, tópicos relacionados |
| Nó entity | Nome, tipo (person/tool/paper/org), artigos que o mencionam, relacionamentos com outras entities |
| Nó topic | Descrição, artigos filhos, entities filhas, conexões cross-topic |
| Nó claim | Texto da asserção, artigos de suporte, claims contraditórios (se houver), score de confiança |
| Nó source | URL/path original, artigos que o citam, data de ingestão |

### Reading Mode

- Clicar em um nó article dispara um painel de leitura que sobe de baixo (mesmo padrão do code viewer overlay atual)
- Mostra o markdown compilado completo renderizado como HTML
- Inclui uma mini-sidebar de backlinks dentro do painel
- Clicar em um `[[wikilink]]` ou referência de entity no painel de leitura navega o grafo para aquele nó

### Estilo Visual de Nó

| Tipo de Nó | Forma | Cor de Destaque |
|-----------|-------|-------------|
| `article` | Retângulo arredondado | Âmbar quente |
| `entity` | Círculo | Azul suave |
| `topic` | Retângulo arredondado grande | Dourado esmaecido |
| `claim` | Diamante | Verde/vermelho dependendo de contradições |
| `source` | Quadrado pequeno | Cinza |

### Estilo Visual de Aresta

| Tipo de Aresta | Estilo |
|-----------|-------|
| `cites` | Linha tracejada |
| `contradicts` | Linha vermelha |
| `builds_on` | Sólida com seta |
| `categorized_under` | Cinza fina |
| `authored_by` | Pontilhada azul |
| `exemplifies` | Pontilhada verde |

---

## Interface da Skill

### Uso

```bash
# Full scan — first time or rescan
/understand-knowledge

# Point at a specific directory
/understand-knowledge path/to/my-notes

# Incremental ingest — add new sources to existing graph
/understand-knowledge --ingest path/to/new-note.md
/understand-knowledge --ingest path/to/new-folder/
```

### Comportamento

1. Auto-detecta o formato (Obsidian, Logseq, Karpathy, etc.)
2. Anuncia: "Detected Obsidian vault with 342 notes. Scanning..."
3. Roda o pipeline de agentes (scanner → detector → analyzer → relationship-builder → reviewer)
4. Escreve `knowledge-graph.json` em `.understand-anything/` com `"kind": "knowledge"`
5. Auto-dispara `/understand-dashboard` após a conclusão

### Estrutura de Arquivos

```
skills/understand-knowledge/
  SKILL.md                     — skill entry point, orchestration logic
  formats/
    obsidian.md
    logseq.md
    dendron.md
    foam.md
    karpathy.md
    zettelkasten.md
    plain.md
```

### Coexistência com `/understand`

- `/understand` produz grafos `"kind": "codebase"`
- `/understand-knowledge` produz grafos `"kind": "knowledge"`
- Ambos escrevem em `.understand-anything/knowledge-graph.json`
- Rodar um substitui o outro
- Para limitar a análise de knowledge a um subdiretório (ex: `docs/` dentro de um repo de código), use `/understand-knowledge path/to/docs`

---

## O Que Isto Habilita Que Nada Mais Habilita

| Ferramentas Existentes | Limitação | Nossa Vantagem |
|---------------|-----------|---------------|
| Graph view do Obsidian | Arestas não-tipadas — todos os links parecem iguais | Arestas tipadas: cites, contradicts, builds_on |
| Graph do Logseq | Mostra apenas links explícitos | LLM descobre relacionamentos implícitos |
| Todas as ferramentas de PKM | Apenas formato único | Suporte cross-format com auto-detecção |
| LLM Wiki do Karpathy | Wiki de texto plano, sem visualização | Dashboard de grafo interativo com tours guiados |
| Nenhuma | Sem tours de knowledge graph | Modo tour percorre uma knowledge base passo a passo |
