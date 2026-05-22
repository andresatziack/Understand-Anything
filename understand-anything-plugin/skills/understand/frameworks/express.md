# Adendo do Framework Express

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Express é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Express

Ao analisar um projeto Express, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `app.js`, `app.ts` | Ponto de entrada da aplicação — cria o app Express, registra middleware e rotas | `entry-point`, `config` |
| `server.js`, `server.ts`, `index.js`, `index.ts` | Bootstrap do servidor — inicia o listener HTTP, pode importar o app | `entry-point`, `config` |
| `routes/*.js`, `routes/*.ts` | Definições de rotas — mapeiam métodos e caminhos HTTP para handlers | `api-handler`, `routing` |
| `controllers/*.js`, `controllers/*.ts` | Tratadores de requisição — processam requisições, orquestram services, retornam respostas | `api-handler`, `service` |
| `models/*.js`, `models/*.ts` | Modelos de dados — schemas do Mongoose, modelos do Sequelize ou definições de dados puras | `data-model` |
| `middleware/*.js`, `middleware/*.ts` | Funções de middleware — autenticação, logging, validação, tratamento de erros | `middleware` |
| `services/*.js`, `services/*.ts` | Lógica de negócio — operações de domínio desacopladas da camada HTTP | `service` |
| `db/*.js`, `db/*.ts`, `database/*.js` | Conexão e configuração de banco de dados | `data-model`, `config` |
| `config/*.js`, `config/*.ts` | Configuração da aplicação — variáveis de ambiente, feature flags | `config` |
| `validators/*.js`, `validators/*.ts` | Schemas de validação de requisição (Joi, Zod, express-validator) | `validation`, `utility` |
| `utils/*.js`, `utils/*.ts` | Funções utilitárias compartilhadas | `utility` |
| `tests/*.js`, `test/*.js`, `__tests__/*.js` | Testes unitários e de integração | `test` |

### Padrões de Aresta a Procurar

**Montagem de rotas** — Quando `app.use('/api/users', usersRouter)` monta um router, crie arestas `depends_on` do app principal para o módulo do router. Essas arestas representam a árvore de roteamento HTTP.

**Cadeia de middleware** — Quando `app.use(cors())`, `app.use(authMiddleware)` ou `router.use(validate)` registra um middleware, crie arestas de middleware do app ou router para a função de middleware. A ordem importa — middleware é executado na ordem de registro.

**Chamadas controller-service** — Quando um controller importa e chama uma função de service, crie arestas `depends_on` do controller para o service. Isso representa a separação entre tratamento HTTP e lógica de negócio.

**Relacionamentos de modelos** — Quando modelos referenciam uns aos outros (`ref` do Mongoose, associations do Sequelize), crie arestas `depends_on` entre os arquivos de modelo com descrições indicando o tipo de relacionamento.

### Camadas Arquiteturais para Express

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | `routes/`, `controllers/`, validadores de requisição |
| `layer:data` | Data Layer | `models/`, `db/`, arquivos de migration, seeders |
| `layer:service` | Service Layer | `services/`, módulos de lógica de negócio |
| `layer:middleware` | Middleware Layer | `middleware/`, tratadores de erro, autenticação, logging |
| `layer:config` | Config Layer | `app.js`, `config/`, configuração de ambiente, `server.js` |
| `layer:utility` | Utility Layer | `utils/`, `helpers/`, funções puras compartilhadas |
| `layer:test` | Test Layer | `tests/`, `__tests__/`, `*.test.js`, `*.spec.js` |

### Padrões Notáveis a Capturar em languageLesson

- **Cadeia de middleware (req, res, next)**: o Express processa requisições por uma pipeline de funções de middleware — cada uma recebe a requisição, a resposta e um callback `next()` para passar o controle adiante
- **Middleware de tratamento de erros (4 parâmetros)**: middleware com a assinatura `(err, req, res, next)` captura erros — deve ser registrado depois de todas as rotas para atuar como tratador global de erros
- **Modularidade do Router**: `express.Router()` cria handlers de rota modulares e montáveis, que podem ser compostos no app principal sob diferentes prefixos de caminho
- **Padrão MVC**: aplicações Express geralmente separam responsabilidades em Models (dados), Views (formatação de resposta) e Controllers (tratamento de requisição)
- **Parsing e validação de body**: o parsing do body da requisição (`express.json()`, `express.urlencoded()`) e a validação (Joi, Zod, express-validator) são preocupações de middleware aplicadas antes dos handlers de rota
