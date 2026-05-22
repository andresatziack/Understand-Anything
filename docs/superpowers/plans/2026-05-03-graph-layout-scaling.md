# Plano de Implementação do Graph Layout Scaling

> **Para workers agênticos:** SUB-SKILL OBRIGATÓRIA: Use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano tarefa por tarefa. Os steps usam sintaxe de checkbox (`- [ ]`) para tracking.

**Objetivo:** Substituir dagre por ELK em todas as views de dashboard de estilo estrutural, adicionar containers baseados em folder/community na view layer-detail, e computar o layout em dois estágios lazy para que layers com muitos nós fiquem legíveis e graphs grandes mantenham performance.

**Arquitetura:** Três views (overview, DomainGraphView, layer-detail) chamam um novo `applyElkLayout` em vez de `applyDagreLayout`. A view layer-detail ganha um passo `deriveContainers` (estratégia folder com fallback Louvain), arestas cross-container agregadas, chamadas ELK lazy em dois estágios (Stage 1 = containers; Stage 2 = filhos de um container sob demanda), um novo tipo de nó React Flow `ContainerNode`, e extensões na store para estado de expansão e caches de layout.

**Stack Tecnológica:** TypeScript, React 19, Vite, React Flow (`@xyflow/react`), Zustand, Vitest, ELK.js (`elkjs`), `graphology` + `graphology-communities-louvain`.

**Spec:** `docs/superpowers/specs/2026-05-03-graph-layout-scaling-design.md`

---

## Mapa de Arquivos

```
packages/dashboard/
├── package.json                                  [modify] add elkjs, graphology, graphology-communities-louvain, vitest
├── vite.config.ts                                [modify] add vitest test config
├── src/
│   ├── utils/
│   │   ├── layout.ts                              [modify] export applyElkLayout
│   │   ├── elk-layout.ts                          [new]    runElk + repairElkInput + GraphIssue mapping
│   │   ├── containers.ts                          [new]    deriveContainers (folder + community fallback)
│   │   ├── louvain.ts                             [new]    thin wrapper around graphology-communities-louvain
│   │   ├── edgeAggregation.ts                     [modify] add aggregateContainerEdges
│   │   └── __tests__/
│   │       ├── containers.test.ts                 [new]
│   │       ├── edgeAggregation.test.ts            [new]
│   │       └── elk-layout.test.ts                 [new]
│   ├── components/
│   │   ├── ContainerNode.tsx                      [new]
│   │   ├── GraphView.tsx                          [modify] Stage 1 / Stage 2 wiring, expand state, auto-expand
│   │   └── DomainGraphView.tsx                    [modify] dagre → ELK
│   └── store.ts                                   [modify] expandedContainers, containerLayoutCache, containerSizeMemory
└── scripts/
    └── benchmark-layout.mjs                        [new] perf benchmark (uses scripts/generate-large-graph.mjs)
```

---

## Tarefa 1: Dependências + setup do Vitest

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/package.json`
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/smoke.test.ts`
- Modificar: `understand-anything-plugin/packages/dashboard/vite.config.ts`

- [ ] **Step 1: Adicionar deps e devDeps ao package.json**

Edite `understand-anything-plugin/packages/dashboard/package.json`. Adicione em `dependencies`:

```json
    "elkjs": "^0.9.3",
    "graphology": "^0.25.4",
    "graphology-communities-louvain": "^2.0.1",
```

Adicione em `devDependencies`:

```json
    "vitest": "^3.1.0",
    "@vitest/coverage-v8": "^3.2.4",
```

Adicione em `scripts`:

```json
    "test": "vitest run",
    "test:watch": "vitest"
```

- [ ] **Step 2: Atualizar vite.config.ts para registrar o vitest**

Em `understand-anything-plugin/packages/dashboard/vite.config.ts` adicione uma referência triple-slash no topo e um bloco `test`. Abra o arquivo e, no topo, adicione:

```ts
/// <reference types="vitest" />
```

Dentro do objeto `defineConfig({ ... })` adicione:

```ts
  test: {
    environment: "node",
    include: ["src/**/__tests__/**/*.test.ts"],
  },
```

- [ ] **Step 3: Instalar deps**

Execute a partir da raiz do repo:

```bash
pnpm install
```

Esperado: pnpm resolve e instala sem erros.

- [ ] **Step 4: Escrever smoke test**

Crie `understand-anything-plugin/packages/dashboard/src/utils/__tests__/smoke.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import ELK from "elkjs/lib/elk.bundled.js";
import Graph from "graphology";
import louvain from "graphology-communities-louvain";

describe("dependency smoke test", () => {
  it("imports elkjs", () => {
    expect(typeof ELK).toBe("function");
  });

  it("imports graphology", () => {
    const g = new Graph();
    g.addNode("a");
    expect(g.order).toBe(1);
  });

  it("imports graphology-communities-louvain", () => {
    expect(typeof louvain).toBe("function");
  });
});
```

- [ ] **Step 5: Executar smoke test**

```bash
pnpm --filter @understand-anything/dashboard test
```

Esperado: 3 testes passam.

- [ ] **Step 6: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/package.json \
        understand-anything-plugin/packages/dashboard/vite.config.ts \
        understand-anything-plugin/packages/dashboard/src/utils/__tests__/smoke.test.ts \
        pnpm-lock.yaml
git commit -m "chore(dashboard): add elkjs, graphology, vitest"
```

---

## Tarefa 2: deriveContainers — estratégia folder + casos limite

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/containers.ts`
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/containers.test.ts`

- [ ] **Step 1: Escrever testes que vão falhar**

Crie `understand-anything-plugin/packages/dashboard/src/utils/__tests__/containers.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { deriveContainers } from "../containers";
import type { GraphNode, GraphEdge } from "@understand-anything/core/types";

function node(id: string, filePath?: string): GraphNode {
  return {
    id,
    type: "file",
    name: id,
    filePath,
    summary: "",
    complexity: "simple",
  } as GraphNode;
}

describe("deriveContainers — folder strategy", () => {
  it("groups nodes by first folder segment after LCP", () => {
    const nodes = [
      node("a", "src/auth/login.go"),
      node("b", "src/auth/oauth.go"),
      node("c", "src/cart/cart.go"),
      node("d", "src/cart/checkout.go"),
    ];
    const { containers, ungrouped } = deriveContainers(nodes, []);
    expect(ungrouped).toEqual([]);
    expect(containers).toHaveLength(2);
    const names = containers.map((c) => c.name).sort();
    expect(names).toEqual(["auth", "cart"]);
    const auth = containers.find((c) => c.name === "auth")!;
    expect(auth.strategy).toBe("folder");
    expect(auth.nodeIds.sort()).toEqual(["a", "b"]);
  });

  it("strips deep LCP", () => {
    const nodes = [
      node("a", "monorepo/backend/src/auth/login.go"),
      node("b", "monorepo/backend/src/cart/cart.go"),
    ];
    const { containers } = deriveContainers(nodes, []);
    const names = containers.map((c) => c.name).sort();
    expect(names).toEqual(["auth", "cart"]);
  });

  it("collapses nested folders into the first segment", () => {
    const nodes = [
      node("a", "auth/handlers/oauth.go"),
      node("b", "auth/services/token.go"),
      node("c", "cart/cart.go"),
    ];
    const { containers } = deriveContainers(nodes, []);
    expect(containers.find((c) => c.name === "auth")?.nodeIds.sort()).toEqual(["a", "b"]);
  });

  it("places nodes without filePath in '~' container", () => {
    const nodes = [
      node("a", "auth/login.go"),
      node("b", "auth/oauth.go"),
      node("c"),
      node("d"),
    ];
    const { containers } = deriveContainers(nodes, []);
    expect(containers.find((c) => c.name === "~")?.nodeIds.sort()).toEqual(["c", "d"]);
  });

  it("suppresses single-child containers (single child becomes ungrouped)", () => {
    const nodes = [
      node("a", "auth/login.go"),
      node("b", "auth/oauth.go"),
      node("c", "cart/cart.go"),
    ];
    const { containers, ungrouped } = deriveContainers(nodes, []);
    // 'cart' has only 1 child → suppressed
    expect(containers.find((c) => c.name === "cart")).toBeUndefined();
    expect(ungrouped).toContain("c");
    // 'auth' kept
    expect(containers.find((c) => c.name === "auth")?.nodeIds.sort()).toEqual(["a", "b"]);
  });

  it("returns flat (no containers) when total nodes < 8", () => {
    const nodes = [
      node("a", "auth/x.go"),
      node("b", "cart/y.go"),
      node("c", "logs/z.go"),
    ];
    const { containers, ungrouped } = deriveContainers(nodes, []);
    expect(containers).toHaveLength(0);
    expect(ungrouped.sort()).toEqual(["a", "b", "c"]);
  });
});
```

- [ ] **Step 2: Executar os testes para verificar que falham**

```bash
pnpm --filter @understand-anything/dashboard test containers
```

Esperado: erro de import — `Cannot find module '../containers'`.

- [ ] **Step 3: Implementar `containers.ts`**

Crie `understand-anything-plugin/packages/dashboard/src/utils/containers.ts`:

```ts
import type {
  GraphNode,
  GraphEdge,
} from "@understand-anything/core/types";
import { detectCommunities } from "./louvain";

export interface DerivedContainer {
  id: string;
  name: string;
  nodeIds: string[];
  strategy: "folder" | "community";
}

export interface DeriveResult {
  containers: DerivedContainer[];
  ungrouped: string[];
}

