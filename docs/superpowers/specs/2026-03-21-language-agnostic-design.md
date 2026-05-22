# Design de Suporte Agnóstico de Linguagem

**Data:** 2026-03-21
**Status:** Aprovado
**Issue:** Tornar o Understand-Anything ciente do codebase e agnóstico de linguagem em vez de pesado em TypeScript

## Problema

Os prompts de agente, o plugin tree-sitter e o sistema de language lesson da ferramenta são fortemente enviesados para TypeScript/JavaScript. Codebases não-TS recebem análise degradada porque:

1. Os prompts de agente usam exemplos e conceitos específicos de TS (ex: "barrel files", "type guards", "generics")
2. O plugin tree-sitter só envia suporte a grammar de TS/JS — a análise estrutural falha silenciosamente para outras linguagens
3. A detecção de language lesson hardcoda padrões de conceitos específicos de TS e display names

A arquitetura (PluginRegistry, GraphBuilder, dashboard, busca) já é neutra em relação à linguagem. O viés está no conteúdo enviado, não no framework.

## Decisões

- **Escopo:** Todas as três camadas — prompts, plugins tree-sitter e o framework de linguagem
- **Linguagens (v1):** TypeScript, JavaScript, Python, Go, Java, Rust, C/C++, C#, Ruby, PHP, Swift, Kotlin
- **Arquitetura:** Config-first com escape hatch de código (híbrido)
- **Estratégia de prompt:** Prompt base + arquivos markdown de snippets por linguagem em uma pasta `languages/`
- **Localização da config:** Snippets de prompt em `skills/understand/languages/`, configs do tree-sitter em `packages/core/src/languages/`
- **Projetos multi-linguagem:** Análise de linguagem por arquivo + resumo multi-linguagem em nível de projeto
- **Detecção de linguagem:** Auto-detecção apenas a partir de extensões de arquivo (sem override manual na v1)

## Design

### 1. Tipo LanguageConfig e Registry

#### Interface LanguageConfig

```typescript
// packages/core/src/languages/types.ts
interface LanguageConfig {
  id: string;                          // e.g., "python"
  displayName: string;                 // e.g., "Python"
  extensions: string[];                // e.g., [".py", ".pyi"]
  treeSitter: {
    grammarPackage: string;            // npm package name
    nodeTypes: {
      function: string[];              // e.g., ["function_definition"]
      class: string[];                 // e.g., ["class_definition"]
      import: string[];                // e.g., ["import_statement", "import_from_statement"]
      export: string[];                // e.g., ["export_statement"] or [] for languages without exports
      typeAnnotation: string[];        // e.g., ["type"] for Python type hints
    };
  };
  concepts: string[];                  // e.g., ["decorators", "list comprehensions", "generators"]
  filePatterns?: Record<string, string>; // special files, e.g., {"config": "pyproject.toml"}
  customAnalyzer?: (node: SyntaxNode) => AnalysisResult; // escape hatch for unusual AST shapes
}
```

#### Language Registry

```typescript
// packages/core/src/languages/registry.ts
class LanguageRegistry {
  private configs: Map<string, LanguageConfig>;

  register(config: LanguageConfig): void;
  getByExtension(ext: string): LanguageConfig | null;
  getById(id: string): LanguageConfig;
  getAll(): LanguageConfig[];
}
```

#### Estrutura de Arquivos

```
packages/core/src/languages/
├── types.ts
├── registry.ts
├── index.ts
├── configs/
│   ├── typescript.ts
│   ├── javascript.ts
│   ├── python.ts
│   ├── go.ts
│   ├── java.ts
│   ├── rust.ts
│   ├── cpp.ts
│   ├── csharp.ts
│   ├── ruby.ts
│   ├── php.ts
│   ├── swift.ts
│   └── kotlin.ts
```

Todas as configs built-in são auto-registradas no import.

### 2. GenericTreeSitterPlugin

Substitui o atual `TreeSitterPlugin` somente-TS por uma versão dirigida por config.

```typescript
// packages/core/src/plugins/generic-tree-sitter-plugin.ts
class GenericTreeSitterPlugin implements AnalyzerPlugin {
  private registry: LanguageRegistry;

  canAnalyze(filePath: string): boolean {
    return this.registry.getByExtension(path.extname(filePath)) !== null;
  }

  async analyzeFile(filePath: string, content: string): Promise<FileAnalysis> {
    const config = this.registry.getByExtension(path.extname(filePath));

    // Custom analyzer escape hatch
    if (config.customAnalyzer) {
      return config.customAnalyzer(tree.rootNode);
    }

    // Generic extraction driven by config.treeSitter.nodeTypes
    const functions = this.extractNodes(tree, config.treeSitter.nodeTypes.function);
    const classes = this.extractNodes(tree, config.treeSitter.nodeTypes.class);
    const imports = this.extractNodes(tree, config.treeSitter.nodeTypes.import);
    const exports = this.extractNodes(tree, config.treeSitter.nodeTypes.export);
    // ...
  }

  private extractNodes(tree: Tree, nodeTypes: string[]): NodeInfo[] {
    // Walk AST, collect all nodes matching any of the given types
  }
}
```

