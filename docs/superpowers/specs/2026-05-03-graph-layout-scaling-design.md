# Escalonamento do Layout do Grafo do Dashboard — Design

## Problema

Quando uma camada de grafo estrutural contém muitos nós, o `applyDagreLayout` atual (direção TB) posiciona nós de mesmo rank em uma única linha horizontal. Com 50+ nós por rank, a linha se estende por milhares de pixels e a visualização se torna ilegível: nós encolhem, rótulos desaparecem, arestas se enroscam e não há âncoras visuais para orientar o leitor.

Este design substitui o dagre pelo ELK em todas as views de estilo estrutural, introduz **containers** baseados em pasta/comunidade para a view layer-detail e calcula o layout em **dois estágios lazy** — uma única passada sobre os containers, depois layout dos filhos por container sob demanda.

O schema do grafo e a saída do pipeline (`graph.json`) permanecem inalterados. Todas as melhorias derivam dos dados existentes.

## Objetivos

- Eliminar o sprawl horizontal nas views layer-detail em ≤100 nós por camada (alvo atual) e permanecer utilizável em até 1000+ nós (escala futura).
- Dar a cada view layer-detail âncoras visuais explícitas para que a estrutura seja legível à primeira vista.
- Agregar arestas cross-cluster por padrão; expor arestas individuais sob demanda.
- Manter o estilo visual contínuo com a apresentação existente das layer-clusters (nível de overview).
- Tratar falhas de layout com o mesmo modelo `GraphIssue` já usado para validação de schema.

## Não-Objetivos

- Sem regeneração de `graph.json`. Todo o agrupamento é derivado no client-side.
- Sem mudança na KnowledgeGraphView (já é force-directed; fora do escopo).
- Sem aninhamento de containers em múltiplos níveis (apenas profundidade única na v1).
- Sem reporte remoto de erros (estilo Sentry) — plugin open-source, sem telemetria por padrão.
- Sem comportamento de agrupamento específico por persona além do filtro de tipo de nó existente.

## Escopo

Três views são afetadas:

| View | Mudança |
|---|---|
| Overview (layer clusters) | Substituir dagre → ELK. Sem novo agrupamento (camadas já são grupos). |
| DomainGraphView | Substituir dagre → ELK com domínio como pai de flow/step. |
| Layer-detail | Substituir dagre → ELK + novos containers de pasta/comunidade + agregação de arestas + layout lazy em dois estágios. |

A KnowledgeGraphView permanece em `applyForceLayout` e não é tocada.

---

## §1. Arquitetura

```
existing graph (immutable)
    │
    ▼
deriveContainers(nodes, edges)           // §2 — folder strategy with community fallback
    │
    ▼
buildCompoundGraph()                     // §4 — aggregate inter-container edges, keep intra-container
    │
    ▼
runStage1Layout(containers, aggEdges)    // §6 — ELK on containers only; uses size memory
    │
    ▼   ┌──────────────────────────────┐
    │   │   render: containers laid    │
    │   │   out, children unrendered   │
    │   └──────────────────────────────┘
    │
    │   triggered by: click | zoom > 1.0 | search/focus/tour hit child
    ▼
runStage2Layout(container)               // §6 — ELK on one container's children; cached
    │
    ▼
React Flow render (parentId for parent-child) + visual overlay (selection/diff/search/tour)
```

Duas invariantes preservadas do código atual:

1. **A computação de layout é pura e memoizada.** Só re-roda quando topologia do grafo / persona / diff / focus / nodeTypeFilters mudam.
2. **Estado visual é uma passada de overlay O(n) separada.** Seleção, destaque de busca, destaque de tour e hover não disparam relayout.

Isso combina com a divisão `useLayerDetailTopology` / `useLayerDetailGraph` existente em `GraphView.tsx`.

---

## §2. Derivação de Container (Apenas Layer-Detail)

### 2.1 Estratégia de pastas (padrão)