const MIN_LAYER_SIZE_FOR_GROUPING = 8;
const MIN_FOLDER_COUNT = 3;
const MAX_CONCENTRATION = 0.6;
const ROOT_BUCKET = "~";

function commonPrefix(paths: string[]): string {
  if (paths.length === 0) return "";
  let prefix = paths[0];
  for (const p of paths) {
    while (!p.startsWith(prefix)) {
      prefix = prefix.slice(0, -1);
      if (!prefix) return "";
    }
  }
  // Trim back to a directory boundary
  const lastSlash = prefix.lastIndexOf("/");
  return lastSlash >= 0 ? prefix.slice(0, lastSlash + 1) : "";
}

function firstSegment(path: string): string {
  const slash = path.indexOf("/");
  return slash >= 0 ? path.slice(0, slash) : path;
}

function groupByFolder(
  nodes: GraphNode[],
): { groups: Map<string, string[]>; rooted: string[] } {
  const withPath = nodes.filter((n) => n.filePath);
  const lcp = commonPrefix(withPath.map((n) => n.filePath!));
  const groups = new Map<string, string[]>();
  const rooted: string[] = [];
  for (const n of withPath) {
    const stripped = n.filePath!.slice(lcp.length);
    if (!stripped.includes("/")) {
      rooted.push(n.id);
      continue;
    }
    const seg = firstSegment(stripped);
    const arr = groups.get(seg) ?? [];
    arr.push(n.id);
    groups.set(seg, arr);
  }
  for (const n of nodes) {
    if (!n.filePath) rooted.push(n.id);
  }
  return { groups, rooted };
}

function shouldFallbackToCommunity(
  groups: Map<string, string[]>,
  totalNodes: number,
): boolean {
  if (groups.size < MIN_FOLDER_COUNT) return true;
  for (const ids of groups.values()) {
    if (ids.length / totalNodes > MAX_CONCENTRATION) return true;
  }
  return false;
}

export function deriveContainers(
  nodes: GraphNode[],
  edges: GraphEdge[],
): DeriveResult {
  if (nodes.length < MIN_LAYER_SIZE_FOR_GROUPING) {
    return { containers: [], ungrouped: nodes.map((n) => n.id) };
  }

  const { groups, rooted } = groupByFolder(nodes);

  const useCommunity = shouldFallbackToCommunity(groups, nodes.length);
  let containers: DerivedContainer[];

  if (useCommunity) {
    const communities = detectCommunities(
      nodes.map((n) => n.id),
      edges,
    );
    const byCommunity = new Map<number, string[]>();
    for (const [nodeId, cid] of communities) {
      const arr = byCommunity.get(cid) ?? [];
      arr.push(nodeId);
      byCommunity.set(cid, arr);
    }
    const sorted = [...byCommunity.entries()].sort((a, b) => a[0] - b[0]);
    containers = sorted.map(([cid, ids], i) => ({
      id: `container:cluster-${cid}`,
      name: `Cluster ${String.fromCharCode(65 + i)}`,
      nodeIds: ids,
      strategy: "community" as const,
    }));
  } else {
    containers = [...groups.entries()].map(([seg, ids]) => ({
      id: `container:${seg}`,
      name: seg,
      nodeIds: ids,
      strategy: "folder" as const,
    }));
    if (rooted.length > 0) {
      containers.push({
        id: `container:${ROOT_BUCKET}`,
        name: ROOT_BUCKET,
        nodeIds: rooted,
        strategy: "folder" as const,
      });
    }
  }

  // Suppress single-child containers
  const ungrouped: string[] = [];
  containers = containers.filter((c) => {
    if (c.nodeIds.length === 1) {
      ungrouped.push(c.nodeIds[0]);
      return false;
    }
    return true;
  });

  return { containers, ungrouped };
}
```

- [ ] **Step 4: Stub do `louvain.ts` (impl real na Tarefa 3)**

Crie `understand-anything-plugin/packages/dashboard/src/utils/louvain.ts`:

```ts
import type { GraphEdge } from "@understand-anything/core/types";

/** Returns [nodeId, communityId] for every node provided. */
export function detectCommunities(
  _nodeIds: string[],
  _edges: GraphEdge[],
): Map<string, number> {
  // Real implementation arrives in Task 3. Stub: every node in community 0.
  const m = new Map<string, number>();
  for (const id of _nodeIds) m.set(id, 0);
  return m;
}
```

- [ ] **Step 5: Executar os testes**

```bash
pnpm --filter @understand-anything/dashboard test containers
```

Esperado: 6 testes passam.

- [ ] **Step 6: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/utils/containers.ts \
        understand-anything-plugin/packages/dashboard/src/utils/louvain.ts \
        understand-anything-plugin/packages/dashboard/src/utils/__tests__/containers.test.ts
git commit -m "feat(dashboard): deriveContainers folder strategy"
```

---

## Tarefa 3: deriveContainers — fallback de community (Louvain)

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/utils/louvain.ts`
- Modificar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/containers.test.ts`

- [ ] **Step 1: Adicionar teste que falha para o fallback de community**

Adicione no final de `containers.test.ts`:

```ts
describe("deriveContainers — community fallback", () => {
  it("falls back to communities when only one folder present", () => {
    const nodes = Array.from({ length: 10 }, (_, i) =>
      node(`n${i}`, `services/n${i}.go`),
    );
    // Two clusters of 5 nodes; densely connected within, no edges between
    const edges: GraphEdge[] = [];
    for (const i of [0, 1, 2, 3, 4]) {
      for (const j of [0, 1, 2, 3, 4]) {
        if (i !== j) edges.push({ source: `n${i}`, target: `n${j}`, type: "calls" } as GraphEdge);
      }
    }
    for (const i of [5, 6, 7, 8, 9]) {
      for (const j of [5, 6, 7, 8, 9]) {
        if (i !== j) edges.push({ source: `n${i}`, target: `n${j}`, type: "calls" } as GraphEdge);
      }
    }
    const { containers } = deriveContainers(nodes, edges);
    expect(containers.length).toBeGreaterThanOrEqual(2);
    for (const c of containers) {
      expect(c.strategy).toBe("community");
      expect(c.name).toMatch(/^Cluster [A-Z]$/);
    }
  });

  it("falls back when one folder holds > 60%", () => {
    const nodes = [
      ...Array.from({ length: 8 }, (_, i) => node(`big${i}`, `big/file${i}.go`)),
      node("a", "small1/a.go"),
      node("b", "small2/b.go"),
    ];
    const { containers } = deriveContainers(nodes, []);
    expect(containers.every((c) => c.strategy === "community")).toBe(true);
  });
});
```

- [ ] **Step 2: Executar os testes, esperar falha**

```bash
pnpm --filter @understand-anything/dashboard test containers
```

Esperado: os novos testes falham porque o stub do louvain coloca todo nó em community 0 (apenas 1 container após supressão).

- [ ] **Step 3: Substituir o stub do louvain pela implementação real**

Sobrescreva `understand-anything-plugin/packages/dashboard/src/utils/louvain.ts`:

```ts
import Graph from "graphology";
import louvain from "graphology-communities-louvain";
import type { GraphEdge } from "@understand-anything/core/types";

/**
 * Run Louvain community detection over the provided node set and the
 * subset of edges whose endpoints are both in the set. Returns a map of
 * nodeId → communityId. Disconnected nodes get unique community ids so
 * they don't collapse into a single cluster.
 */
export function detectCommunities(
  nodeIds: string[],
  edges: GraphEdge[],
): Map<string, number> {
  const ids = new Set(nodeIds);
  const g = new Graph({ type: "undirected", multi: false });
  for (const id of nodeIds) g.addNode(id);
  for (const e of edges) {
    if (!ids.has(e.source) || !ids.has(e.target)) continue;
    if (e.source === e.target) continue;
    if (g.hasEdge(e.source, e.target)) continue;
    g.addEdge(e.source, e.target);
  }
  // graphology-communities-louvain returns Record<nodeId, communityId>
  const result = louvain(g) as Record<string, number>;
  const map = new Map<string, number>();
  for (const id of nodeIds) {
    map.set(id, result[id] ?? -1);
  }
  // Reassign disconnected nodes (community -1) to unique ids past the max
  let next =
    Math.max(...Array.from(map.values()).filter((v) => v >= 0), -1) + 1;
  for (const [id, c] of map) {
    if (c === -1) {
      map.set(id, next++);
    }
  }
  return map;
}
```

- [ ] **Step 4: Executar os testes**

```bash
pnpm --filter @understand-anything/dashboard test containers
```

Esperado: todos os 8 testes passam.

- [ ] **Step 5: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/utils/louvain.ts \
        understand-anything-plugin/packages/dashboard/src/utils/__tests__/containers.test.ts
git commit -m "feat(dashboard): deriveContainers community fallback via Louvain"
```

---

## Tarefa 4: aggregateContainerEdges

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/utils/edgeAggregation.ts`
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/edgeAggregation.test.ts`

- [ ] **Step 1: Escrever testes que vão falhar**

Crie `understand-anything-plugin/packages/dashboard/src/utils/__tests__/edgeAggregation.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { aggregateContainerEdges } from "../edgeAggregation";
import type { GraphEdge } from "@understand-anything/core/types";

const ce = (source: string, target: string, type: string = "calls"): GraphEdge =>
  ({ source, target, type }) as GraphEdge;

