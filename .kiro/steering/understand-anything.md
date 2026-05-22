<!--
  MIRROR FILE — DO NOT EDIT IN ISOLATION.

  Canonical source: understand-anything-plugin/.kiro/steering/understand-anything.md
  This copy lives at the repo root so Kiro picks it up via its standard
  `.kiro/steering/*.md` auto-discovery scope when the project is opened.
  Any change to one file MUST be mirrored to the other in the same commit.
-->

# Understand Anything — Guia de uso para o Kiro

Este projeto distribui o plugin **Understand Anything**: um pipeline multi-agente que analisa qualquer codebase, gera um knowledge graph (`.understand-anything/knowledge-graph.json`) e expõe um dashboard interativo em React + React Flow. Use este steering file como contexto persistente sempre que o usuário pedir para entender, explorar, explicar ou comparar partes de um projeto.

## Quando usar este plugin

Acione o slash command correspondente quando a intenção do usuário se encaixar em um dos casos abaixo. Se houver dúvida, prefira `/understand-explain` para um arquivo específico ou `/understand-chat` para uma pergunta livre.

- `/understand` — "analise este repositório", "preciso entender este projeto", "monte o knowledge graph", "primeira execução em uma codebase nova".
- `/understand-dashboard` — "abra o dashboard", "quero visualizar o grafo", "mostre a UI interativa".
- `/understand-chat <pergunta>` — "como funciona o fluxo de pagamento?", "onde fica a autenticação?", perguntas livres em linguagem natural sobre o codebase já analisado.
- `/understand-diff` — "qual o impacto destas mudanças?", "o que esta branch quebra?", "analise o diff atual antes do commit".
- `/understand-explain <arquivo|símbolo>` — "explique `src/auth/login.ts`", "o que esta função faz?", deep-dive em um arquivo ou símbolo.
- `/understand-onboard` — "gere um guia de onboarding", "preciso introduzir um novo dev", "produza um tour passo a passo".
- `/understand-domain` — "extraia o domínio de negócio", "quais são os fluxos e processos", "mapeie o lado business deste código".
- `/understand-knowledge <caminho>` — "analise esta wiki", "construa o grafo de conhecimento desta knowledge base no padrão Karpathy".

## Como executar

1. Localize a skill correspondente em `~/.kiro/skills/<skill-name>/SKILL.md`. Caso o diretório não exista, faça fallback para `~/.understand-anything-plugin/skills/<skill-name>/SKILL.md` (link universal criado pelo instalador).
2. Leia o `SKILL.md` **inteiro** antes de executar qualquer ação. Esses arquivos descrevem entradas, saídas, variáveis de ambiente e a ordem dos sub-agentes.
3. Siga as instruções passo a passo. Quando o `SKILL.md` mandar invocar um agente especializado (`project-scanner`, `file-analyzer`, `architecture-analyzer`, `tour-builder`, `graph-reviewer`, `domain-analyzer`, `article-analyzer`, `assemble-reviewer`, `knowledge-graph-guide`), carregue o prompt correspondente em `~/.understand-anything-plugin/agents/<agent>.md` e rode-o como sub-agente, repassando o contexto pedido.
4. Respeite o paralelismo descrito nos skills (geralmente até 5 file-analyzers em paralelo, lotes de 20–30 arquivos).
5. Sempre confirme que os caminhos relativos no projeto analisado existem antes de gravar saídas.

## Onde gravar resultados

- O grafo final e seus metadados ficam em `.understand-anything/` na raiz do projeto analisado.
- Saídas intermediárias (lotes parciais, logs de batch, recortes de diff) ficam em `.understand-anything/intermediate/`. Trate esses arquivos como descartáveis.
- Configurações persistentes do usuário (idioma preferido, opções de UI) ficam em `.understand-anything/config.json`.
- Nunca sobrescreva arquivos fora de `.understand-anything/` sem pedido explícito do usuário.

## Saída em português do Brasil

- Para gerar nós do grafo e UI do dashboard em PT-BR, passe `--language pt-BR` em qualquer comando que aceite a flag (`/understand`, `/understand-dashboard`, `/understand-knowledge`, etc.).
- A guia de estilo PT-BR (tags, sumários, nomes de camadas, glossário) está em `understand-anything-plugin/skills/understand/locales/pt-BR.md`. Leia esse arquivo antes de produzir qualquer texto em PT-BR para manter consistência.
- Mantenha termos técnicos consagrados em inglês (`middleware`, `hook`, `entry-point`, `ORM`, `REST API`, `CI/CD`, `CRUD`, `singleton`, `factory`, `observer`, `interceptor`, `guard`).

## Convenções

- **Não invente arquivos.** Se um caminho mencionado pelo usuário não existir, diga isso explicitamente em vez de fabricar o conteúdo.
- **Leia antes de responder.** Sempre abra o `SKILL.md` relevante (e os agentes que ele invoca) antes de produzir uma resposta extensa.
- **Comandos, paths e nomes de ferramentas em inglês.** A prosa pode ser em PT-BR, mas `pnpm install`, `.understand-anything/`, `understand-anything-plugin`, nomes de arquivos e flags permanecem em inglês.
- **Não rode `pnpm lint`.** O repositório não tem configuração ESLint (gap pré-existente, documentado em `CLAUDE.md`).
- **Versão sincronizada.** Toda alteração que toque o plugin precisa atualizar a versão em todos os `plugin.json` (`.claude-plugin/`, `.cursor-plugin/`, `.copilot-plugin/`, `.kiro-plugin/`, `understand-anything-plugin/.claude-plugin/plugin.json`) e em `understand-anything-plugin/package.json`.
- **Em caso de dúvida, prefira ler o código** ao especular. Os agentes `file-analyzer` e `graph-reviewer` existem justamente para validar antes de afirmar.
