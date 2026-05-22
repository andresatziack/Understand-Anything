# Snippet de Prompt da Linguagem C#

## Conceitos-Chave

- **Queries LINQ**: queries integradas à linguagem usando sintaxe de método (`.Where().Select()`) ou sintaxe de query
- **Async/Await com Task**: modelo de programação assíncrona retornando `Task<T>` para I/O não bloqueante
- **Generics e Constraints**: parâmetros de tipo com cláusulas de constraint `where T : class, IDisposable`
- **Properties (get/set)**: sintaxe de property de primeira classe com backing fields, auto-properties e init-only
- **Delegates e Events**: ponteiros de função type-safe; events fornecem o padrão publisher-subscriber
- **Attributes**: anotações de metadados (`[HttpGet]`, `[Authorize]`) para configuração declarativa
- **Nullable Reference Types**: null safety imposta pelo compilador com anotações `?` (C# 8+)
- **Pattern Matching**: expressões `is` e `switch` com padrões de tipo, propriedade e relacionais
- **Records e Init-Only Setters**: tipos de referência imutáveis com semântica de igualdade por valor (C# 9+)
- **Dependency Injection (Built-in)**: container de DI de primeira classe no ASP.NET Core (`IServiceCollection`)

## Padrões de Importação

- `using System.Collections.Generic` — importa um namespace para acesso a tipos sem qualificação
- `using static System.Math` — importa membros estáticos para acesso direto aos métodos
- `global using` — usings com escopo de arquivo aplicados ao projeto inteiro (C# 10)
- `using Alias = Namespace.Type` — alias de tipo para desambiguação

## Padrões de Arquivos

- `*.csproj` — arquivo de projeto MSBuild definindo targets, pacotes e propriedades de build
- `*.sln` — arquivo de solução do Visual Studio agrupando múltiplos projetos
- `Program.cs` — ponto de entrada da aplicação (top-level statements no .NET 6+)
- `Startup.cs` — configuração de serviços e middleware (padrão antigo do ASP.NET Core)
- `appsettings.json` — configuração hierárquica da aplicação

## Frameworks Comuns

- **ASP.NET Core** — framework web cross-platform para APIs, MVC e Razor Pages
- **Entity Framework** — ORM com LINQ-to-SQL, migrations e change tracking
- **Blazor** — framework de UI baseado em componentes usando C# em vez de JavaScript
- **MAUI** — UI nativa cross-platform para aplicações mobile e desktop
- **xUnit** — framework de testes moderno com theories, facts e injeção de dependências

## Exemplo de Notas da Linguagem

> Usa a sintaxe de método LINQ `.Where().Select()` para compor uma pipeline de query
> sobre a coleção. Operações LINQ são avaliadas de forma preguiçosa — a query só executa
> quando os resultados são enumerados, permitindo composição eficiente sem alocações
> intermediárias.
>
> O container de DI integrado do ASP.NET Core registra serviços em `Program.cs` e os
> resolve via injeção de construtor, seguindo o padrão composition root.