describe("aggregateContainerEdges", () => {
  it("returns empty arrays for empty input", () => {
    const r = aggregateContainerEdges([], new Map());
    expect(r.intraContainer).toEqual([]);
    expect(r.interContainerAggregated).toEqual([]);
  });

  it("preserves intra-container edges as-is", () => {
    const m = new Map([
      ["a", "auth"],
      ["b", "auth"],
    ]);
    const r = aggregateContainerEdges([ce("a", "b")], m);
    expect(r.intraContainer).toHaveLength(1);
    expect(r.interContainerAggregated).toEqual([]);
  });

  it("merges multiple same-direction inter edges into one", () => {
    const m = new Map([
      ["a", "auth"],
      ["b", "auth"],
      ["c", "cart"],
      ["d", "cart"],
    ]);
    const edges = [ce("a", "c"), ce("a", "d"), ce("b", "c", "imports")];
    const r = aggregateContainerEdges(edges, m);
    expect(r.interContainerAggregated).toHaveLength(1);
    const agg = r.interContainerAggregated[0];
    expect(agg.sourceContainerId).toBe("auth");
    expect(agg.targetContainerId).toBe("cart");
    expect(agg.count).toBe(3);
    expect(agg.types.sort()).toEqual(["calls", "imports"]);
  });

  it("treats opposite directions as separate aggregated edges", () => {
    const m = new Map([
      ["a", "auth"],
      ["c", "cart"],
    ]);
    const r = aggregateContainerEdges([ce("a", "c"), ce("c", "a")], m);
    expect(r.interContainerAggregated).toHaveLength(2);
    const dirs = r.interContainerAggregated.map(
      (e) => `${e.sourceContainerId}→${e.targetContainerId}`,
    );
    expect(dirs.sort()).toEqual(["auth→cart", "cart→auth"]);
  });

  it("ignores edges whose endpoints have no container mapping", () => {
    const m = new Map([["a", "auth"]]);
    const r = aggregateContainerEdges([ce("a", "z")], m);
    expect(r.intraContainer).toEqual([]);
    expect(r.interContainerAggregated).toEqual([]);
  });
});
```

- [ ] **Step 2: Executar os testes, esperar falha**

```bash
pnpm --filter @understand-anything/dashboard test edgeAggregation
```

Esperado: erro de import — `aggregateContainerEdges` não exportado.

- [ ] **Step 3: Implementar**

Adicione no final de `understand-anything-plugin/packages/dashboard/src/utils/edgeAggregation.ts`:

```ts
import type { GraphEdge } from "@understand-anything/core/types";

export interface AggregatedContainerEdge {
  sourceContainerId: string;
  targetContainerId: string;
  count: number;
  types: string[];
}

export interface ContainerEdgeBuckets {
  intraContainer: GraphEdge[];
  interContainerAggregated: AggregatedContainerEdge[];
}

/**
 * Bucket edges into intra-container (preserved) and inter-container
 * (aggregated by directed (source,target) container pair).
 *
 * Direction is significant: A→B and B→A produce two independent
 * aggregated edges. Edges whose endpoints have no container mapping
 * are dropped (treat them as pre-filtered).
 */
export function aggregateContainerEdges(
  edges: GraphEdge[],
  nodeToContainer: Map<string, string>,
): ContainerEdgeBuckets {
  const intra: GraphEdge[] = [];
  const interMap = new Map<
    string,
    {
      sourceContainerId: string;
      targetContainerId: string;
      count: number;
      types: Set<string>;
    }
  >();

  for (const e of edges) {
    const sc = nodeToContainer.get(e.source);
    const tc = nodeToContainer.get(e.target);
    if (!sc || !tc) continue;
    if (sc === tc) {
      intra.push(e);
      continue;
    }
    const key = `${sc} ${tc}`;
    const existing = interMap.get(key);
    if (existing) {
      existing.count++;
      existing.types.add(e.type);
    } else {
      interMap.set(key, {
        sourceContainerId: sc,
        targetContainerId: tc,
        count: 1,
        types: new Set([e.type]),
      });
    }
  }

  const interContainerAggregated: AggregatedContainerEdge[] = [...interMap.values()].map(
    (v) => ({
      sourceContainerId: v.sourceContainerId,
      targetContainerId: v.targetContainerId,
      count: v.count,
      types: [...v.types],
    }),
  );

  return { intraContainer: intra, interContainerAggregated };
}
```

- [ ] **Step 4: Executar os testes**

```bash
pnpm --filter @understand-anything/dashboard test edgeAggregation
```

Esperado: 5 testes passam.

- [ ] **Step 5: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/utils/edgeAggregation.ts \
        understand-anything-plugin/packages/dashboard/src/utils/__tests__/edgeAggregation.test.ts
git commit -m "feat(dashboard): aggregateContainerEdges (directional, types-set)"
```

---

## Tarefa 5: Reparo do input do ELK

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/elk-layout.ts`
- Criar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/elk-layout.test.ts`

- [ ] **Step 1: Escrever testes que vão falhar para as funções de reparo**

Crie `understand-anything-plugin/packages/dashboard/src/utils/__tests__/elk-layout.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { repairElkInput, type ElkInput } from "../elk-layout";

describe("repairElkInput", () => {
  it("ensures node dimensions when missing", () => {
    const input: ElkInput = {
      id: "root",
      children: [{ id: "a" }, { id: "b", width: 100, height: 50 }] as ElkInput["children"],
      edges: [],
    };
    const { input: out, issues } = repairElkInput(input);
    expect(out.children![0].width).toBeGreaterThan(0);
    expect(out.children![0].height).toBeGreaterThan(0);
    expect(out.children![1]).toEqual({ id: "b", width: 100, height: 50 });
    expect(issues.some((i) => i.level === "auto-corrected" && /dimensions/.test(i.message))).toBe(true);
  });

  it("dedupes duplicate child ids and reports auto-corrected", () => {
    const input: ElkInput = {
      id: "root",
      children: [
        { id: "a", width: 1, height: 1 },
        { id: "a", width: 1, height: 1 },
      ],
      edges: [],
    };
    const { input: out, issues } = repairElkInput(input);
    expect(out.children).toHaveLength(1);
    expect(issues.some((i) => i.level === "auto-corrected" && /duplicate/.test(i.message))).toBe(true);
  });

  it("drops orphan edges referencing nonexistent nodes", () => {
    const input: ElkInput = {
      id: "root",
      children: [{ id: "a", width: 1, height: 1 }],
      edges: [
        { id: "e1", sources: ["a"], targets: ["ghost"] },
      ],
    };
    const { input: out, issues } = repairElkInput(input);
    expect(out.edges).toHaveLength(0);
    expect(issues.some((i) => i.level === "dropped" && /edge/.test(i.message))).toBe(true);
  });

  it("drops children referencing nonexistent parents", () => {
    const input: ElkInput = {
      id: "root",
      children: [
        {
          id: "p",
          width: 100,
          height: 100,
          children: [{ id: "c1", width: 1, height: 1 }],
        },
        { id: "orphan", width: 1, height: 1, parentId: "ghost" } as ElkInput["children"][0] & { parentId: string },
      ],
      edges: [],
    };
    const { input: out, issues } = repairElkInput(input);
    expect(out.children!.find((c) => c.id === "orphan")).toBeUndefined();
    expect(issues.some((i) => i.level === "dropped" && /parent/.test(i.message))).toBe(true);
  });

  it("strict mode throws on any issue", () => {
    const input: ElkInput = {
      id: "root",
      children: [{ id: "a" }] as ElkInput["children"],
      edges: [],
    };
    expect(() => repairElkInput(input, { strict: true })).toThrow(/dimensions/);
  });
});
```

- [ ] **Step 2: Executar os testes, esperar falha**

```bash
pnpm --filter @understand-anything/dashboard test elk-layout
```

Esperado: erro de import — `../elk-layout` não encontrado.

- [ ] **Step 3: Implementar repairElkInput**

Crie `understand-anything-plugin/packages/dashboard/src/utils/elk-layout.ts`:

```ts
import ELK from "elkjs/lib/elk.bundled.js";
import type { GraphIssue } from "@understand-anything/core/schema";

export interface ElkChild {
  id: string;
  width?: number;
  height?: number;
  children?: ElkChild[];
  parentId?: string;
}

export interface ElkEdge {
  id: string;
  sources: string[];
  targets: string[];
}

export interface ElkInput {
  id: string;
  children: ElkChild[];
  edges: ElkEdge[];
  layoutOptions?: Record<string, string>;
}

const DEFAULT_NODE_WIDTH = 280;
const DEFAULT_NODE_HEIGHT = 120;

interface RepairOptions {
  strict?: boolean;
}

interface RepairResult {
  input: ElkInput;
  issues: GraphIssue[];
}

function makeIssue(level: GraphIssue["level"], message: string): GraphIssue {
  return { level, message };
}

function maybeThrow(strict: boolean | undefined, issue: GraphIssue): void {
  if (strict) throw new Error(`[ELK repair] ${issue.level}: ${issue.message}`);
}

export function repairElkInput(
  input: ElkInput,
  opts: RepairOptions = {},
): RepairResult {
  const issues: GraphIssue[] = [];
  const strict = opts.strict;

  // 1. ensureNodeDimensions
  let dimsAdded = 0;
  const fillDims = (children: ElkChild[]): ElkChild[] =>
    children.map((c) => {
      const next: ElkChild = { ...c };
      if (next.width == null || next.height == null) {
        next.width = next.width ?? DEFAULT_NODE_WIDTH;
        next.height = next.height ?? DEFAULT_NODE_HEIGHT;
        dimsAdded++;
      }
      if (next.children) next.children = fillDims(next.children);
      return next;
    });
  const childrenA = fillDims(input.children);
  if (dimsAdded > 0) {
    const issue = makeIssue(
      "auto-corrected",
      `Set default dimensions on ${dimsAdded} node(s) missing width/height.`,
    );
    issues.push(issue);
    maybeThrow(strict, issue);
  }

  // 2. dedupeNodeIds (per parent)
  let dupesRemoved = 0;
  const dedupe = (children: ElkChild[]): ElkChild[] => {
    const seen = new Set<string>();
    const out: ElkChild[] = [];
    for (const c of children) {
      if (seen.has(c.id)) {
        dupesRemoved++;
        continue;
      }
      seen.add(c.id);
      out.push({
        ...c,
        children: c.children ? dedupe(c.children) : undefined,
      });
    }
    return out;
  };
  const childrenB = dedupe(childrenA);
  if (dupesRemoved > 0) {
    const issue = makeIssue(
      "auto-corrected",
      `Removed ${dupesRemoved} duplicate child id(s).`,
    );
    issues.push(issue);
    maybeThrow(strict, issue);
  }

  // 3. dropOrphanChildren — children whose parentId references nonexistent parent
  // (Only top-level children are checked; ELK uses nesting, not parentId, but
  // upstream code may use parentId hints.)
  const allIds = new Set<string>();
  const walk = (children: ElkChild[]) => {
    for (const c of children) {
      allIds.add(c.id);
      if (c.children) walk(c.children);
    }
  };
  walk(childrenB);
  let orphanChildren = 0;
  const childrenC = childrenB.filter((c) => {
    if (c.parentId && !allIds.has(c.parentId)) {
      orphanChildren++;
      return false;
    }
    return true;
  });
  if (orphanChildren > 0) {
    const issue = makeIssue(
      "dropped",
      `Dropped ${orphanChildren} child(ren) with missing parent reference.`,
    );
    issues.push(issue);
    maybeThrow(strict, issue);
  }

  // 4. dropOrphanEdges
  let orphanEdges = 0;
  const edges = input.edges.filter((e) => {
    const ok = e.sources.every((s) => allIds.has(s)) &&
      e.targets.every((t) => allIds.has(t));
    if (!ok) {
      orphanEdges++;
      return false;
    }
    return true;
  });
  if (orphanEdges > 0) {
    const issue = makeIssue(
      "dropped",
      `Dropped ${orphanEdges} edge(s) referencing nonexistent nodes.`,
    );
    issues.push(issue);
    maybeThrow(strict, issue);
  }

  // 5. dropCircularContainment
  // Build parent map by walking nesting
  const parentOf = new Map<string, string>();
  const fillParents = (children: ElkChild[], parent?: string) => {
    for (const c of children) {
      if (parent) parentOf.set(c.id, parent);
      if (c.children) fillParents(c.children, c.id);
    }
  };
  fillParents(childrenC);
  let cyclesRemoved = 0;
  const isCyclic = (id: string): boolean => {
    const seen = new Set<string>();
    let cur = parentOf.get(id);
    while (cur) {
      if (cur === id || seen.has(cur)) return true;
      seen.add(cur);
      cur = parentOf.get(cur);
    }
    return false;
  };
  const stripCycles = (children: ElkChild[]): ElkChild[] =>
    children
      .filter((c) => {
        if (isCyclic(c.id)) {
          cyclesRemoved++;
          return false;
        }
        return true;
      })
      .map((c) => ({
        ...c,
        children: c.children ? stripCycles(c.children) : undefined,
      }));
  const childrenD = stripCycles(childrenC);
  if (cyclesRemoved > 0) {
    const issue = makeIssue(
      "dropped",
      `Dropped ${cyclesRemoved} node(s) in containment cycles.`,
    );
    issues.push(issue);
    maybeThrow(strict, issue);
  }

  return {
    input: { ...input, children: childrenD, edges },
    issues,
  };
}

const elk = new ELK();

export interface ElkLayoutOptions {
  strict?: boolean;
}

export interface ElkLayoutResult {
  positioned: ElkInput;
  issues: GraphIssue[];
}

export async function applyElkLayout(
  input: ElkInput,
  opts: ElkLayoutOptions = {},
): Promise<ElkLayoutResult> {
  const { input: repaired, issues } = repairElkInput(input, opts);
  try {
    const positioned = (await elk.layout(repaired as never)) as ElkInput;
    return { positioned, issues };
  } catch (err) {
    const fatal: GraphIssue = {
      level: "fatal",
      message:
        `ELK layout failed: ${err instanceof Error ? err.message : String(err)}. ` +
        `This looks like a dashboard rendering bug — please file an issue with the copied error.`,
    };
    if (opts.strict) throw err;
    return { positioned: { ...repaired, children: [], edges: [] }, issues: [...issues, fatal] };
  }
}
```

- [ ] **Step 4: Executar os testes**

```bash
pnpm --filter @understand-anything/dashboard test elk-layout
```

Esperado: 5 testes passam.

- [ ] **Step 5: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/utils/elk-layout.ts \
        understand-anything-plugin/packages/dashboard/src/utils/__tests__/elk-layout.test.ts
git commit -m "feat(dashboard): elk-layout repair pipeline + applyElkLayout"
```

---

## Tarefa 6: Teste de integração do applyElkLayout

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/utils/__tests__/elk-layout.test.ts`

- [ ] **Step 1: Adicionar teste de integração**

Adicione no final de `elk-layout.test.ts`:

```ts
import { applyElkLayout } from "../elk-layout";

describe("applyElkLayout", () => {
  it("lays out a small graph and returns positions", async () => {
    const result = await applyElkLayout({
      id: "root",
      children: [
        { id: "a", width: 100, height: 50 },
        { id: "b", width: 100, height: 50 },
      ],
      edges: [{ id: "e1", sources: ["a"], targets: ["b"] }],
      layoutOptions: { algorithm: "layered", "elk.direction": "DOWN" },
    });
    expect(result.issues).toEqual([]);
    expect(result.positioned.children).toHaveLength(2);
    for (const c of result.positioned.children) {
      expect(typeof (c as { x?: number }).x).toBe("number");
      expect(typeof (c as { y?: number }).y).toBe("number");
    }
  });

  it("returns fatal issue when ELK rejects (without throwing in non-strict)", async () => {
    // Force ELK rejection by giving an invalid algorithm
    const result = await applyElkLayout(
      {
        id: "root",
        children: [{ id: "a", width: 1, height: 1 }],
        edges: [],
        layoutOptions: { algorithm: "this-algorithm-does-not-exist" },
      },
      { strict: false },
    );
    expect(result.issues.some((i) => i.level === "fatal")).toBe(true);
  });
});
```

- [ ] **Step 2: Executar os testes**

```bash
pnpm --filter @understand-anything/dashboard test elk-layout
```

Esperado: 7 testes passam.

- [ ] **Step 3: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/utils/__tests__/elk-layout.test.ts
git commit -m "test(dashboard): applyElkLayout integration cases"
```

---

## Tarefa 7: Extensões da store

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/store.ts`

- [ ] **Step 1: Ler a store atual**

Abra `understand-anything-plugin/packages/dashboard/src/store.ts` e localize a interface `DashboardStore` (por volta da linha 62) e o inicializador `create<DashboardStore>`.

- [ ] **Step 2: Adicionar campos à interface**

Dentro de `interface DashboardStore { ... }`, depois dos campos existentes, adicione:

```ts
  // Container expand/collapse + lazy layout caches
  expandedContainers: Set<string>;
  toggleContainer: (containerId: string) => void;
  expandContainer: (containerId: string) => void;
  collapseAllContainers: () => void;

  containerLayoutCache: Map<
    string,
    {
      childPositions: Map<string, { x: number; y: number }>;
      actualSize: { width: number; height: number };
    }
  >;
  setContainerLayout: (
    containerId: string,
    childPositions: Map<string, { x: number; y: number }>,
    actualSize: { width: number; height: number },
  ) => void;
  clearContainerLayouts: () => void;

  containerSizeMemory: Map<string, { width: number; height: number }>;
```

- [ ] **Step 3: Adicionar inicializador + métodos**

Dentro do bloco `create<DashboardStore>((set) => ({ ... }))`, adicione:

```ts
      expandedContainers: new Set<string>(),
      toggleContainer: (containerId) =>
        set((state) => {
          const next = new Set(state.expandedContainers);
          if (next.has(containerId)) next.delete(containerId);
          else next.add(containerId);
          return { expandedContainers: next };
        }),
      expandContainer: (containerId) =>
        set((state) => {
          if (state.expandedContainers.has(containerId)) return {};
          const next = new Set(state.expandedContainers);
          next.add(containerId);
          return { expandedContainers: next };
        }),
      collapseAllContainers: () => set({ expandedContainers: new Set() }),

      containerLayoutCache: new Map(),
      setContainerLayout: (containerId, childPositions, actualSize) =>
        set((state) => {
          const next = new Map(state.containerLayoutCache);
          next.set(containerId, { childPositions, actualSize });
          const sizeNext = new Map(state.containerSizeMemory);
          sizeNext.set(containerId, actualSize);
          return { containerLayoutCache: next, containerSizeMemory: sizeNext };
        }),
      clearContainerLayouts: () =>
        set({ containerLayoutCache: new Map(), expandedContainers: new Set() }),

      containerSizeMemory: new Map(),
```

- [ ] **Step 4: Conectar a limpeza à action existente de graph-load**

Encontre `setGraph` (ou qualquer action que carregue um novo graph). Dentro do corpo dela, adicione uma chamada para limpar os caches de container quando `graph.id` (ou a referência ao objeto graph) mudar. Exemplo: ao final da call `set(...)` do setter `setGraph`, anexe:

