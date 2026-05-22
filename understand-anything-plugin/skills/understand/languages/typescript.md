# Snippet de Prompt da Linguagem TypeScript

## Conceitos-Chave

- **Generics**: tipos parametrizados (`<T>`) que habilitam abstrações reutilizáveis e type-safe
- **Type Guards**: checagens em runtime que estreitam tipos dentro de blocos condicionais (`is`, `in`, `typeof`, `instanceof`)
- **Discriminated Unions**: tipos union com um campo literal compartilhado usado para narrowing exaustivo
- **Utility Types**: mapped types embutidos como `Partial<T>`, `Pick<T, K>`, `Omit<T, K>`, `Record<K, V>`
- **Interfaces vs Types**: interfaces suportam declaration merging; type aliases suportam unions e mapped types
- **Enums**: enums numéricos e de string para conjuntos de constantes nomeadas; prefira objetos `as const` quando possível
- **Mapped Types**: transformam tipos existentes propriedade por propriedade usando a sintaxe `[K in keyof T]`
- **Conditional Types**: `T extends U ? X : Y` para lógica de branching no nível de tipo
- **Template Literal Types**: manipulação de strings no nível de tipo usando sintaxe de backticks
- **Declaration Merging**: interfaces com o mesmo nome mesclam seus membros automaticamente
- **Module Augmentation**: estende tipos de módulos de terceiros via blocos `declare module`

## Padrões de Importação

- `import { X } from 'module'` — named import (mais comum)
- `import type { X } from 'module'` — import apenas de tipo (apagado em runtime)
- `import * as X from 'module'` — import de namespace
- `import X from 'module'` — default import

## Padrões de Arquivos

- `index.ts` — barrel file reexportando a API pública de um diretório
- `*.d.ts` — arquivos de declaração de tipo (declarações ambient, sem código de runtime)
- `tsconfig.json` — configuração do compilador TypeScript e project references
- `*.tsx` — arquivos TypeScript contendo JSX (componentes React)

## Frameworks Comuns

- **React** — biblioteca de componentes de UI com hooks e JSX
- **Angular** — framework completo com decorators e injeção de dependências
- **Next.js** — meta-framework React com SSR, SSG e rotas de API
- **NestJS** — framework server-side inspirado no Angular (decorators, módulos, DI)
- **Express (com TS)** — framework HTTP mínimo com handlers de request/response tipados

## Exemplo de Notas da Linguagem

> Usa o parâmetro de tipo genérico `T extends BaseEntity` para garantir segurança de
> tipos entre os métodos do repository. A constraint garante que todas as entidades
> compartilhem um campo `id` comum, permitindo que tipos de entidade específicos
> fluam pela camada de dados sem casting.
>
> Barrel files (`index.ts`) reexportam símbolos para que consumidores importem do
> diretório em vez de alcançar caminhos internos de módulos — mantendo o
> encapsulamento.
