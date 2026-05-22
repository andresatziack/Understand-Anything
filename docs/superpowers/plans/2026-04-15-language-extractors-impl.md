# Plano de Implementação da Arquitetura de Extractors Específicos por Linguagem

> **Para workers agênticos:** SUB-SKILL OBRIGATÓRIA: Use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano tarefa por tarefa. Os steps usam sintaxe de checkbox (`- [ ]`) para tracking.

**Objetivo:** (1) Desacoplar a lógica de extração de AST dos node types específicos de TS/JS para que 8 linguagens adicionais (Python, Go, Rust, Java, Ruby, PHP, C/C++, C#) ganhem análise estrutural via tree-sitter. Swift e Kotlin estão excluídos — não há pacotes de gramática WASM disponíveis. (2) Substituir a geração ad-hoc de scripts regex do agent file-analyzer por um script de extração tree-sitter pré-construído e determinístico.

**Arquitetura:** Introduz uma interface `LanguageExtractor` que cada linguagem implementa. `TreeSitterPlugin` delega a extração para o extractor registrado da linguagem do arquivo. Um script bundleado `extract-structure.mjs` em `skills/understand/` usa `PluginRegistry` (que inclui tanto `TreeSitterPlugin` quanto os parsers não-código) para fornecer extração estrutural determinística para o agent file-analyzer — substituindo a abordagem atual em que o LLM escreve scripts regex descartáveis a cada execução.

**Stack Tecnológica:** web-tree-sitter (WASM), TypeScript, Vitest

---

## Estrutura de Arquivos

```
packages/core/src/plugins/
├── extractors/
│   ├── types.ts              # LanguageExtractor interface + TreeSitterNode re-export
│   ├── base-extractor.ts     # Shared utilities (traverse, getStringValue)
│   ├── typescript-extractor.ts  # TS/JS (moved from tree-sitter-plugin.ts)
│   ├── python-extractor.ts
│   ├── go-extractor.ts
│   ├── rust-extractor.ts
│   ├── java-extractor.ts
│   ├── ruby-extractor.ts
│   ├── php-extractor.ts
│   ├── cpp-extractor.ts
│   ├── csharp-extractor.ts
│   └── index.ts              # builtinExtractors array + re-exports
├── tree-sitter-plugin.ts     # Refactored to use extractors
└── tree-sitter-plugin.test.ts  # Existing tests (should still pass)

packages/core/src/plugins/__tests__/
└── extractors.test.ts        # Tests for all new extractors

skills/understand/
├── extract-structure.mjs     # Pre-built tree-sitter extraction script (NEW)
└── SKILL.md                  # Updated to reference extract-structure.mjs

agents/
└── file-analyzer.md          # Phase 1 rewritten to execute pre-built script
```

---

### Tarefa 1: Criar a interface LanguageExtractor e utilidades compartilhadas

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/types.ts`
- Criar: `packages/core/src/plugins/extractors/base-extractor.ts`

- [ ] **Step 1: Criar a interface do extractor**

```typescript
// packages/core/src/plugins/extractors/types.ts
import type { StructuralAnalysis, CallGraphEntry } from "../../types.js";

// Re-export the tree-sitter Node type for use by extractors
export type TreeSitterNode = import("web-tree-sitter").Node;

/**
 * Language-specific extractor that maps a tree-sitter AST
 * to the common StructuralAnalysis / CallGraphEntry types.
 */
export interface LanguageExtractor {
  /** Language IDs this extractor handles (must match LanguageConfig.id) */
  languageIds: string[];

  /** Extract functions, classes, imports, exports from the root AST node */
  extractStructure(rootNode: TreeSitterNode): StructuralAnalysis;

  /** Extract caller→callee relationships from the root AST node */
  extractCallGraph(rootNode: TreeSitterNode): CallGraphEntry[];
}
```

- [ ] **Step 2: Criar base-extractor com utilidades compartilhadas**

Mova `traverse()` e `getStringValue()` de `tree-sitter-plugin.ts` para um módulo compartilhado:

```typescript
// packages/core/src/plugins/extractors/base-extractor.ts
import type { TreeSitterNode } from "./types.js";

/** Recursively traverse an AST tree, calling the visitor for each node. */
export function traverse(
  node: TreeSitterNode,
  visitor: (node: TreeSitterNode) => void,
): void {
  visitor(node);
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (child) traverse(child, visitor);
  }
}