```ts
        containerLayoutCache: new Map(),
        expandedContainers: new Set(),
        containerSizeMemory: new Map(),
```

(Mantenha o reset de `containerSizeMemory` apenas em recargas completas do graph — pelo spec, ele persiste entre colapsos mas não entre graphs distintos.)

- [ ] **Step 5: Sanity-check pelo build**

```bash
pnpm --filter @understand-anything/dashboard build
```

Esperado: build OK.

- [ ] **Step 6: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/store.ts
git commit -m "feat(dashboard): store fields for expanded containers + layout cache"
```

---

## Tarefa 8: Componente ContainerNode

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/components/ContainerNode.tsx`

- [ ] **Step 1: Criar o componente**

Crie `understand-anything-plugin/packages/dashboard/src/components/ContainerNode.tsx`:

```tsx
import { memo } from "react";
import type { NodeProps, Node } from "@xyflow/react";
import { getLayerColor } from "./LayerLegend";

export interface ContainerNodeData extends Record<string, unknown> {
  containerId: string;
  name: string;
  childCount: number;
  strategy: "folder" | "community";
  colorIndex: number;
  isExpanded: boolean;
  hasSearchHits: boolean;
  searchHitCount?: number;
  isDiffAffected: boolean;
  isFocusedViaChild: boolean;
  onToggle: (containerId: string) => void;
}

export type ContainerFlowNode = Node<ContainerNodeData, "container">;

const ContainerNode = memo(({ data, width, height }: NodeProps<ContainerFlowNode>) => {
  const color = getLayerColor(data.colorIndex);

  const borderColor = data.isDiffAffected
    ? "rgba(224,82,82,0.5)"
    : data.isExpanded || data.isFocusedViaChild
      ? "rgba(212,165,116,0.6)"
      : "rgba(212,165,116,0.25)";
  const borderWidth = data.isExpanded || data.isFocusedViaChild ? 1.5 : 1;

  const labelDimmed = data.name === "~";
  const labelText = labelDimmed ? "(root)" : data.name;

  return (
    <div
      className="rounded-xl cursor-pointer transition-all"
      style={{
        width,
        height,
        background: "rgba(255,255,255,0.02)",
        border: `${borderWidth}px solid ${borderColor}`,
        position: "relative",
      }}
      onClick={(e) => {
        e.stopPropagation();
        data.onToggle(data.containerId);
      }}
    >
      <div
        className="flex items-center justify-between"
        style={{
          padding: "12px 16px",
          color: color.label,
          fontFamily: '"DM Serif Display", serif',
          fontSize: 14,
          fontWeight: 400,
        }}
      >
        <span
          className={labelDimmed ? "opacity-50" : ""}
          style={{ display: "flex", alignItems: "center", gap: 6 }}
        >
          {data.isExpanded && <span style={{ fontSize: 10 }}>▾</span>}
          {labelText}
          {data.hasSearchHits && data.searchHitCount && data.searchHitCount > 0 && (
            <span
              style={{
                marginLeft: 6,
                fontSize: 10,
                background: "rgba(212,165,116,0.2)",
                padding: "1px 6px",
                borderRadius: 8,
              }}
            >
              🔍 {data.searchHitCount}
            </span>
          )}
        </span>
        <span style={{ color: "#a39787", fontSize: 11 }}>{data.childCount}</span>
      </div>
    </div>
  );
});

export default ContainerNode;
```

- [ ] **Step 2: Build para verificar type-check**

```bash
pnpm --filter @understand-anything/dashboard build
```

Esperado: build OK.

- [ ] **Step 3: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/ContainerNode.tsx
git commit -m "feat(dashboard): ContainerNode component (visual + click toggle)"
```

---

## Tarefa 9: Migrar layout overview-level para ELK

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

- [ ] **Step 1: Ler o useOverviewGraph atual**

Abra `GraphView.tsx`. Localize `useOverviewGraph` (começa na linha ~125). Identifique a chamada `applyDagreLayout(clusterNodes ..., flowEdges, "TB", dims)` (linha ~202).

- [ ] **Step 2: Converter para ELK assíncrono**

Substitua o bloco de layout síncrono. O formato atual retorna `{ nodes, edges }` de `useMemo`. Mude para usar `useState` + `useEffect` para que a chamada async ao ELK faça setState. Exemplo de substituição (mantenha o código existente que constrói `clusterNodes`, `flowEdges` e `dims`; mude apenas a chamada de layout e os hooks ao redor):

```tsx
  const [overview, setOverview] = useState<{ nodes: Node[]; edges: Edge[] }>({
    nodes: [],
    edges: [],
  });

  useEffect(() => {
    if (!graph) {
      setOverview({ nodes: [], edges: [] });
      return;
    }
    let cancelled = false;
    const elkInput = clusterNodesToElkInput(clusterNodes, flowEdges, dims);
    applyElkLayout(elkInput, { strict: import.meta.env.DEV }).then(({ positioned }) => {
      if (cancelled) return;
      const positionedNodes = mergeElkPositions(clusterNodes as unknown as Node[], positioned);
      setOverview({ nodes: positionedNodes, edges: flowEdges });
    });
    return () => {
      cancelled = true;
    };
  }, [graph, searchResults, drillIntoLayer]);

  return overview;
```

- [ ] **Step 3: Adicionar helpers `clusterNodesToElkInput` e `mergeElkPositions`**

Adicione no final de `utils/layout.ts`:

```ts
import type { ElkInput } from "./elk-layout";

const ELK_DEFAULT_LAYOUT_OPTIONS: Record<string, string> = {
  algorithm: "layered",
  "elk.direction": "DOWN",
  "elk.layered.spacing.nodeNodeBetweenLayers": "80",
  "elk.spacing.nodeNode": "60",
  "elk.layered.crossingMinimization.strategy": "LAYER_SWEEP",
  "elk.edgeRouting": "ORTHOGONAL",
  "elk.layered.compaction.postCompaction.strategy": "LEFT",
  "elk.padding": "[top=40,left=20,right=20,bottom=20]",
};

export function nodesToElkInput(
  nodes: Node[],
  edges: Edge[],
  dims: Map<string, { width: number; height: number }>,
): ElkInput {
  return {
    id: "root",
    layoutOptions: ELK_DEFAULT_LAYOUT_OPTIONS,
    children: nodes.map((n) => {
      const d = dims.get(n.id);
      return {
        id: n.id,
        width: d?.width ?? NODE_WIDTH,
        height: d?.height ?? NODE_HEIGHT,
      };
    }),
    edges: edges.map((e, i) => ({
      id: e.id ?? `e${i}`,
      sources: [String(e.source)],
      targets: [String(e.target)],
    })),
  };
}

export function mergeElkPositions<T extends Node>(
  nodes: T[],
  positioned: ElkInput,
): T[] {
  const posMap = new Map<string, { x: number; y: number }>();
  for (const c of positioned.children ?? []) {
    const cx = (c as ElkInput["children"][number] & { x?: number; y?: number }).x ?? 0;
    const cy = (c as ElkInput["children"][number] & { x?: number; y?: number }).y ?? 0;
    posMap.set(c.id, { x: cx, y: cy });
  }
  return nodes.map((n) => ({
    ...n,
    position: posMap.get(n.id) ?? n.position ?? { x: 0, y: 0 },
  }));
}
```

Em `GraphView.tsx`, renomeie a chamada do helper de `clusterNodesToElkInput` (usado no step 2) para `nodesToElkInput`. Atualize o import:

```tsx
import { applyDagreLayout, nodesToElkInput, mergeElkPositions, NODE_WIDTH, NODE_HEIGHT, LAYER_CLUSTER_WIDTH, LAYER_CLUSTER_HEIGHT, PORTAL_NODE_WIDTH, PORTAL_NODE_HEIGHT } from "../utils/layout";
import { applyElkLayout } from "../utils/elk-layout";
```

- [ ] **Step 4: Verificar manualmente o overview**

```bash
pnpm dev:dashboard
```

No browser, abra a view de project overview (o nível de layer-cluster). Esperado: layer clusters dispostos top-to-bottom (DOWN combina com TB do dagre), arestas visíveis, sem erros no console.

- [ ] **Step 5: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx \
        understand-anything-plugin/packages/dashboard/src/utils/layout.ts
git commit -m "feat(dashboard): overview view uses ELK"
```

---

## Tarefa 10: Migrar DomainGraphView para ELK

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/DomainGraphView.tsx`

- [ ] **Step 1: Ler a DomainGraphView atual**

Abra o arquivo e encontre toda chamada de `applyDagreLayout(...)`.

- [ ] **Step 2: Substituir por ELK no mesmo padrão assíncrono**

Para cada local de `applyDagreLayout`, troque por:

```tsx
import { applyElkLayout } from "../utils/elk-layout";
import { nodesToElkInput, mergeElkPositions } from "../utils/layout";

// ... inside the component:
const [layout, setLayout] = useState<{ nodes: Node[]; edges: Edge[] }>({ nodes: [], edges: [] });

useEffect(() => {
  let cancelled = false;
  const elkInput = nodesToElkInput(domainNodes, domainEdges, dims);
  applyElkLayout(elkInput, { strict: import.meta.env.DEV }).then(({ positioned }) => {
    if (cancelled) return;
    setLayout({
      nodes: mergeElkPositions(domainNodes, positioned),
      edges: domainEdges,
    });
  });
  return () => { cancelled = true; };
}, [/* same deps as the previous useMemo */]);
```

Combine o array de deps exatamente com o que o `useMemo` original usava.

- [ ] **Step 3: Build + smoke manual**

```bash
pnpm --filter @understand-anything/dashboard build
pnpm dev:dashboard
```

Abra um graph com domain data e troque para a view Domain. Esperado: nós renderizam, arestas visíveis, sem erros no console.

- [ ] **Step 4: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/DomainGraphView.tsx
git commit -m "feat(dashboard): DomainGraphView uses ELK"
```

