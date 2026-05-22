# Design de Redução de Tokens

**Data:** 2026-03-27
**Status:** Rascunho
**Objetivo:** Reduzir o custo total de tokens do `/understand` em ~85-90% em codebases grandes (200+ arquivos)

---

## Problema

Em codebases grandes, o pipeline `/understand` gasta a vasta maioria dos seus tokens em **injeção de contexto repetida**. Os mesmos dados são enviados para cada subagente independentemente, mesmo quando esses dados poderiam ser computados uma vez e compartilhados.

### Detalhamento do custo de tokens (projeto TypeScript+React de 500 arquivos, baseline)

| Origem | Fase | Tokens (input) | % do total |
|---|---|---|---|
| Lista `allProjectFiles` × 67 batches | Fase 2 | ~167,000 | ~50% |
| `file-analyzer-prompt.md` × 67 batches | Fase 2 | ~134,000 | ~40% |
| Adendos de linguagem/framework × 67 batches | Fase 2 | ~68,000 | ~20% |
| Payload do tour builder (todos os nós + arestas) | Fase 5 | ~80,000 | ~24% |
| Graph reviewer (grafo montado + inventário) | Fase 6 | ~58,000 | ~17% |
| Payload do architecture analyzer | Fase 4 | ~22,000 | ~7% |
| **Total** | | **~529,000** | |

A causa raiz: **a Fase 2 roda 67 batches (em 5-10 arquivos cada) e cada batch recebe a lista completa de 500 arquivos para resolução de imports.** Apenas a lista de arquivos custa ~2.500 tokens × 67 repetições = 167.000 tokens no input, fazendo um trabalho que é totalmente redundante entre batches.

---

## Objetivos

- Reduzir os tokens totais de input em 85%+ em um projeto de 500 arquivos
- Sem degradação na qualidade do grafo para projetos padrão
- Preservar as flags `--full` / incremental / scope
- Manter compatibilidade retroativa com o schema de saída existente do `knowledge-graph.json`

---

## Mudanças

Cinco mudanças compõem a abordagem completa (C1–C5). Cada uma é independente e pode ser shippada separadamente, mas todas as cinco são necessárias para a redução completa.

---

### C1 — Pré-resolver imports no project scanner

**Causa raiz endereçada:** `allProjectFiles` (a lista de arquivos inteira) é injetada em todo batch do file-analyzer apenas para que o script de extração de cada batch consiga resolver imports relativos. Isso é redundante: a lista completa de arquivos está disponível durante a Fase 1, e a resolução de imports é determinística. Ela deveria acontecer uma vez, não 67.

**Mudança:** Estender o script do scanner da Fase 1 para também parsear declarações de import de cada arquivo source e resolver imports relativos contra a lista de arquivos descobertos. Os resultados resolvidos são escritos em `scan-result.json` como um novo campo `importMap`. Os batches do file-analyzer recebem então apenas os imports pré-resolvidos do seu próprio batch — não a lista completa de arquivos.

#### Adição na saída do scanner

`scan-result.json` ganha:

```json
{
  "importMap": {
    "src/index.ts": ["src/utils.ts", "src/config.ts"],
    "src/utils.ts": [],
    "src/components/App.tsx": ["src/hooks/useAuth.ts", "src/store/index.ts"]
  }
}
```

- Chaves são caminhos relativos ao projeto (combinando com `files[*].path`)
- Valores são apenas caminhos resolvidos relativos ao projeto (imports externos/não resolvíveis são omitidos)
- Imports externos (`node_modules`, caminhos não resolvíveis) são excluídos do mapa por completo

#### Adições no script do scanner (Fase 1, Step 8)

Após os 7 steps existentes, o script do scanner adiciona um novo step:

```
Step 8 — Import Resolution

For each file in the discovered source list:
  1. Read the file content
  2. Extract import statements (language-specific patterns per Step 3's language detection):
     - TypeScript/JavaScript: `import ... from '...'`, `require('...')`
     - Python: `import ...`, `from ... import ...`
     - Go: `import "..."` blocks
     - Rust: `use ...` statements
     - Java/Kotlin: `import ...` statements
     - Ruby: `require`, `require_relative`
  3. For each relative import (starts with `./` or `../`):
     a. Compute the resolved path from the current file's directory
     b. Normalize to project-relative format
     c. Try common extension variants if the import has no extension:
        `.ts`, `.tsx`, `.js`, `.jsx`, `/index.ts`, `/index.js`, `/index.tsx`
     d. If any variant exists in the discovered file list, record it; otherwise skip
  4. For absolute imports (no `.` prefix): skip (external package)

Output the full importMap in the JSON result.
```

