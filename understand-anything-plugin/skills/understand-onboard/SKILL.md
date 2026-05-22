---
name: understand-onboard
description: Use when you need to generate an onboarding guide for new team members joining a project
---

# /understand-onboard

Gere um guia de onboarding completo a partir do knowledge graph do projeto.

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

2. **Leia os metadados do projeto** — use Grep ou Read com limite de linhas para extrair a seção `"project"` (name, description, languages, frameworks).

3. **Leia as camadas** — Grep por `"layers"` para obter o array completo de camadas. Elas definem a arquitetura e estruturarão o guia.

4. **Leia o tour** — Grep por `"tour"` para obter os passos do walkthrough guiado. Eles fornecem o trajeto de aprendizado recomendado.

5. **Leia somente nós em nível de arquivo** — use Grep para encontrar nós com `"type": "file"` no knowledge graph. Pule nós em nível de função e classe para manter o guia em alto nível. Extraia `name`, `filePath`, `summary` e `complexity` de cada nó de arquivo.

6. **Identifique pontos quentes de complexidade** — a partir dos nós em nível de arquivo, encontre os de maior `complexity`. São áreas que novos devs devem abordar com cautela.

7. **Gere o guia de onboarding** com estas seções:
   - **Visão Geral do Projeto**: name, languages, frameworks, description (a partir dos metadados do projeto)
   - **Camadas da Arquitetura**: nome, descrição e arquivos-chave de cada camada (a partir de layers + nós de arquivo)
   - **Conceitos-Chave**: padrões importantes e decisões de design (a partir dos resumos e tags dos nós)
   - **Tour Guiado**: walkthrough passo a passo (a partir da seção tour)
   - **Mapa de Arquivos**: o que cada arquivo-chave faz (a partir dos nós em nível de arquivo, organizados por camada)
   - **Pontos Quentes de Complexidade**: áreas para abordar com cautela (a partir dos valores de complexity)

8. Formate em markdown limpo
9. Ofereça-se para salvar o guia em `docs/ONBOARDING.md` no projeto
10. Sugira ao usuário fazer commit dele no repo para o time