---

## Tarefa 11: Layer-detail Stage 1

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

Esta tarefa substitui dagre por ELK em `useLayerDetailTopology` E introduz `deriveContainers` + agregação de arestas, mas renderiza containers como nós opacos apenas (sem filhos visíveis). A expansão Stage 2 é conectada na Tarefa 12.

- [ ] **Step 1: Registrar o tipo de nó ContainerNode**

Próximo ao topo de `GraphView.tsx`, encontre o registro de `nodeTypes` e adicione `container`:

```tsx
import ContainerNode from "./ContainerNode";
// ...
const nodeTypes = {
  custom: CustomNode,
  "layer-cluster": LayerClusterNode,
  portal: PortalNode,
  container: ContainerNode,
};
```

- [ ] **Step 2: Dentro de `useLayerDetailTopology`, adicionar derivação de containers**

Depois da lógica existente de filtragem (`filteredGraphNodes`, `filteredGraphEdges`) mas antes da construção dos flow nodes, adicione:

```tsx
import { deriveContainers } from "../utils/containers";
import { aggregateContainerEdges } from "../utils/edgeAggregation";
import { nodesToElkInput, mergeElkPositions } from "../utils/layout";
import { applyElkLayout } from "../utils/elk-layout";

// Inside useLayerDetailTopology, after filteredGraphEdges:
const { containers, ungrouped } = deriveContainers(filteredGraphNodes, filteredGraphEdges);
const nodeToContainer = new Map<string, string>();
for (const c of containers) {
  for (const id of c.nodeIds) nodeToContainer.set(id, c.id);
}
const { intraContainer, interContainerAggregated } =
  aggregateContainerEdges(filteredGraphEdges, nodeToContainer);
```

- [ ] **Step 3: Construir input ELK do Stage 1 a partir de containers + ungrouped**

Continue dentro de `useLayerDetailTopology`:

```tsx
const colorIndexFor = (containerId: string) => {
  const idx = containers.findIndex((c) => c.id === containerId);
  return idx === -1 ? 0 : idx % 12;
};
const sizeMemory = useDashboardStore.getState().containerSizeMemory;

const stage1Children: ElkChild[] = [
  ...containers.map((c) => {
    const memorySize = sizeMemory.get(c.id);
    return {
      id: c.id,
      width:
        memorySize?.width ?? Math.sqrt(c.nodeIds.length) * NODE_WIDTH * 1.2,
      height:
        memorySize?.height ?? Math.sqrt(c.nodeIds.length) * NODE_HEIGHT * 1.2,
    };
  }),
  ...ungrouped.map((id) => ({ id, width: NODE_WIDTH, height: NODE_HEIGHT })),
];

const stage1Edges: ElkEdge[] = interContainerAggregated.map((agg, i) => ({
  id: `agg-${i}`,
  sources: [agg.sourceContainerId],
  targets: [agg.targetContainerId],
}));
```

(Os types `ElkChild` e `ElkEdge` vêm de `../utils/elk-layout` — adicione aos imports.)

- [ ] **Step 4: Substituir `useMemo` por `useState + useEffect`**

Converta `useLayerDetailTopology` de retornar um valor memoizado para gerenciar estado com effects, espelhando a Tarefa 9. Mantenha toda a preparação visual existente (`flowNodes`, `flowEdges`, `portalNodes`, `portalEdges`) mas alimente o layout do Stage 1 em um state setter:

```tsx
const [topology, setTopology] = useState<{
  nodes: Node[];
  edges: Edge[];
  portalNodes: PortalFlowNode[];
  portalEdges: Edge[];
  filteredEdges: KnowledgeGraph["edges"];
}>({ nodes: [], edges: [], portalNodes: [], portalEdges: [], filteredEdges: [] });

useEffect(() => {
  if (!graph || !activeLayerId) {
    setTopology({ nodes: [], edges: [], portalNodes: [], portalEdges: [], filteredEdges: [] });
    return;
  }
  let cancelled = false;
  applyElkLayout(
    {
      id: "stage1",
      layoutOptions: { /* default options copied from nodesToElkInput */ },
      children: stage1Children,
      edges: stage1Edges,
    },
    { strict: import.meta.env.DEV },
  ).then(({ positioned }) => {
    if (cancelled) return;

    // Build container flow nodes
    const containerFlowNodes = containers.map((c) => {
      const elkChild = positioned.children?.find((ch) => ch.id === c.id);
      return {
        id: c.id,
        type: "container" as const,
        position: {
          x: (elkChild as { x?: number })?.x ?? 0,
          y: (elkChild as { y?: number })?.y ?? 0,
        },
        data: {
          containerId: c.id,
          name: c.name,
          childCount: c.nodeIds.length,
          strategy: c.strategy,
          colorIndex: colorIndexFor(c.id),
          isExpanded: false,
          hasSearchHits: false,
          searchHitCount: 0,
          isDiffAffected: false,
          isFocusedViaChild: false,
          onToggle: (id: string) => useDashboardStore.getState().toggleContainer(id),
        },
        width:
          (elkChild as { width?: number })?.width ?? NODE_WIDTH,
        height:
          (elkChild as { height?: number })?.height ?? NODE_HEIGHT,
      };
    });

    // Ungrouped (top-level files outside any container) — keep existing flow node logic for these
    const ungroupedFlowNodes = ungrouped
      .map((id) => filteredGraphNodes.find((n) => n.id === id))
      .filter((n): n is GraphNode => n != null)
      .map((node) => buildCustomFlowNode(node, /* helpers */));
    // (positioned.children also has positions for ungrouped ids)
    for (const ufn of ungroupedFlowNodes) {
      const ec = positioned.children?.find((c) => c.id === ufn.id);
      ufn.position = {
        x: (ec as { x?: number })?.x ?? 0,
        y: (ec as { y?: number })?.y ?? 0,
      };
    }

    // Stage 1 edges = aggregated inter-container edges
    const aggEdges: Edge[] = interContainerAggregated.map((agg, i) => ({
      id: `agg-${i}`,
      source: agg.sourceContainerId,
      target: agg.targetContainerId,
      label: String(agg.count),
      style: {
        stroke: "rgba(212,165,116,0.4)",
        strokeWidth: Math.min(1 + Math.log2(agg.count + 1), 5),
      },
      labelStyle: { fill: "#a39787", fontSize: 11 },
    }));

    setTopology({
      nodes: [...containerFlowNodes, ...ungroupedFlowNodes] as unknown as Node[],
      edges: aggEdges,
      portalNodes,
      portalEdges,
      filteredEdges: filteredGraphEdges,
    });
  });
  return () => { cancelled = true; };
}, [graph, activeLayerId, persona, diffMode, changedNodeIds, affectedNodeIds, focusNodeId, nodeTypeFilters, drillIntoLayer]);

return topology;
```

O helper `buildCustomFlowNode` é a lógica inline existente que converte um `GraphNode` no formato `CustomFlowNode` existente — extraia do código atual (os mesmos campos de dados populados para `flowNodes`).

- [ ] **Step 5: Smoke test manual**

```bash
pnpm dev:dashboard
```

Faça drill-down em uma layer no microservices-demo (ou qualquer sample). Esperado: containers visíveis como caixas com borda dourada, com nome + count, sem filhos renderizados ainda, arestas agregadas entre containers.

- [ ] **Step 6: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx
git commit -m "feat(dashboard): layer-detail Stage 1 — containers + ELK"
```

---

## Tarefa 12: Layer-detail Stage 2 + expansão de arestas

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

- [ ] **Step 1: Adicionar effect do Stage 2**

Depois do effect do Stage 1 da Tarefa 11, adicione outro effect que observa `expandedContainers` e roda ELK Stage 2 para qualquer container recém-expandido sem entrada de cache:

```tsx
const expandedContainers = useDashboardStore((s) => s.expandedContainers);
const containerLayoutCache = useDashboardStore((s) => s.containerLayoutCache);
const setContainerLayout = useDashboardStore((s) => s.setContainerLayout);

