---
name: understand-knowledge
description: Analyze a Karpathy-pattern LLM wiki knowledge base and generate an interactive knowledge graph with entity extraction, implicit relationships, and topic clustering.
argument-hint: [wiki-directory]
---

# /understand-knowledge

Analisa um wiki LLM no padrão Karpathy — uma knowledge base de três camadas com sources brutos, markdown de wiki e um arquivo de schema — e produz um dashboard interativo de knowledge graph.

## O Que Ele Detecta

O **padrão de wiki LLM Karpathy** (veja https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f):
- **Sources brutos** — documentos-fonte imutáveis (artigos, papers, arquivos de dados)
- **Wiki** — arquivos markdown gerados por LLM com wikilinks (sintaxe `[[target]]`)
- **Schema** — CLAUDE.md, AGENTS.md ou arquivo de configuração similar
- **index.md** — catálogo de conteúdo organizado por categorias
- **log.md** — log cronológico de operações

Sinais de detecção: presença de `index.md` + múltiplos arquivos `.md` com wikilinks. Pode ter um diretório `raw/` e um arquivo de schema.

## Instruções

### Fase 1: DETECT

1. Determine o diretório alvo:
   - Se o usuário forneceu um argumento de caminho, use-o
   - Caso contrário, use o diretório de trabalho atual

2. Execute o script de detecção de formato empacotado com esta skill:
   ```
   python3 <SKILL_DIR>/parse-knowledge-base.py <TARGET_DIR>
   ```
   - Se o script sair com erro, diga ao usuário que isso não parece ser um wiki no padrão Karpathy e explique o que era esperado
   - Se for bem-sucedido, prossiga. O script grava `scan-manifest.json` em `<TARGET_DIR>/.understand-anything/intermediate/`

3. Leia o scan-manifest.json e anuncie os resultados:
   - "Detected Karpathy wiki: N articles, N sources, N topics, N wikilinks (N unresolved)"
   - Liste as categorias encontradas a partir do index.md

### Fase 2: SCAN (já feito)

O script de parse na Fase 1 já realizou o scan determinístico. O scan-manifest.json contém:
- Nós Article (um por arquivo .md do wiki) com wikilinks extraídos, headings, frontmatter
- Nós Source (um por arquivo em raw/)
- Nós Topic (a partir dos headings de seção do index.md)
- Arestas `related` (a partir dos wikilinks)
- Arestas `categorized_under` (a partir das seções do index.md)

Nenhum scan adicional é necessário. Prossiga para a Fase 3.

### Fase 3: ANALYZE

Despache subagentes `article-analyzer` para extrair conhecimento implícito:

1. Leia o scan-manifest.json para obter a lista de artigos

2. Prepare lotes de 10 a 15 artigos cada, agrupados por categoria quando possível (artigos da mesma categoria têm mais chance de ter referências cruzadas implícitas)

3. Para cada lote, despache um subagente `article-analyzer` com:
   - O lote de artigos (id, name, summary, wikilinks, category, content do knowledgeMeta)
   - A lista completa de IDs de nós existentes (para que o agente possa referenciá-los)
   - O número do lote para nomear o arquivo de saída
   - O caminho do diretório intermediário: `$INTERMEDIATE_DIR = <TARGET_DIR>/.understand-anything/intermediate`
   
   O agente gravará `analysis-batch-{N}.json` no diretório intermediário.

4. Execute até 3 lotes concorrentemente. Aguarde todos os lotes terminarem.

5. Se algum lote falhar, registre um warning mas continue — o scan-manifest fornece um grafo-base sólido mesmo sem análise por LLM.

### Fase 4: MERGE

1. Execute o script de merge empacotado com esta skill:
   ```
   python3 <SKILL_DIR>/merge-knowledge-graph.py <TARGET_DIR>
   ```

2. O script:
   - Combina o scan-manifest.json + todos os arquivos analysis-batch-*.json
   - Deduplica entidades (case-insensitive em nomes)
   - Normaliza tipos de nó/aresta via mapas de alias
   - Constrói camadas a partir das categorias do index.md
   - Constrói um tour a partir da ordenação das seções do index.md
   - Grava `assembled-graph.json` no diretório intermediário

3. Leia o relatório de merge no stderr e anuncie:
   - Total de nós, arestas, camadas, passos do tour
   - Quantas entidades/afirmações a análise por LLM adicionou

### Fase 5: SAVE

1. Leia o assembled-graph.json

2. Faça uma validação básica:
   - Todo source/target de aresta deve referenciar um nó existente
   - Todo nó deve ter: id, type, name, summary, tags, complexity
   - Remova quaisquer arestas com referências pendentes

3. Copie o grafo validado para `<TARGET_DIR>/.understand-anything/knowledge-graph.json`

4. Grave os metadados em `<TARGET_DIR>/.understand-anything/meta.json`:
   ```json
   {
     "lastAnalyzedAt": "<ISO timestamp>",
     "gitCommitHash": "<from git rev-parse HEAD or empty>",
     "version": "1.0.0",
     "analyzedFiles": <number of wiki articles>
   }
   ```

5. Limpe os arquivos intermediários:
   ```
   rm -rf <TARGET_DIR>/.understand-anything/intermediate
   ```

6. Reporte um resumo ao usuário:
   - "Knowledge graph saved: N articles, N entities, N topics, N claims, N sources"
   - "N edges (N wikilink, N categorized, N implicit)"
   - "N layers, N tour steps"

7. Auto-dispare o dashboard:
   ```
   /understand-dashboard <TARGET_DIR>
   ```

## Notas

- O script de parse cuida de TODA extração determinística (wikilinks, headings, frontmatter, categorias do index.md). Os agentes LLM apenas adicionam o conhecimento implícito que requer inferência.
- Categorias e taxonomia vêm dos headings de seção do index.md, NÃO de prefixos de nome de arquivo. A spec Karpathy é intencionalmente abstrata sobre convenções de nomeação.
- O grafo usa `kind: "knowledge"` para sinalizar ao dashboard que use layout force-directed em vez do dagre hierárquico.
- Os nós Source vindos de raw/ são leves (apenas nome de arquivo + tamanho) — não parseamos PDFs nem arquivos binários.
