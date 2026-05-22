# Snippet de Prompt da Linguagem Rust

## Conceitos-Chave

- **Ownership e Borrowing**: cada valor tem um proprietário; referências fazem borrow sem assumir a posse
- **Lifetimes**: anotações (`'a`) garantindo que referências permaneçam válidas pela duração necessária
- **Traits e Trait Objects**: definições de comportamento compartilhado; `dyn Trait` para despacho dinâmico
- **Pattern Matching**: expressões `match` exaustivas que desconstruem enums, structs e tuples
- **Enums com Dados**: tipos algébricos de dados — cada variante pode carregar dados associados diferentes
- **Tratamento de Erros com Result/Option**: `Result<T, E>` para operações falíveis; `Option<T>` para valores nuláveis
- **Macros**: geração de código declarativa (`macro_rules!`) e procedural (derive, attribute, function-like)
- **Async/Await com Tokio**: async com custo zero usando o trait `Future` e executores de runtime
- **Unsafe Blocks**: blocos opt-in para desreferenciar raw pointers, FFI e contornar o borrow checker
- **Generics com Trait Bounds**: `<T: Clone + Send>` restringindo parâmetros genéricos
- **Closures e Traits Fn**: `Fn`, `FnMut`, `FnOnce` determinam como closures capturam o ambiente

## Padrões de Importação

- `use crate::module::Item` — importa do crate atual
- `use std::collections::HashMap` — importa da biblioteca padrão
- `use super::*` — importa tudo do módulo pai
- `mod module_name` — declara um submódulo (carrega do arquivo)

## Padrões de Arquivos

- `mod.rs` — barrel file de módulo (convenção antiga) ou `module_name.rs` (edition 2018+)
- `lib.rs` — raiz do crate de biblioteca definindo a API pública
- `main.rs` — ponto de entrada de crate binário
- `Cargo.toml` — manifesto do projeto com dependências e metadados
- `build.rs` — script de build executado antes da compilação

## Frameworks Comuns

- **Actix-web** — framework web baseado em atores e de alta performance
- **Axum** — framework web ergonômico construído sobre Tower e Hyper
- **Rocket** — framework web type-safe com roteamento declarativo
- **Diesel** — ORM e query builder seguro e composável
- **Tokio** — runtime async fornecendo I/O, timers e agendamento de tasks

## Exemplo de Notas da Linguagem

> Faz borrow `&self` para ler estado sem transferir a posse; retorna `Result<T, Error>`
> para propagação explícita de erros. O operador `?` propaga erros pela call stack
> de forma concisa, substituindo blocos `match` verbosos.
>
> O sistema de módulos mapeia para o sistema de arquivos: `mod handlers;` carrega ou
> `handlers.rs` ou `handlers/mod.rs`, estabelecendo a árvore de módulos em tempo de
> compilação.