1. Coletar o `filePath` de cada nó na camada.
2. Calcular o longest common prefix (LCP) entre todos os caminhos e removê-lo.
3. Agrupar pelo **primeiro segmento de caminho após o LCP**.
   - `auth/login.go` → container `auth`
   - `auth/handlers/oauth.go` → container `auth`
   - `cart/cart.go` → container `cart`
4. Apenas agrupamento de profundidade única; sem aninhamento recursivo na v1.
5. Nós sem `filePath` (ex: tipo `concept`) → container `~` (renderizado como `(root)`, esmaecido).

### 2.2 Fallback de comunidade (Louvain)

Disparado quando **qualquer** uma das condições abaixo:

- Todos os nós compartilham a mesma pasta única após remoção do LCP.
- Contagem de buckets (pastas + rooted) `< 2`.
- Algum bucket único (pasta ou rooted) detém `> 70%` dos nós.

Roda detecção de comunidades baseada em modularidade Louvain sobre as arestas internas da camada. Cada comunidade vira um container. Nomes são placeholders (`Cluster A`, `Cluster B`, ...) já que não há nome semântico disponível.

Implementação: usar `graphology` + `graphology-communities-louvain` (~30KB no total). JS puro, sem deps nativas, roda na main thread sincronamente para arestas internas da camada.

### 2.3 Casos de borda

| Caso | Comportamento |
|---|---|
| Container tem 1 filho (apenas quando o total da camada é ≥ 3) | Sem caixa de container renderizada; o filho vira um nó top-level no layout do Estágio 1 |
| Container tem 2 filhos | Container renderizado; rótulo esmaecido |
| Todos os nós sem `filePath` | Todos vão para o container `~`; se ele virasse single-child, fallback para flat |

### 2.4 Assinatura da função

```ts
function deriveContainers(
  nodes: GraphNode[],
  edges: GraphEdge[],
): {
  containers: Array<{
    id: string;                        // e.g. "container:auth" or "container:cluster-0"
    name: string;                       // "auth" or "Cluster A"
    nodeIds: string[];
    strategy: "folder" | "community";
  }>;
  ungrouped: string[];                  // nodes that bypass containerization
};
```

O campo `strategy` é exposto na UI ("Grouped by folder" vs "Grouped by edge density") para que o usuário saiba como uma camada específica foi organizada.

---

## §3. Integração ELK

### 3.1 Pacote

- `elkjs` ^0.9 (~250KB gzipped). Use `elk.bundled.js`, não a variante worker.
- API baseada em Promise. Roda na main thread para grafos ≤500 nós; <100ms típico.

### 3.2 Configuração

```ts
{
  algorithm: "layered",
  "elk.direction": "DOWN",                                 // matches dagre TB
  "elk.layered.spacing.nodeNodeBetweenLayers": 80,
  "elk.spacing.nodeNode": 60,
  "elk.layered.crossingMinimization.strategy": "LAYER_SWEEP",
  "elk.edgeRouting": "ORTHOGONAL",
  "elk.layered.compaction.postCompaction.strategy": "LEFT",
  "elk.padding": "[top=40,left=20,right=20,bottom=20]",   // container internal padding
}
```

`hierarchyHandling: INCLUDE_CHILDREN` **não** é usado — a abordagem de dois estágios (§6) emite chamadas separadas ao ELK para containers top-level e para filhos por container, então um único compound graph nunca é montado.

### 3.3 Modelagem de entrada por view

| View | Entrada do ELK |
|---|---|
| Overview | Flat. Filhos = nós layer-cluster. |
| DomainGraphView | Flat na v1 (domínio fica como o único agrupamento; nós flow/step posicionados internamente). |
| Layer-detail Estágio 1 | Flat. Filhos = containers (tratados como átomos opacos). |
| Layer-detail Estágio 2 | Flat por container. Filhos = arquivos dentro dele. |

Uma única função `runElk(input): Promise<positioned>` atende aos quatro casos.

