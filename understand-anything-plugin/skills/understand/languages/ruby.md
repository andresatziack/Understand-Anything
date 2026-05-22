# Snippet de Prompt da Linguagem Ruby

## Conceitos-Chave

- **Blocks/Procs/Lambdas**: objetos invocáveis de primeira classe; blocks são implícitos, procs e lambdas são explícitos
- **Mixins (include/extend)**: compartilham comportamento entre classes via módulos sem herança
- **Metaprogramação**: definição dinâmica de métodos (`define_method`), interceptação (`method_missing`)
- **Duck Typing**: objetos são definidos pelo que podem fazer, não pela classe que são
- **DSLs**: linguagens específicas de domínio construídas usando blocks e metaprogramação (por exemplo, rotas do Rails)
- **Monkey Patching**: reabertura de classes existentes para adicionar ou modificar métodos em runtime
- **Symbols**: strings imutáveis e internadas (`:name`) usadas como identificadores e chaves de hash
- **Open Classes**: qualquer classe pode ser reaberta e estendida em qualquer ponto do programa
- **Módulo Enumerable**: mixin que fornece métodos de coleção (map, select, reduce) a qualquer classe com `each`

## Padrões de Importação

- `require 'gem_name'` — carrega um gem ou módulo da biblioteca padrão
- `require_relative './file'` — carrega um arquivo relativo ao diretório do arquivo atual
- `load 'file.rb'` — carrega e reexecuta um arquivo (diferente do require, não cacheia)
- `autoload :ClassName, 'path'` — carregamento preguiçoso de constantes na primeira referência

## Padrões de Arquivos

- `Gemfile` — declarações de dependências gerenciadas pelo Bundler
- `Rakefile` — definições de tasks (equivalente do make em Ruby)
- `spec/` — diretório de testes RSpec com convenção `*_spec.rb`
- `test/` — diretório de Minitest com convenção `test_*.rb` ou `*_test.rb`
- `config.ru` — ponto de entrada da aplicação Rack para web servers
- `lib/` — diretório principal de código-fonte por convenção

## Frameworks Comuns

- **Rails** — framework web full-stack seguindo convenção sobre configuração
- **Sinatra** — DSL minimalista para criar aplicações web rapidamente
- **RSpec** — framework de testes orientado a comportamento com DSL expressiva
- **Sidekiq** — processamento de jobs em background usando filas baseadas em Redis
- **Grape** — micro-framework de APIs REST para Ruby

## Exemplo de Notas da Linguagem

> Usa `method_missing` para delegar dinamicamente o acesso a atributos para o objeto
> de modelo envolvido. Quando um método não é encontrado no decorator, ele cai para o
> modelo, fornecendo delegação transparente sem métodos de forwarding explícitos.
>
> O Rails depende fortemente de convenção sobre configuração — a localização dos
> arquivos em `app/models/`, `app/controllers/`, etc. determina o comportamento sem
> registro explícito.