/** Extract the unquoted string value from a string-like node. */
export function getStringValue(node: TreeSitterNode): string {
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (child && child.type === "string_fragment") {
      return child.text;
    }
  }
  return node.text.replace(/^['"`]|['"`]$/g, "");
}

/** Find the first child matching a type. */
export function findChild(node: TreeSitterNode, type: string): TreeSitterNode | null {
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (child && child.type === type) return child;
  }
  return null;
}

/** Find all children matching a type. */
export function findChildren(node: TreeSitterNode, type: string): TreeSitterNode[] {
  const result: TreeSitterNode[] = [];
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (child && child.type === type) result.push(child);
  }
  return result;
}

/** Check if a node has a child of the given type (used for export/visibility checks). */
export function hasChildOfType(node: TreeSitterNode, type: string): boolean {
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (child && child.type === type) return true;
  }
  return false;
}
```

- [ ] **Step 3: Commit**

```bash
git add packages/core/src/plugins/extractors/types.ts packages/core/src/plugins/extractors/base-extractor.ts
git commit -m "feat: add LanguageExtractor interface and shared base utilities"
```

---

### Tarefa 2: Mover a lógica de extração de TS/JS para TypeScriptExtractor

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/typescript-extractor.ts`
- Modificar: `packages/core/src/plugins/tree-sitter-plugin.ts`

Este é um refator puro. Todos os testes existentes devem continuar passando com zero mudanças.

- [ ] **Step 1: Criar TypeScriptExtractor**

Mova todos os métodos de extração específicos de TS/JS (`extractFunction`, `extractClass`, `extractVariableDeclarations`, `extractImport`, `processExportStatement`, `extractParams`, `extractReturnType`, `extractImportSpecifiers`, e o walker do call graph) de `tree-sitter-plugin.ts` para `typescript-extractor.ts`, implementando a interface `LanguageExtractor`.

O `languageIds` deve ser `["typescript", "javascript"]`. NÃO inclua `"tsx"` — é uma chave sintética interna ao `TreeSitterPlugin` para seleção de gramática, não um `LanguageConfig.id`. O mapeamento tsx→typescript é tratado em `getExtractor()` abaixo.

- [ ] **Step 2: Refatorar TreeSitterPlugin para usar extractors**

Substitua a lógica de extração hardcoded em `TreeSitterPlugin` por dispatch de extractor:

```typescript
// In TreeSitterPlugin
private extractors = new Map<string, LanguageExtractor>();

registerExtractor(extractor: LanguageExtractor): void {
  for (const id of extractor.languageIds) {
    this.extractors.set(id, extractor);
  }
}

private getExtractor(langKey: string): LanguageExtractor | null {
  // tsx is a synthetic grammar key — extraction logic is identical to typescript
  const key = langKey === "tsx" ? "typescript" : langKey;
  return this.extractors.get(key) ?? null;
}
```

O método `analyzeFile()` se torna:

```typescript
analyzeFile(filePath: string, content: string): StructuralAnalysis {
  const parser = this.getParser(filePath);
  if (!parser) return { functions: [], classes: [], imports: [], exports: [] };

  const tree = parser.parse(content);
  if (!tree) { parser.delete(); return { functions: [], classes: [], imports: [], exports: [] }; }

  const langKey = this.languageKeyFromPath(filePath);
  const extractor = langKey ? this.getExtractor(langKey) : null;

  let result: StructuralAnalysis;
  if (extractor) {
    result = extractor.extractStructure(tree.rootNode);
  } else {
    result = { functions: [], classes: [], imports: [], exports: [] };
  }

  tree.delete();
  parser.delete();
  return result;
}
```

O método `extractCallGraph()` segue o mesmo padrão — o ciclo de vida do parser deve ser gerenciado identicamente:

```typescript
extractCallGraph(filePath: string, content: string): CallGraphEntry[] {
  const parser = this.getParser(filePath);
  if (!parser) return [];

  const tree = parser.parse(content);
  if (!tree) { parser.delete(); return []; }

  const langKey = this.languageKeyFromPath(filePath);
  const extractor = langKey ? this.getExtractor(langKey) : null;
  const result = extractor ? extractor.extractCallGraph(tree.rootNode) : [];

  tree.delete();
  parser.delete();
  return result;
}
```

O construtor deve aceitar um array opcional `extractors` e registrá-los. Se nenhum for fornecido, registre o `TypeScriptExtractor` built-in para compatibilidade retroativa.

- [ ] **Step 3: Executar os testes existentes para verificar mudança comportamental zero**

Execute: `pnpm --filter @understand-anything/core test`
Esperado: Todos os 426 testes passam (idêntico ao anterior)

- [ ] **Step 4: Commit**

```bash
git add packages/core/src/plugins/extractors/typescript-extractor.ts packages/core/src/plugins/tree-sitter-plugin.ts
git commit -m "refactor: move TS/JS extraction logic to TypeScriptExtractor, dispatch via LanguageExtractor interface"
```

---

### Tarefa 2.5: Adicionar extractCallGraph ao PluginRegistry e atualizar DEFAULT_PLUGIN_CONFIG

**Arquivos:**
- Modificar: `packages/core/src/plugins/registry.ts`
- Modificar: `packages/core/src/plugins/discovery.ts`

**Contexto:** `PluginRegistry` atualmente expõe apenas `analyzeFile` e `resolveImports` — ele não tem `extractCallGraph`. O script `extract-structure.mjs` (Tarefa 13) precisa de dados do call graph através do registry. Além disso, `DEFAULT_PLUGIN_CONFIG` hardcoda `["typescript", "javascript"]` que precisa refletir todas as linguagens suportadas.

- [ ] **Step 1: Adicionar extractCallGraph ao PluginRegistry**

```typescript
// In PluginRegistry (registry.ts)
extractCallGraph(filePath: string, content: string): CallGraphEntry[] | null {
  const plugin = this.getPluginForFile(filePath);
  if (!plugin?.extractCallGraph) return null;
  return plugin.extractCallGraph(filePath, content);
}
```

- [ ] **Step 2: Atualizar DEFAULT_PLUGIN_CONFIG para derivar linguagens dinamicamente**

Em `discovery.ts`, substitua o hardcoded `["typescript", "javascript"]` por uma derivação dinâmica de `builtinLanguageConfigs`:

```typescript
import { builtinLanguageConfigs } from "../languages/configs/index.js";

export const DEFAULT_PLUGIN_CONFIG: PluginConfig = {
  plugins: [
    {
      name: "tree-sitter",
      enabled: true,
      languages: builtinLanguageConfigs
        .filter((c) => c.treeSitter)
        .map((c) => c.id),
    },
  ],
};
```

- [ ] **Step 3: Executar os testes, commit**

```bash
pnpm --filter @understand-anything/core test
git add packages/core/src/plugins/registry.ts packages/core/src/plugins/discovery.ts
git commit -m "feat: add extractCallGraph to PluginRegistry, derive DEFAULT_PLUGIN_CONFIG from configs"
```

---

### Tarefa 3: Adicionar dependências npm e configs treeSitter para todas as 10 linguagens

**Arquivos:**
- Modificar: `packages/core/package.json` (add 8 deps: python, go, rust, java, ruby, php, cpp, c-sharp)
- Modificar: 10 config files in `packages/core/src/languages/configs/`

- [ ] **Step 1: Adicionar dependências de gramática tree-sitter ao package.json**

Adicione em `dependencies`:

```json
"tree-sitter-c-sharp": "^0.23.1",
"tree-sitter-cpp": "^0.23.4",
"tree-sitter-go": "^0.25.0",
"tree-sitter-java": "^0.23.5",
"tree-sitter-php": "^0.23.11",
"tree-sitter-python": "^0.25.0",
"tree-sitter-ruby": "^0.23.1",
"tree-sitter-rust": "^0.24.0"
```

