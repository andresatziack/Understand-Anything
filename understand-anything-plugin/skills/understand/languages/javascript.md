# Snippet de Prompt da Linguagem JavaScript

## Conceitos-Chave

- **Closures**: funções que capturam variáveis do seu escopo léxico envolvente
- **Prototypes**: herança baseada em cadeia de prototypes que sustenta todos os objetos JavaScript
- **Promises**: containers de valor assíncrono que habilitam encadeamento `.then()` e `async/await`
- **Event Loop**: modelo de concorrência single-threaded com filas de microtasks e macrotasks
- **Destructuring**: extrai valores de objetos e arrays para variáveis distintas
- **Operadores Spread/Rest**: `...` para expandir iteráveis ou coletar argumentos restantes
- **Proxies**: construto de meta-programação para interceptar e customizar operações de objeto
- **Generators**: funções usando `function*` e `yield` para iteração preguiçosa
- **Symbol**: primitiva única e imutável usada como chaves de propriedade não-string
- **WeakMap/WeakSet**: coleções com chaves mantidas por referências fracas, permitindo coleta de lixo
- **Modules (ESM vs CJS)**: ES Modules usam `import/export`; CommonJS usa `require/module.exports`

## Padrões de Importação

- `import { X } from 'module'` — named import ESM
- `const X = require('module')` — require CommonJS
- `import('module')` — dynamic import retornando uma Promise (code splitting)
- `export default X` / `export { X }` — formas de export ESM

## Padrões de Arquivos

- `index.js` — barrel file ou ponto de entrada do diretório
- `.mjs` — arquivos explicitamente ES Module
- `.cjs` — arquivos explicitamente CommonJS
- Campo `"type"` em `package.json` — define o sistema de módulos padrão (`"module"` ou `"commonjs"`)

## Frameworks Comuns

- **React** — UI declarativa com virtual DOM e modelo de componentes
- **Vue** — framework progressivo com sistema de reatividade e single-file components
- **Express** — framework web mínimo e flexível para Node.js
- **Next.js** — framework React para produção com renderização híbrida
- **Svelte** — framework em tempo de compilação que move trabalho do runtime para o build step

## Exemplo de Notas da Linguagem

> Closure captura a variável externa `config`, fornecendo estado encapsulado sem o
> overhead de uma classe. Os métodos do objeto retornado compartilham acesso à mesma
> referência de `config`, formando o module pattern que era padrão antes dos ES Modules.
>
> Ao encontrar extensões `.mjs` vs `.cjs`, o sistema de módulos é determinado pela
> extensão independentemente do campo `type` do `package.json` — útil em codebases
> mistos.