### 3.4 Fronteiras com o `utils/layout.ts` existente

| Função | Status |
|---|---|
| `applyDagreLayout` | Mantida temporariamente; removida na versão após a migração de layout ser verificada como estável |
| `applyForceLayout` | Não tocada (apenas KnowledgeGraphView) |
| `applyElkLayout` (nova) | Wrapper que lida com repair → ELK → coerção de resultado |

### 3.5 Async + estado de carregamento

O Estágio 1 roda em um `useEffect` com cancelamento ao mudar a dependência:

```ts
useEffect(() => {
  let cancelled = false;
  setLayoutStatus("computing");
  applyElkLayout(input).then(result => {
    if (!cancelled) {
      setLayout(result);
      setLayoutStatus("ready");
    }
  });
  return () => { cancelled = true };
}, [graph, activeLayerId, persona, diffMode, nodeTypeFilters]);
```

Enquanto `layoutStatus === "computing"`, renderizar um overlay `"Computing layout…"` (semitransparente, centralizado). O layout antigo do estado anterior é mantido por baixo para que o viewport não pisque.

### 3.6 Tratamento de falhas — reusa o modelo GraphIssue existente

Antes de invocar o ELK, rodar `repairElkInput()` sobre a entrada montada. Cada repair emite um `GraphIssue` consumido pelo `WarningBanner` existente.

| Função de repair | Disparada por | Nível do issue |
|---|---|---|
| `ensureNodeDimensions` | Nó sem width/height | `auto-corrected` |
| `dedupeNodeIds` | Id de filho duplicado sob o mesmo pai | `auto-corrected` |
| `dropOrphanEdges` | Aresta com source/target fora do conjunto de nós | `dropped` |
| `dropOrphanChildren` | Filho referencia um pai inexistente | `dropped` |
| `dropCircularContainment` | Ciclo de containment de container | `dropped` |

Se o ELK ainda rejeitar após o repair → emitir um `GraphIssue` `fatal`, renderizar um grafo vazio + o banner fatal existente. O texto do copy fatal é aumentado com "this looks like a dashboard rendering bug — please file an issue with the copied error" para que o usuário saiba direcionar o report ao dashboard, não aos dados do grafo.

### 3.7 Falhas estritas em modo dev

Tanto `repairElkInput` quanto `runElk` aceitam um `strict: boolean`. Em `import.meta.env.DEV`, strict está ativo — repairs e erros do ELK são lançados imediatamente em vez de produzirem issues graciosos. Isso captura bugs de construção de entrada durante o desenvolvimento antes que sejam shippados como fallbacks silenciosos.

---

## §4. Agregação de Arestas

### 4.1 Algoritmo

Executado dentro de `buildCompoundGraph()`, antes de qualquer estágio do ELK.

```ts
function aggregateContainerEdges(
  nodes: GraphNode[],
  edges: GraphEdge[],
  nodeToContainer: Map<string, string>,
): {
  intraContainer: Edge[];                       // preserved as-is
  interContainerAggregated: AggregatedEdge[];   // one per (sourceContainer, targetContainer)
};
```

Regras:

- Para cada aresta, consultar os containers de source/target.
- Mesmo container → intra (inalterado).
- Containers diferentes → bucket por `(sourceContainer, targetContainer)`. Direção importa: A→B e B→A são independentes.
- Cada aresta agregada carrega `count` e `types` (conjunto de tipos de aresta que aparecem no bucket).

### 4.2 Visual

Reusar o padrão de estilo já presente na agregação de arestas no nível de overview (`GraphView.tsx` linha ~186):

- `strokeWidth: Math.min(1 + Math.log2(count + 1), 5)`
- Rótulo: número de count
- Cor: o `rgba(212,165,116,0.4)` existente

### 4.3 Expandir / colapsar

Estado (zustand store):

```ts
expandedContainers: Set<string>;   // currently expanded container ids
```

Gatilhos:

- **Clique no container** → alterna a participação.
- **Clique no canvas vazio** ou `Esc` → limpa todos.
- **Expansão de múltiplos containers é permitida** (usuário comparando relacionamentos entre duas pastas).

Quando um container é expandido:

- Suas arestas inter-container agregadas (em ambas direções) são substituídas pelas arestas individuais arquivo→arquivo subjacentes.
- As arestas agregadas dos outros containers permanecem agregadas.
- O re-layout de posição **não** é disparado. Apenas o array de arestas do React Flow muda.

### 4.4 Interações com persona / diff

- **Filtro de persona** muda o `count` (apenas arestas pós-filtro). A aresta agregada é re-derivada no pipeline memoizado.
- **Modo diff**: aresta agregada contendo qualquer nó alterado → stroke vermelho + animado; ao expandir, as arestas individuais seguem o estilo normal de diff.

---

## §5. Visual do Container

### 5.1 Novo componente: `ContainerNode`

Um novo tipo de nó do React Flow `"container"` registrado ao lado do `custom` / `layer-cluster` / `portal` existentes.

Ele **não** reusa o `LayerClusterNode` porque:

- A semântica do clique difere (`LayerClusterNode` faz drill-in em uma camada; `ContainerNode` alterna a expansão de arestas).
- Os metadados diferem (`ContainerNode` não carrega `aggregateComplexity`).

A linguagem visual é compartilhada: caixa translúcida com cantos arredondados, borda dourada, título DM Serif.

### 5.2 Especificação

| Elemento | Estilo |
|---|---|
| Borda (padrão) | `1px solid rgba(212,165,116,0.25)` |
| Borda (hover / expandido) | `1.5px rgba(212,165,116,0.6)`, expandido adiciona chevron `▾` |
| Background | `rgba(255,255,255,0.02)` |
| Raio do canto | `12px` |
| Título | DM Serif, 14px, `#d4a574`, padding top-left `12px 16px` |
| Badge de contagem de filhos | chip top-right, `#a39787`, 11px |
| Padding interno (ao redor dos filhos) | `40px top / 20px L,R,B` |

### 5.3 Codificação por cores

Índice do container módulo paleta de 12 cores (mesma paleta usada para `layerColorIndex` em `LayerClusterNode`). A matiz é aplicada com baixa saturação apenas na borda + título — nunca no preenchimento do corpo — para que a paleta não sobrecarregue os nós individuais por dentro.

### 5.4 Estilos de estado

| Estado | Visual |
|---|---|
| `default` | Especificação base |
| `hover` | Borda mais brilhante, sublinhado no título |
| `expanded` | Borda dourada de 1.5px + chevron `▾` |
| `search-hit-inside` | Badge de busca na linha do título mostrando contagem de matches |
| `diff-affected` | Borda muda para `rgba(224,82,82,0.5)` |
| `focused-via-child` | Igual ao expanded mais aumento de brilho |

### 5.5 Fonte do rótulo

| Estratégia | Rótulo |
|---|---|
| `folder` | Primeiro segmento de caminho após o LCP (ex: `auth`) |
| `community` | `Cluster A`, `Cluster B`, ... ordenado por id da comunidade |
| `~` (root) | `(root)` em estilo esmaecido |

---

## §6. Layout Lazy em Dois Estágios

### 6.1 Máquina de estados

```
[layer entered]
    │
    │ Stage 1: ELK on containers (always runs)
    ▼
[containers laid out, children unrendered]
    │
    ├── click container ─────┐
    ├── zoom > 1.0 in viewport (200ms debounce, hysteresis) ─┤
    └── search / focus / tour hit a child ─┘
                                            ▼
                            Stage 2 (per container)
                                            │
                                            ▼
                       [container expanded, children laid out + rendered]
```

### 6.2 Extensões do store

```ts
expandedContainers: Set<string>;
containerLayoutCache: Map<string, {
  childPositions: Map<string, { x: number; y: number }>;
  actualSize: { width: number; height: number };
}>;
containerSizeMemory: Map<string, { width: number; height: number }>;
```