Em seguida execute `pnpm install`.

- [ ] **Step 2: Adicionar campo treeSitter em todas as 10 configs de linguagem**

Cada config recebe um bloco `treeSitter`. Exemplos:

```typescript
// python.ts
treeSitter: { wasmPackage: "tree-sitter-python", wasmFile: "tree-sitter-python.wasm" },

// go.ts
treeSitter: { wasmPackage: "tree-sitter-go", wasmFile: "tree-sitter-go.wasm" },

// rust.ts
treeSitter: { wasmPackage: "tree-sitter-rust", wasmFile: "tree-sitter-rust.wasm" },

// java.ts
treeSitter: { wasmPackage: "tree-sitter-java", wasmFile: "tree-sitter-java.wasm" },

// ruby.ts
treeSitter: { wasmPackage: "tree-sitter-ruby", wasmFile: "tree-sitter-ruby.wasm" },

// php.ts
treeSitter: { wasmPackage: "tree-sitter-php", wasmFile: "tree-sitter-php.wasm" },

// cpp.ts
treeSitter: { wasmPackage: "tree-sitter-cpp", wasmFile: "tree-sitter-cpp.wasm" },

// csharp.ts
treeSitter: { wasmPackage: "tree-sitter-c-sharp", wasmFile: "tree-sitter-c_sharp.wasm" },
```

Nota: configs de Swift e Kotlin NÃO são alteradas (não há pacotes WASM disponíveis).

- [ ] **Step 3: Executar pnpm install e verificar que os arquivos WASM resolvem**

```bash
pnpm install
node -e "const r=require('module').createRequire(import.meta.url??__filename); console.log(r.resolve('tree-sitter-python/tree-sitter-python.wasm'))"
```

- [ ] **Step 4: Commit**

```bash
git add packages/core/package.json pnpm-lock.yaml packages/core/src/languages/configs/
git commit -m "feat: add tree-sitter grammar deps and treeSitter configs for 10 languages"
```

---

### Tarefa 4: Criar extractor Python

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/python-extractor.ts`

- [ ] **Step 1: Escrever o extractor Python**

Tipos de nó tree-sitter chave do Python:
- Functions: `function_definition` (name, parameters, return_type)
- Classes: `class_definition` (name, body → métodos + assignments como properties)
- Imports: `import_statement`, `import_from_statement`
- Decorated: `decorated_definition` envolvendo function_definition ou class_definition
- Calls: `call` (function field)
- Sem exports formais (todos os nomes top-level são "exportados")

```typescript
languageIds: ["python"]
```

- [ ] **Step 2: Escrever testes para o extractor Python**

Teste com código Python representativo:

```python
import os
from pathlib import Path
from typing import Optional

class DataProcessor:
    name: str
    
    def __init__(self, name: str):
        self.name = name
    
    def process(self, data: list) -> dict:
        return transform(data)

def helper(x: int) -> str:
    return str(x)

@decorator
def decorated_func():
    pass
```

Verifique: 2 functions (helper, decorated_func), 1 class (DataProcessor com métodos __init__/process e propriedade name), 3 imports, call graph (process→transform).

- [ ] **Step 3: Executar os testes**

Execute: `pnpm --filter @understand-anything/core test`

- [ ] **Step 4: Commit**

---

### Tarefa 5: Criar extractor Go

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/go-extractor.ts`

- [ ] **Step 1: Escrever o extractor Go**

Tipos de nó tree-sitter chave do Go:
- Functions: `function_declaration` (name, parameter_list, result)
- Methods: `method_declaration` (receiver, name, parameter_list, result)
- Structs: `type_declaration` → `type_spec` → `struct_type`
- Interfaces: `type_declaration` → `type_spec` → `interface_type`
- Imports: `import_declaration` → `import_spec_list` → `import_spec`
- Exports: primeira letra do nome capitalizada
- Calls: `call_expression` (function field)

```typescript
languageIds: ["go"]
```

- [ ] **Step 2: Escrever testes**

