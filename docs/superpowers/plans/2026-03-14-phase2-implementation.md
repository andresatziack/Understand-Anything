# Understand Anything — Plano de Implementação da Fase 2 (Inteligência)

> **Para o Claude:** SUB-SKILL OBRIGATÓRIA: Use superpowers:executing-plans para implementar este plano tarefa por tarefa.

**Objetivo:** Adicionar a camada "Inteligência" — busca aprimorada, detecção de staleness, auto-detecção de layers, comando de skill `/understand-chat`, e um painel de chat no dashboard com Q&A consciente de contexto.

**Arquitetura:** Estende o monorepo existente (packages/core, packages/dashboard) com um novo pacote packages/skill. O core ganha search engine, detecção de staleness e detecção de layers. O dashboard ganha auto-layout, UX de busca aprimorada e painel de chat. O pacote skill fornece o comando `/understand-chat` do Claude Code.

**Stack Tecnológica:** Stack existente + fuse.js (busca fuzzy), zod (validação de schema), @dagrejs/dagre (layout de graph)

---

## Tarefa 1: Validação de Schema com Zod no Carregamento do Graph

**Arquivos:**
- Criar: `packages/core/src/schema.ts`
- Modificar: `packages/core/src/persistence/index.ts`
- Modificar: `packages/core/package.json`
- Criar: `packages/core/src/__tests__/schema.test.ts`

**Contexto:** Currently `loadGraph` does `JSON.parse()` with no validation. Corrupted or incompatible graph files silently produce broken data. Add zod schemas matching every type in `types.ts`, and validate on load. This is foundational — all Phase 2 features rely on correct graph data.

**Step 1: Instalar zod**

```bash
cd packages/core && pnpm add zod
```

**Step 2: Escrever testes que vão falhar**

```typescript
// packages/core/src/__tests__/schema.test.ts
import { describe, it, expect } from 'vitest';
import { KnowledgeGraphSchema, validateGraph } from '../schema.js';

describe('schema validation', () => {
  it('validates a correct knowledge graph', () => {
    const valid = {
      version: '1.0.0',
      project: {
        name: 'test',
        languages: ['typescript'],
        frameworks: [],
        description: 'A test project',
        analyzedAt: '2026-03-14T00:00:00Z',
        gitCommitHash: 'abc123',
      },
      nodes: [{
        id: 'file:src/index.ts',
        type: 'file',
        name: 'index.ts',
        filePath: 'src/index.ts',
        summary: 'Main entry',
        tags: ['entry'],
        complexity: 'simple',
      }],
      edges: [{
        source: 'file:src/index.ts',
        target: 'file:src/utils.ts',
        type: 'imports',
        direction: 'forward',
        weight: 0.7,
      }],
      layers: [],
      tour: [],
    };
    const result = validateGraph(valid);
    expect(result.success).toBe(true);
  });

  it('rejects graph with missing required fields', () => {
    const invalid = { version: '1.0.0' }; // missing everything else
    const result = validateGraph(invalid);
    expect(result.success).toBe(false);
    expect(result.errors).toBeDefined();
    expect(result.errors!.length).toBeGreaterThan(0);
  });

  it('rejects node with invalid type', () => {
    const invalid = {
      version: '1.0.0',
      project: {
        name: 'test', languages: [], frameworks: [],
        description: '', analyzedAt: '', gitCommitHash: '',
      },
      nodes: [{
        id: 'x', type: 'invalid_type', name: 'x',
        summary: '', tags: [], complexity: 'simple',
      }],
      edges: [], layers: [], tour: [],
    };
    const result = validateGraph(invalid);
    expect(result.success).toBe(false);
  });

  it('rejects edge with invalid EdgeType', () => {
    const invalid = {
      version: '1.0.0',
      project: {
        name: 'test', languages: [], frameworks: [],
        description: '', analyzedAt: '', gitCommitHash: '',
      },
      nodes: [],
      edges: [{
        source: 'a', target: 'b', type: 'fake_edge',
        direction: 'forward', weight: 0.5,
      }],
      layers: [], tour: [],
    };
    const result = validateGraph(invalid);
    expect(result.success).toBe(false);
  });

  it('coerces weight out of range to clamped value', () => {
    const graph = {
      version: '1.0.0',
      project: {
        name: 'test', languages: [], frameworks: [],
        description: '', analyzedAt: '', gitCommitHash: '',
      },
      nodes: [],
      edges: [{
        source: 'a', target: 'b', type: 'imports',
        direction: 'forward', weight: 1.5,
      }],
      layers: [], tour: [],
    };
    const result = validateGraph(graph);
    // weight > 1 should fail validation
    expect(result.success).toBe(false);
  });
});
```

**Step 3: Executar os testes para verificar que falham**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: FAIL — `schema.ts` ainda não existe.

**Step 4: Implementar schema.ts**

```typescript
// packages/core/src/schema.ts
import { z } from 'zod';

const EdgeTypeSchema = z.enum([
  'imports', 'exports', 'contains', 'inherits', 'implements',
  'calls', 'subscribes', 'publishes', 'middleware',
  'reads_from', 'writes_to', 'transforms', 'validates',
  'depends_on', 'tested_by', 'configures',
  'related', 'similar_to',
]);

const GraphNodeSchema = z.object({
  id: z.string(),
  type: z.enum(['file', 'function', 'class', 'module', 'concept']),
  name: z.string(),
  filePath: z.string().optional(),
  lineRange: z.tuple([z.number(), z.number()]).optional(),
  summary: z.string(),
  tags: z.array(z.string()),
  complexity: z.enum(['simple', 'moderate', 'complex']),
  languageNotes: z.string().optional(),
});

const GraphEdgeSchema = z.object({
  source: z.string(),
  target: z.string(),
  type: EdgeTypeSchema,
  direction: z.enum(['forward', 'backward', 'bidirectional']),
  description: z.string().optional(),
  weight: z.number().min(0).max(1),
});

const LayerSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
  nodeIds: z.array(z.string()),
});

const TourStepSchema = z.object({
  order: z.number(),
  title: z.string(),
  description: z.string(),
  nodeIds: z.array(z.string()),
  languageLesson: z.string().optional(),
});

const ProjectMetaSchema = z.object({
  name: z.string(),
  languages: z.array(z.string()),
  frameworks: z.array(z.string()),
  description: z.string(),
  analyzedAt: z.string(),
  gitCommitHash: z.string(),
});

export const KnowledgeGraphSchema = z.object({
  version: z.string(),
  project: ProjectMetaSchema,
  nodes: z.array(GraphNodeSchema),
  edges: z.array(GraphEdgeSchema),
  layers: z.array(LayerSchema),
  tour: z.array(TourStepSchema),
});

export interface ValidationResult {
  success: boolean;
  data?: z.infer<typeof KnowledgeGraphSchema>;
  errors?: string[];
}

export function validateGraph(data: unknown): ValidationResult {
  const result = KnowledgeGraphSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return {
    success: false,
    errors: result.error.issues.map(
      (i) => `${i.path.join('.')}: ${i.message}`
    ),
  };
}
```

**Step 5: Conectar a validação ao loadGraph da persistência**

Modifique `packages/core/src/persistence/index.ts`:

Adicione um parâmetro opcional `validate` (default `true`) ao `loadGraph`. Quando true, execute `validateGraph` no JSON parseado. Se a validação falhar, lance um erro com detalhes. Mantenha compatibilidade retroativa por meio do default validado.

```typescript
import { validateGraph } from '../schema.js';

export function loadGraph(
  baseDir: string,
  options?: { validate?: boolean }
): KnowledgeGraph | null {
  const graphPath = path.join(baseDir, '.understand-anything', 'knowledge-graph.json');
  if (!fs.existsSync(graphPath)) return null;
  const data = JSON.parse(fs.readFileSync(graphPath, 'utf-8'));
  if (options?.validate !== false) {
    const result = validateGraph(data);
    if (!result.success) {
      throw new Error(
        `Invalid knowledge graph: ${result.errors?.join('; ')}`
      );
    }
    return result.data as KnowledgeGraph;
  }
  return data as KnowledgeGraph;
}
```

