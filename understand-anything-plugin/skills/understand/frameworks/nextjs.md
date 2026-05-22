# Adendo do Framework Next.js

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Next.js é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Next.js

Ao analisar um projeto Next.js, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `app/layout.tsx` | Layout raiz — envolve todas as páginas, define o shell HTML e providers globais | `entry-point`, `config`, `ui` |
| `app/page.tsx` | Componente de página raiz — renderiza em `/` | `ui`, `routing` |
| `app/**/page.tsx` | Componentes de página de rota — o caminho do arquivo determina a URL | `ui`, `routing` |
| `app/**/layout.tsx` | Layouts aninhados — envolvem rotas filhas com UI compartilhada | `ui`, `config` |
| `app/**/loading.tsx` | UI de loading — exibida como fallback do Suspense durante transições de rota | `ui` |
| `app/**/error.tsx` | Boundary de erro — captura erros no segmento de rota | `ui` |
| `app/**/not-found.tsx` | UI 404 — exibida quando `notFound()` é chamado | `ui` |
| `app/api/**/route.ts` | Handlers de rota de API — funções de endpoint serverless (GET, POST, etc.) | `api-handler` |
| `middleware.ts` | Edge middleware — intercepta requisições antes que cheguem às rotas | `middleware` |
| `lib/*.ts`, `lib/**/*.ts` | Utilitários, acesso a dados e lógica de negócio compartilhados no servidor | `service` |
| `components/*.tsx`, `components/**/*.tsx` | Componentes de UI reutilizáveis | `ui` |
| `next.config.js`, `next.config.mjs`, `next.config.ts` | Configuração do Next.js — redirects, rewrites, env, overrides do webpack | `config` |
| `actions/*.ts`, `app/**/actions.ts` | Server Actions — funções de mutação no servidor invocáveis pelo cliente | `service`, `api-handler` |

### Padrões de Aresta a Procurar

**Aninhamento de layouts** — Quando `app/foo/layout.tsx` envolve `app/foo/page.tsx` e `app/foo/bar/page.tsx`, crie arestas `contains` do layout para as páginas que ele envolve. Layouts compõem via a hierarquia do sistema de arquivos.

**Handlers de rotas de API** — Quando um arquivo `route.ts` exporta funções nomeadas (GET, POST, PUT, DELETE), crie arestas dos componentes consumidores ou server actions para o handler de rota com base nas chamadas de fetch.

**Fronteira Server/Client Component** — Arquivos com a diretiva `"use client"` no topo são Client Components. Todos os outros componentes no diretório `app/` são Server Components por padrão. Crie arestas `depends_on` que cruzem essa fronteira e registre a fronteira na descrição da aresta.

**Parallel routes** — Quando padrões `app/@slot/page.tsx` aparecem, crie arestas `contains` do layout pai para cada slot paralelo. Eles renderizam simultaneamente no mesmo layout.

**Route groups** — Diretórios envolvidos por parênteses `(group)` organizam rotas sem afetar o caminho da URL. Anote isso nas descrições dos nós.

### Camadas Arquiteturais para Next.js

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:ui` | UI Layer | `app/**/page.tsx`, `app/**/layout.tsx`, `components/`, boundaries de loading/error |
| `layer:api` | API Layer | `app/api/**/route.ts`, handlers de rota de API |
| `layer:service` | Service Layer | `lib/`, server actions, utilitários de data fetching |
| `layer:middleware` | Middleware Layer | `middleware.ts`, edge functions |
| `layer:config` | Config Layer | `next.config.*`, layout raiz, `tailwind.config.*`, configuração de ambiente |
| `layer:test` | Test Layer | `__tests__/`, `*.test.tsx`, `*.spec.tsx`, `e2e/` |

### Padrões Notáveis a Capturar em languageLesson

- **Server Components por padrão**: componentes no diretório `app/` são Server Components — nenhum JavaScript é enviado ao cliente a menos que `"use client"` seja declarado
- **Server Actions para mutações**: funções marcadas com `"use server"` podem ser chamadas diretamente de client components, substituindo rotas de API tradicionais para submissões de formulário e mutações
- **Convenções de arquivos do App Router**: arquivos especiais (`page`, `layout`, `loading`, `error`, `not-found`, `route`) definem comportamento por convenção de nome dentro do roteador baseado em sistema de arquivos
- **ISR e geração estática**: `generateStaticParams` pré-renderiza páginas em build time; estratégias de revalidação controlam o frescor do cache
- **Parallel e intercepting routes**: diretórios `@slot` habilitam renderização paralela; diretórios prefixados com `(.)` habilitam interceptação de rota para padrões de modal