Teste com:
```go
package main

import (
    "fmt"
    "os"
)

type Server struct {
    Host string
    Port int
}

func (s *Server) Start() error {
    fmt.Println("starting")
    return nil
}

func NewServer(host string, port int) *Server {
    return &Server{Host: host, Port: port}
}
```

Verifique: 2 functions (Start, NewServer), 1 class/struct (Server com método Start, propriedades Host/Port), 2 imports, exports (Server, Start, NewServer — todos capitalizados), call graph (Start→fmt.Println).

- [ ] **Step 3: Executar os testes e commit**

---

### Tarefa 6: Criar extractor Rust

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/rust-extractor.ts`

- [ ] **Step 1: Escrever o extractor Rust**

Tipos de nó tree-sitter chave do Rust:
- Functions: `function_item` (name, parameters, return_type via `->`)
- Structs: `struct_item` (name, field_declaration_list)
- Enums: `enum_item`
- Impl blocks: `impl_item` (type, body contendo function_items)
- Traits: `trait_item`
- Imports: `use_declaration` (scoped_identifier, use_list, use_wildcard)
- Exports: `visibility_modifier` contendo `pub`
- Calls: `call_expression` (function field)

```typescript
languageIds: ["rust"]
```

- [ ] **Step 2: Escrever testes**

Teste com:
```rust
use std::collections::HashMap;
use std::io::{self, Read};

pub struct Config {
    name: String,
    port: u16,
}

impl Config {
    pub fn new(name: String, port: u16) -> Self {
        Config { name, port }
    }

    fn validate(&self) -> bool {
        check_port(self.port)
    }
}

pub fn check_port(port: u16) -> bool {
    port > 0
}
```

Verifique: 3 functions (new, validate, check_port), 1 class/struct (Config com métodos new/validate, propriedades name/port), 2 imports, exports (Config, new, check_port — aqueles com `pub`), call graph (validate→check_port).

- [ ] **Step 3: Executar os testes e commit**

---

### Tarefa 7: Criar extractor Java

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/java-extractor.ts`

- [ ] **Step 1: Escrever o extractor Java**

Tipos de nó tree-sitter chave do Java:
- Methods: `method_declaration` (name, formal_parameters, type/dimensions)
- Constructors: `constructor_declaration` (name, formal_parameters)
- Classes: `class_declaration` (name, class_body)
- Interfaces: `interface_declaration`
- Fields: `field_declaration` (declarator → variable_declarator → identifier)
- Imports: `import_declaration` (scoped_identifier)
- Exports: modifier `public` (modifiers node)
- Calls: `method_invocation` (name, object, arguments)

```typescript
languageIds: ["java"]
```

- [ ] **Step 2: Escrever testes com código Java representativo, executar, commit**

---

### Tarefa 8: Criar extractor Ruby

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/ruby-extractor.ts`

- [ ] **Step 1: Escrever o extractor Ruby**

Tipos de nó tree-sitter chave do Ruby:
- Methods: `method` (name, parameters)
- Classes: `class` (name, body contendo métodos)
- Modules: `module` (name)
- Imports: `call` onde method é `require` ou `require_relative` (Ruby usa method calls para imports)
- Calls: `call` (method, receiver, arguments)
- Sem sintaxe de export formal

```typescript
languageIds: ["ruby"]
```

- [ ] **Step 2: Escrever testes, executar, commit**

---

### Tarefa 9: Criar extractor PHP

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/php-extractor.ts`

- [ ] **Step 1: Escrever o extractor PHP**

Tipos de nó tree-sitter chave do PHP:
- Functions: `function_definition` (name, formal_parameters, return_type)
- Methods: `method_declaration` (name, formal_parameters, return_type)
- Classes: `class_declaration` (name, declaration_list)
- Imports: `namespace_use_declaration` (namespace_use_clause)
- Calls: `function_call_expression` / `member_call_expression`
- Nota: a árvore PHP envolve tudo em `program` → `php_tag` + statements

```typescript
languageIds: ["php"]
```

- [ ] **Step 2: Escrever testes, executar, commit**

---

