# Adendo do Framework Gin (Go)

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Gin é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Gin

Ao analisar um projeto Gin, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `main.go` | Ponto de entrada da aplicação — inicializa o engine do Gin, registra rotas, inicia o servidor | `entry-point`, `config` |
| `cmd/*.go`, `cmd/**/*.go` | Pontos de entrada CLI — múltiplos binários em um projeto multi-comando | `entry-point`, `config` |
| `handlers/*.go`, `handler/*.go` | Handlers HTTP — processam requisições com `gin.Context` | `api-handler` |
| `controllers/*.go`, `controller/*.go` | Controllers — nomenclatura alternativa para handlers HTTP | `api-handler` |
| `routes/*.go`, `router/*.go` | Definições de rota — registram endpoints e route groups | `routing`, `config` |
| `models/*.go`, `model/*.go` | Modelos de dados — definições de struct mapeadas para tabelas do banco | `data-model` |
| `middleware/*.go` | Funções de middleware — autenticação, logging, CORS, rate limiting | `middleware` |
| `services/*.go`, `service/*.go` | Lógica de negócio — operações de domínio desacopladas da camada HTTP | `service` |
| `repository/*.go`, `repo/*.go` | Camada de acesso a dados — queries de banco e lógica de persistência | `data-model`, `service` |
| `config/*.go`, `config.go` | Configuração da aplicação — carregamento de ambiente, config baseada em struct | `config` |
| `dto/*.go` | Data transfer objects — structs de request e response | `type-definition` |
| `utils/*.go`, `pkg/*.go` | Pacotes utilitários compartilhados | `utility` |
| `*_test.go` | Testes unitários e de integração | `test` |

### Padrões de Aresta a Procurar

**Registro de route groups** — Quando `r.Group("/api")` cria um route group e registra handlers, crie arestas `configures` do arquivo de definição de rotas para cada handler. Route groups organizam endpoints por prefixo e middleware compartilhado.

**Chamadas handler-service** — Quando uma função handler chama um método de service, crie arestas `depends_on` do handler para o service. Isso representa a separação entre tratamento HTTP e lógica de negócio.

**Chamadas service-repository** — Quando um service chama um método de repository para acesso a dados, crie arestas `depends_on` do service para o repository. Isso representa a abstração de acesso a dados.

**Encadeamento de middleware** — Quando `r.Use(middleware)` ou um route group aplica middleware, crie arestas de middleware do router ou group para a função de middleware. Middleware é executado na ordem de registro.

### Camadas Arquiteturais para Gin

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | `handlers/`, `controllers/`, funções handler HTTP |
| `layer:data` | Data Layer | `models/`, `repository/`, acesso a banco, migrations |
| `layer:service` | Service Layer | `services/`, lógica de negócio |
| `layer:middleware` | Middleware Layer | `middleware/`, autenticação, logging, rate limiting |
| `layer:config` | Config Layer | `main.go`, `routes/`, `config/`, configuração de ambiente |
| `layer:utility` | Utility Layer | `utils/`, `pkg/`, pacotes auxiliares compartilhados |
| `layer:test` | Test Layer | `*_test.go`, fixtures de teste, helpers de teste |

### Padrões Notáveis a Capturar em languageLesson

- **Funções handler com gin.Context**: cada handler do Gin recebe um parâmetro `*gin.Context` — ele fornece parsing de requisição (`c.Bind`, `c.Param`, `c.Query`), escrita de resposta (`c.JSON`, `c.HTML`) e controle de fluxo (`c.Abort`, `c.Next`)
- **Cadeia de middleware com c.Next()**: o middleware chama `c.Next()` para passar o controle ao próximo handler na cadeia — código antes de `c.Next()` roda na fase pré-handler, código depois roda na fase pós-handler
- **Agrupamento de rotas para APIs modulares**: `r.Group("/v1")` cria sub-routers modulares que podem ter sua própria pilha de middleware — habilita versionamento e controle de acesso no nível do grupo
- **Injeção de dependências via construtores (sem framework de DI)**: Go não tem framework de DI — dependências são passadas como parâmetros de construtor (por exemplo, `NewUserHandler(userService)`) e armazenadas como campos da struct
- **Design baseado em interfaces para testabilidade**: services e repositories são definidos como interfaces — handlers dependem da interface, habilitando implementações mock em testes
- **Tratamento de erros com gin.Error**: o Gin coleta erros via `c.Error(err)` — middleware pode inspecionar `c.Errors` após a execução do handler para implementar logging de erros centralizado e formatação de respostas
