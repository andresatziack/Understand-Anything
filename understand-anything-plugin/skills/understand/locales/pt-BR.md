# Guia de Saída em Português (Brasil)

Este arquivo fornece orientação específica para gerar conteúdo do knowledge graph em português do Brasil.

## Tag Conventions

Use uma estratégia híbrida: tags descritivas em PT-BR convivem com termos técnicos consagrados em inglês.

| Padrão | Tags recomendadas |
|--------|-------------------|
| Arquivo de entrada | `ponto-de-entrada`, `barrel`, `exports` ou `entry-point` |
| Funções utilitárias | `utilitários`, `helpers`, `common` ou `utility` |
| Manipuladores de API | `manipulador-api`, `controller`, `endpoint` ou `api-handler` |
| Modelos de dados | `modelo-de-dados`, `entity`, `schema` ou `data-model` |
| Arquivos de teste | `teste`, `unit-test`, `spec` |
| Configuração | `configuração`, `build-system`, `settings` ou `configuration` |
| Infraestrutura | `infraestrutura`, `deployment`, `containerização` ou `infrastructure` |
| Documentação | `documentação`, `guia`, `referência` ou `documentation` |

**Estratégia híbrida:** mantenha termos técnicos genéricos em inglês (`middleware`, `api-handler`, `entry-point`); use PT-BR apenas para tags descritivas que tenham equivalente natural na língua.

## Summary Style

Escreva sumários de 1–2 frases em PT-BR que:
- Descrevam o **propósito** e o **papel** do arquivo no projeto.
- Usem voz ativa (`Fornece...`, `Manipula...`, `Gerencia...`, `Coordena...`).
- Não repitam o nome do arquivo.

**Exemplos:**
- Bom: "Fornece helpers de formatação de datas e sanitização de strings reutilizados pela camada de API."
- Ruim: "O arquivo utils contém funções utilitárias."

## Technical Terms

Mantenha estes termos em inglês (sem tradução):
- `middleware`, `hook`, `barrel`, `entry-point`
- `ORM`, `REST API`, `CI/CD`, `CRUD`
- `singleton`, `factory`, `observer`
- `interceptor`, `guard`

## Layer Names

Prefira nomes de camadas em PT-BR para a maioria dos contextos:
- `Camada API`, `Camada de Serviço`, `Camada de Dados`, `Camada UI`
- `Infraestrutura`, `Configuração`, `Documentação`
- `Camada de Utilitários`, `Camada de Middleware`, `Camada de Testes`

Ou mantenha em inglês quando o time já adotou essa convenção:
- `API Layer`, `Service Layer`, `Data Layer`, `UI Layer`
- `Infrastructure`, `Configuration`, `Documentation`
- `Utility Layer`, `Middleware Layer`, `Test Layer`