**Step 6: Atualizar barrel export**

Adicione em `packages/core/src/index.ts`:
```typescript
export { KnowledgeGraphSchema, validateGraph, type ValidationResult } from './schema.js';
```

**Step 7: Executar os testes para verificar que passam**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: TODOS PASSAM

**Step 8: Commit**

```bash
git add packages/core/src/schema.ts packages/core/src/__tests__/schema.test.ts packages/core/src/persistence/index.ts packages/core/src/index.ts packages/core/package.json pnpm-lock.yaml
git commit -m "feat(core): add zod schema validation for knowledge graph loading"
```

---

## Tarefa 2: Search Engine Aprimorado com Matching Fuzzy

**Arquivos:**
- Criar: `packages/core/src/search.ts`
- Criar: `packages/core/src/__tests__/search.test.ts`
- Modificar: `packages/core/src/index.ts`
- Modificar: `packages/core/package.json`

**Contexto:** The current dashboard store has basic case-insensitive substring search across name/summary/tags. Phase 2 needs fuzzy matching and relevance scoring. We build a reusable `SearchEngine` in core (used by both dashboard and skill), powered by Fuse.js. The dashboard store will switch to using this engine in a later task.

**Step 1: Instalar fuse.js**

```bash
cd packages/core && pnpm add fuse.js
```

**Step 2: Escrever testes que vão falhar**

```typescript
// packages/core/src/__tests__/search.test.ts
import { describe, it, expect } from 'vitest';
import { SearchEngine } from '../search.js';
import type { GraphNode } from '../types.js';

const makeNode = (overrides: Partial<GraphNode>): GraphNode => ({
  id: 'test',
  type: 'file',
  name: 'test',
  summary: '',
  tags: [],
  complexity: 'simple',
  ...overrides,
});

describe('SearchEngine', () => {
  it('returns empty results for empty query', () => {
    const engine = new SearchEngine([makeNode({ id: 'a', name: 'foo' })]);
    expect(engine.search('')).toEqual([]);
  });

  it('finds exact name match', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'AuthController' }),
      makeNode({ id: 'b', name: 'UserService' }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('AuthController');
    expect(results.length).toBe(1);
    expect(results[0].nodeId).toBe('a');
  });

  it('finds fuzzy name match', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'AuthenticationController' }),
      makeNode({ id: 'b', name: 'DatabaseConnection' }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('auth contrl');
    expect(results.some(r => r.nodeId === 'a')).toBe(true);
  });

  it('searches across summary field', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'handler.ts', summary: 'Handles WebSocket communication' }),
      makeNode({ id: 'b', name: 'utils.ts', summary: 'General utilities' }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('communication');
    expect(results[0].nodeId).toBe('a');
  });

  it('searches across tags', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'x.ts', tags: ['authentication', 'security'] }),
      makeNode({ id: 'b', name: 'y.ts', tags: ['database'] }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('security');
    expect(results[0].nodeId).toBe('a');
  });

  it('ranks name matches higher than summary matches', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'utils.ts', summary: 'Contains the auth function' }),
      makeNode({ id: 'b', name: 'auth.ts', summary: 'Some utility functions' }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('auth');
    expect(results[0].nodeId).toBe('b'); // name match ranks higher
  });

  it('returns scored results', () => {
    const nodes = [makeNode({ id: 'a', name: 'foo' })];
    const engine = new SearchEngine(nodes);
    const results = engine.search('foo');
    expect(results[0]).toHaveProperty('score');
    expect(typeof results[0].score).toBe('number');
  });

  it('can update nodes and re-index', () => {
    const engine = new SearchEngine([makeNode({ id: 'a', name: 'old' })]);
    engine.updateNodes([makeNode({ id: 'b', name: 'new' })]);
    const results = engine.search('new');
    expect(results[0].nodeId).toBe('b');
    expect(engine.search('old')).toEqual([]);
  });

  it('filters by node type', () => {
    const nodes = [
      makeNode({ id: 'a', name: 'auth', type: 'file' }),
      makeNode({ id: 'b', name: 'auth', type: 'function' }),
    ];
    const engine = new SearchEngine(nodes);
    const results = engine.search('auth', { types: ['function'] });
    expect(results.length).toBe(1);
    expect(results[0].nodeId).toBe('b');
  });
});
```

**Step 3: Executar os testes para verificar que falham**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: FAIL — `search.ts` não existe.

**Step 4: Implementar SearchEngine**

```typescript
// packages/core/src/search.ts
import Fuse from 'fuse.js';
import type { GraphNode } from './types.js';

export interface SearchResult {
  nodeId: string;
  score: number; // 0 = perfect match, 1 = worst match
}

export interface SearchOptions {
  types?: GraphNode['type'][];
  limit?: number;
}

export class SearchEngine {
  private fuse: Fuse<GraphNode>;
  private nodes: GraphNode[];

  constructor(nodes: GraphNode[]) {
    this.nodes = nodes;
    this.fuse = this.createIndex(nodes);
  }

  private createIndex(nodes: GraphNode[]): Fuse<GraphNode> {
    return new Fuse(nodes, {
      keys: [
        { name: 'name', weight: 0.4 },
        { name: 'tags', weight: 0.3 },
        { name: 'summary', weight: 0.2 },
        { name: 'languageNotes', weight: 0.1 },
      ],
      threshold: 0.4,
      includeScore: true,
      ignoreLocation: true,
    });
  }

  search(query: string, options?: SearchOptions): SearchResult[] {
    if (!query.trim()) return [];

    let results = this.fuse.search(query);

    if (options?.types?.length) {
      results = results.filter((r) => options.types!.includes(r.item.type));
    }

    const limit = options?.limit ?? 50;

    return results.slice(0, limit).map((r) => ({
      nodeId: r.item.id,
      score: r.score ?? 1,
    }));
  }

  updateNodes(nodes: GraphNode[]): void {
    this.nodes = nodes;
    this.fuse = this.createIndex(nodes);
  }
}
```

**Step 5: Atualizar barrel export**

Adicione em `packages/core/src/index.ts`:
```typescript
export { SearchEngine, type SearchResult, type SearchOptions } from './search.js';
```

**Step 6: Executar os testes para verificar que passam**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: TODOS PASSAM

**Step 7: Commit**

```bash
git add packages/core/src/search.ts packages/core/src/__tests__/search.test.ts packages/core/src/index.ts packages/core/package.json pnpm-lock.yaml
git commit -m "feat(core): add fuzzy search engine with Fuse.js"
```

---

## Tarefa 3: Auto-Layout com Dagre na Graph View

**Arquivos:**
- Criar: `packages/dashboard/src/utils/layout.ts`
- Modificar: `packages/dashboard/src/components/GraphView.tsx`
- Modificar: `packages/dashboard/package.json`

**Contexto:** Currently GraphView positions nodes in a simple `(index % 3) * 300` grid. This produces chaotic graphs for real projects. Add dagre (hierarchical graph layout) to compute positions respecting edge direction. Nodes flow top-to-bottom, with edges determining hierarchy.

**Step 1: Instalar dagre**

```bash
cd packages/dashboard && pnpm add @dagrejs/dagre
```

**Step 2: Criar utilitário de layout**

