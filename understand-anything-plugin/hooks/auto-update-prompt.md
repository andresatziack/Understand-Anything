# Atualização Automática do Knowledge Graph (Interno — Disparado por Hook)

Atualize o knowledge graph de forma incremental usando fingerprinting estrutural determinístico para minimizar o consumo de tokens. Este prompt é disparado automaticamente pelo hook post-commit quando `autoUpdate` está habilitado. NÃO é uma skill voltada ao usuário.

**Princípio-chave:** Gaste zero tokens de LLM quando as mudanças forem cosméticas (formatação, lógica interna). Invoque agentes LLM apenas quando mudanças estruturais (novas/removidas funções, classes, imports, exports) forem detectadas.

---

## Fase 0 — Pré-execução (Custo Zero de Token)

1. Defina `PROJECT_ROOT` como o diretório de trabalho atual.

2. Verifique se `$PROJECT_ROOT/.understand-anything/knowledge-graph.json` existe.
   - Se não existir: reporte "No existing knowledge graph found. Run `/understand` first to create one." e **PARE**.

3. Verifique se `$PROJECT_ROOT/.understand-anything/meta.json` existe e leia `gitCommitHash`.
   - Se não existir: reporte "No analysis metadata found. Run `/understand` to create a baseline." e **PARE**.

4. Obtenha o hash do commit atual:
   ```bash
   git rev-parse HEAD
   ```

5. Se os hashes de commit forem iguais e `--force` NÃO estiver em `$ARGUMENTS`: reporte "Knowledge graph is already up to date." e **PARE**.

6. Obtenha os arquivos alterados:
   ```bash
   git diff <lastCommitHash>..HEAD --name-only
   ```
   Se nenhum arquivo mudou: atualize `meta.json` com o novo hash de commit e **PARE**.