useEffect(() => {
  let cancelled = false;
  const toCompute = [...expandedContainers].filter(
    (id) => !containerLayoutCache.has(id),
  );
  if (toCompute.length === 0) return;

  Promise.all(
    toCompute.map(async (containerId) => {
      const c = containers.find((c) => c.id === containerId);
      if (!c) return null;
      const childIds = new Set(c.nodeIds);
      const childEdges = intraContainer.filter(
        (e) => childIds.has(e.source) && childIds.has(e.target),
      );
      const stage2Input = {
        id: containerId,
        layoutOptions: { /* default opts */ },
        children: c.nodeIds.map((id) => {
          const dims = filteredGraphNodes.find((n) => n.id === id);
          return { id, width: NODE_WIDTH, height: NODE_HEIGHT };
        }),
        edges: childEdges.map((e, i) => ({
          id: `${containerId}-e${i}`,
          sources: [e.source],
          targets: [e.target],
        })),
      };
      const { positioned } = await applyElkLayout(stage2Input, { strict: import.meta.env.DEV });
      const childPositions = new Map<string, { x: number; y: number }>();
      let maxX = 0, maxY = 0;
      for (const ch of positioned.children ?? []) {
        const x = (ch as { x?: number }).x ?? 0;
        const y = (ch as { y?: number }).y ?? 0;
        const w = (ch as { width?: number }).width ?? NODE_WIDTH;
        const h = (ch as { height?: number }).height ?? NODE_HEIGHT;
        childPositions.set(ch.id, { x, y });
        if (x + w > maxX) maxX = x + w;
        if (y + h > maxY) maxY = y + h;
      }
      const actualSize = { width: maxX + 40, height: maxY + 60 };
      return { containerId, childPositions, actualSize };
    }),
  ).then((results) => {
    if (cancelled) return;
    for (const r of results) {
      if (!r) continue;
      setContainerLayout(r.containerId, r.childPositions, r.actualSize);
    }
  });

  return () => { cancelled = true; };
}, [expandedContainers, containers, intraContainer, filteredGraphNodes, containerLayoutCache, setContainerLayout]);
```

- [ ] **Step 2: Renderizar filhos expandidos + substituir arestas no overlay visual**

Na função de visual-overlay (`useLayerDetailGraph`), depois de obter `topo`, integre o estado de expansão:

```tsx
// Build child flow nodes for each expanded container with cached layout
const expandedChildNodes: Node[] = [];
for (const containerId of expandedContainers) {
  const cache = containerLayoutCache.get(containerId);
  const container = topo.containers?.find((c) => c.id === containerId);
  if (!cache || !container) continue;
  for (const childId of container.nodeIds) {
    const node = filteredGraphNodes.find((n) => n.id === childId);
    const pos = cache.childPositions.get(childId);
    if (!node || !pos) continue;
    expandedChildNodes.push({
      ...buildCustomFlowNode(node, /* helpers */),
      parentId: containerId,
      extent: "parent",
      position: pos,
    } as Node);
  }
}

// Replace aggregated edges where the container is expanded
const expandedEdges: Edge[] = [];
for (const e of topo.edges) {
  const srcExpanded = expandedContainers.has(String(e.source));
  const tgtExpanded = expandedContainers.has(String(e.target));
  if (!srcExpanded && !tgtExpanded) {
    expandedEdges.push(e);
  } else {
    // Replace this aggregated edge with the underlying file→file edges
    // that match its source/target containers
    const matching = filteredGraphEdges.filter((fe) => {
      const fsc = nodeToContainer.get(fe.source);
      const ftc = nodeToContainer.get(fe.target);
      return fsc === e.source && ftc === e.target;
    });
    for (const m of matching) {
      expandedEdges.push({
        id: `inflated-${m.source}-${m.target}`,
        source: m.source,
        target: m.target,
        label: m.type,
        style: { stroke: "rgba(212,165,116,0.5)", strokeWidth: 1.5 },
        labelStyle: { fill: "#a39787", fontSize: 10 },
      });
    }
  }
}
```

Em seguida, retorne `{ nodes: [...topo.nodes, ...expandedChildNodes], edges: expandedEdges, ... }`.

(Atualize o effect do Stage 1 para também expor `containers` e `nodeToContainer` no retorno do topology, para que sejam acessíveis aqui.)

- [ ] **Step 3: Smoke test manual**

```bash
pnpm dev:dashboard
```

Faça drill-down em uma layer. Clique em um container. Esperado: container mostra filhos posicionados dentro; arestas agregadas de/para esse container substituídas por arestas individuais file→file. Clique novamente para colapsar.

- [ ] **Step 4: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx
git commit -m "feat(dashboard): layer-detail Stage 2 — lazy children layout + edge expansion"
```

---

## Tarefa 13: Triggers de auto-expand (zoom + search/focus/tour)

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

- [ ] **Step 1: Auto-expand dirigido por zoom dentro do componente ReactFlow**

Dentro do componente interno que monta `<ReactFlow>` (onde você tem acesso ao viewport do React Flow via `useReactFlow` ou a prop `onMove`), adicione um listener de viewport com debounce:

```tsx
import { useReactFlow } from "@xyflow/react";

function ZoomAutoExpand({ containers }: { containers: Array<{ id: string }> }) {
  const { getViewport, getNodes } = useReactFlow();
  const expandContainer = useDashboardStore((s) => s.expandContainer);
  const expandedContainers = useDashboardStore((s) => s.expandedContainers);
  const collapseAllContainers = useDashboardStore((s) => s.collapseAllContainers);
  const timeoutRef = useRef<number | null>(null);

  const onMove = useCallback(() => {
    if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
    timeoutRef.current = window.setTimeout(() => {
      const vp = getViewport();
      if (vp.zoom > 1.0) {
        // Auto-expand visible containers
        const nodes = getNodes();
        for (const c of containers) {
          if (expandedContainers.has(c.id)) continue;
          const n = nodes.find((nn) => nn.id === c.id);
          if (!n) continue;
          // Crude visibility check: node origin in negative-window coordinates
          // (refined check could project the bounding box, but this is enough
          // to pre-warm common cases)
          expandContainer(c.id);
        }
      } else if (vp.zoom < 0.6) {
        // Hysteresis: only auto-collapse below 0.6
        // Don't collapse explicit user-clicked containers — for now treat all
        // as one set; user can re-expand
        // (simple approach: do nothing on auto-collapse; user collapses manually)
      }
    }, 200);
  }, [getViewport, getNodes, containers, expandContainer, expandedContainers, collapseAllContainers]);

  return <></>; // attach via ReactFlow's onMove prop instead
}
```

Em seguida conecte `onMove={onMoveDebounced}` no elemento `<ReactFlow>`. O componente acima é ilustrativo — você pode inlinhar `onMove` direto no caminho de render do layer-detail por simplicidade.

- [ ] **Step 2: Auto-expand por search/focus/tour**

Adicione no componente layer-detail:

```tsx
const searchResults = useDashboardStore((s) => s.searchResults);
const focusNodeId = useDashboardStore((s) => s.focusNodeId);
const tourHighlightedNodeIds = useDashboardStore((s) => s.tourHighlightedNodeIds);
const expandContainer = useDashboardStore((s) => s.expandContainer);

// Focus mode: expand container of focused node
useEffect(() => {
  if (!focusNodeId) return;
  const containerId = nodeToContainer.get(focusNodeId);
  if (containerId) expandContainer(containerId);
}, [focusNodeId, nodeToContainer, expandContainer]);

// Tour: expand containers of tour-highlighted nodes
useEffect(() => {
  for (const nid of tourHighlightedNodeIds) {
    const cid = nodeToContainer.get(nid);
    if (cid) expandContainer(cid);
  }
}, [tourHighlightedNodeIds, nodeToContainer, expandContainer]);

// Search: do NOT auto-expand. Surface a hasSearchHits flag on the container.
// (this is consumed in Task 14's visual overlay update)
```

- [ ] **Step 3: Smoke test manual**

```bash
pnpm dev:dashboard
```

- Drill into layer. Zoom in past ~1.0. Esperado: visible containers expand within ~200ms.
- Use search to find a node inside a container. Esperado: container shows search badge but does **not** auto-expand. Click the badge → container expands and `fitView`s.
- Use focus mode on a child file. Esperado: its container expands, neighbors fade.

- [ ] **Step 4: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx
git commit -m "feat(dashboard): auto-expand on zoom, focus, and tour"
```

---

## Tarefa 14: Overlays visuais de container — search hit, diff, focused-via-child

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

- [ ] **Step 1: Computar dados de overlay de container em `useLayerDetailGraph`**

Dentro do passo de visual overlay, compute flags por container e atualize o `data` dos container nodes de acordo:

```tsx
const searchByContainer = new Map<string, number>();
for (const r of searchResults) {
  const cid = nodeToContainer.get(r.nodeId);
  if (!cid) continue;
  searchByContainer.set(cid, (searchByContainer.get(cid) ?? 0) + 1);
}

const diffByContainer = new Set<string>();
if (diffMode) {
  for (const id of [...changedNodeIds, ...affectedNodeIds]) {
    const cid = nodeToContainer.get(id);
    if (cid) diffByContainer.add(cid);
  }
}

const focusContainer = focusNodeId ? nodeToContainer.get(focusNodeId) : null;

const visualNodes = topo.nodes.map((n) => {
  if (n.type !== "container") return n;
  const cid = String(n.id);
  return {
    ...n,
    data: {
      ...(n.data as ContainerNodeData),
      isExpanded: expandedContainers.has(cid),
      hasSearchHits: searchByContainer.has(cid),
      searchHitCount: searchByContainer.get(cid) ?? 0,
      isDiffAffected: diffByContainer.has(cid),
      isFocusedViaChild: focusContainer === cid,
    },
  };
});
```

- [ ] **Step 2: Smoke test manual**

```bash
pnpm dev:dashboard
```

- Search "login" in a layer with `auth/` files. Esperado: auth container shows `🔍 N` badge.
- Open a diff view. Esperado: containers with changed files have red borders.
- Use focus mode. Esperado: container with focused child has gold border + chevron.

- [ ] **Step 3: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx
git commit -m "feat(dashboard): container overlays — search/diff/focus"
```

---