```typescript
// packages/dashboard/src/utils/layout.ts
import dagre from '@dagrejs/dagre';
import type { Node, Edge } from '@xyflow/react';

const NODE_WIDTH = 280;
const NODE_HEIGHT = 120;

export function applyDagreLayout(
  nodes: Node[],
  edges: Edge[],
  direction: 'TB' | 'LR' = 'TB'
): { nodes: Node[]; edges: Edge[] } {
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({
    rankdir: direction,
    nodesep: 60,
    ranksep: 80,
    marginx: 20,
    marginy: 20,
  });

  nodes.forEach((node) => {
    g.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT });
  });

  edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target);
  });

  dagre.layout(g);

  const layoutedNodes = nodes.map((node) => {
    const pos = g.node(node.id);
    return {
      ...node,
      position: {
        x: pos.x - NODE_WIDTH / 2,
        y: pos.y - NODE_HEIGHT / 2,
      },
    };
  });

  return { nodes: layoutedNodes, edges };
}
```

**Step 3: Atualizar GraphView para usar layout dagre**

Substitua o posicionamento em grade `(index % 3) * 300` em `GraphView.tsx` por uma chamada a `applyDagreLayout`. As principais mudanças:

1. Importe `applyDagreLayout` de `../utils/layout.js`
2. Construa flow nodes/edges a partir dos dados do graph (sem position)
3. Passe pelo `applyDagreLayout` para obter nós posicionados
4. Use `useMemo` para recomputar o layout apenas quando graph/search mudam

O componente deve manter toda a funcionalidade existente (custom nodes, destaque de busca, seleção, controls, minimap).

**Step 4: Verificar manualmente**

```bash
pnpm dev:dashboard
```
Abra http://localhost:5173 — o graph deve exibir nós em um layout hierárquico seguindo a direção das arestas, não em um grid plano.

**Step 5: Commit**

```bash
git add packages/dashboard/src/utils/layout.ts packages/dashboard/src/components/GraphView.tsx packages/dashboard/package.json pnpm-lock.yaml
git commit -m "feat(dashboard): add dagre auto-layout for hierarchical graph visualization"
```

---

## Tarefa 4: Detecção de Staleness + Updates Incrementais

**Arquivos:**
- Criar: `packages/core/src/staleness.ts`
- Criar: `packages/core/src/__tests__/staleness.test.ts`
- Modificar: `packages/core/src/index.ts`