#### Mudança no schema de input do file-analyzer

**Antes:**
```json
{
  "projectRoot": "/path/to/project",
  "allProjectFiles": ["src/index.ts", "src/utils.ts", "...500 paths..."],
  "batchFiles": [
    {"path": "src/index.ts", "language": "typescript", "sizeLines": 150}
  ]
}
```

**Depois:**
```json
{
  "projectRoot": "/path/to/project",
  "batchFiles": [
    {"path": "src/index.ts", "language": "typescript", "sizeLines": 150}
  ],
  "batchImportData": {
    "src/index.ts": ["src/utils.ts", "src/config.ts"],
    "src/components/App.tsx": ["src/hooks/useAuth.ts"]
  }
}
```

`allProjectFiles` é removido por completo. `batchImportData` contém apenas os imports pré-resolvidos para os arquivos deste batch (fatiados do `importMap` pelo orquestrador).

#### Mudança no script de extração do file-analyzer

O script de extração não realiza mais resolução de imports. Ele:
- Continua extraindo: funções, classes, exports, métricas (inalterado)
- Para imports: lê `batchImportData[file.path]` do JSON de input — sem cross-referencing necessário
- O array `imports` em cada resultado de arquivo se torna: `batchImportData[file.path]` mapeado para objetos de aresta de import com `resolvedPath` já populado, `isExternal: false`

#### Mudança na Fase 2 do SKILL.md

Remover a injeção de `allProjectFiles` do prompt de dispatch do batch. Substituir por uma fatia de `batchImportData` por batch:

```
For each batch, slice importData from the importMap read in Phase 1:
batchImportData = { [file.path]: importMap[file.path] ?? [] }
  for each file in this batch
```

#### Estimativa de economia de tokens

| | Batches | Tokens/batch | Total |
|---|---|---|---|
| Antes | 67 | ~2,500 (lista de arquivos) | ~167,500 |
| Depois (C1 sozinho) | 67 | ~200 (batch importData) | ~13,400 |
| **Economia** | | | **~154,100** |

---

### C2 — Aumentar o tamanho do batch de 5-10 para 20-30 arquivos

**Causa raiz endereçada:** Cada batch incorre no custo total do `file-analyzer-prompt.md` (~2.000 tokens) mais o overhead do dispatch do batch. Com 67 batches, isso soma muito mesmo sem `allProjectFiles`. Menos batches, maiores, reduzem diretamente essa repetição.

**Mudança:** Na Fase 2 do SKILL.md, mudar a orientação de tamanho de batch:

- **Antes:** "Batch the file list from Phase 1 into groups of **5-10 files each**"
- **Depois:** "Batch the file list from Phase 1 into groups of **20-30 files each** (aim for ~25 per batch)"

Também atualizar o limite de concorrência de 3 para **5** batches concorrentes. Menos batches no total significa que podemos pagar por mais paralelismo sem sobrecarregar o sistema.

#### Trade-offs

| | Batches menores (atual) | Batches maiores (novo) |
|---|---|---|
| Arquivos por batch | 5-10 | 20-30 |
| Total de batches (500 arquivos) | ~67 | ~20 |
| Repetição de prompt | 67× | 20× |
| Risco de qualidade | Menor (focado) | Levemente maior (mais arquivos por subagente) |
| Concorrência | 3 | 5 |

O risco de qualidade é baixo: cada subagente ainda opera sobre grupos de arquivos distintos e não sobrepostos. O script de extração é determinístico independente do tamanho do batch. A análise semântica (resumos, tags) pode estar marginalmente menos focada, mas a diferença de qualidade é desprezível na prática para arquivos bem-estruturados.

#### Estimativa de economia de tokens (combinada com C1)

| | Batches | Tokens/batch (prompt) | Total |
|---|---|---|---|
| Antes (apenas C1) | 67 | ~2,000 | ~134,000 |
| Depois (C1+C2) | 20 | ~2,000 | ~40,000 |
| **Economia de C2** | | | **~94,000** |

C1+C2 combinados eliminam ~248.000 tokens da Fase 2 (de ~301.500 para ~53.500, uma redução de ~82% na Fase 2).

---

### C3 — Remover adendos de linguagem/framework dos batches do file-analyzer