7. Filtre apenas para arquivos-fonte (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.go`, `.rs`, `.java`, `.rb`, `.cpp`, `.c`, `.h`, `.cs`, `.swift`, `.kt`, `.php`).
   Se nenhum arquivo-fonte mudou: atualize `meta.json` com o novo hash de commit, reporte "Only non-source files changed. Metadata updated." e **PARE**.

8. Crie o diretório intermediário:
   ```bash
   mkdir -p $PROJECT_ROOT/.understand-anything/intermediate
   ```

9. **Aplique exclusões de `.understandignore`** (mesma semântica do Passo 2.5 de `/understand` em `agents/project-scanner.md`).

   Sem este passo, arquivos em caminhos excluídos pelo usuário (migrations, código vendored, testes) são contados como mudanças estruturais e podem espuriamente escalar a ação para `FULL_UPDATE` mesmo quando o conjunto real de mudanças é minúsculo.

   1. Se nem `$PROJECT_ROOT/.understand-anything/.understandignore` nem `$PROJECT_ROOT/.understandignore` existir, o filtro de extensões do passo 7 é suficiente — pule para a Fase 1.

   2. Grave a lista de arquivos do passo 7 em `$PROJECT_ROOT/.understand-anything/intermediate/changed-files-pre.json` como um array JSON de caminhos relativos.

   3. Resolva `$PLUGIN_ROOT`:
      - Use `$CLAUDE_PLUGIN_ROOT` se estiver definido (o contexto de hook do Claude Code define isso).
      - Caso contrário, tente `$HOME/.understand-anything-plugin`.
      - Valide o candidato escolhido verificando se `$candidate/packages/core/dist/ignore-filter.js` existe.
      - Se nenhum resolver: reporte "Cannot locate plugin install at `$CLAUDE_PLUGIN_ROOT` or `$HOME/.understand-anything-plugin`; auto-update aborted. Run `/understand` to re-baseline." e **PARE**. Não pule silenciosamente — pular silenciosamente reproduz a issue #153.

   4. Grave `$PROJECT_ROOT/.understand-anything/intermediate/ignore-filter.mjs`:
      ```javascript
      import { readFileSync, writeFileSync } from 'node:fs';
      import { pathToFileURL } from 'node:url';
      import path from 'node:path';

      const PROJECT_ROOT = process.cwd();
      const PLUGIN_ROOT = process.argv[2];
      const inputPath = process.argv[3];

      const modUrl = pathToFileURL(
        path.join(PLUGIN_ROOT, 'packages/core/dist/ignore-filter.js'),
      ).href;
      const { createIgnoreFilter } = await import(modUrl);
      const filter = createIgnoreFilter(PROJECT_ROOT);

      const input = JSON.parse(readFileSync(inputPath, 'utf-8'));
      const kept = input.filter((p) => !filter.isIgnored(p));
      const removed = input.length - kept.length;

      writeFileSync(
        path.join(PROJECT_ROOT, '.understand-anything/intermediate/changed-files.json'),
        JSON.stringify({ kept, removed, total: input.length }, null, 2),
      );
      console.log(`.understandignore: kept ${kept.length}/${input.length} (removed ${removed})`);
      ```

   5. Execute-o:
      ```bash
      node $PROJECT_ROOT/.understand-anything/intermediate/ignore-filter.mjs \
        "$PLUGIN_ROOT" \
        $PROJECT_ROOT/.understand-anything/intermediate/changed-files-pre.json
      ```

   6. Leia `$PROJECT_ROOT/.understand-anything/intermediate/changed-files.json`. Passe o array `kept` como lista de arquivos de entrada para o script de fingerprint da Fase 1.

   7. Se `kept.length === 0`: atualize `meta.json` com o novo hash de commit, reporte "All changed source files are in ignored paths. Metadata updated." e **PARE**.

---

## Fase 1 — Verificação de Fingerprint Estrutural (Zero Tokens de LLM)

Esta fase executa um script Node.js determinístico que compara estruturas de arquivo contra fingerprints armazenados. Custa **zero tokens de LLM** — apenas o custo de execução do script.

1. Escreva e execute um script Node.js (`$PROJECT_ROOT/.understand-anything/intermediate/fingerprint-check.mjs`):

```javascript
// The script should:
// 1. Read fingerprints.json from .understand-anything/fingerprints.json
// 2. For each changed source file:
//    a. Read the file content
//    b. Compute SHA-256 content hash
//    c. If content hash matches stored hash → NONE (skip)
//    d. Extract structural elements via regex:
//       - Functions: match patterns like `function NAME(`, `const NAME = (`, `export function NAME(`
//       - Classes: match `class NAME`, `export class NAME`
//       - Imports: match `import ... from '...'`, `import '...'`
//       - Exports: match `export { ... }`, `export default`, `export function`, `export class`, `export const`
//    e. Compare extracted elements against stored fingerprint
//    f. Classify as NONE, COSMETIC, or STRUCTURAL
// 3. For new files (not in fingerprints.json): classify as STRUCTURAL
// 4. For deleted files (in fingerprints.json but not on disk): classify as STRUCTURAL
// 5. Determine overall decision:
//    - All NONE/COSMETIC → action: "SKIP"
//    - Some STRUCTURAL, ≤10 files, same directories → action: "PARTIAL_UPDATE"
//    - New/deleted directories or >10 structural files → action: "ARCHITECTURE_UPDATE"
//    - >30 structural files or >50% of graph → action: "FULL_UPDATE"
// 6. Write result to .understand-anything/intermediate/change-analysis.json
```

O JSON de saída deve ter este formato:
```json
{
  "action": "SKIP | PARTIAL_UPDATE | ARCHITECTURE_UPDATE | FULL_UPDATE",
  "filesToReanalyze": ["src/new-feature.ts"],
  "rerunArchitecture": false,
  "rerunTour": false,
  "reason": "1 file has structural changes (new function added)",
  "fileChanges": [
    { "filePath": "src/utils.ts", "changeLevel": "COSMETIC", "details": ["internal logic changed"] },
    { "filePath": "src/new-feature.ts", "changeLevel": "STRUCTURAL", "details": ["new function: handleRequest"] }
  ]
}
```

2. Leia `.understand-anything/intermediate/change-analysis.json`.

3. **Portão de decisão:**

   | Action | O que fazer |
   |---|---|
   | `SKIP` | Atualize `meta.json` com o novo hash de commit. Reporte: "No structural changes detected. Graph metadata updated. Zero tokens spent." **PARE.** |
   | `FULL_UPDATE` | Reporte: "Major structural changes detected (reason). Recommend running `/understand --full` for a complete rebuild." **PARE.** |
   | `PARTIAL_UPDATE` | Prossiga para a Fase 2 com `filesToReanalyze` |
   | `ARCHITECTURE_UPDATE` | Prossiga para a Fase 2 com `filesToReanalyze`, sinalize a re-execução da arquitetura |

---

## Fase 2 — Reanálise Direcionada (Custo Mínimo de Token)

Reanalise apenas arquivos com mudanças estruturais. Esta é a **única** fase que custa tokens de LLM.

1. Leia o knowledge graph existente em `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`.

2. Faça batch dos arquivos de `filesToReanalyze` (vindos da Fase 1). Use um único batch se ≤10 arquivos, caso contrário separe em grupos de 5 a 10.

3. Para cada batch, despache um subagente usando a definição de agente `file-analyzer` (em `agents/file-analyzer.md`). Anexe:

   > **Additional context from main session:**
   >
   > Project: `<projectName from existing graph>` — `<projectDescription>`
   > Frameworks detected: `<frameworks from existing graph>`
   > Languages: `<languages from existing graph>`
   >
   > **IMPORTANT:** This is an incremental update. Only the files listed below have structural changes. Analyze them thoroughly but do not invent nodes for files not in this batch.

   Preencha os parâmetros específicos do batch:

   > Analyze these source files and produce GraphNode and GraphEdge objects.
   > Project root: `$PROJECT_ROOT`
   > Project: `<projectName>`
   > Languages: `<languages>`
   > Batch index: `1`
   > Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/batch-1.json`
   >
   > All project files (for import resolution):
   > `<file list from existing graph nodes>`
   >
   > Files to analyze in this batch:
   > 1. `<path>` (`<sizeLines>` lines)
   > ...

4. Após o(s) batch(es) concluírem, leia cada `batch-<N>.json` e mescle os resultados.

5. **Mescle com o grafo existente:**
   - Remova nós antigos cujo `filePath` corresponda a qualquer arquivo em `filesToReanalyze` ou na lista de arquivos deletados
   - Remova arestas antigas cujo `source` ou `target` referencie um nó removido
   - Adicione nós e arestas novas a partir da análise atualizada
   - Deduplique nós por ID (mantenha o mais recente), arestas por `source + target + type`
   - Remova qualquer aresta com referência pendente em `source` ou `target`

---

## Fase 3 — Arquitetura/Tour Condicional + Salvar

### 3a. Atualização de arquitetura (apenas se `rerunArchitecture === true`)

Se a análise de mudanças sinalizou `ARCHITECTURE_UPDATE`:

1. Despache um subagente usando a definição de agente `architecture-analyzer` (em `agents/architecture-analyzer.md`), passando o conjunto completo de nós mesclados e as arestas de import. Inclua as definições anteriores de camada para consistência de nomes:

   > Previous layer definitions (for naming consistency):
   > ```json
   > [previous layers from existing graph]
   > ```
   > Maintain the same layer names and IDs where possible. Only add/remove layers if the file structure has materially changed.

2. Após a conclusão, leia e normalize as camadas (mesma normalização da Fase 4 de `/understand`).

3. Opcionalmente, re-execute o tour builder se as camadas mudaram significativamente.

### 3b. Atualização leve de camada (se `rerunArchitecture === false`)

Se for apenas uma atualização parcial:
1. Para **arquivos novos**: atribua-os à camada existente mais provável com base no casamento de caminho de diretório
2. Para **arquivos deletados**: remova seus IDs dos arrays `nodeIds` das camadas
3. Remova qualquer camada que termine com zero nodeIds

### 3c. Validação leve

Realize validação leve (sem o agente graph-reviewer):
1. Remova qualquer aresta com `source` ou `target` pendente
2. Remova qualquer entrada de `nodeIds` em camada que não exista no conjunto de nós
3. Garanta que todo nó de arquivo apareça em exatamente uma camada (adicione a uma camada catch-all se faltar)

### 3d. Salvar

1. Grave o knowledge graph final em `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`.

2. Grave os metadados atualizados em `$PROJECT_ROOT/.understand-anything/meta.json`:
   ```json
   {
     "lastAnalyzedAt": "<ISO 8601 timestamp>",
     "gitCommitHash": "<current commit hash>",
     "version": "1.0.0",
     "analyzedFiles": <total file count in graph>
   }
   ```

3. **Atualize fingerprints (LOAD-PATCH-SAVE, não OVERWRITE).**

   O modo de falha mais comum aqui: gravar somente as entradas de batch recém-computadas em `fingerprints.json`, descartando o fingerprint de todo o restante. A próxima auto-update então enxerga todos esses arquivos como novos (sem fingerprint armazenado), classifica-os como STRUCTURAL e escala para FULL_UPDATE permanentemente (issue #152). O script precisa CARREGAR todas as entradas existentes, APLICAR PATCH apenas nas reanalisadas e SALVAR o dict completo de volta.

   Escreva e execute um script Node.js exatamente nesta ordem:

   ```javascript
   import { readFileSync, writeFileSync, existsSync } from 'node:fs';
   import { createHash } from 'node:crypto';
   import path from 'node:path';

   const fpPath = path.join(PROJECT_ROOT, '.understand-anything', 'fingerprints.json');
   const existedAndNonEmpty = existsSync(fpPath) && readFileSync(fpPath, 'utf-8').trim().length > 0;

   // 1. LOAD ALL existing entries (NEVER skip — preserves un-analyzed files)
   const all = existedAndNonEmpty
     ? JSON.parse(readFileSync(fpPath, 'utf-8'))
     : {};
   const before = Object.keys(all).length;

   // 2. PATCH (file still exists) or REMOVE (file deleted) for each re-analyzed path.
   //    `filesToReanalyze` may include paths that were deleted in this commit —
   //    handle both branches inline rather than expecting a separate deleted list.
   for (const filePath of filesToReanalyze) {
     const fullPath = path.join(PROJECT_ROOT, filePath);
     if (!existsSync(fullPath)) {
       delete all[filePath];
       continue;
     }
     const content = readFileSync(fullPath, 'utf-8');
     const contentHash = createHash('sha256').update(content).digest('hex');
     // Extract functions, classes, imports, exports via the same regex as Phase 1.
     all[filePath] = { contentHash, functions, classes, imports, exports };
   }

   // 3. GUARD against silent load failure: if fingerprints.json existed and was
   //    non-empty but `before` came out as 0, refuse to overwrite — something
   //    went wrong reading the file and writing now would clobber every entry.
   if (existedAndNonEmpty && before === 0) {
     throw new Error('fingerprints.json existed and was non-empty but loaded as {} — refusing to overwrite');
   }

   // 4. SAVE ALL entries back (full dict — not just the patched subset)
   writeFileSync(fpPath, JSON.stringify(all, null, 2));
   console.log(`Fingerprints: ${before} → ${Object.keys(all).length}`);
   ```

   O guard `existedAndNonEmpty && before === 0` captura o caso de falha silenciosa de carregamento antes que ele corrompa o store. Se a contagem encolher de N para um número pequeno que coincide com o tamanho do batch, o passo de LOAD foi pulado — aborte a gravação em vez de persistir o dict errado.

4. Limpe os arquivos intermediários:
   ```bash
   rm -rf $PROJECT_ROOT/.understand-anything/intermediate
   ```

5. Reporte um resumo:
   - Arquivos verificados: N (total alterados)
   - Mudanças estruturais encontradas: N arquivos
   - Mudanças apenas cosméticas: N arquivos (puladas)
   - Nós atualizados: N
   - Ação tomada: PARTIAL_UPDATE / ARCHITECTURE_UPDATE
   - Caminho de saída: `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`

---

## Tratamento de Erros

- Se o script de verificação de fingerprint falhar: faça fallback tratando todos os arquivos alterados como STRUCTURAL (abordagem conservadora).
- Se `fingerprints.json` não existir: trate todos os arquivos alterados como STRUCTURAL e regenere os fingerprints após a atualização.
- Se o despacho de um subagente falhar: tente novamente uma vez. Se falhar de novo, salve resultados parciais e reporte o erro.
- SEMPRE salve resultados parciais — um grafo parcialmente atualizado é melhor do que nenhuma atualização.

---

## Notas

- Esta skill reusa as mesmas definições de agente `file-analyzer` e `architecture-analyzer` que `/understand` — não são necessários prompts de agente separados.
- A comparação de fingerprint na Fase 1 usa extração baseada em regex (não tree-sitter) porque é executada como script Node.js temporário e não precisa de precisão de AST completa — apenas detecção em nível de assinatura.
- Os fingerprints autoritativos armazenados em `fingerprints.json` são gerados pela Fase 7 de `/understand` usando o módulo core `fingerprint.ts` (que usa tree-sitter para extração precisa).