- `containerLayoutCache` invalidado por `(graphHash, containerId)`.
- `containerSizeMemory` persiste entre colapsos do container para evitar jitter na próxima expansão.

### 6.3 Estágio 1

```ts
async function runStage1Layout(containers, aggregatedInterEdges, sizeMemory) {
  const elkInput = {
    id: "root",
    children: containers.map(c => ({
      id: c.id,
      width: sizeMemory.get(c.id)?.width
        ?? Math.sqrt(c.nodeIds.length) * NODE_WIDTH * 1.2,
      height: sizeMemory.get(c.id)?.height
        ?? Math.sqrt(c.nodeIds.length) * NODE_HEIGHT * 1.2,
    })),
    edges: aggregatedInterEdges.map(toElkEdge),
  };
  return runElk(elkInput);
}
```

O tamanho do container é estimado a partir de `sqrt(childCount)` para que cresça sub-linearmente com o conteúdo. Se a memória tiver o tamanho real de uma execução anterior, ele vence.

### 6.4 Estágio 2

```ts
async function runStage2Layout(container, intraEdges) {
  if (containerLayoutCache.has(container.id)) {
    return containerLayoutCache.get(container.id)!;
  }
  const elkInput = {
    id: container.id,
    children: container.nodeIds.map(toElkChild),
    edges: intraEdges.filter(e => isWithin(container, e)).map(toElkEdge),
  };
  const result = await runElk(elkInput);
  containerLayoutCache.set(container.id, result);
  containerSizeMemory.set(container.id, result.actualSize);
  return result;
}
```

Se `result.actualSize` diferir da estimativa do Estágio 1 em **> 20%** em qualquer dimensão, dispara um re-layout do Estágio 1 (re-execução completa; <100ms nesta escala, então o usuário percebe um pequeno reflow em vez de dois layouts distintos).

### 6.5 Gatilhos de auto-expansão

| Gatilho | Implementação |
|---|---|
| Clique | `onClick` alterna `expandedContainers` |
| Zoom | Listener `onMove` do React Flow (debounce de 200ms). Quando o zoom do viewport > 1.0, todos os containers no viewport são adicionados a `expandedContainers`. Histerese: containers não auto-colapsam até zoom < 0.6, evitando flapping. |
| Busca / focus / tour | `useEffect` observa `searchResults` / `focusNodeId` / `tourHighlightedNodeIds`; encontra o container pai de qualquer nó folha correspondente e adiciona a `expandedContainers` |

### 6.6 Orçamento de performance

| Operação | Alvo |
|---|---|
| Estágio 1 (qualquer camada) | < 100ms |
| Estágio 2 (primeira expansão de um container) | < 100ms |
| Estágio 2 (cache hit) | < 5ms |
| Auto-expansão dirigida por zoom | debounce de 200ms |
| Re-layout do Estágio 1 após desvio >20% | < 100ms (reusa o caminho do Estágio 1) |

---

## §7. Matriz de Interação

| Feature existente | Comportamento com o novo layout |
|---|---|
| Filtro de persona | Dirige a dependência `nodeTypeFilters` no memo do Estágio 1. Nós filtrados não entram na derivação de container; containers com todos os filhos filtrados desaparecem. |
| Modo diff | Container com um filho alterado recebe borda vermelha (§5.4); arestas agregadas contendo um nó alterado animam em vermelho; ao expandir, o estilo individual de diff se aplica. |
| Modo focus (1-hop) | O container do nó em foco auto-expande. Containers não-vizinhos esmaecem para opacidade 0.2; seus filhos permanecem não renderizados. |
| Busca | Container com um hit recebe um badge de busca no título; o container **não** auto-expande para evitar expandir muitos de uma vez. Clicar no badge expande e faz `fitView`. |
| Tour | Filho destacado pelo tour auto-expande seu container. `TourFitView` ajusta para as posições de folha destacadas (cacheadas após a expansão). |
| Drill-in (`overview → layer-detail`) | Inalterado. Após o drill-in, o Estágio 1 roda nos containers da nova camada. |
| Breadcrumb | Containers não entram no breadcrumb. O caminho continua `Project > LAYER`. |
| Visualizador de código | Inalterado. Clicar em um nó de arquivo dentro de um container → visualizador slide-up existente. |
| WarningBanner | Issues de repair de layout alimentam o mesmo banner. O texto do copy fatal é aumentado para diferenciar bugs de render de bugs de dados. |
| Export (PNG/SVG) | Captura o estado atual incluindo containers expandidos. O nome do arquivo inclui o nome da camada. |

