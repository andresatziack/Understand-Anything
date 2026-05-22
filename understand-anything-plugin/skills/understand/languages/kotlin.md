# Snippet de Prompt da Linguagem Kotlin

## Conceitos-Chave

- **Coroutines e Flow**: concorrência estruturada com funções suspensas; Flow para streams reativos
- **Data Classes**: `equals`, `hashCode`, `toString`, `copy` e destructuring auto-gerados
- **Sealed Classes/Interfaces**: hierarquias restritas que habilitam expressões `when` exaustivas
- **Extension Functions**: adicionam métodos a classes existentes sem herança ou wrappers
- **Null Safety**: chamada segura `?.`, asserção não-nula `!!`, operador Elvis `?:` para valores padrão
- **Delegation (palavra-chave by)**: delega implementação de interface ou acesso a property para outro objeto
- **DSL Builders**: sintaxe lambda-with-receiver que habilita padrões de builder type-safe
- **Inline Functions e Reified Types**: inline para lambdas com overhead zero; reified para acesso a tipo em runtime
- **Companion Objects**: singleton nomeado ou anônimo associado a uma classe (substitui membros estáticos)
- **Scope Functions**: `let`, `run`, `apply`, `also`, `with` para configuração e transformação concisas de objetos

## Padrões de Importação

- `import package.ClassName` — importa uma classe específica
- `import package.*` — import wildcard de todas as declarações em um package
- `import package.function as alias` — import com alias para resolver conflitos de nomenclatura

## Padrões de Arquivos

- `build.gradle.kts` — script de build do Gradle usando a DSL Kotlin
- `Application.kt` — ponto de entrada da aplicação (Spring Boot ou Ktor)
- `src/main/kotlin/` — raiz dos fontes principais seguindo as convenções do Gradle
- `src/test/kotlin/` — raiz dos fontes de teste com estrutura de package equivalente
- `settings.gradle.kts` — configuração de projeto multi-módulo

## Frameworks Comuns

- **Spring Boot (Kotlin)** — suporte Kotlin-first com coroutines e extensões DSL
- **Ktor** — framework web async Kotlin-native da JetBrains
- **Jetpack Compose** — toolkit declarativo de UI para Android usando funções composable
- **Exposed** — framework SQL leve com DSL type-safe e padrões DAO
- **Koin** — framework pragmático de injeção de dependências usando DSL Kotlin

## Exemplo de Notas da Linguagem

> Usa hierarquia sealed class com casamento exaustivo via `when` para tratar todos os
> estados possíveis de resposta da API. O compilador impõe que toda variante seja
> coberta, eliminando a necessidade de um branch `else` de fallback e capturando casos
> ausentes em tempo de compilação.
>
> Extension functions permitem adicionar utilitários como `String.toSlug()` sem
> modificar a classe original — mantendo a extensão descobrível via auto-complete da
> IDE.