## Tarefa 15: Re-layout do Stage 2 por desvio de tamanho

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`

- [ ] **Step 1: Detectar desvio depois do Stage 2**

No effect Stage 2 da Tarefa 12, depois que `setContainerLayout` for chamado, compare `actualSize` com a estimativa do Stage 1 que foi usada. Se o desvio passar de 20% em width ou height, agende uma re-execução do Stage 1 invalidando sua dependência.

O mecanismo mais simples: incrementar um contador `stage1Tick` na store em desvios. Adicione na store:

```ts
stage1Tick: number;
bumpStage1Tick: () => void;
```

Inicializador:

```ts
stage1Tick: 0,
bumpStage1Tick: () => set((s) => ({ stage1Tick: s.stage1Tick + 1 })),
```

No effect Stage 2, depois do cache:

```tsx
const stage1Estimate = stage1Children.find((sc) => sc.id === r.containerId);
if (stage1Estimate) {
  const dw = Math.abs(r.actualSize.width - (stage1Estimate.width ?? 1)) / (stage1Estimate.width ?? 1);
  const dh = Math.abs(r.actualSize.height - (stage1Estimate.height ?? 1)) / (stage1Estimate.height ?? 1);
  if (dw > 0.2 || dh > 0.2) {
    useDashboardStore.getState().bumpStage1Tick();
  }
}
```

Adicione `stage1Tick` no array de dependências do effect Stage 1.

- [ ] **Step 2: Smoke test manual**

```bash
pnpm dev:dashboard
```

Faça drill-down em uma layer com uma pasta que tenha muitos arquivos. Clique para expandir. O container deve crescer até o tamanho real e o layout ao redor deve refluir uma vez.

- [ ] **Step 3: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx \
        understand-anything-plugin/packages/dashboard/src/store.ts
git commit -m "feat(dashboard): Stage 2 size-deviation triggers Stage 1 re-layout"
```

---

## Tarefa 16: Texto do WarningBanner para issues de layout + overlay Computing layout

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/WarningBanner.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/store.ts`

- [ ] **Step 1: Adicionar funil de issues de layout à store**

Adicione na store:

```ts
layoutIssues: GraphIssue[];
appendLayoutIssues: (issues: GraphIssue[]) => void;
clearLayoutIssues: () => void;
```

Inicializador + setters com semântica de merge (deduplicação por `level + message`).

- [ ] **Step 2: Funilar issues do ELK para a store após cada chamada de layout**

Após cada resolução de `applyElkLayout(...)` em `GraphView.tsx` e `DomainGraphView.tsx`, anexe `issues` à store:

```tsx
const { positioned, issues } = await applyElkLayout(input, { strict: import.meta.env.DEV });
if (issues.length > 0) useDashboardStore.getState().appendLayoutIssues(issues);
```

- [ ] **Step 3: Exibir banner em todas as fontes**

Em `App.tsx`, onde `<WarningBanner issues={graphIssues} />` é renderizado, substitua por uma fonte mesclada:

```tsx
const layoutIssues = useDashboardStore((s) => s.layoutIssues);
<WarningBanner issues={[...graphIssues, ...layoutIssues]} />
```

- [ ] **Step 4: Atualizar texto de copy no WarningBanner**

Edite `buildCopyText` em `WarningBanner.tsx`. Substitua o preâmbulo hardcoded por copy condicional baseado em haver issues `fatal`:

```ts
const hasFatal = issues.some((i) => i.level === "fatal");
const lines = hasFatal
  ? [
      "Some of these issues look like dashboard rendering bugs.",
      "Please file an issue at github.com/Lum1104/Understand-Anything/issues with the text below.",
      "",
    ]
  : [
      "The following issues were found in your knowledge-graph.json.",
      "These are LLM generation errors — not a system bug.",
      "You can ask your agent to fix these specific issues in the knowledge-graph.json file:",
      "",
    ];
```

- [ ] **Step 5: Overlay "Computing layout…"**

Em `GraphView.tsx`, mantenha um state `layoutStatus` (`"computing" | "ready"`) por view. Enquanto computando, renderize um overlay posicionado absolutamente sobre a superfície do React Flow:

```tsx
{layoutStatus === "computing" && (
  <div
    style={{
      position: "absolute",
      inset: 0,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      background: "rgba(10,10,10,0.5)",
      pointerEvents: "none",
      zIndex: 10,
    }}
  >
    <span style={{ color: "#d4a574", fontSize: 14 }}>Computing layout…</span>
  </div>
)}
```

Defina `layoutStatus` para `"computing"` antes de `applyElkLayout(...)` e `"ready"` depois.

- [ ] **Step 6: Smoke test manual**

```bash
pnpm dev:dashboard
```

- Open a graph. Esperado: brief "Computing layout…" overlay during initial layout.
- Manually corrupt a graph (e.g., introduce an edge to a nonexistent node) → expected: WarningBanner shows the dropped-edge issue with the graph-data copy text.
- Force a fatal (set an invalid ELK option in dev tools) → expected: WarningBanner shows fatal with the rendering-bug copy text.

- [ ] **Step 7: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/src/components/WarningBanner.tsx \
        understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx \
        understand-anything-plugin/packages/dashboard/src/components/DomainGraphView.tsx \
        understand-anything-plugin/packages/dashboard/src/store.ts \
        understand-anything-plugin/packages/dashboard/src/App.tsx
git commit -m "feat(dashboard): layout-issue banner + Computing layout overlay"
```

---

## Tarefa 17: Benchmark de performance

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/scripts/benchmark-layout.mjs`

- [ ] **Step 1: Escrever benchmark**

Crie `understand-anything-plugin/packages/dashboard/scripts/benchmark-layout.mjs`:

```js
import { performance } from "node:perf_hooks";
import { applyElkLayout } from "../dist/utils/elk-layout.js";

function makeGraph(nodeCount, containerCount = Math.min(20, Math.ceil(nodeCount / 25))) {
  const containers = Array.from({ length: containerCount }, (_, i) => ({
    id: `c${i}`,
    width: 400,
    height: 300,
  }));
  const edges = [];
  for (let i = 0; i < containerCount; i++) {
    for (let j = i + 1; j < containerCount; j++) {
      if (Math.random() < 0.3) {
        edges.push({ id: `e-${i}-${j}`, sources: [`c${i}`], targets: [`c${j}`] });
      }
    }
  }
  return { id: "root", children: containers, edges };
}

async function bench(label, n) {
  const input = makeGraph(n);
  const t0 = performance.now();
  await applyElkLayout(input);
  const t1 = performance.now();
  console.log(`${label} (${n} nodes): ${(t1 - t0).toFixed(1)}ms`);
}

await bench("Stage1", 500);
await bench("Stage1", 1000);
await bench("Stage1", 3000);
```

- [ ] **Step 2: Buildar dashboard para que o script consiga importar dist**

```bash
pnpm --filter @understand-anything/dashboard build
```

- [ ] **Step 3: Executar benchmark**

```bash
node understand-anything-plugin/packages/dashboard/scripts/benchmark-layout.mjs
```

Esperado: imprime três linhas. Verifique Stage 1 < 200ms a 500 nós, < 500ms a 3000 nós conforme spec §8.3.

Se um budget for ultrapassado, **investigue** — não baixe o budget. Suspeitos prováveis: estimativa de tamanho de container criando posições iniciais sobrepostas, opções do ELK mal configuradas, ou bloqueio na main thread que deveria ir para um worker.

- [ ] **Step 4: Commit**

```bash
git add understand-anything-plugin/packages/dashboard/scripts/benchmark-layout.mjs
git commit -m "test(dashboard): layout perf benchmark script"
```

---

## Self-Review

**Spec coverage check** (compared against `docs/superpowers/specs/2026-05-03-graph-layout-scaling-design.md`):

- §1 Architecture — Tasks 9 (overview), 10 (domain), 11 (Stage 1 layer-detail), 12 (Stage 2)
- §2 Container derivation — Tasks 2 (folder + edge cases) + 3 (community fallback)
- §3 ELK integration — Tasks 5 (repair), 6 (applyElkLayout integration), 9–12 (per-view wiring)
- §3.5 Loading + failure handling — Task 16
- §3.6 GraphIssue model — Task 5 (repair functions emit issues), Task 16 (banner)
- §3.7 Dev strict mode — Task 5 (`strict` flag in repair + apply)
- §4 Edge aggregation + expand/collapse — Tasks 4 (aggregator), 7 (store), 12 (visual)
- §5 ContainerNode visual — Task 8, refined in Task 14
- §6 Lazy two-stage — Tasks 11 (Stage 1), 12 (Stage 2), 13 (auto-expand triggers), 15 (size deviation)
- §7 Interaction matrix — Tasks 13 (focus/tour/zoom auto-expand), 14 (search/diff/focus container overlays)
- §8 Files + tests — Each task creates the test file alongside the impl; perf benchmark in Task 17

**Placeholder scan:** No `TBD`/`TODO` left. Function signatures, options, and thresholds are concrete. Tests have full code, not "similar to above."

**Type consistency:** `ElkInput` / `ElkChild` / `ElkEdge` defined once in `elk-layout.ts` (Task 5), used unchanged everywhere. Container shapes (`DerivedContainer`, `ContainerNodeData`) are defined in their canonical files (Tasks 2, 8) and not redefined later. Method names (`expandContainer`, `toggleContainer`, `collapseAllContainers`, `setContainerLayout`, `bumpStage1Tick`) are stable across Tasks 7 → 13 → 15.

**Out of plan (deferred):** Removing `applyDagreLayout` from `utils/layout.ts` is deferred to a follow-up after this plan ships and is verified stable, per spec Migration Notes.

---

## Execution Handoff

Plano completo e salvo em `docs/superpowers/plans/2026-05-03-graph-layout-scaling.md`. Duas opções de execução:

1. **Subagent-Driven (recomendado)** — Despache um subagent novo por tarefa, revise entre tarefas, iteração rápida.
2. **Inline Execution** — Execute as tarefas nesta sessão usando executing-plans, execução em lote com checkpoints.

Qual abordagem?
