---
name: understand-chat
description: Use when you need to ask questions about a codebase or understand code using a knowledge graph
argument-hint: [query]
---

# /understand-chat

Responda perguntas sobre este codebase usando o knowledge graph em `.understand-anything/knowledge-graph.json`.

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

1. Verifique se `.understand-anything/knowledge-graph.json` existe na raiz do projeto atual. Se não existir, peça ao usuário para rodar `/understand` primeiro.

2. **Leia apenas os metadados do projeto** — use Grep ou Read com limite de linhas para extrair somente a seção `"project"` do topo do arquivo para contexto (name, description, languages, frameworks).

3. **Busque nós relevantes** — use Grep para procurar no arquivo do knowledge graph pelas palavras-chave da pergunta do usuário: "$ARGUMENTS"
   - Busque em campos `"name"`: `grep -i "query_keyword"` no arquivo do grafo
   - Busque em campos `"summary"` por matches semânticos
   - Busque em arrays `"tags"` por matches de tópico
   - Anote os valores de `id` de todos os nós que casarem

4. **Encontre as arestas conectadas** — para cada ID de nó casado, faça Grep por esse ID na seção `edges` para encontrar:
   - O que ele importa ou do que depende (downstream)
   - O que o chama ou importa (upstream)
   - Isso te dá o subgrafo de 1-hop em torno da consulta

5. **Leia o contexto de camada** — Grep por `"layers"` para entender a quais camadas arquiteturais os nós casados pertencem.

6. **Responda à consulta** usando apenas o subgrafo relevante:
   - Referencie arquivos, funções e relações específicos vindos do grafo
   - Explique qual(is) camada(s) é/são relevante(s) e por quê
   - Seja conciso mas minucioso — ligue os conceitos a localizações reais de código
   - Se a pergunta não casar com nenhum nó, diga isso e sugira termos relacionados a partir do grafo
