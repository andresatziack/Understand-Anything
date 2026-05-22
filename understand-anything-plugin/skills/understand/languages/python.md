# Snippet de Prompt da Linguagem Python

## Conceitos-Chave

- **Decorators**: funções que envolvem outras funções ou classes usando a sintaxe `@decorator`
- **List/Dict Comprehensions**: sintaxe concisa para criar coleções a partir de iteráveis
- **Generators e Yield**: iteradores preguiçosos usando `yield` para processamento de dados eficiente em memória
- **Context Managers**: statement `with` para gerenciamento de recursos via `__enter__`/`__exit__`
- **Type Hints e o módulo typing**: anotações de tipo estáticas opcionais para ferramentas e documentação
- **Dunder Methods**: métodos especiais como `__init__`, `__repr__`, `__eq__` definindo o comportamento de objetos
- **Metaclasses**: classes que definem como outras classes são criadas (type como metaclasse padrão)
- **Dataclasses**: decorator `@dataclass` que auto-gera código boilerplate a partir de anotações de campo
- **Protocols**: subtipagem estrutural via `typing.Protocol` para interfaces seguras com duck typing
- **Descriptors**: objetos que definem `__get__`, `__set__`, `__delete__` para customizar acesso a atributos
- **Async/Await com Asyncio**: concorrência cooperativa usando coroutines e um event loop

## Padrões de Importação

- `from module import name` — importa um nome específico de um módulo
- `import module` — importa o módulo inteiro, acessível via `module.name`
- `from package.module import name` — import absoluto de um package aninhado
- `from . import relative` — import relativo dentro de um package

## Padrões de Arquivos

- `__init__.py` — inicializador do package (equivalente ao barrel), pode reexportar a API pública
- `__main__.py` — ponto de entrada do package quando executado com `python -m package`
- `conftest.py` — fixtures e hooks compartilhados do pytest (descobertos automaticamente)
- `setup.py` / `pyproject.toml` — configuração do projeto e metadados de build
- `requirements.txt` — lista de dependências fixadas

## Frameworks Comuns

- **Django** — framework web full-stack com ORM, admin e baterias inclusas
- **FastAPI** — framework de API async moderno com documentação OpenAPI automática
- **Flask** — micro-framework WSGI leve para aplicações web
- **SQLAlchemy** — toolkit SQL e ORM com padrão unit-of-work
- **Celery** — fila de tasks distribuída para processamento de jobs em background
- **Pydantic** — validação de dados e gerenciamento de configurações usando anotações de tipo

## Exemplo de Notas da Linguagem

> Usa o decorator `@dataclass` para auto-gerar `__init__`, `__repr__` e `__eq__` a
> partir das anotações de campo. Isso elimina boilerplate enquanto mantém a definição
> da classe legível e os métodos gerados consistentes.
>
> Quando `__init__.py` reexporta símbolos, atua como a superfície de API pública do
> package — consumidores importam do package em vez de alcançar módulos internos.