### Tarefa 10: Criar extractor C/C++

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/cpp-extractor.ts`

- [ ] **Step 1: Escrever o extractor C/C++**

Tipos de nó tree-sitter chave de C/C++:
- Functions: `function_definition` (declarator → function_declarator → identifier + parameter_list)
- Classes: `class_specifier` (name, body → field_declaration_list)
- Structs: `struct_specifier` (name, body)
- Includes: `preproc_include` (path → string_literal ou system_lib_string)
- Namespaces: `namespace_definition`
- Calls: `call_expression` (function, arguments)

Nota: assinaturas de função em C/C++ são aninhadas (o nome está dentro de um `function_declarator` dentro do campo `declarator`).

O `cppConfig` tem `id: "cpp"` e `extensions: [".cpp", ".cc", ".cxx", ".c", ".h", ".hpp", ".hxx"]`. Arquivos C puros (`.c`, `.h`) são parseados com a gramática C++, o que funciona mas não produz node types específicos de C++ como `class_specifier`. O extractor deve lidar com a ausência deles graciosamente (retornar arrays vazios para classes ao parsear C puro).

```typescript
languageIds: ["cpp"]
```

- [ ] **Step 2: Escrever testes para código C++ e C puro, executar, commit**

---

### Tarefa 11: Criar extractor C#

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/csharp-extractor.ts`

- [ ] **Step 1: Escrever o extractor C#**

Tipos de nó tree-sitter chave do C#:
- Methods: `method_declaration` (name, parameter_list, return type)
- Constructors: `constructor_declaration`
- Classes: `class_declaration` (name, declaration_list)
- Interfaces: `interface_declaration`
- Properties: `property_declaration` (name, type)
- Imports: `using_directive` (qualified_name)
- Calls: `invocation_expression` (identifier/member_access, argument_list)

```typescript
languageIds: ["csharp"]
```

- [ ] **Step 2: Escrever testes, executar, commit**

---

### Tarefa 12: Criar índice de extractors e conectar ao TreeSitterPlugin

**Arquivos:**
- Criar: `packages/core/src/plugins/extractors/index.ts`
- Modificar: `packages/core/src/plugins/tree-sitter-plugin.ts` (import builtinExtractors)

- [ ] **Step 1: Criar index.ts exportando todos os extractors**

```typescript
// packages/core/src/plugins/extractors/index.ts
export type { LanguageExtractor, TreeSitterNode } from "./types.js";
export { traverse, getStringValue, findChild, findChildren, hasChildOfType } from "./base-extractor.js";
export { TypeScriptExtractor } from "./typescript-extractor.js";
export { PythonExtractor } from "./python-extractor.js";
export { GoExtractor } from "./go-extractor.js";
export { RustExtractor } from "./rust-extractor.js";
export { JavaExtractor } from "./java-extractor.js";
export { RubyExtractor } from "./ruby-extractor.js";
export { PhpExtractor } from "./php-extractor.js";
export { CppExtractor } from "./cpp-extractor.js";
export { CSharpExtractor } from "./csharp-extractor.js";

import type { LanguageExtractor } from "./types.js";
import { TypeScriptExtractor } from "./typescript-extractor.js";
import { PythonExtractor } from "./python-extractor.js";
import { GoExtractor } from "./go-extractor.js";
import { RustExtractor } from "./rust-extractor.js";
import { JavaExtractor } from "./java-extractor.js";
import { RubyExtractor } from "./ruby-extractor.js";
import { PhpExtractor } from "./php-extractor.js";
import { CppExtractor } from "./cpp-extractor.js";
import { CSharpExtractor } from "./csharp-extractor.js";

export const builtinExtractors: LanguageExtractor[] = [
  new TypeScriptExtractor(),
  new PythonExtractor(),
  new GoExtractor(),
  new RustExtractor(),
  new JavaExtractor(),
  new RubyExtractor(),
  new PhpExtractor(),
  new CppExtractor(),
  new CSharpExtractor(),
];
```

- [ ] **Step 2: Conectar builtinExtractors no construtor do TreeSitterPlugin**

Quando nenhum extractor for fornecido, default para `builtinExtractors`.

- [ ] **Step 3: Executar a suíte de testes completa**