**Contexto:** The design doc specifies an auto-sync flow: read `meta.json` → git diff against last hash → re-analyze only changed files → merge into existing graph. This task builds the staleness detection and graph merging logic. It does NOT invoke LLM or tree-sitter (that's orchestration, done by the skill). It provides the building blocks: detect changed files, merge updated nodes/edges into an existing graph.

**Step 1: Escrever testes que vão falhar**

```typescript
// packages/core/src/__tests__/staleness.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  getChangedFiles,
  isStale,
  mergeGraphUpdate,
} from '../staleness.js';
import type { KnowledgeGraph, GraphNode, GraphEdge } from '../types.js';

// Mock child_process.execSync for git commands
vi.mock('child_process', () => ({
  execSync: vi.fn(),
}));

import { execSync } from 'child_process';
const mockExecSync = vi.mocked(execSync);

describe('staleness detection', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe('getChangedFiles', () => {
    it('returns changed file list from git diff', () => {
      mockExecSync.mockReturnValue(Buffer.from('src/a.ts\nsrc/b.ts\n'));
      const files = getChangedFiles('/project', 'abc123');
      expect(files).toEqual(['src/a.ts', 'src/b.ts']);
      expect(mockExecSync).toHaveBeenCalledWith(
        'git diff abc123..HEAD --name-only',
        expect.objectContaining({ cwd: '/project' })
      );
    });

    it('returns empty array when no changes', () => {
      mockExecSync.mockReturnValue(Buffer.from(''));
      const files = getChangedFiles('/project', 'abc123');
      expect(files).toEqual([]);
    });

    it('returns empty array on git error', () => {
      mockExecSync.mockImplementation(() => { throw new Error('git error'); });
      const files = getChangedFiles('/project', 'abc123');
      expect(files).toEqual([]);
    });
  });

  describe('isStale', () => {
    it('returns stale when files have changed', () => {
      mockExecSync.mockReturnValue(Buffer.from('src/a.ts\n'));
      const result = isStale('/project', 'abc123');
      expect(result.stale).toBe(true);
      expect(result.changedFiles).toEqual(['src/a.ts']);
    });

    it('returns not stale when no files changed', () => {
      mockExecSync.mockReturnValue(Buffer.from(''));
      const result = isStale('/project', 'abc123');
      expect(result.stale).toBe(false);
      expect(result.changedFiles).toEqual([]);
    });
  });

  describe('mergeGraphUpdate', () => {
    const baseGraph: KnowledgeGraph = {
      version: '1.0.0',
      project: {
        name: 'test',
        languages: ['typescript'],
        frameworks: [],
        description: '',
        analyzedAt: '2026-01-01T00:00:00Z',
        gitCommitHash: 'old',
      },
      nodes: [
        { id: 'file:src/a.ts', type: 'file', name: 'a.ts', filePath: 'src/a.ts', summary: 'old', tags: [], complexity: 'simple' },
        { id: 'file:src/b.ts', type: 'file', name: 'b.ts', filePath: 'src/b.ts', summary: 'unchanged', tags: [], complexity: 'simple' },
        { id: 'func:src/a.ts:foo', type: 'function', name: 'foo', filePath: 'src/a.ts', summary: 'old foo', tags: [], complexity: 'simple' },
      ],
      edges: [
        { source: 'file:src/a.ts', target: 'file:src/b.ts', type: 'imports', direction: 'forward', weight: 0.7 },
        { source: 'file:src/a.ts', target: 'func:src/a.ts:foo', type: 'contains', direction: 'forward', weight: 1.0 },
      ],
      layers: [],
      tour: [],
    };

    it('replaces nodes for changed files', () => {
      const newNodes: GraphNode[] = [
        { id: 'file:src/a.ts', type: 'file', name: 'a.ts', filePath: 'src/a.ts', summary: 'updated', tags: ['new'], complexity: 'moderate' },
        { id: 'func:src/a.ts:bar', type: 'function', name: 'bar', filePath: 'src/a.ts', summary: 'new func', tags: [], complexity: 'simple' },
      ];
      const newEdges: GraphEdge[] = [
        { source: 'file:src/a.ts', target: 'func:src/a.ts:bar', type: 'contains', direction: 'forward', weight: 1.0 },
      ];

      const merged = mergeGraphUpdate(baseGraph, ['src/a.ts'], newNodes, newEdges, 'newHash');

      // Old a.ts nodes removed, new ones added
      expect(merged.nodes.find(n => n.id === 'func:src/a.ts:foo')).toBeUndefined();
      expect(merged.nodes.find(n => n.id === 'func:src/a.ts:bar')).toBeDefined();
      expect(merged.nodes.find(n => n.id === 'file:src/a.ts')?.summary).toBe('updated');

      // b.ts unchanged
      expect(merged.nodes.find(n => n.id === 'file:src/b.ts')?.summary).toBe('unchanged');

      // Git hash updated
      expect(merged.project.gitCommitHash).toBe('newHash');
    });

    it('removes edges originating from changed files', () => {
      const newNodes: GraphNode[] = [
        { id: 'file:src/a.ts', type: 'file', name: 'a.ts', filePath: 'src/a.ts', summary: 'updated', tags: [], complexity: 'simple' },
      ];
      const newEdges: GraphEdge[] = [
        { source: 'file:src/a.ts', target: 'file:src/b.ts', type: 'imports', direction: 'forward', weight: 0.9 },
      ];

      const merged = mergeGraphUpdate(baseGraph, ['src/a.ts'], newNodes, newEdges, 'newHash');

      // Old contains edge removed, new imports edge present with new weight
      const importEdge = merged.edges.find(e => e.source === 'file:src/a.ts' && e.target === 'file:src/b.ts');
      expect(importEdge?.weight).toBe(0.9);
      expect(merged.edges.find(e => e.type === 'contains')).toBeUndefined();
    });

    it('updates analyzedAt timestamp', () => {
      const merged = mergeGraphUpdate(baseGraph, ['src/a.ts'], [], [], 'newHash');
      expect(merged.project.analyzedAt).not.toBe('2026-01-01T00:00:00Z');
    });
  });
});
```

**Step 3: Executar os testes para verificar que falham**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: FAIL — `staleness.ts` não existe.

**Step 4: Implementar staleness.ts**

```typescript
// packages/core/src/staleness.ts
import { execSync } from 'child_process';
import type { KnowledgeGraph, GraphNode, GraphEdge } from './types.js';

export interface StalenessResult {
  stale: boolean;
  changedFiles: string[];
}

export function getChangedFiles(projectDir: string, lastCommitHash: string): string[] {
  try {
    const output = execSync(`git diff ${lastCommitHash}..HEAD --name-only`, {
      cwd: projectDir,
      encoding: 'utf-8',
    });
    return output.trim().split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

export function isStale(projectDir: string, lastCommitHash: string): StalenessResult {
  const changedFiles = getChangedFiles(projectDir, lastCommitHash);
  return {
    stale: changedFiles.length > 0,
    changedFiles,
  };
}

export function mergeGraphUpdate(
  existingGraph: KnowledgeGraph,
  changedFilePaths: string[],
  newNodes: GraphNode[],
  newEdges: GraphEdge[],
  newCommitHash: string,
): KnowledgeGraph {
  const changedSet = new Set(changedFilePaths);

  // Remove old nodes belonging to changed files
  const keptNodes = existingGraph.nodes.filter(
    (node) => !node.filePath || !changedSet.has(node.filePath)
  );

  // Remove old edges where source node belongs to a changed file
  const changedNodeIds = new Set(
    existingGraph.nodes
      .filter((n) => n.filePath && changedSet.has(n.filePath))
      .map((n) => n.id)
  );
  const keptEdges = existingGraph.edges.filter(
    (edge) => !changedNodeIds.has(edge.source)
  );

  return {
    ...existingGraph,
    project: {
      ...existingGraph.project,
      gitCommitHash: newCommitHash,
      analyzedAt: new Date().toISOString(),
    },
    nodes: [...keptNodes, ...newNodes],
    edges: [...keptEdges, ...newEdges],
  };
}
```

**Step 5: Atualizar barrel export**

Adicione em `packages/core/src/index.ts`:
```typescript
export {
  getChangedFiles,
  isStale,
  mergeGraphUpdate,
  type StalenessResult,
} from './staleness.js';
```

**Step 6: Executar os testes para verificar que passam**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: TODOS PASSAM

**Step 7: Commit**

```bash
git add packages/core/src/staleness.ts packages/core/src/__tests__/staleness.test.ts packages/core/src/index.ts
git commit -m "feat(core): add staleness detection and incremental graph merging"
```

---

## Tarefa 5: Auto-Detecção de Layers

**Arquivos:**
- Criar: `packages/core/src/analyzer/layer-detector.ts`
- Criar: `packages/core/src/__tests__/layer-detector.test.ts`
- Modificar: `packages/core/src/index.ts`

**Contexto:** Layer detection groups nodes into logical layers (e.g., "API Layer", "Data Layer", "UI Layer") based on file paths, naming patterns, and edge structure. This uses a heuristic approach: analyze file paths for common patterns (routes/, controllers/, models/, services/, etc.) and node connectivity. An LLM prompt builder is provided for enhanced detection when LLM is available, but the heuristic works standalone. Layers populate the `layers[]` field in the KnowledgeGraph.

**Step 1: Escrever testes que vão falhar**

```typescript
// packages/core/src/__tests__/layer-detector.test.ts
import { describe, it, expect } from 'vitest';
import { detectLayers, buildLayerDetectionPrompt, parseLayerDetectionResponse } from '../analyzer/layer-detector.js';
import type { KnowledgeGraph } from '../types.js';

const makeGraph = (nodes: Array<{ id: string; filePath: string; name: string }>): KnowledgeGraph => ({
  version: '1.0.0',
  project: {
    name: 'test', languages: ['typescript'], frameworks: [],
    description: '', analyzedAt: '', gitCommitHash: '',
  },
  nodes: nodes.map((n) => ({
    ...n,
    type: 'file' as const,
    summary: '',
    tags: [],
    complexity: 'simple' as const,
  })),
  edges: [],
  layers: [],
  tour: [],
});

describe('layer detection (heuristic)', () => {
  it('detects API/routes layer', () => {
    const graph = makeGraph([
      { id: 'file:src/routes/users.ts', filePath: 'src/routes/users.ts', name: 'users.ts' },
      { id: 'file:src/routes/auth.ts', filePath: 'src/routes/auth.ts', name: 'auth.ts' },
      { id: 'file:src/models/user.ts', filePath: 'src/models/user.ts', name: 'user.ts' },
    ]);
    const layers = detectLayers(graph);
    const apiLayer = layers.find((l) => l.name.toLowerCase().includes('api') || l.name.toLowerCase().includes('route'));
    expect(apiLayer).toBeDefined();
    expect(apiLayer!.nodeIds).toContain('file:src/routes/users.ts');
  });

  it('detects data/model layer', () => {
    const graph = makeGraph([
      { id: 'file:src/models/user.ts', filePath: 'src/models/user.ts', name: 'user.ts' },
      { id: 'file:src/models/post.ts', filePath: 'src/models/post.ts', name: 'post.ts' },
      { id: 'file:src/index.ts', filePath: 'src/index.ts', name: 'index.ts' },
    ]);
    const layers = detectLayers(graph);
    const dataLayer = layers.find((l) => l.name.toLowerCase().includes('data') || l.name.toLowerCase().includes('model'));
    expect(dataLayer).toBeDefined();
    expect(dataLayer!.nodeIds).toContain('file:src/models/user.ts');
  });

  it('puts unmatched files in a general layer', () => {
    const graph = makeGraph([
      { id: 'file:src/foo.ts', filePath: 'src/foo.ts', name: 'foo.ts' },
    ]);
    const layers = detectLayers(graph);
    expect(layers.length).toBeGreaterThan(0);
    expect(layers.some((l) => l.nodeIds.includes('file:src/foo.ts'))).toBe(true);
  });

  it('assigns unique IDs to layers', () => {
    const graph = makeGraph([
      { id: 'file:src/routes/a.ts', filePath: 'src/routes/a.ts', name: 'a.ts' },
      { id: 'file:src/models/b.ts', filePath: 'src/models/b.ts', name: 'b.ts' },
    ]);
    const layers = detectLayers(graph);
    const ids = layers.map((l) => l.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('only assigns file nodes to layers', () => {
    const graph: KnowledgeGraph = {
      ...makeGraph([{ id: 'file:src/routes/a.ts', filePath: 'src/routes/a.ts', name: 'a.ts' }]),
      nodes: [
        { id: 'file:src/routes/a.ts', type: 'file', filePath: 'src/routes/a.ts', name: 'a.ts', summary: '', tags: [], complexity: 'simple' },
        { id: 'func:src/routes/a.ts:handler', type: 'function', filePath: 'src/routes/a.ts', name: 'handler', summary: '', tags: [], complexity: 'simple' },
      ],
    };
    const layers = detectLayers(graph);
    const allNodeIds = layers.flatMap((l) => l.nodeIds);
    expect(allNodeIds).not.toContain('func:src/routes/a.ts:handler');
  });
});

describe('LLM layer detection prompt', () => {
  it('builds a prompt containing file paths', () => {
    const graph = makeGraph([
      { id: 'file:src/routes/a.ts', filePath: 'src/routes/a.ts', name: 'a.ts' },
    ]);
    const prompt = buildLayerDetectionPrompt(graph);
    expect(prompt).toContain('src/routes/a.ts');
    expect(prompt).toContain('JSON');
  });

  it('parses a valid LLM response', () => {
    const response = JSON.stringify({
      layers: [
        { name: 'API Layer', description: 'HTTP routes', filePatterns: ['src/routes/'] },
        { name: 'Data Layer', description: 'Models', filePatterns: ['src/models/'] },
      ],
    });
    const result = parseLayerDetectionResponse(response);
    expect(result).not.toBeNull();
    expect(result!.length).toBe(2);
    expect(result![0].name).toBe('API Layer');
  });

  it('returns null for invalid response', () => {
    expect(parseLayerDetectionResponse('not json')).toBeNull();
  });
});
```

**Step 3: Executar os testes para verificar que falham**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: FAIL — `layer-detector.ts` não existe.

**Step 4: Implementar layer-detector.ts**

```typescript
// packages/core/src/analyzer/layer-detector.ts
import type { KnowledgeGraph, Layer } from '../types.js';

// Heuristic layer patterns: directory path substring → layer info
const LAYER_PATTERNS: Array<{ patterns: string[]; name: string; description: string }> = [
  {
    patterns: ['route', 'controller', 'handler', 'endpoint', 'api/'],
    name: 'API Layer',
    description: 'HTTP routes, controllers, and API endpoint handlers',
  },
  {
    patterns: ['service', 'usecase', 'use-case', 'business'],
    name: 'Service Layer',
    description: 'Business logic and service orchestration',
  },
  {
    patterns: ['model', 'entity', 'schema', 'database', 'db/', 'migration', 'repository', 'repo'],
    name: 'Data Layer',
    description: 'Data models, database schemas, and persistence',
  },
  {
    patterns: ['component', 'view', 'page', 'screen', 'layout', 'widget', 'ui/'],
    name: 'UI Layer',
    description: 'User interface components and views',
  },
  {
    patterns: ['middleware', 'interceptor', 'guard', 'filter', 'pipe'],
    name: 'Middleware Layer',
    description: 'Request processing middleware and interceptors',
  },
  {
    patterns: ['util', 'helper', 'lib/', 'common/', 'shared/'],
    name: 'Utility Layer',
    description: 'Shared utilities, helpers, and common code',
  },
  {
    patterns: ['test', 'spec', '__test__', '__spec__'],
    name: 'Test Layer',
    description: 'Tests and test utilities',
  },
  {
    patterns: ['config', 'setting', 'env'],
    name: 'Configuration Layer',
    description: 'Application configuration and environment settings',
  },
];

export function detectLayers(graph: KnowledgeGraph): Layer[] {
  const fileNodes = graph.nodes.filter((n) => n.type === 'file' && n.filePath);

  const layerMap = new Map<string, { name: string; description: string; nodeIds: string[] }>();
  const assignedNodes = new Set<string>();

  // Match file paths against patterns
  for (const node of fileNodes) {
    const fp = node.filePath!.toLowerCase();
    for (const layerDef of LAYER_PATTERNS) {
      if (layerDef.patterns.some((p) => fp.includes(p))) {
        if (!layerMap.has(layerDef.name)) {
          layerMap.set(layerDef.name, {
            name: layerDef.name,
            description: layerDef.description,
            nodeIds: [],
          });
        }
        layerMap.get(layerDef.name)!.nodeIds.push(node.id);
        assignedNodes.add(node.id);
        break; // First matching pattern wins
      }
    }
  }

  // Unassigned files go to "Core" layer
  const unassigned = fileNodes.filter((n) => !assignedNodes.has(n.id));
  if (unassigned.length > 0) {
    layerMap.set('Core', {
      name: 'Core',
      description: 'Core application files and entry points',
      nodeIds: unassigned.map((n) => n.id),
    });
  }

  // Convert to Layer[] with unique IDs
  return Array.from(layerMap.values()).map((entry, i) => ({
    id: `layer:${entry.name.toLowerCase().replace(/\s+/g, '-')}`,
    name: entry.name,
    description: entry.description,
    nodeIds: entry.nodeIds,
  }));
}

// --- LLM-enhanced layer detection ---

export function buildLayerDetectionPrompt(graph: KnowledgeGraph): string {
  const filePaths = graph.nodes
    .filter((n) => n.type === 'file' && n.filePath)
    .map((n) => n.filePath!);

  return `Analyze this project's file structure and identify logical architectural layers.

File paths:
${filePaths.map((f) => `- ${f}`).join('\n')}

Respond with JSON only:
{
  "layers": [
    {
      "name": "Layer Name",
      "description": "What this layer does",
      "filePatterns": ["path/prefix/"]
    }
  ]
}

Rules:
- Identify 3-7 logical layers
- Each layer should have a clear architectural purpose
- filePatterns are path prefixes that match files in that layer
- Common layers: API, Service/Business Logic, Data/Models, UI, Middleware, Utility, Configuration, Tests`;
}

interface LLMLayerResponse {
  name: string;
  description: string;
  filePatterns: string[];
}

export function parseLayerDetectionResponse(response: string): LLMLayerResponse[] | null {
  try {
    // Handle markdown fences
    let cleaned = response.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```\w*\n?/, '').replace(/\n?```$/, '');
    }
    const parsed = JSON.parse(cleaned);
    if (!parsed.layers || !Array.isArray(parsed.layers)) return null;
    return parsed.layers.map((l: Record<string, unknown>) => ({
      name: String(l.name || ''),
      description: String(l.description || ''),
      filePatterns: Array.isArray(l.filePatterns) ? l.filePatterns.map(String) : [],
    }));
  } catch {
    return null;
  }
}

/**
 * Convert LLM layer response into Layer[] by matching file patterns against graph nodes.
 */
export function applyLLMLayers(
  graph: KnowledgeGraph,
  llmLayers: LLMLayerResponse[],
): Layer[] {
  const fileNodes = graph.nodes.filter((n) => n.type === 'file' && n.filePath);
  const assignedNodes = new Set<string>();

  const layers: Layer[] = llmLayers.map((ll) => {
    const matching = fileNodes.filter((n) => {
      if (assignedNodes.has(n.id)) return false;
      return ll.filePatterns.some((p) => n.filePath!.includes(p));
    });
    matching.forEach((n) => assignedNodes.add(n.id));
    return {
      id: `layer:${ll.name.toLowerCase().replace(/\s+/g, '-')}`,
      name: ll.name,
      description: ll.description,
      nodeIds: matching.map((n) => n.id),
    };
  });

  // Unassigned files
  const unassigned = fileNodes.filter((n) => !assignedNodes.has(n.id));
  if (unassigned.length > 0) {
    layers.push({
      id: 'layer:other',
      name: 'Other',
      description: 'Files not matching any detected layer',
      nodeIds: unassigned.map((n) => n.id),
    });
  }

  return layers.filter((l) => l.nodeIds.length > 0);
}
```

**Step 5: Atualizar barrel export**

Adicione em `packages/core/src/index.ts`:
```typescript
export {
  detectLayers,
  buildLayerDetectionPrompt,
  parseLayerDetectionResponse,
  applyLLMLayers,
} from './analyzer/layer-detector.js';
```

**Step 6: Executar os testes para verificar que passam**

```bash
pnpm --filter @understand-anything/core test
```
Esperado: TODOS PASSAM

**Step 7: Commit**

```bash
git add packages/core/src/analyzer/layer-detector.ts packages/core/src/__tests__/layer-detector.test.ts packages/core/src/index.ts
git commit -m "feat(core): add heuristic and LLM-based layer auto-detection"
```

---

## Tarefa 6: Scaffolding do Pacote Skill + Comando `/understand-chat`

**Arquivos:**
- Criar: `packages/skill/package.json`
- Criar: `packages/skill/tsconfig.json`
- Criar: `packages/skill/src/understand-chat.ts`
- Criar: `packages/skill/src/context-builder.ts`
- Criar: `packages/skill/src/__tests__/context-builder.test.ts`
- Criar: `packages/skill/.claude/skills/understand-chat.md` (the skill definition file)

**Contexto:** This is the first Claude Code skill command. `/understand-chat` provides in-terminal Q&A using the knowledge graph. As a Claude Code skill, it needs: (1) a skill markdown file that Claude loads, (2) a context-builder that extracts relevant graph context for a user query, (3) the prompt template that combines context + query. The skill reads the persisted `.understand-anything/knowledge-graph.json` and uses the active Claude session for LLM — no separate API call needed.

**Step 1: Criar skill package.json**

```json
{
  "name": "@understand-anything/skill",
  "version": "0.1.0",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "vitest run"
  },
  "dependencies": {
    "@understand-anything/core": "workspace:*"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "typescript": "^5.7.0",
    "vitest": "^3.1.0"
  }
}
```

**Step 2: Criar skill tsconfig.json**

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

**Step 3: Escrever testes que vão falhar para o context-builder**

```typescript
// packages/skill/src/__tests__/context-builder.test.ts
import { describe, it, expect } from 'vitest';
import { buildChatContext, formatContextForPrompt } from '../context-builder.js';
import type { KnowledgeGraph } from '@understand-anything/core';

const sampleGraph: KnowledgeGraph = {
  version: '1.0.0',
  project: {
    name: 'test-project',
    languages: ['typescript'],
    frameworks: ['express'],
    description: 'A sample web API',
    analyzedAt: '2026-03-14T00:00:00Z',
    gitCommitHash: 'abc123',
  },
  nodes: [
    { id: 'file:src/auth/login.ts', type: 'file', name: 'login.ts', filePath: 'src/auth/login.ts', summary: 'Handles user authentication and login flow', tags: ['auth', 'login', 'security'], complexity: 'moderate' },
    { id: 'func:src/auth/login.ts:authenticate', type: 'function', name: 'authenticate', filePath: 'src/auth/login.ts', summary: 'Validates credentials and returns JWT', tags: ['auth', 'jwt'], complexity: 'complex' },
    { id: 'file:src/routes/api.ts', type: 'file', name: 'api.ts', filePath: 'src/routes/api.ts', summary: 'Express API route definitions', tags: ['routes', 'api', 'express'], complexity: 'simple' },
    { id: 'file:src/db/connection.ts', type: 'file', name: 'connection.ts', filePath: 'src/db/connection.ts', summary: 'Database connection pooling', tags: ['database', 'connection'], complexity: 'moderate' },
  ],
  edges: [
    { source: 'file:src/routes/api.ts', target: 'file:src/auth/login.ts', type: 'imports', direction: 'forward', weight: 0.7 },
    { source: 'func:src/auth/login.ts:authenticate', target: 'file:src/db/connection.ts', type: 'reads_from', direction: 'forward', weight: 0.6 },
  ],
  layers: [
    { id: 'layer:api', name: 'API Layer', description: 'HTTP routes', nodeIds: ['file:src/routes/api.ts'] },
    { id: 'layer:auth', name: 'Auth Layer', description: 'Authentication', nodeIds: ['file:src/auth/login.ts', 'func:src/auth/login.ts:authenticate'] },
  ],
  tour: [],
};

describe('buildChatContext', () => {
  it('finds relevant nodes for a query', () => {
    const context = buildChatContext(sampleGraph, 'how does authentication work?');
    expect(context.relevantNodes.some((n) => n.id.includes('auth'))).toBe(true);
  });

  it('includes connected nodes', () => {
    const context = buildChatContext(sampleGraph, 'authentication');
    const nodeIds = context.relevantNodes.map((n) => n.id);
    // Should include auth nodes AND their connections (db/connection, routes/api)
    expect(nodeIds.length).toBeGreaterThan(1);
  });

  it('includes project metadata', () => {
    const context = buildChatContext(sampleGraph, 'anything');
    expect(context.projectName).toBe('test-project');
    expect(context.projectDescription).toBe('A sample web API');
  });

  it('includes relevant layers', () => {
    const context = buildChatContext(sampleGraph, 'authentication');
    expect(context.relevantLayers.length).toBeGreaterThan(0);
  });
});

describe('formatContextForPrompt', () => {
  it('produces a string containing node summaries', () => {
    const context = buildChatContext(sampleGraph, 'authentication');
    const formatted = formatContextForPrompt(context);
    expect(formatted).toContain('login.ts');
    expect(formatted).toContain('authentication');
  });

  it('includes edge descriptions', () => {
    const context = buildChatContext(sampleGraph, 'authentication');
    const formatted = formatContextForPrompt(context);
    expect(formatted).toContain('imports');
  });
});
```

**Step 4: Executar os testes para verificar que falham**

```bash
pnpm install && pnpm --filter @understand-anything/skill test
```
Esperado: FAIL — arquivos ainda não existem.

**Step 5: Implementar context-builder.ts**

```typescript
// packages/skill/src/context-builder.ts
import { SearchEngine } from '@understand-anything/core';
import type { KnowledgeGraph, GraphNode, GraphEdge, Layer } from '@understand-anything/core';

export interface ChatContext {
  projectName: string;
  projectDescription: string;
  languages: string[];
  frameworks: string[];
  relevantNodes: GraphNode[];
  relevantEdges: GraphEdge[];
  relevantLayers: Layer[];
  query: string;
}

export function buildChatContext(
  graph: KnowledgeGraph,
  query: string,
  maxNodes: number = 15,
): ChatContext {
  const searchEngine = new SearchEngine(graph.nodes);
  const searchResults = searchEngine.search(query, { limit: maxNodes });

  // Collect directly matching nodes
  const relevantNodeIds = new Set(searchResults.map((r) => r.nodeId));

  // Expand to connected nodes (1 hop)
  for (const edge of graph.edges) {
    if (relevantNodeIds.has(edge.source)) relevantNodeIds.add(edge.target);
    if (relevantNodeIds.has(edge.target)) relevantNodeIds.add(edge.source);
  }

  const relevantNodes = graph.nodes.filter((n) => relevantNodeIds.has(n.id));
  const relevantEdges = graph.edges.filter(
    (e) => relevantNodeIds.has(e.source) && relevantNodeIds.has(e.target)
  );

  // Find layers that contain any relevant nodes
  const relevantLayers = graph.layers.filter((l) =>
    l.nodeIds.some((id) => relevantNodeIds.has(id))
  );

  return {
    projectName: graph.project.name,
    projectDescription: graph.project.description,
    languages: graph.project.languages,
    frameworks: graph.project.frameworks,
    relevantNodes,
    relevantEdges,
    relevantLayers,
    query,
  };
}

export function formatContextForPrompt(context: ChatContext): string {
  const sections: string[] = [];

  sections.push(`## Project: ${context.projectName}`);
  sections.push(context.projectDescription);
  if (context.languages.length) {
    sections.push(`Languages: ${context.languages.join(', ')}`);
  }
  if (context.frameworks.length) {
    sections.push(`Frameworks: ${context.frameworks.join(', ')}`);
  }

  if (context.relevantLayers.length) {
    sections.push('\n## Relevant Layers');
    for (const layer of context.relevantLayers) {
      sections.push(`### ${layer.name}\n${layer.description}`);
    }
  }

  sections.push('\n## Relevant Code Components');
  for (const node of context.relevantNodes) {
    const parts = [`**${node.name}** (${node.type}, ${node.complexity})`];
    if (node.filePath) parts.push(`  File: ${node.filePath}`);
    parts.push(`  ${node.summary}`);
    if (node.tags.length) parts.push(`  Tags: ${node.tags.join(', ')}`);
    if (node.languageNotes) parts.push(`  Note: ${node.languageNotes}`);
    sections.push(parts.join('\n'));
  }

  if (context.relevantEdges.length) {
    sections.push('\n## Relationships');
    for (const edge of context.relevantEdges) {
      const sourceNode = context.relevantNodes.find((n) => n.id === edge.source);
      const targetNode = context.relevantNodes.find((n) => n.id === edge.target);
      const sourceName = sourceNode?.name ?? edge.source;
      const targetName = targetNode?.name ?? edge.target;
      sections.push(`- ${sourceName} --[${edge.type}]--> ${targetName}${edge.description ? ` (${edge.description})` : ''}`);
    }
  }

  return sections.join('\n');
}
```

**Step 6: Implementar understand-chat.ts (template do prompt)**

```typescript
// packages/skill/src/understand-chat.ts
import { formatContextForPrompt, buildChatContext } from './context-builder.js';
import type { KnowledgeGraph } from '@understand-anything/core';