---

## §8. Arquivos e Plano de Teste

### 8.1 Arquivos

```
packages/dashboard/src/
├── utils/
│   ├── layout.ts              [modify] add applyElkLayout export
│   ├── elk-layout.ts          [new]    runElk + repairElkInput + GraphIssue mapping
│   ├── containers.ts          [new]    deriveContainers (folder + community fallback)
│   ├── louvain.ts             [new]    thin wrapper around graphology-communities-louvain
│   └── edgeAggregation.ts     [modify] add aggregateContainerEdges
├── components/
│   ├── ContainerNode.tsx      [new]    container box visual
│   ├── GraphView.tsx          [modify] Stage 1 / Stage 2 wiring, expand state, auto-expand triggers
│   └── DomainGraphView.tsx    [modify] dagre → ELK
├── store.ts                   [modify] expandedContainers, containerLayoutCache, containerSizeMemory
└── package.json               [modify] add elkjs ^0.9, graphology, graphology-communities-louvain
```

### 8.2 Matriz de testes

| Tipo | Alvo | Casos |
|---|---|---|
| Unit | `deriveContainers` | happy path do agrupamento por pasta; fallback all-in-root; fallback <2 buckets; fallback de concentração >70%; nós sem `filePath`; supressão de container single-child (gated por camada ≥ 3) |
| Unit | `aggregateContainerEdges` | edges vazios; múltiplas arestas na mesma direção fundem; arestas bidirecionais separam; mistura intra + inter; types deduplicados |
| Unit | `repairElkInput` | cada função de repair em isolamento; valida o nível de `GraphIssue` correto emitido |
| Unit | `runElk` | entrada mínima válida; throw estrito em modo dev; fatal gracioso em produção; cancelamento ao mudar dependência |
| Integration | Fluxo Estágio 1 + Estágio 2 | fixture de 50 nós; clique → cache miss; segundo clique → cache hit; desvio de tamanho >20% → re-layout |
| Integration | Interações persona / focus / search | trocar persona re-roda o Estágio 1; focar um filho auto-expande seu container; hit de busca adiciona badge sem auto-expandir |
| Visual regression (opcional) | Playwright + fixture microservices-demo | screenshots de baseline para overview, layer-detail, domain views |

### 8.3 Benchmarks de performance

Gerar fixtures com `scripts/generate-large-graph.mjs` em 500 / 1000 / 3000 nós. Verificar:

- Estágio 1 < 200ms em 500 nós; < 500ms em 3000 nós.
- Estágio 2 em qualquer container < 100ms.

Se o Estágio 1 com 3000 nós perder o orçamento, revisitar a estimativa de tamanho do container ou a configuração do ELK — não baixar o orçamento.

---

## Questões em Aberto

Nenhuma neste ponto. Todas as decisões tomadas durante o brainstorming estão capturadas acima.

## Notas de Migração

- `applyDagreLayout` é mantida no codebase por uma release após esta entrar, depois removida na próxima. Isso dá um caminho de fallback durante o rollout e uma desinstalação limpa uma vez estável.
- Sem migração de dados de grafo necessária.
- Novas dependências (elkjs, graphology, graphology-communities-louvain) são JS puro, sem bindings nativos — seguras na matriz de plataformas suportadas.