Execute: `pnpm --filter @understand-anything/core test`
Esperado: Todos os testes passam (existentes + novos testes de extractor)

- [ ] **Step 4: Commit**

---

### Tarefa 13: Criar o script bundleado extract-structure.mjs

**Arquivos:**
- Criar: `skills/understand/extract-structure.mjs`

**Contexto:** Atualmente o agent file-analyzer (Fase 1) instrui o LLM a escrever um script Node.js/Python descartável baseado em regex a cada execução. Isto é lento, não-determinístico e ignora a infraestrutura tree-sitter que acabamos de construir. Esta tarefa substitui isso por um script pré-construído que usa `PluginRegistry` (que roteia para `TreeSitterPlugin` para arquivos de código e para os parsers regex para arquivos não-código).

- [ ] **Step 1: Criar extract-structure.mjs**

O script:
1. Aceita o path do JSON de input (arg 1) e o path do JSON de output (arg 2)
2. O formato de input bate com o que o file-analyzer.md já especifica: `{ projectRoot, batchFiles: [{path, language, sizeLines, fileCategory}], batchImportData }`
3. Resolve `@understand-anything/core` a partir do próprio `node_modules` do plugin usando `createRequire` relativo ao próprio local do script (dois diretórios acima até o root do plugin)
4. Cria um `PluginRegistry` com `TreeSitterPlugin` (todas as configs builtin de linguagem) + todos os parsers não-código registrados
5. Para cada arquivo: lê o conteúdo, chama `registry.analyzeFile()`, formata a saída para bater com o schema de saída do script existente (functions, classes, exports, sections, definitions, services, etc.)
6. Para arquivos de código com suporte tree-sitter: também extrai o call graph via `plugin.extractCallGraph()`
7. Para arquivos onde nenhum plugin existe (Swift, Kotlin, linguagens desconhecidas): emite `{ path, language, fileCategory, totalLines, nonEmptyLines, metrics }` com dados estruturais vazios — o agent LLM lida com eles na Fase 2
8. Escreve JSON de saída batendo com o schema existente `scriptCompleted/filesAnalyzed/filesSkipped/results`

Lógica de resolução chave (com fallback para diferentes layouts de instalação):
```javascript
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pluginRoot = resolve(__dirname, '../..');
const require = createRequire(resolve(pluginRoot, 'package.json'));

let core;
try {
  core = await import(require.resolve('@understand-anything/core'));
} catch {
  // Fallback: direct path for installed plugin cache where pnpm symlinks may differ
  core = await import(resolve(pluginRoot, 'packages/core/dist/index.js'));
}
```

- [ ] **Step 2: Testar o script localmente**

Crie um pequeno JSON de input de teste com um arquivo TS, um arquivo Python e um arquivo YAML. Execute:
```bash
node skills/understand/extract-structure.mjs test-input.json test-output.json
```
Verifique que o output contém dados estruturais para todos os três.

- [ ] **Step 3: Commit**

```bash
git add skills/understand/extract-structure.mjs
git commit -m "feat: add bundled tree-sitter extraction script for file-analyzer agent"
```

---

### Tarefa 14: Reescrever a Fase 1 do file-analyzer.md para usar o script bundleado

**Arquivos:**
- Modificar: `agents/file-analyzer.md`

**Contexto:** A Fase 1 atualmente tem ~150 linhas instruindo o agent a escrever um script de extração customizado do zero. Substitua isto por uma seção curta que diz ao agent para executar o script pré-construído `extract-structure.mjs`.

- [ ] **Step 1: Substituir a Fase 1 no file-analyzer.md**

Delete a Fase 1 atual inteira (~150 linhas de instruções de geração de script regex). Substitua por:

1. Diga ao agent para preparar o arquivo JSON de input (mesmo formato de antes):
   ```bash
   cat > $PROJECT_ROOT/.understand-anything/tmp/ua-file-analyzer-input-<batchIndex>.json << 'ENDJSON'
   {
     "projectRoot": "<project-root>",
     "batchFiles": [<this batch's files including fileCategory>],
     "batchImportData": <batchImportData JSON>
   }
   ENDJSON
   ```

