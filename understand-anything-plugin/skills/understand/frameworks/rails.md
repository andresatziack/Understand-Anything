# Adendo do Framework Ruby on Rails

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Rails é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Rails

Ao analisar um projeto Ruby on Rails, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `config.ru` | Ponto de entrada Rack — inicializa a aplicação Rails para o web server | `entry-point` |
| `config/application.rb` | Configuração da aplicação — configura o Rails, carrega gems, configura middleware | `entry-point`, `config` |
| `app/controllers/*_controller.rb` | Controllers — lidam com requisições HTTP, orquestram models, renderizam respostas | `api-handler` |
| `app/controllers/concerns/*.rb` | Concerns de controller — comportamento compartilhado de controller via mixins | `middleware`, `utility` |
| `app/models/*.rb` | Modelos ActiveRecord — mapeiam para tabelas do banco, contêm validações e associations | `data-model` |
| `app/models/concerns/*.rb` | Concerns de model — comportamento compartilhado de model via mixins | `utility` |
| `app/views/**/*.erb`, `app/views/**/*.haml` | Templates de view — renderização de HTML com Ruby embutido | `ui` |
| `app/helpers/*_helper.rb` | View helpers — métodos utilitários disponíveis nos templates | `utility` |
| `app/mailers/*_mailer.rb` | Classes Action Mailer — enviam notificações por e-mail | `service` |
| `app/jobs/*_job.rb` | Classes Active Job — processamento de jobs em background | `service` |
| `app/channels/*_channel.rb` | Channels do Action Cable — comunicação via WebSocket | `service` |
| `app/serializers/*_serializer.rb` | Serializers de API — formatação de respostas JSON (ActiveModelSerializers, Blueprinter) | `api-handler`, `utility` |
| `app/services/*.rb` | Service objects — encapsulam lógica de negócio complexa | `service` |
| `db/migrate/*.rb` | Migrations de banco — mudanças de schema versionadas por timestamp | `config`, `data-model` |
| `db/schema.rb`, `db/structure.sql` | Snapshot de schema gerado — estrutura atual do banco | `data-model`, `config` |
| `config/routes.rb` | Definições de rota — mapeia URLs para ações de controller | `routing`, `config` |
| `config/initializers/*.rb` | Initializers — rodam uma vez no boot para configurar gems e serviços | `config` |
| `lib/**/*.rb` | Código de biblioteca — classes customizadas, tasks Rake, extensões | `utility`, `service` |
| `spec/**/*_spec.rb`, `test/**/*_test.rb` | Arquivos de teste do RSpec ou Minitest | `test` |

### Padrões de Aresta a Procurar

**Mapeamento rota-controller** — Quando `config/routes.rb` define `resources :users` ou `get '/foo', to: 'bar#baz'`, crie arestas `configures` do arquivo de rotas para o controller correspondente. Recursos RESTful geram um conjunto completo de mapeamentos de ação.

**Associations do ActiveRecord** — Quando models definem `has_many`, `belongs_to`, `has_one` ou `has_and_belongs_to_many`, crie arestas `depends_on` entre os arquivos de model com descrições indicando o tipo e a direção da association.

**Controller-modelo** — Quando um controller chama métodos de model (`User.find`, `@post.save`), crie arestas `depends_on` do controller para o model. Controllers são os principais consumidores dos dados dos models.

**Callbacks** — Quando models ou controllers usam `before_action`, `after_save`, `before_validation` ou callbacks similares, registre-os como arestas semelhantes a middleware. Callbacks criam caminhos de execução implícitos que não são visíveis no ponto de chamada.

### Camadas Arquiteturais para Rails

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | `app/controllers/`, `app/serializers/`, controllers específicos de API |
| `layer:data` | Data Layer | `app/models/`, `db/migrate/`, `db/schema.rb` |
| `layer:ui` | UI Layer | `app/views/`, `app/helpers/`, `app/assets/`, `app/javascript/` |
| `layer:service` | Service Layer | `app/mailers/`, `app/jobs/`, `app/channels/`, `app/services/`, `lib/` |
| `layer:config` | Config Layer | `config/routes.rb`, `config/initializers/`, `config/application.rb`, `config.ru` |
| `layer:middleware` | Middleware Layer | `app/middleware/`, concerns de controller, middleware Rack |
| `layer:test` | Test Layer | `spec/`, `test/`, `*.spec.rb`, `*_test.rb` |

### Padrões Notáveis a Capturar em languageLesson

- **Convenção sobre configuração**: o Rails deriva roteamento, nomes de tabela e localizações de arquivos a partir de convenções de nomenclatura — `UsersController` mapeia para `users_controller.rb`, lida com `/users` e consulta a tabela `users`
- **Padrão ActiveRecord**: models são wrappers de banco — cada classe de model mapeia para uma tabela, instâncias mapeiam para linhas e atributos mapeiam para colunas com coerção automática de tipos
- **Concerns para comportamento compartilhado**: módulos `ActiveSupport::Concern` são mixins incluídos em models ou controllers para compartilhar validações, scopes, callbacks e métodos entre classes
- **Strong parameters para proteção contra mass-assignment**: `params.require(:user).permit(:name, :email)` faz whitelist dos atributos — controllers precisam declarar explicitamente quais campos podem ser definidos a partir da entrada do usuário
- **Roteamento RESTful de recursos**: `resources :posts` gera sete rotas CRUD padrão — o Rails incentiva fortemente design RESTful, em que cada controller mapeia para um recurso
- **Callbacks e observers**: `before_save`, `after_create` e callbacks similares injetam lógica no ciclo de vida do objeto — eles criam caminhos de execução invisíveis que podem ser difíceis de rastrear
