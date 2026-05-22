# Adendo do Framework Django

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Django é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Django

Ao analisar um projeto Django, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `manage.py` | Ponto de entrada CLI para servidor de desenvolvimento, migrations e comandos de gerenciamento | `entry-point`, `config` |
| `*/settings.py`, `*/settings/*.py` | Configuração do projeto (banco, apps instalados, middleware) | `config` |
| `*/urls.py` | Roteamento de URLs — mapeia padrões de URL para views | `api-handler`, `routing` |
| `*/views.py`, `*/views/*.py` | Tratadores de requisição (function-based ou class-based views) | `api-handler`, `controller` |
| `*/models.py`, `*/models/*.py` | Modelos do ORM — mapeiam para tabelas do banco | `data-model` |
| `*/serializers.py` | Serializers do DRF — convertem modelos de/para JSON | `serialization`, `api-handler` |
| `*/forms.py` | Forms do Django — lógica de validação e renderização | `validation`, `ui` |
| `*/admin.py` | Registros no admin — expõem modelos no admin do Django | `config` |
| `*/signals.py` | Tratadores de signals — efeitos colaterais transversais em eventos de modelo | `event-handler` |
| `*/tasks.py` | Definições de tasks assíncronas do Celery | `service`, `event-handler` |
| `*/middleware.py`, `*/middleware/*.py` | Classes de middleware de request/response | `middleware` |
| `*/permissions.py` | Classes de permissão do DRF | `middleware`, `validation` |
| `*/filters.py` | Backends de filtro do DRF | `utility` |
| `*/migrations/*.py` | Migrations de schema geradas automaticamente — não devem ser resumidas individualmente | `config` |
| `*/templates/**/*.html` | Templates HTML do Django | `ui` |
| `*/templatetags/*.py` | Filtros e tags de template customizados | `utility` |
| `*/management/commands/*.py` | Comandos de gerenciamento customizados (`./manage.py mycommand`) | `config`, `entry-point` |
| `wsgi.py`, `asgi.py` | Adaptador de servidor WSGI/ASGI — ponto de entrada de produção | `config`, `entry-point` |
| `*/apps.py` | Configuração do app e hooks de inicialização (`AppConfig`) | `config` |
| `*/tests.py`, `*/tests/*.py` | Testes unitários e de integração | `test` |

### Padrões de Aresta a Procurar

**Grafo de roteamento de URLs** — Crie arestas `calls` dos nós de `urls.py` para os nós de view correspondentes quando `path()` ou `re_path()` mapeia um padrão de URL para uma função ou classe de view. Essas arestas representam a cadeia de roteamento HTTP.

**Conexão de signals** — Quando `signals.py` usa `post_save.connect(handler, sender=Model)` ou `@receiver(post_save, sender=Model)`, crie arestas `subscribes` da função tratadora do signal para a classe do modelo. Crie arestas `publishes` do modelo para o tratador do signal para mostrar a direção do disparo.

**Relacionamentos do ORM** — Quando `models.py` define `ForeignKey`, `OneToOneField` ou `ManyToManyField`, crie arestas `depends_on` entre as classes de modelo com uma descrição indicando o tipo e a cardinalidade do relacionamento.

**Ligação serializer-modelo** — Quando um serializer do DRF tem `model = MyModel` em sua classe `Meta`, crie uma aresta `depends_on` do serializer para o modelo.

**Ligação view-serializer** — Quando um ViewSet ou APIView do DRF referencia uma classe de serializer, crie uma aresta `depends_on` da view para o serializer.

### Camadas Arquiteturais para Django

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | `views.py`, `serializers.py`, `urls.py`, ViewSets e APIViews do DRF |
| `layer:data` | Data Layer | `models.py`, `migrations/`, arquivos utilitários de banco |
| `layer:service` | Service Layer | `signals.py`, `tasks.py`, managers customizados, módulos de serviço |
| `layer:ui` | UI Layer | `templates/`, `forms.py`, `templatetags/` |
| `layer:middleware` | Middleware Layer | `middleware.py`, `permissions.py`, backends de autenticação |
| `layer:config` | Config Layer | `settings.py`, `urls.py` (raiz), `wsgi.py`, `asgi.py`, `apps.py`, `manage.py` |
| `layer:test` | Test Layer | `tests.py`, diretório `tests/`, `conftest.py` |

### Padrões Notáveis a Capturar em languageLesson

- **Fat models vs. thin views**: Django incentiva colocar a lógica de negócio em métodos do modelo, mantendo as views como adaptadores HTTP enxutos
- **Avaliação preguiçosa do ORM do Django**: QuerySets não são avaliados até serem iterados — encadeie filtros sem acessar o banco
- **Class-based views (CBVs)**: Mixins como `LoginRequiredMixin` e `PermissionRequiredMixin` compõem comportamento via herança múltipla
- **Anti-padrões de signals**: Signals criam acoplamento invisível; um signal em `signals.py` pode ser disparado por uma chamada `save()` em qualquer ponto do codebase
- **Isolamento de apps**: Cada app do Django (`INSTALLED_APPS`) deve ser autocontido com seus próprios models, views, urls e migrations
