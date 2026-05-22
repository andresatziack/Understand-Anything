# Snippet de Prompt da Linguagem JSON

## Conceitos-Chave

- **Sintaxe Estrita**: sem trailing commas, sem comentários (diferente de JSONC ou JSON5), apenas strings entre aspas duplas
- **Tipos de Dados**: objects, arrays, strings, numbers, booleans e null — sem undefined ou tipos de data
- **Estrutura Aninhada**: profundidade arbitrária de aninhamento para configuração ou dados hierárquicos
- **Validação por Schema**: JSON Schema (palavra-chave `$schema`) para validar estrutura e tipos
- **JSONC**: variante JSON with Comments usada pelo VS Code, tsconfig.json e outras ferramentas
- **JSON5**: JSON estendido permitindo comentários, trailing commas, chaves sem aspas e mais
- **JSON Lines** (`.jsonl`): um objeto JSON por linha para processamento de dados em streaming

## Padrões de Arquivo Notáveis

- `package.json` — manifesto de projeto Node.js com dependências, scripts e metadados
- `tsconfig.json` — configuração do compilador TypeScript (na verdade é JSONC)
- `.eslintrc.json` — regras e configuração de linting do ESLint
- `*.schema.json` — definições de JSON Schema para validação
- `composer.json` — manifesto de projeto do Composer (PHP)
- `appsettings.json` — configuração de aplicação .NET
- `manifest.json` — manifesto de extensão de browser ou de PWA

## Padrões de Aresta

- `package.json` `configures` a toolchain de build e define as dependências do projeto
- `tsconfig.json` `configures` a compilação TypeScript para todos os arquivos `.ts`
- Arquivos JSON Schema `defines_schema` para validação de request/response de APIs
- Arquivos JSON de configuração `configures` o comportamento da aplicação em runtime

## Estilo de Resumo

> "Manifesto de projeto Node.js definindo N dependências, scripts de build e metadados do projeto."
> "Configuração do compilador TypeScript habilitando strict mode com path aliases para packages do monorepo."
> "JSON Schema definindo a estrutura de request/response do endpoint da API de usuários."