**Causa raiz endereçada:** `languages/typescript.md` (~600 tokens) e `frameworks/react.md` (~700 tokens) são lidos e injetados em todo prompt de batch do file-analyzer. Para um projeto TypeScript+React com 20 batches (após C2), isso custa 20 × 1.300 = 26.000 tokens adicionais — e o modelo já tem conhecimento profundo dessas linguagens a partir do treinamento.

**Mudança:** Parar de injetar arquivos de adendo nos prompts dos batches da Fase 2 por completo. Os adendos permanecem injetados na Fase 4 (architecture analyzer), onde há apenas **uma** chamada de subagente, tornando o custo aceitável.

Em vez disso, adicionar uma seção compacta de "Language and Framework Hints" diretamente no `file-analyzer-prompt.md`. Essa seção é uma adição única e destilada (~150 tokens no total) que captura os padrões mais úteis de todos os adendos em uma tabela de lookup concisa.

#### Nova seção em `file-analyzer-prompt.md` (substituindo a injeção de adendos)

```markdown
## Language and Framework Quick Reference

Use these hints to improve tag and edge accuracy. These supplement your training knowledge.

| Signal | Tag(s) | Note |
|---|---|---|
| File in `hooks/`, exports function starting with `use` | `hook`, `service` | React custom hook |
| File in `contexts/`, exports a Provider | `service`, `state` | React context |
| File in `pages/` or `views/` | `ui`, `routing` | Page-level component |
| File in `store/`, `slices/`, `reducers/` | `state` | State management |
| File in `services/`, `api/` | `service` | Data-fetching / API client |
| `__init__.py` with re-exports | `entry-point`, `barrel` | Python package root |
| `manage.py` at project root | `entry-point` | Django management entry |
| File named `mod.rs` | `barrel` | Rust module barrel |
| File named `main.go` in `cmd/` | `entry-point` | Go binary entry |

For React: create `depends_on` edges from components to hooks they call. Create `publishes`/`subscribes` edges for Context provider/consumer patterns.
```

#### Mudança na Fase 2 do SKILL.md

Remover os passos 2 e 3 do bloco "Build the combined prompt template":
- **Remover:** Passo 2 (injeção de Language context — ler `./languages/<language-id>.md` por linguagem detectada)
- **Remover:** Passo 3 (injeção de adendo de Framework — ler `./frameworks/<framework-id>.md` por framework detectado)
- **Manter:** Passo 1 (Ler o template base em `./file-analyzer-prompt.md`)

Os passos de injeção de adendo **permanecem inalterados** na Fase 4 (architecture analyzer), já que rodam uma vez.

#### Estimativa de economia de tokens

| | Batches | Tokens de adendo/batch | Total |
|---|---|---|---|
| Antes (após C2) | 20 | ~1,300 (TS+React) | ~26,000 |
| Depois | 20 | ~150 (hints inline) | ~3,000 |
| **Economia** | | | **~23,000** |

---

### C4 — Enxugar os payloads das Fases 4 e 5

**Causa raiz endereçada:** A Fase 5 (tour builder) recebe todos os nós (file + function + class) e todas as arestas (imports + contains + calls + exports + ...). Para um projeto de 500 arquivos, isso pode incluir 1.500+ nós e 3.000+ arestas. A maior parte desses dados não é necessária para o design do tour.

#### Fase 4 (Architecture Analyzer) — corte menor

A Fase 4 já envia apenas nós do tipo file, o que está correto. Mudança menor: explicitamente remover `languageNotes` de cada objeto de nó no payload (não é útil para atribuição de camada e pode ser verboso). Também remover `name` — sempre derivável como o basename de `filePath`.

**Antes por nó:** `{id, name, filePath, summary, tags, complexity, languageNotes?}`
**Depois por nó:** `{id, filePath, summary, tags}`

Economia: ~15-20% menos tokens por nó, ~3.000–5.000 tokens no total para a Fase 4.

#### Fase 5 (Tour Builder) — corte maior

Três mudanças no que o orquestrador injeta no subagente tour-builder:

**1. Apenas nós de arquivo (remover nós de function/class)**

O tour referencia IDs de nó para wayfinding. Na prática o tour sempre referencia nós `file:` — nós function e class são visíveis na sidebar NodeInfo do dashboard quando um arquivo é selecionado, mas o próprio tour navega no nível de arquivo.

- **Antes:** todos os nós (file + function + class) — para 500 arquivos, talvez 1.500+ nós
- **Depois:** apenas nós do tipo file — 500 nós

**2. Formato de nó enxuto**

O script do tour builder usa apenas IDs, nomes e tipos dos nós para computação do grafo. Resumos e tags são usados na Fase 2 (escrita narrativa pedagógica). Remover campos opcionais pesados do payload injetado:

