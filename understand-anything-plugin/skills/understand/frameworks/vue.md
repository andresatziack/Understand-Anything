# Adendo do Framework Vue

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Vue é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Vue

Ao analisar um projeto Vue, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `src/App.vue` | Componente raiz da aplicação — monta o layout de nível superior e a router view | `entry-point`, `ui` |
| `src/main.ts`, `src/main.js` | Bootstrap da aplicação — cria a instância do app Vue, registra plugins e monta no DOM | `entry-point`, `config` |
| `components/*.vue`, `components/**/*.vue` | Componentes de UI reutilizáveis | `ui` |
| `views/*.vue`, `pages/*.vue` | Componentes de página mapeados para rotas | `ui`, `routing` |
| `composables/*.ts`, `composables/*.js` | Funções composables — lógica stateful reutilizável usando a Composition API | `service`, `utility` |
| `store/*.ts`, `stores/*.ts` | Módulos de gerenciamento de estado (stores do Pinia ou módulos do Vuex) | `service`, `state` |
| `router/*.ts`, `router/index.ts` | Configuração do Vue Router — definições de rota, navigation guards | `config`, `routing` |
| `plugins/*.ts`, `plugins/*.js` | Registros de plugins do Vue — estendem a funcionalidade do app (i18n, auth, etc.) | `config` |
| `utils/*.ts`, `helpers/*.ts` | Funções utilitárias puras | `utility` |
| `types/*.ts`, `types/*.d.ts` | Definições de tipos e interfaces TypeScript | `type-definition` |
| `api/*.ts`, `services/*.ts` | Funções cliente de API e lógica de data fetching | `service` |
| `directives/*.ts` | Diretivas Vue customizadas | `utility` |
| `tests/*.spec.ts`, `__tests__/*.spec.ts` | Testes unitários e de integração | `test` |

### Padrões de Aresta a Procurar

**Pai-filho de componentes** — Quando um componente pai usa um componente filho em seu `<template>`, crie arestas `contains` do pai para o filho. Refs de template e uso de slots indicam ainda mais relações de composição.

**Uso de composables** — Quando um componente ou composable importa e chama uma função `useX`, crie arestas `depends_on` do consumidor para o módulo do composable. Composables são o principal mecanismo de lógica stateful compartilhada.

**Actions/getters de stores** — Quando componentes ou composables importam e usam uma store do Pinia (`useXStore()`), crie arestas `depends_on` do consumidor para a store. Dependências entre stores também devem ser capturadas.

**Mapeamento da router view** — Quando `router/index.ts` mapeia paths para componentes de view, crie arestas `configures` do router para cada componente de view. Navigation guards adicionam arestas semelhantes a middleware.

**Registro de plugins** — Quando `main.ts` chama `app.use(plugin)`, crie arestas `configures` do arquivo de bootstrap para cada plugin.

### Camadas Arquiteturais para Vue

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:ui` | UI Layer | `components/`, `views/`, `pages/`, componentes de layout |
| `layer:service` | Service Layer | `composables/`, `store/`, `stores/`, `api/`, `services/` |
| `layer:config` | Config Layer | `router/`, `plugins/`, `main.ts`, `App.vue`, arquivos de configuração |
| `layer:utility` | Utility Layer | `utils/`, `helpers/`, `directives/`, funções puras |
| `layer:test` | Test Layer | `tests/`, `__tests__/`, `*.spec.ts` |

### Padrões Notáveis a Capturar em languageLesson

- **Composition API em vez da Options API**: o Vue moderno favorece `setup()` e `<script setup>` com composables, substituindo a separação data/methods/computed da Options API
- **Pinia para gerenciamento de estado**: stores do Pinia oferecem estado modular e type-safe com actions e getters — cada store é definida de forma independente e pode depender de outras stores
- **Vue Router com navigation guards**: guards `beforeEach`, `beforeEnter` e `afterEach` atuam como middleware para transições de rota — usados para autenticação e prefetching de dados
- **Single-file components (.vue)**: cada arquivo `.vue` encapsula template, script e style em um único arquivo — a sintaxe `<script setup>` é a forma concisa recomendada
- **Refs reativos e computed properties**: `ref()` e `reactive()` criam estado reativo; `computed()` deriva valores que se atualizam automaticamente — entender a reatividade é fundamental para rastrear o fluxo de dados
- **Provide/inject para passagem profunda de dependências**: `provide()` e `inject()` passam valores árvore abaixo sem props drilling — criam dependências implícitas que devem ser capturadas como arestas
