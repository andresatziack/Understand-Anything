# Spec de Design do .understandignore

## Visão Geral

Adicionar exclusão de arquivos configurável pelo usuário via arquivos `.understandignore`, usando a sintaxe `.gitignore`. Isso torna a análise mais rápida ao pular arquivos irrelevantes (vendor code, output gerado, fixtures de teste) sem modificar os defaults hardcoded.

## Objetivos

- Deixar usuários excluírem arquivos/diretórios da análise via `.understandignore`
- Usar sintaxe `.gitignore` (familiar, sem curva de aprendizado)
- Manter os defaults hardcoded como built-in — `.understandignore` adiciona padrões por cima
- Permitir negação `!` para forçar a inclusão de arquivos excluídos pelos defaults
- Auto-gerar um arquivo starter com sugestões comentadas no primeiro run (código determinístico, não LLM)
- Pausar antes da análise para deixar o usuário revisar o arquivo de ignore

## Não-Objetivos

- Substituir o `.gitignore` — este é específico para análise
- Arquivos `.understandignore` por diretório (apenas project root e `.understand-anything/`)
- GUI para edição de padrões de ignore

---

## Módulo IgnoreFilter

Novo arquivo: `packages/core/src/ignore-filter.ts`

Usa o pacote npm [`ignore`](https://www.npmjs.com/package/ignore) para matching de padrões compatível com gitignore.

### API

```typescript
export interface IgnoreFilter {
  isIgnored(relativePath: string): boolean;
}

export function createIgnoreFilter(projectRoot: string): IgnoreFilter;
```

### Comportamento

`createIgnoreFilter` carrega padrões nesta ordem (entradas posteriores podem sobrescrever as anteriores):

1. **Defaults hardcoded** — os padrões de exclusão existentes do project-scanner (node_modules/, .git/, dist/, build/, bin/, obj/, *.lock, *.min.js, etc.)
2. **`.understand-anything/.understandignore`** — em nível de projeto, fica junto com a saída
3. **`.understandignore`** no project root — localização alternativa para visibilidade

Os padrões mesclam de forma aditiva. A negação `!` em arquivos do usuário pode sobrescrever os defaults hardcoded (ex: `!dist/` força a inclusão de dist/).

### Padrões Default Hardcoded

Estes são os defaults built-in (combinando com o comportamento atual do project-scanner, mais bin/obj para .NET):

```
# Dependency directories
node_modules/
.git/
vendor/
venv/
.venv/
__pycache__/

# Build output
dist/
build/
out/
coverage/
.next/
.cache/
.turbo/
target/
bin/
obj/

# Lock files
*.lock
package-lock.json
yarn.lock
pnpm-lock.yaml

# Binary/asset files
*.png
*.jpg
*.jpeg
*.gif
*.svg
*.ico
*.woff
*.woff2
*.ttf
*.eot
*.mp3
*.mp4
*.pdf
*.zip
*.tar
*.gz

# Generated files
*.min.js
*.min.css
*.map
*.generated.*

# IDE/editor
.idea/
.vscode/

# Misc
LICENSE
.gitignore
.editorconfig
.prettierrc
.eslintrc*
*.log
```

---

## Gerador de Arquivo Starter

Novo arquivo: `packages/core/src/ignore-generator.ts`

### API

```typescript
export function generateStarterIgnoreFile(projectRoot: string): string;
```

### Comportamento

- Código determinístico — escaneia o diretório do projeto por padrões comuns
- Retorna o conteúdo do arquivo como string (o caller escreve em disco)
- Todas as sugestões são **comentadas** — o usuário precisa descomentar para ativar
- Comentário de cabeçalho explica o arquivo, a sintaxe e os defaults built-in

### Lógica de Detecção

| Se existe | Sugerir |
|-----------|---------|
| Arquivos `__tests__/` ou `*.test.*` | `# __tests__/`, `# *.test.*`, `# *.spec.*` |
| `fixtures/` ou `testdata/` | `# fixtures/`, `# testdata/` |
| `test/` ou `tests/` | `# test/`, `# tests/` |
| `.storybook/` | `# .storybook/` |
| `docs/` | `# docs/` |
| `examples/` | `# examples/` |
| `scripts/` | `# scripts/` |
| `migrations/` | `# migrations/` |
| Arquivos `*.snap` | `# *.snap` |
| `bin/` (não-.NET, ou seja, shell scripts) | `# bin/` |
| `obj/` | `# obj/` |

### Formato do Arquivo Gerado

```
# .understandignore — patterns for files/dirs to exclude from analysis
# Syntax: same as .gitignore (globs, # comments, ! negation, trailing / for dirs)
# Lines below are suggestions — uncomment to activate.
# Use ! prefix to force-include something excluded by defaults.
#
# Built-in defaults (always excluded unless negated):
#   node_modules/, .git/, dist/, build/, bin/, obj/, *.lock, *.min.js, etc.
#

# --- Suggested exclusions (uncomment to activate) ---

# Test files
# __tests__/
# *.test.*
# *.spec.*

# Test data
# fixtures/
# testdata/

# Documentation
# docs/

# ... (more suggestions based on detection)
```

Gerado apenas se `.understand-anything/.understandignore` ainda não existir.

---

## Integração com a Skill

### Fase 0.5: Ignore Setup (nova fase no SKILL.md)

Adicionada entre o Pre-flight (Fase 0) e o SCAN (Fase 1):

1. Verifica se `.understand-anything/.understandignore` existe
2. Se não, roda `generateStarterIgnoreFile(projectRoot)` e escreve o resultado em `.understand-anything/.understandignore`
3. Reporta ao usuário:
   - **Primeiro run:** "Generated `.understand-anything/.understandignore` with suggested exclusions. Please review it and uncomment any patterns you'd like to exclude. When ready, confirm to continue."
   - **Runs subsequentes:** "Found `.understand-anything/.understandignore`. Review it if needed, then confirm to continue."
4. Aguarda confirmação do usuário antes de prosseguir

### Mudanças na Fase 1: SCAN

O script de scan do agente `project-scanner` é atualizado para:

1. Coletar arquivos via `git ls-files` (ou fallback)
2. Aplicar o filtro de padrões hardcoded do agente (Camada 1 — comportamento existente)
3. Aplicar o `IgnoreFilter` do core (Camada 2 — padrões do usuário)
4. Adicionar contagem `filteredByIgnore` à saída do scan
5. Reportar: "Scanned {totalFiles} files ({filteredByIgnore} excluded by .understandignore)"

Filtragem em duas camadas:
- **Camada 1:** Padrões hardcoded do agente no prompt (filtro rápido e grosseiro)
- **Camada 2:** `IgnoreFilter` do core (código determinístico, configurável pelo usuário)

---

## Atualização do Agente Project Scanner

Mudanças em `understand-anything-plugin/agents/project-scanner.md`:

- Após a lista de arquivos ser construída e a filtragem da Camada 1 aplicada, o agente roda um script Node.js que importa `createIgnoreFilter` de `@understand-anything/core` e filtra os caminhos restantes
- O JSON de resultado do scan inclui um novo campo `filteredByIgnore: number`
- Os padrões de exclusão hardcoded existentes no prompt do agente permanecem para compatibilidade retroativa

---

## Testes

### `packages/core/src/__tests__/ignore-filter.test.ts`

- Parsea padrões glob básicos (`*.log`, `dist/`)
- Lida com comentários `#` e linhas em branco
- Lida com negação `!` (force-include)
- Lida com matching recursivo `**/`
- Lida com `/` no final para padrões de apenas-diretório
- Mescla defaults + padrões do usuário corretamente
- `!` em arquivo do usuário sobrescreve defaults hardcoded
- Retorna `false` para caminhos que não correspondem a nenhum padrão

### `packages/core/src/__tests__/ignore-generator.test.ts`

- Gera o arquivo starter com comentário de cabeçalho
- Detecta diretórios existentes e sugere padrões relevantes
- Todas as sugestões são comentadas (prefixadas com `# `)
- Não sobrescreve arquivo existente
- Inclui sugestões de bin/obj quando relevante

---

## Estrutura de Arquivos

| Arquivo | Propósito |
|------|---------|
| `packages/core/src/ignore-filter.ts` | Parsear .understandignore, mesclar com defaults, filtrar caminhos |
| `packages/core/src/ignore-generator.ts` | Gerar arquivo starter escaneando a estrutura do projeto |
| `packages/core/src/__tests__/ignore-filter.test.ts` | Testes da lógica de filtro |
| `packages/core/src/__tests__/ignore-generator.test.ts` | Testes do generator |
| `agents/project-scanner.md` | Adicionar filtragem da Camada 2 via IgnoreFilter |
| `skills/understand/SKILL.md` | Adicionar Fase 0.5 (gerar + pausar para review) |
| `packages/core/package.json` | Adicionar dependência npm `ignore` |