- **Antes por nó:** `{id, name, filePath, summary, type, tags, complexity, languageNotes?}`
- **Depois por nó:** `{id, name, filePath, summary, type}` (remover tags, complexity, languageNotes)

**3. Arestas enxutas (apenas imports + calls) e camadas enxutas**

A travessia BFS do tour só percorre arestas `imports` e `calls`. `contains`, `exports`, `tested_by`, `depends_on` e outros tipos de aresta não agregam valor à travessia e inflam o payload.

- **Antes (arestas):** todos os tipos de aresta (~3.000+ arestas incluindo todas as arestas `contains` para nós function/class)
- **Depois (arestas):** apenas tipos de aresta `imports` e `calls` (~400–800 arestas para projetos típicos)

Para camadas, o tour builder usa os dados de camada apenas para informar o arco narrativo do tour (qual camada apresentar primeiro, segunda, etc.). Ele não precisa dos arrays completos de `nodeIds` — esses podem ser muito grandes.

- **Antes por camada:** `{id, name, description, nodeIds: [...centenas de IDs]}`
- **Depois por camada:** `{id, name, description}` (remover nodeIds)

#### Estimativa de economia de tokens (Fase 5)

| Dados | Antes | Depois |
|---|---|---|
| Contagem de nós | ~1.500 × ~180 chars | ~500 × ~120 chars |
| Tokens de nó | ~67,500 | ~15,000 |
| Contagem de arestas | ~3.000 × ~80 chars | ~600 × ~80 chars |
| Tokens de aresta | ~60,000 | ~12,000 |
| Tokens de camada | ~5,000 | ~500 |
| **Total Fase 5** | **~132,500** | **~27,500** |
| **Economia** | | **~105,000** |

#### Mudanças no SKILL.md

No template de prompt de dispatch da **Fase 4**, atualizar o formato de nó de arquivo:
```
File nodes:
[list of {id, filePath, summary, tags} for all file-type nodes]
```

No template de prompt de dispatch da **Fase 5**, atualizar todas as três especificações de payload:
```
Nodes (file nodes only):
[list of {id, name, filePath, summary, type} for all file-type nodes only — do NOT include function or class nodes]

Key edges (imports and calls only):
[list of edges where type is "imports" or "calls" only]

Layers:
[list of {id, name, description} — omit nodeIds]
```

---

### C5 — Colocar o subagente graph-reviewer atrás de `--review`

**Causa raiz endereçada:** O subagente graph-reviewer (Fase 6) lê o grafo montado inteiro (~500 nós, todas as arestas, camadas, tour) e roda uma validação alimentada por LLM. Entretanto, sua Fase 1 é inteiramente um script determinístico, e sua Fase 2 é uma decisão simples de threshold: se `issues.length === 0`, aprova. Não há julgamento de LLM necessário no happy path.

**Mudança:** Por padrão, pular o subagente graph-reviewer. O orquestrador realiza validação determinística inline usando um script pré-escrito. Apenas quando `--review` é passado explicitamente em `$ARGUMENTS`, o subagente reviewer LLM completo roda.

#### Caminho padrão (sem `--review`)

Na Fase 6, em vez de despachar o subagente graph-reviewer, o orquestrador:

1. Escreve um script compacto de validação inline (embutido no SKILL.md, ~50 linhas de Node.js):
   - Verificar: toda aresta source/target referencia um ID de nó real
   - Verificar: todo nó de arquivo aparece em exatamente uma camada
   - Verificar: todo nodeId de step do tour existe
   - Verificar: sem IDs de nó duplicados
   - Verificar: campos obrigatórios presentes em nós e arestas
2. Roda o script contra `assembled-graph.json`
3. Se `issues.length === 0`: prossegue para a Fase 7 (save)
4. Se `issues.length > 0`: aplica os mesmos fixes automatizados de antes (remove dangling edges, preenche defaults), então salva

Isto é suficiente para execuções padrão. O reviewer LLM agrega valor para capturar problemas sutis de qualidade (resumos genéricos, nós órfãos, coerência de step do tour) — mas estes são nice-to-have, não bloqueantes.

#### Caminho `--review`

Quando `--review` está em `$ARGUMENTS`, o subagente graph-reviewer completo roda como hoje. Sem mudança nesse code path.

#### Estimativa de economia de tokens

