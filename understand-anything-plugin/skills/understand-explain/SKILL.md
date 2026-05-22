---
name: understand-explain
description: Use when you need a deep-dive explanation of a specific file, function, or module in the codebase
argument-hint: [file-path]
---

# /understand-explain

Forneça uma explicação aprofundada e detalhada de um componente de código específico.

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

2. **Encontre o nó alvo** — use Grep para buscar no knowledge graph pelo componente: "$ARGUMENTS"
   - Para caminhos de arquivo (ex.: `src/auth/login.ts`): busque por matches em `"filePath"`
   - Para notação de função (ex.: `src/auth/login.ts:verifyToken`): busque pelo nome da função em campos `"name"` filtrados pelo caminho do arquivo
   - Anote o `id`, `type`, `summary`, `tags` e `complexity` exatos do nó

3. **Encontre todas as arestas conectadas** — Grep pelo ID do nó alvo na seção de arestas:
   - Matches em `"source"` → coisas que este nó chama/importa/depende (saída)
   - Matches em `"target"` → coisas que chamam/importam/dependem deste nó (entrada)
   - Anote os IDs de nó conectados e os tipos de aresta

4. **Leia os nós conectados** — para cada ID de nó conectado do passo 3, faça Grep por esses IDs na seção de nós para obter `name`, `summary` e `type`. Isso constrói a vizinhança do componente.

5. **Identifique a camada** — Grep pelo ID do nó alvo na seção `"layers"` para descobrir a qual camada arquitetural ele pertence e a descrição daquela camada.

6. **Leia o arquivo-fonte real** — leia o arquivo-fonte no `filePath` do nó para a análise aprofundada.

7. **Explique o componente em contexto**:
   - Seu papel na arquitetura (qual camada, por que existe)
   - Estrutura interna (funções, classes que ele contém — vindas das arestas `contains`)
   - Conexões externas (o que importa, o que o chama, do que depende — vindas das arestas)
   - Fluxo de dados (entradas → processamento → saídas — vindo do código-fonte)
   - Explique de forma clara, supondo que o leitor pode não conhecer a linguagem de programação
   - Destaque quaisquer padrões, idiomas ou complexidades que valha a pena entender
