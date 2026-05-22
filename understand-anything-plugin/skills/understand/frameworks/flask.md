# Adendo do Framework Flask

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Flask é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Flask

Ao analisar um projeto Flask, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `app.py`, `__init__.py` (no pacote do app) | Application factory (`create_app()`) ou instância direta `Flask(__name__)` | `entry-point`, `config` |
| `run.py`, `wsgi.py` | Ponto de entrada do servidor de produção/desenvolvimento | `entry-point`, `config` |
| `*/views.py`, `*/routes.py` | Funções tratadoras de rota com `@app.route` ou `@blueprint.route` | `api-handler`, `routing` |
| `*/blueprints/*.py`, `*/api/*.py` | Módulos de blueprint — agrupam rotas por feature | `api-handler`, `routing` |
| `*/models.py` | Modelos do SQLAlchemy ou outros modelos de ORM | `data-model` |
| `*/forms.py` | Classes de form do WTForms | `validation`, `ui` |
| `*/schemas.py` | Schemas de serialização do Marshmallow | `serialization`, `type-definition` |
| `*/config.py` | Classes de configuração (`DevelopmentConfig`, `ProductionConfig`) | `config` |
| `*/extensions.py` | Inicialização de extensões do Flask (`db = SQLAlchemy()`, `login_manager = LoginManager()`) | `config`, `singleton` |
| `*/decorators.py` | Decorators de rota customizados (auth guards, rate limiting) | `middleware`, `utility` |
| `*/utils.py`, `*/helpers.py` | Funções utilitárias compartilhadas | `utility` |
| `*/templates/**/*.html` | Templates Jinja2 | `ui` |
| `*/static/` | Arquivos de CSS, JS e demais assets | `assets` |
| `*/tests/*.py`, `test_*.py` | Arquivos de teste do pytest ou unittest | `test` |

### Padrões de Aresta a Procurar

**Registro de blueprints** — Quando `app.register_blueprint(bp, url_prefix='/api')` aparece na application factory, crie arestas `depends_on` da factory do app para cada módulo de blueprint.

**Acoplamento via extensões** — Quando uma view importa de `extensions.py` (por exemplo, `from .extensions import db, login_manager`), crie arestas `imports` para mostrar quais views dependem de quais extensões.

**Hooks before/after request** — Quando `@app.before_request` ou `@blueprint.before_request` decora uma função, crie arestas de middleware dessas funções para o app/blueprint ao qual elas se conectam.

### Camadas Arquiteturais para Flask

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | Arquivos de rota de blueprints, funções de view |
| `layer:data` | Data Layer | `models.py`, arquivos de migration de banco |
| `layer:service` | Service Layer | Módulos de lógica de negócio, `schemas.py`, classes de service |
| `layer:ui` | UI Layer | `templates/`, `forms.py`, `static/` |
| `layer:config` | Config Layer | Factory `app.py`, `config.py`, `extensions.py` |
| `layer:middleware` | Middleware Layer | `decorators.py`, hooks before/after request |
| `layer:test` | Test Layer | Arquivos de teste, `conftest.py` |

### Padrões Notáveis a Capturar em languageLesson

- **Padrão application factory**: funções `create_app()` permitem múltiplas instâncias do app (por exemplo, para testes) e adiam a inicialização de extensões — evita imports circulares
- **Modularidade de blueprints**: blueprints agrupam rotas, templates e arquivos estáticos relacionados; são registrados no app com um prefixo de URL, tornando-os testáveis de forma independente
- **Protocolo de extensões do Flask**: extensões seguem o padrão `init_app(app)` para inicialização preguiçosa — o objeto da extensão é criado globalmente, mas vinculado a uma instância do app posteriormente