| Caminho | Tokens |
|---|---|
| Atual (sempre roda LLM reviewer) | ~58.000 input + ~500 output |
| Padrão (script inline, sem LLM) | ~0 |
| `--review` (inalterado) | ~58.000 (igual ao atual) |
| **Economia para execuções padrão** | **~58,500** |

---

## Resumo combinado de economia

| Mudança | Tokens antes | Tokens depois | Economia |
|---|---|---|---|
| C1+C2: import map + consolidação de batch | ~301,500 | ~53,500 | ~248,000 |
| C3: remover adendos dos batches | ~26,000 | ~3,000 | ~23,000 |
| C4: enxugar payloads das Fases 4+5 | ~154,500 | ~33,000 | ~121,500 |
| C5: gate do reviewer (caminho padrão) | ~58,500 | ~0 | ~58,500 |
| **Total** | **~540,500** | **~89,500** | **~451,000 (~83%)** |

As estimativas são para um projeto TypeScript+React de 500 arquivos. A economia real escala com o tamanho do projeto — um projeto de 1.000 arquivos veria economia proporcionalmente maior em C1+C2 (mais batches = mais repetição eliminada).

---

## Mudanças de arquivos

| Arquivo | Mudança |
|---|---|
| `skills/understand/project-scanner-prompt.md` | Adicionar Step 8 (resolução de imports); adicionar `importMap` ao schema de saída |
| `skills/understand/file-analyzer-prompt.md` | Substituir `allProjectFiles` por `batchImportData` no schema de input; atualizar o script de extração para usar imports pré-resolvidos; adicionar seção compacta de Language/Framework Quick Reference; remover passos de injeção de adendo |
| `skills/understand/SKILL.md` | Fase 1: notar importMap no resultado do scan; Fase 2: remover injeção de adendo (passos 2+3), aumentar tamanho do batch 5-10→20-30, aumentar concorrência 3→5, substituir injeção de `allProjectFiles` por fatia de `batchImportData`; Fase 4: formato de nó enxuto no dispatch; Fase 5: apenas nós de arquivo + arestas enxutas + camadas enxutas no dispatch; Fase 6: reviewer condicional — script inline padrão, flag `--review` para reviewer LLM |
| `skills/understand/architecture-analyzer-prompt.md` | Sem mudança (adendos ainda injetados aqui) |
| `skills/understand/tour-builder-prompt.md` | Atualizar schema de input para refletir nós apenas-de-arquivo, arestas apenas-imports+calls, formato enxuto de camada |
| `skills/understand/graph-reviewer-prompt.md` | Sem mudança (usado apenas quando a flag `--review` é passada) |

---

## Riscos e mitigações

| Risco | Probabilidade | Mitigação |
|---|---|---|
| A resolução de imports do scanner perde casos de borda (re-exports complexos, dynamic imports) | Média | Logar imports não resolvidos; o file-analyzer ainda usa os dados resolvidos e cria arestas apenas para matches confirmados. Imports perdidos = arestas faltando, que é o mesmo comportamento de antes para imports não resolvíveis |
| Batches maiores (C2) reduzem a qualidade do resumo | Baixa | A qualidade do resumo é dirigida pela análise do modelo de arquivos individuais. O tamanho do batch afeta principalmente quantos arquivos compartilham a context window de um subagente, não a qualidade por arquivo. 20-30 arquivos permanece bem dentro dos limites de contexto |
| Remover nós function/class do tour (C4) quebra steps de tour existentes | Nenhuma | Os steps de tour referenciam IDs de nó `file:`. Nenhum dado de tour existente referencia nós function/class no nível de step |
| Remover o reviewer por padrão (C5) deixa passar erros de grafo | Baixa | O script determinístico inline captura todos os problemas estruturais críticos (refs dangling, camadas faltando, IDs duplicados). O valor adicional do reviewer LLM é warnings de qualidade (nós órfãos, resumos genéricos), que são não-bloqueantes |
| A geração do import map atrasa a Fase 1 | Baixa | O script do scanner já lê todos os arquivos para contagem de linhas. O parsing de imports adiciona uma passada de regex por arquivo — overhead desprezível |

---

## Recomendação de rollout em fases

Dado o perfil de risco, implementar nesta ordem:

1. **C5 primeiro** — colocar o reviewer atrás de gate, menor risco, economia imediata de 58K tokens por execução
2. **C4** — enxugar o payload da Fase 5, sem mudanças no scanner, sem risco de qualidade
3. **C3** — remover adendos dos batches, adicionar hints inline
4. **C1+C2 juntos** — mudanças no scanner e consolidação de batch, testar exaustivamente em projetos pequenos/médios/grandes antes de release
