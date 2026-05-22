---
name: understand-diff
description: Use when you need to analyze git diffs or pull requests to understand what changed, affected components, and risks
---

# /understand-diff

Analise as alterações de código atuais contra o knowledge graph em `.understand-anything/knowledge-graph.json`.

## Referência da Estrutura do Grafo

O JSON do knowledge graph tem esta estrutura:
- `project` — {name, description, languages, frameworks, analyzedAt, gitCommitHash}
- `nodes[]` — cada um tem {id, type, name, filePath, summary, tags[], complexity, languageNotes?}
  - Tipos de nó: file, function, class, module, concept
  - IDs: `file:path`, `function:path:name`, `class:path:name`
- `edges[]` — cada uma tem {source, target, type, direction, weight}
  - Tipos-chave: imports, contains, calls, depends_on
- `layers[]` — cada uma tem {id, name, description, nodeIds[]}
- `tour[]` — cada um tem {order, title, description, nodeIds[]}

## Como Ler com Eficiência

1. Use Grep para buscar dentro do JSON pelas entradas relevantes ANTES de ler o arquivo inteiro
2. Leia apenas as seções que você precisa — não despeje o grafo inteiro no contexto
3. Os campos mais úteis para compreensão são `name` e `summary` dos nós
4. As arestas dizem como os componentes se conectam — siga imports e calls para cadeias de dependência

## Instruções

1. Verifique se `.understand-anything/knowledge-graph.json` existe. Se não existir, peça ao usuário para rodar `/understand` primeiro.

2. **Obtenha a lista de arquivos alterados** (NÃO leia o grafo ainda):
   - Se estiver em um branch com mudanças não commitadas: `git diff --name-only`
   - Se estiver em um branch de feature: `git diff main...HEAD --name-only` (ou o branch base)
   - Se o usuário especifica um número de PR: pegue o diff daquele PR

3. **Leia apenas os metadados do projeto** — use Grep ou Read com limite de linhas para extrair somente a seção `"project"` para contexto.

4. **Encontre nós para os arquivos alterados** — para cada caminho de arquivo alterado, use Grep para procurar no knowledge graph por:
   - Nós com valores `"filePath"` correspondentes (ex.: `grep "changed/file/path"`)
   - Isso encontra nós de arquivo E nós de função/classe definidos nesses arquivos
   - Anote os valores de `id` de todos os nós casados

5. **Encontre arestas conectadas (1-hop)** — para cada ID de nó casado, faça Grep por esse ID nas arestas para encontrar:
   - O que importa ou depende dos nós alterados (chamadores upstream)
   - O que os nós alterados importam ou chamam (dependências downstream)
   - Esses são os "componentes afetados" — coisas que podem quebrar ou precisar ser atualizadas

6. **Identifique camadas afetadas** — Grep pelos IDs de nó casados na seção `"layers"` para determinar quais camadas arquiteturais foram tocadas.

7. **Forneça uma análise estruturada**:
   - **Componentes Alterados**: O que foi modificado diretamente (com resumos vindos dos nós casados)
   - **Componentes Afetados**: O que pode ser impactado (a partir das arestas de 1-hop)
   - **Camadas Afetadas**: Quais camadas arquiteturais foram tocadas e preocupações cross-layer
   - **Avaliação de Risco**: Com base nos valores de `complexity` dos nós, número de arestas cross-layer e blast radius (número de componentes afetados)
   - Sugira o que revisar com atenção e possíveis problemas

8. **Grave o overlay de diff para o dashboard** — após produzir a análise, grave os dados de diff em `.understand-anything/diff-overlay.json` para que o dashboard consiga visualizar componentes alterados e afetados. O arquivo contém:
   ```json
   {
     "version": "1.0.0",
     "baseBranch": "<the base branch used>",
     "generatedAt": "<ISO timestamp>",
     "changedFiles": ["<list of changed file paths>"],
     "changedNodeIds": ["<node IDs from step 4>"],
     "affectedNodeIds": ["<node IDs from step 5, excluding changedNodeIds>"]
   }
   ```
   Após gravar, diga ao usuário que ele pode rodar `/understand-anything:understand-dashboard` para ver o overlay de diff visualmente.