export function buildChatPrompt(graph: KnowledgeGraph, query: string): string {
  const context = buildChatContext(graph, query);
  const formattedContext = formatContextForPrompt(context);

  return `You are a knowledgeable assistant that helps developers understand a codebase.
You have access to a knowledge graph analysis of the project. Use the context below to answer the user's question accurately and helpfully.

If the question relates to code, reference specific files and functions.
If the question is about architecture, describe the layers and relationships.
If you're unsure, say so rather than guessing.

${formattedContext}

## User Question
${query}`;
}
```

**Step 7: Criar o arquivo de definição da skill do Claude Code**

```markdown
<!-- packages/skill/.claude/skills/understand-chat.md -->
---
name: understand-chat
description: Ask questions about the current codebase using the knowledge graph
arguments: query
---

# /understand-chat

Answer questions about this codebase using the knowledge graph at `.understand-anything/knowledge-graph.json`.

## Instructions

1. Read the knowledge graph file at `.understand-anything/knowledge-graph.json` in the current project root
2. If the file doesn't exist, tell the user to run `/understand` first to analyze the project
3. Use the knowledge graph context to answer the user's query: "${ARGUMENTS}"
4. Reference specific files, functions, and relationships from the graph
5. If the project has layers defined, explain which layer(s) are relevant
6. Be concise but thorough — link concepts to actual code locations
```

**Step 8: Criar barrel export**

```typescript
// packages/skill/src/index.ts
export { buildChatContext, formatContextForPrompt, type ChatContext } from './context-builder.js';
export { buildChatPrompt } from './understand-chat.js';
```

**Step 9: Executar os testes para verificar que passam**

```bash
pnpm install && pnpm --filter @understand-anything/skill test
```
Esperado: TODOS PASSAM

**Step 10: Commit**

```bash
git add packages/skill/
git commit -m "feat(skill): scaffold skill package with /understand-chat command"
```

---

## Tarefa 7: Aprimoramento da Busca no Dashboard + Integração com a Store

**Arquivos:**
- Modificar: `packages/dashboard/src/store.ts`
- Modificar: `packages/dashboard/src/components/SearchBar.tsx`
- Modificar: `packages/dashboard/src/components/GraphView.tsx`

**Contexto:** Wire the core `SearchEngine` into the dashboard. Replace the simple substring filter in the Zustand store with `SearchEngine` from core. Enhance the SearchBar to show scored results with node type icons. Enhance the GraphView to highlight search results with varying intensity based on relevance score.

**Step 1: Atualizar a store Zustand**

Substitua a lógica de busca em `packages/dashboard/src/store.ts`:

```typescript
import { SearchEngine } from '@understand-anything/core';
import type { KnowledgeGraph, SearchResult } from '@understand-anything/core';

