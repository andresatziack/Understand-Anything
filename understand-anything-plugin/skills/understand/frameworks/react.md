# Adendo do Framework React

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando React é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto React

Ao analisar um projeto React, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `src/App.tsx` | Componente raiz da aplicação — monta providers, router e o layout de nível superior | `entry-point`, `ui` |
| `components/*.tsx`, `components/**/*.tsx` | Componentes de UI reutilizáveis | `ui` |
| `hooks/*.ts`, `hooks/*.tsx` | Hooks React customizados — encapsulam lógica stateful reutilizável | `service`, `utility` |
| `contexts/*.tsx`, `context/*.tsx` | Providers e consumers de Context — estado compartilhado pela árvore de componentes | `service`, `state` |
| `pages/*.tsx`, `views/*.tsx` | Componentes de página mapeados para rotas | `ui`, `routing` |
| `utils/*.ts`, `helpers/*.ts` | Funções utilitárias puras — formatação, validação, transformações | `utility` |
| `types/*.ts`, `types/*.d.ts` | Definições de tipos e interfaces TypeScript | `type-definition` |
| `services/*.ts`, `api/*.ts` | Funções cliente de API e lógica de data fetching | `service` |
| `store/*.ts`, `slices/*.ts` | Gerenciamento de estado (Redux, Zustand, etc.) | `service`, `state` |
| `constants/*.ts` | Constantes e enums de toda a aplicação | `config` |
| `__tests__/*.tsx`, `*.test.tsx`, `*.spec.tsx` | Testes unitários e de integração | `test` |

### Padrões de Aresta a Procurar

**Composição de componentes** — Quando um componente pai renderiza um componente filho em seu JSX de retorno, crie arestas `contains` do pai para o filho. Essas arestas representam a hierarquia da árvore de componentes.

**Uso de hooks** — Quando um componente ou hook importa e chama um hook customizado (`useX`), crie arestas `depends_on` do consumidor para o módulo do hook. Hooks são o principal mecanismo de lógica compartilhada em React.

**Provider/consumer de Context** — Quando um Context provider envolve componentes, crie arestas `publishes` do provider para a definição do context. Quando componentes chamam `useContext` ou usam um hook de context customizado, crie arestas `subscribes` do consumidor para o context.

**Cadeias de props drilling** — Quando props são passadas por várias camadas de componentes sem serem usadas, crie arestas `depends_on` ao longo da cadeia para revelar a profundidade do acoplamento.

### Camadas Arquiteturais para React

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:ui` | UI Layer | `components/`, `pages/`, `views/`, componentes de layout |
| `layer:service` | Service Layer | `hooks/`, `contexts/`, `services/`, `api/`, `store/` |
| `layer:types` | Types Layer | `types/`, interfaces e definições de tipo TypeScript compartilhadas |
| `layer:utility` | Utility Layer | `utils/`, `helpers/`, funções puras |
| `layer:config` | Config Layer | `App.tsx`, configuração do router, setup de providers, constantes |
| `layer:test` | Test Layer | `__tests__/`, `*.test.tsx`, `*.spec.tsx` |

### Padrões Notáveis a Capturar em languageLesson

- **Composição de componentes em vez de herança**: o React favorece compor componentes via props e children em vez de hierarquias de herança de classe
- **Hooks customizados para lógica reutilizável**: hooks prefixados com `use` extraem lógica stateful em módulos compartilháveis sem alterar a árvore de componentes
- **React.memo para performance**: componentes envolvidos em `React.memo` pulam re-renders quando as props não mudam — indica caminhos sensíveis a performance
- **Componentes controlados vs. não controlados**: componentes controlados derivam o estado das props; componentes não controlados gerenciam estado interno via refs
- **Padrão render props**: componentes que aceitam uma função como children ou um render prop para delegar decisões de renderização ao consumidor