#### Migração

- O `TreeSitterPlugin` atual é deletado, substituído por `GenericTreeSitterPlugin` + configs de TS/JS
- `PluginRegistry` inalterado
- Testes existentes atualizados para usar o novo plugin

#### Carregamento de WASM Grammar

- Cada grammar é carregado de forma lazy no primeiro uso e cacheado
- Arquivos WASM empacotados em `packages/core/src/languages/grammars/` ou buscados das builds WASM oficiais do tree-sitter

### 3. Prompts Cientes da Linguagem

#### Estrutura de Arquivos

```
skills/understand/
├── file-analyzer-prompt.md            # Base prompt (language-neutral)
├── tour-builder-prompt.md
├── project-scanner-prompt.md
├── languages/
│   ├── typescript.md
│   ├── javascript.md
│   ├── python.md
│   ├── go.md
│   ├── java.md
│   ├── rust.md
│   ├── cpp.md
│   ├── csharp.md
│   ├── ruby.md
│   ├── php.md
│   ├── swift.md
│   └── kotlin.md
```

#### Mudanças no Prompt Base

Todos os exemplos específicos de TS são removidos dos prompts base. Substituídos por um injection point:

```markdown
## Language-Specific Guidance

{{LANGUAGE_CONTEXT}}
```

#### Formato Markdown da Linguagem

Cada arquivo de linguagem contém:

```markdown
# Python

## Key Concepts
- Decorators, comprehensions, generators, context managers, type hints, dunder methods

## Import Patterns
- `import module`, `from module import name`, relative imports

## Notable File Patterns
- `__init__.py` (package initializer), `conftest.py` (pytest), `pyproject.toml` (config)

## Example Summary Style
> "FastAPI route handler that accepts a Pydantic model, validates input..."
```

#### Lógica de Injeção

1. O project scanner detecta as linguagens presentes no codebase
2. File-analyzer: injeta o `.md` da linguagem correspondente para a linguagem daquele arquivo
3. Tour-builder: injeta os arquivos `.md` de todas as linguagens detectadas
4. Project-scanner: injeta os key concepts de todas as linguagens detectadas para o resumo em nível de projeto

#### Projetos Multi-Linguagem

O prompt do project-scanner ganha uma seção combinada listando todas as linguagens detectadas com seus key concepts.

### 4. Atualizações de Language Lesson

- Deletar `LANGUAGE_DISPLAY_NAMES` — usar `LanguageRegistry.getById(id).displayName`
- Deletar padrões de conceito hardcoded — usar `LanguageConfig.concepts` do registry
- A geração de language lesson se torna dirigida por config

### 5. Estratégia de Testes

#### Testes Unitários

1. **Validação de LanguageConfig** — Cada config tem todos os campos obrigatórios, nodeTypes não vazios
2. **LanguageRegistry** — Registration, lookup por extensão/id, tratamento de duplicatas
3. **GenericTreeSitterPlugin por linguagem** — Pequeno arquivo fixture por linguagem verificando extração de função/classe/import
4. **Geração de language lesson** — Conceitos vindos da config

#### Testes de Integração

5. **Projeto multi-linguagem** — Fixture mista TS + Python, verificar que o grafo contém nós de ambas as linguagens
6. **Injeção de prompt** — `.md` da linguagem correta injetado com base na linguagem detectada

#### Testes de Migração

- Os testes atuais do tree-sitter-plugin são reescritos para o GenericTreeSitterPlugin com a config de TS
- Devem produzir resultados idênticos para validar a migração não-breaking

### 6. Tratamento de Erros e Degradação Graciosa

#### Princípio Chave

**Todo arquivo sempre é analisado.** Tree-sitter é uma melhoria, não um gate. O LLM é o analisador primário; a análise estrutural o enriquece.

#### Linguagem Desconhecida

- Tree-sitter pulado (retorna `null`)
- A análise por LLM ainda roda — o arquivo recebe resumo, tags, nó no grafo
- Log de debug: `"No language config for .xyz, skipping structural analysis"`

#### WASM Grammar Ausente

- Warning logado, aquela linguagem degrada para somente-LLM
- Outras linguagens não são afetadas

#### LanguageConfig Malformada

- Validada no momento do registro via schema Zod
- Config inválida lança exceção no startup — fail fast