interface DashboardStore {
  graph: KnowledgeGraph | null;
  selectedNodeId: string | null;
  searchQuery: string;
  searchResults: SearchResult[]; // Changed from string[] to SearchResult[]
  searchEngine: SearchEngine | null;

  setGraph: (graph: KnowledgeGraph) => void;
  selectNode: (nodeId: string | null) => void;
  setSearchQuery: (query: string) => void;
}

export const useDashboardStore = create<DashboardStore>()((set, get) => ({
  graph: null,
  selectedNodeId: null,
  searchQuery: '',
  searchResults: [],
  searchEngine: null,

  setGraph: (graph) => {
    const searchEngine = new SearchEngine(graph.nodes);
    set({ graph, searchEngine });
  },

  selectNode: (nodeId) => set({ selectedNodeId: nodeId }),

  setSearchQuery: (query) => {
    const { searchEngine } = get();
    if (!searchEngine || !query.trim()) {
      set({ searchQuery: query, searchResults: [] });
      return;
    }
    const results = searchEngine.search(query);
    set({ searchQuery: query, searchResults: results });
  },
}));
```

**Step 2: Atualizar o componente SearchBar**

Atualize `SearchBar.tsx` para exibir scores dos resultados e mostrar um dropdown com os top matches:

- Show result count with "fuzzy" label
- Display top 5 results as clickable items below the search input (name + type + score)
- Clicking a result selects that node and scrolls graph to it

**Step 3: Atualizar GraphView para usar destaque por score**

Atualize `GraphView.tsx`:
- Search highlighting intensity varies by score (lower score = better match = brighter highlight)
- Best matches: bright yellow ring; weaker matches: dimmer yellow
- Pass the search score as data to CustomNode so it can adjust its appearance

**Step 4: Verificar manualmente**

```bash
pnpm dev:dashboard
```
Teste: digite "auth" na busca → verifique resultados fuzzy, destaque por score, resultados clicáveis.

**Step 5: Commit**

```bash
git add packages/dashboard/src/store.ts packages/dashboard/src/components/SearchBar.tsx packages/dashboard/src/components/GraphView.tsx
git commit -m "feat(dashboard): wire core SearchEngine with fuzzy matching and scored highlighting"
```

---

## Tarefa 8: Painel de Chat no Dashboard

**Arquivos:**
- Criar: `packages/dashboard/src/components/ChatPanel.tsx`
- Modificar: `packages/dashboard/src/store.ts`
- Modificar: `packages/dashboard/src/App.tsx`

**Contexto:** Replace the "Chat — coming soon" placeholder with a working chat panel. For the standalone dashboard (no Claude Code session), the user provides a Claude API key. The chat is context-aware: it automatically includes the selected node's context and nearby graph relationships. Uses the `@anthropic-ai/sdk` package with streaming for real-time responses. The chat panel shows a message list and input, with messages from both user and assistant.

**Step 1: Instalar Anthropic SDK**

```bash
cd packages/dashboard && pnpm add @anthropic-ai/sdk
```

**Step 2: Adicionar state de chat à store Zustand**

Adicione em `packages/dashboard/src/store.ts`:

```typescript
interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

