# Adendo do Framework FastAPI

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando FastAPI é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto FastAPI

Ao analisar um projeto FastAPI, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `main.py`, `app.py` | Application factory — cria e configura a instância `FastAPI()` | `entry-point`, `config` |
| `*/routers/*.py`, `*/api/*.py` | Módulos `APIRouter` — agrupam endpoints relacionados por domínio | `api-handler`, `routing` |
| `*/schemas.py`, `*/schemas/*.py` | Modelos Pydantic de request/response | `type-definition`, `serialization` |
| `*/models.py`, `*/models/*.py` | Modelos do ORM SQLAlchemy ou outros modelos de banco | `data-model` |
| `*/dependencies.py`, `*/deps.py` | Funções provedoras de `Depends()` — lógica compartilhada injetada nas rotas | `service`, `middleware` |
| `*/crud.py`, `*/repository.py` | Camada de acesso a dados — operações CRUD | `data-model`, `service` |
| `*/database.py`, `*/db.py` | Engine do banco, factory de session, gerenciamento de conexão | `config`, `data-model` |
| `*/config.py`, `*/settings.py` | Classes de configuração `pydantic-settings` / `BaseSettings` | `config` |
| `*/middleware.py` | Classes de middleware do Starlette | `middleware` |
| `*/exceptions.py` | Classes de exceção customizadas e tratadores de exceção | `utility` |
| `*/security.py`, `*/auth.py` | Utilitários de autenticação — decodificação de JWT, hashing de senha, helpers de OAuth | `service`, `middleware` |
| `*/tasks.py` | Definições de tasks em background ou tasks do Celery | `service`, `event-handler` |
| `*/tests/*.py`, `test_*.py` | Arquivos de teste do pytest | `test` |
| `conftest.py` | Fixtures e configuração de teste do pytest | `test`, `config` |

### Padrões de Aresta a Procurar

**Cadeia de inclusão de routers** — Quando `app.include_router(some_router, prefix="/api")` aparece em `main.py` ou em um agregador de routers, crie arestas `imports` + `depends_on` do arquivo principal do app para cada módulo de router. Isso constrói o grafo da hierarquia de URLs.

**Árvore de injeção de dependências** — Quando uma função de rota ou outro provedor `Depends()` importa e chama `Depends(some_function)`, crie arestas `depends_on` do chamador para o provedor da dependência. Rastreie essas cadeias — frequentemente atravessam múltiplos arquivos (por exemplo, rota → dependência de auth → dependência de session de banco).

**Herança de modelos Pydantic** — Quando uma classe de schema herda de outra (por exemplo, `class UserCreate(UserBase)`), crie arestas `inherits` entre os nós das classes de schema.

**Relacionamentos de modelos do ORM** — Quando modelos do SQLAlchemy usam `relationship()` ou `ForeignKey`, crie arestas `depends_on` entre as classes de modelo.

**Ligação CRUD-modelo** — Quando uma função de `crud.py` recebe um tipo de modelo como argumento ou referencia diretamente uma classe de modelo, crie arestas `depends_on` do arquivo CRUD para o arquivo de modelo.

### Camadas Arquiteturais para FastAPI

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | Arquivos de router, funções de endpoint com decorators `@router.get/post/...` |
| `layer:types` | Types Layer | Arquivos de schema Pydantic, modelos de request/response |
| `layer:service` | Service Layer | `dependencies.py`, `crud.py`, módulos de lógica de negócio |
| `layer:data` | Data Layer | Modelos do ORM, `database.py`, migrations |
| `layer:config` | Config Layer | Factory `main.py` / `app.py`, `settings.py`, `config.py` |
| `layer:middleware` | Middleware Layer | `middleware.py`, `security.py`, `auth.py`, tratadores de exceção |
| `layer:test` | Test Layer | `tests/`, `conftest.py` |

### Padrões Notáveis a Capturar em languageLesson

- **Injeção de dependências como composição**: `Depends()` do FastAPI é um sistema de DI de primeira classe — uma rota pode declarar qualquer número de dependências, e cada uma pode ter suas próprias dependências, formando uma árvore resolvida em tempo de requisição
- **Pydantic para validação**: bodies de requisição, query params e path params são validados automaticamente pelo Pydantic — entradas inválidas geram `422 Unprocessable Entity` antes de seu código rodar
- **Endpoints async**: rotas `async def` rodam no event loop; rotas `def` rodam em um threadpool — misturá-las incorretamente pode causar problemas de performance
- **Ordem de path operations**: o FastAPI casa rotas na ordem de declaração; uma rota catch-all antes de uma específica vai sobrescrevê-la
