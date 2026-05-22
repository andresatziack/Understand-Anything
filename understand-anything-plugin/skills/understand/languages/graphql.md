# Snippet de Prompt da Linguagem GraphQL

## Conceitos-Chave

- **Sistema de Tipos**: schema fortemente tipado definindo o contrato da API com tipos scalar, object, enum e union
- **Queries**: operações de leitura que buscam dados com seleção em nível de campo (sem over-fetching)
- **Mutations**: operações de escrita para criar, atualizar e deletar dados
- **Subscriptions**: push de dados em tempo real sobre conexões WebSocket
- **Resolvers**: funções que mapeiam campos do schema para fontes de dados (banco, API, cache)
- **Fragments**: seleções de campo reutilizáveis que reduzem duplicação de queries entre operações
- **Directives**: `@deprecated`, `@include`, `@skip` para inclusão condicional de campos e metadados de schema
- **Input Types**: palavra-chave `input` para argumentos complexos de mutation
- **Interfaces e Unions**: tipos polimórficos para campos compartilhados entre múltiplos tipos object
- **Schema Stitching / Federation**: composição de múltiplos serviços GraphQL em um grafo unificado

## Padrões de Arquivo Notáveis

- `schema.graphql` / `*.graphql` — arquivos de definição de schema
- `*.gql` — extensão alternativa para arquivos GraphQL
- `schema/*.graphql` — arquivos de schema separados por domínio (users.graphql, orders.graphql)
- `*.resolvers.ts` / `*.resolvers.js` — implementações de resolver (convenção em TypeScript/JavaScript)
- `codegen.yml` — configuração do GraphQL Code Generator

## Padrões de Aresta

- Arquivos de schema GraphQL `defines_schema` para o código de resolver que implementa os handlers de query/mutation
- Definições de tipo criam arestas `related` entre tipos conectados por referências de campo
- Arquivos de schema `defines_schema` para arquivos de query/mutation no client que consomem a API
- Configuração do codegen `configures` a pipeline de geração de código a partir do schema

## Estilo de Resumo

> "Schema GraphQL definindo N tipos, M queries e K mutations para a API de gerenciamento de usuários."
> "Schema da API com definições de tipo para produtos, pedidos e processamento de pagamentos com paginação."
> "Schema de subscription habilitando notificações em tempo real para atualizações de status de pedido."