// Add to DashboardStore interface:
apiKey: string;
chatMessages: ChatMessage[];
chatLoading: boolean;
setApiKey: (key: string) => void;
sendChatMessage: (message: string) => Promise<void>;
clearChat: () => void;
```

A implementação de `sendChatMessage`:
1. Pega o `graph`, `selectedNodeId` e `apiKey` atuais da store
2. Usa `buildChatContext` + `formatContextForPrompt` de `@understand-anything/core` (ou inlinha a mesma lógica, já que o pacote skill usa o core)
3. Constrói um system prompt com o contexto do graph
4. Chama a API do Claude com o `@anthropic-ai/sdk`
5. Faz streaming da resposta, atualizando `chatMessages` conforme chegam chunks
6. Define `chatLoading` durante a chamada

**Step 3: Criar componente ChatPanel**

```typescript
// packages/dashboard/src/components/ChatPanel.tsx
// Key features:
// 1. API key input (shown once, stored in zustand, persisted to localStorage)
// 2. Message list with user/assistant styling
// 3. Input field with send button
// 4. "Context: <selected node name>" indicator when a node is selected
// 5. Loading spinner during API calls
// 6. Auto-scroll to latest message
// 7. Markdown rendering for assistant messages (basic: bold, code blocks, lists)
```

O layout do componente:
```
┌─ Chat Panel ────────────────────┐
│ [🔑 Enter API key...]          │ ← Only shown if no key
├─────────────────────────────────┤
│ Context: auth/login.ts          │ ← Shows selected node
├─────────────────────────────────┤
│ User: How does auth work?       │
│                                 │
│ Assistant: The authentication   │
│ flow starts in login.ts...      │
│                                 │
│ User: What calls it?            │
│                                 │
│ Assistant: The API routes in    │
│ routes/api.ts import and call...│
├─────────────────────────────────┤
│ [Ask about this codebase...] 📤│
└─────────────────────────────────┘
```

**Step 4: Conectar ChatPanel ao App.tsx**

Substitua o `div` placeholder na célula inferior esquerda do grid:
```typescript
// In App.tsx, replace:
<div className="bg-gray-800 ...">Chat — coming soon</div>
// With:
<ChatPanel />
```

**Step 5: Verify manually**

```bash
pnpm dev:dashboard
```
Teste:
1. Insira uma chave de API do Claude
2. Selecione um nó no graph
3. Pergunte "what does this do?" → verifique resposta contextual
4. Faça uma pergunta de follow-up → verifique que o histórico de conversa é mantido

**Step 6: Commit**

```bash
git add packages/dashboard/src/components/ChatPanel.tsx packages/dashboard/src/store.ts packages/dashboard/src/App.tsx packages/dashboard/package.json pnpm-lock.yaml
git commit -m "feat(dashboard): add context-aware chat panel with Claude API integration"
```

---

## Tarefa 9: Visualização de Layers no Dashboard

**Arquivos:**
- Modificar: `packages/dashboard/src/store.ts`
- Modificar: `packages/dashboard/src/components/GraphView.tsx`
- Criar: `packages/dashboard/src/components/LayerLegend.tsx`
- Modificar: `packages/dashboard/src/App.tsx`

**Contexto:** When the knowledge graph has layers defined, the dashboard should visually group nodes by layer. Use React Flow's built-in group node feature — create parent nodes for each layer with a colored background, and assign layer member nodes as children. Add a toggleable layer legend showing layer colors and descriptions.

**Step 1: Adicionar state de layer à store**

Adicione em `packages/dashboard/src/store.ts`:
```typescript
// Add to DashboardStore interface:
showLayers: boolean;
toggleLayers: () => void;
```

**Step 2: Atualizar GraphView para agrupamento por layer**

Quando `showLayers` for true e o graph tiver layers:
1. Crie um nó React Flow do tipo "group" para cada layer (retângulo grande de fundo)
2. Defina os nós de layer como `parentId` dos seus nós membros
3. Aplique cores de fundo distintas por layer (semi-transparentes)
4. Use o layout dagre com suporte a subgraphs, ou posicione os grupos de layer em colunas
5. Mostre o nome da layer como label no nó group

Quando `showLayers` for false, renderize normalmente sem grupos.

**Step 3: Criar componente LayerLegend**

```typescript
// packages/dashboard/src/components/LayerLegend.tsx
// Shows:
// - Toggle button "Show Layers" / "Hide Layers"
// - List of layers with color dot, name, node count
// - Click layer name to filter graph to that layer
```

**Step 4: Conectar ao App.tsx**

Adicione `LayerLegend` na área do header, ao lado da SearchBar.

**Step 5: Verify manually**

```bash
pnpm dev:dashboard
```
Atualize o `knowledge-graph.json` de exemplo em `packages/dashboard/public/` para incluir layers, depois verifique se o agrupamento por layer renderiza corretamente.

**Step 6: Commit**

```bash
git add packages/dashboard/src/components/LayerLegend.tsx packages/dashboard/src/components/GraphView.tsx packages/dashboard/src/store.ts packages/dashboard/src/App.tsx packages/dashboard/public/knowledge-graph.json
git commit -m "feat(dashboard): add layer visualization with grouping and legend"
```

---

## Tarefa 10: Polimento de Integração — Sample Data, Verificação de Build, Update do README

**Arquivos:**
- Modificar: `packages/dashboard/public/knowledge-graph.json`
- Modificar: `CLAUDE.md`
- Modificar: `README.md`
- Modificar: `packages/core/src/index.ts` (ensure all exports clean)

**Contexto:** Final task: create a richer sample knowledge graph that exercises all Phase 2 features (layers, many nodes, varied types). Verify the full build succeeds. Update documentation.

**Step 1: Criar knowledge graph de exemplo rico**

Atualize `packages/dashboard/public/knowledge-graph.json` com um exemplo realista:
- 15-20 nodes across all 5 types (file, function, class, module, concept)
- 20+ edges across multiple EdgeTypes
- 4-5 layers (API, Service, Data, UI, Utility)
- Varied complexity levels
- Realistic summaries and tags

Isso serve como dados de demo e fixture de teste manual.

**Step 2: Verificar build completo**

```bash
pnpm install
pnpm --filter @understand-anything/core build
pnpm --filter @understand-anything/skill build
pnpm --filter @understand-anything/core test
pnpm --filter @understand-anything/skill test
pnpm dev:dashboard
```

Todos devem passar/rodar sem erros.

**Step 3: Atualizar CLAUDE.md**

Adicione o contexto da Fase 2:
```markdown
## Key Commands (updated)
- `pnpm --filter @understand-anything/skill build` — Build skill package
- `pnpm --filter @understand-anything/skill test` — Run skill tests