2. Execute o script bundleado:
   ```bash
   node <SKILL_DIR>/extract-structure.mjs \
     $PROJECT_ROOT/.understand-anything/tmp/ua-file-analyzer-input-<batchIndex>.json \
     $PROJECT_ROOT/.understand-anything/tmp/ua-file-extract-results-<batchIndex>.json
   ```

3. Se o script sair com código não-zero, leia o stderr, diagnostique e reporte o erro. NÃO faça fallback para escrever um script manual — o script bundleado é o único caminho de extração.

4. Mantenha o formato de output existente — a Fase 2 (análise semântica) está inalterada.

- [ ] **Step 2: Atualizar SKILL.md para passar SKILL_DIR no dispatch do file-analyzer**

No SKILL.md Fase 2, o prompt de dispatch do file-analyzer precisa incluir o path do diretório do skill para que o agent possa localizar `extract-structure.mjs`.

Adicione aos parâmetros de dispatch:
```
> Skill directory (for bundled scripts): `<SKILL_DIR>`
```

Isto segue o padrão estabelecido — o SKILL.md já passa `<SKILL_DIR>` para `merge-batch-graphs.py` (linha 213) e `merge-subdomain-graphs.py` (linha 44) usando o mesmo mecanismo.

- [ ] **Step 3: Verificar que o formato de saída do file-analyzer está inalterado**

A Fase 2 do file-analyzer.md NÃO deve precisar de mudanças — ela lê a mesma estrutura JSON dos resultados do script. Verifique que o schema de output do `extract-structure.mjs` bate com o que a Fase 2 espera.

- [ ] **Step 4: Commit**

```bash
git add agents/file-analyzer.md skills/understand/SKILL.md
git commit -m "feat: file-analyzer uses bundled tree-sitter script instead of LLM-generated regex"
```

---

### Tarefa 15: Verificação final de integração e cleanup

- [ ] **Step 1: Adicionar exports em packages/core/src/index.ts**

Isto é necessário — `extract-structure.mjs` e consumidores externos precisam destes exports:

```typescript
export type { LanguageExtractor } from "./plugins/extractors/types.js";
export { builtinExtractors } from "./plugins/extractors/index.js";
```

- [ ] **Step 2: Buildar o pacote completo**

```bash
pnpm --filter @understand-anything/core build
```

- [ ] **Step 3: Executar a suíte de testes completa uma última vez**

```bash
pnpm --filter @understand-anything/core test
```

- [ ] **Step 4: Commit final**

```bash
git commit -m "feat: complete language extractor architecture — 10 languages with tree-sitter support"
```

---

## Notas de Implementação

**Convenção de arquivo de teste:** Cada extractor de linguagem ganha seu próprio arquivo de teste em `packages/core/src/plugins/extractors/__tests__/<language>-extractor.test.ts`. Isso segue o padrão existente onde `tree-sitter-plugin.test.ts` é co-localizado.

**Lazy grammar loading (otimização futura):** O `TreeSitterPlugin.init()` atual carrega todos os WASMs de gramática upfront via `Promise.all`. Com 10 gramáticas (~12MB total de WASM), isso pode causar atraso perceptível na inicialização. Uma melhoria futura: carregar TS/JS eagerly (mais comum), deferir os outros para o primeiro uso. Não é necessário para este PR — meça primeiro.

**Efeito colateral do fingerprint:** `buildFingerprintStore` em `fingerprint.ts` usa `PluginRegistry.analyzeFile` internamente. Uma vez que os novos extractors estiverem conectados, o fingerprinting para Python/Go/Rust/etc. vai produzir automaticamente fingerprints estruturais em vez de só content-hash. Não são necessárias mudanças de código — acontece de graça.

**Nota da gramática PHP:** `tree-sitter-php` ships tanto `tree-sitter-php.wasm` (PHP completo + HTML/CSS/JS embutidos) quanto `tree-sitter-php_only.wasm` (só PHP). Usamos `tree-sitter-php.wasm`. O extractor PHP deve ser robusto a nós AST não-PHP que aparecem ao parsear arquivos com templates HTML embutidos.