## Phase 2 Features
- Fuzzy search via Fuse.js (SearchEngine in core)
- Zod schema validation on graph loading
- Staleness detection + incremental graph merging
- Layer auto-detection (heuristic + LLM prompt)
- `/understand-chat` skill command
- Dashboard chat panel (Claude API integration)
- Dagre auto-layout for graph visualization
- Layer visualization with grouping and legend
```

**Step 4: Atualizar README.md**

Adicione descrições das features da Fase 2, placeholder para a seção de screenshots atualizados, novos comandos.

**Step 5: Commit**

```bash
git add packages/dashboard/public/knowledge-graph.json CLAUDE.md README.md packages/core/src/index.ts
git commit -m "docs: update sample data, CLAUDE.md, and README for Phase 2"
```

---

## Checklist de Verificação

Depois de todas as tarefas estarem completas:

1. **Validação de schema**: Carregue um JSON corrompido → verifique que lança erro com mensagem clara
2. **Busca fuzzy**: Digite "auth contrl" na busca → verifique que encontra "AuthController" ou similar
3. **Auto-layout**: Abra o dashboard → verifique que os nós aparecem hierarquicamente, não em grid
4. **Staleness**: Chame `isStale('/project', 'oldHash')` → verifique que detecta mudanças
5. **Detecção de layers**: Chame `detectLayers(graph)` em um projeto com routes/models/services → verifique layers populadas
6. **`/understand-chat`**: Verifique que o arquivo da skill existe em `packages/skill/.claude/skills/understand-chat.md`
7. **Painel de chat**: Insira a chave de API, selecione um nó, faça uma pergunta → verifique resposta contextual
8. **Visualização de layers**: Ative as layers → verifique que aparecem nós-grupo coloridos
9. **Todos os testes passam**: `pnpm --filter @understand-anything/core test && pnpm --filter @understand-anything/skill test`
10. **Build completo**: `pnpm -r build` é bem-sucedido

---

## Dependency Graph

```
Task 1 (zod schema) ─────────────────────────────┐
Task 2 (search engine) ──┬── Task 7 (dashboard    │
Task 3 (dagre layout) ───┤   search + store)      │
                         │                         │
Task 4 (staleness) ──────┤                         │
                         │                         │
Task 5 (layers) ─────────┼── Task 9 (layer viz) ──┤
                         │                         ├── Task 10 (polish)
Task 6 (skill pkg) ──────┼── Task 8 (chat panel) ─┤
                         │                         │
Task 7 ──────────────────┘                         │
Task 8 ────────────────────────────────────────────┘
Task 9 ────────────────────────────────────────────┘
```

**Safe parallel groups:**
- Tasks 1, 2, 3, 4, 5, 6 are all independent (but run sequentially per subagent-driven-dev)
- Task 7 depends on Tasks 2 + 3
- Task 8 depends on Task 6
- Task 9 depends on Tasks 3 + 5
- Task 10 depends on all others
