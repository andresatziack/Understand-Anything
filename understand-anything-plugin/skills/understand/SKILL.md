---
name: understand
description: Analyze a codebase to produce an interactive knowledge graph for understanding architecture, components, and relationships
argument-hint: ["[path] [--full|--auto-update|--no-auto-update|--review|--language <lang>]"]
---

# /understand

Analise o codebase atual e produza um arquivo `knowledge-graph.json` em `.understand-anything/`. Esse arquivo alimenta o dashboard interativo para exploração da arquitetura do projeto.

## Opções

- `$ARGUMENTS` pode conter:
  - `--full` — Força um rebuild completo, ignorando qualquer grafo existente
  - `--auto-update` — Habilita atualizações automáticas do grafo no commit (grava `autoUpdate: true` em `.understand-anything/config.json`)
  - `--no-auto-update` — Desabilita atualizações automáticas do grafo (grava `autoUpdate: false` em `.understand-anything/config.json`)
  - `--review` — Roda o LLM graph-reviewer completo em vez da validação determinística inline
  - `--language <lang>` — Gera todo o conteúdo textual (summaries, descriptions, tags, titles, languageNotes, languageLesson) no idioma especificado. Aceita códigos ISO 639-1 (`zh`, `ja`, `ko`, `en`, `es`, `fr`, `de`, etc.) ou nomes amigáveis (`chinese`, `japanese`, `korean`, `english`, `spanish`, etc.). Variantes de locale suportadas: `zh-TW`, `zh-HK`, etc. Padrão `en` (Inglês). Armazena a preferência em `.understand-anything/config.json` para consistência ao longo de atualizações incrementais.
  - Um caminho de diretório (ex.: `/path/to/repo` ou `../other-project`) — Analisa o diretório informado em vez do diretório de trabalho atual

---

## Fase 0 — Pré-execução

Determine se deve rodar uma análise completa ou uma atualização incremental.

1. **Resolva `PROJECT_ROOT`:**
   - Faça parse de `$ARGUMENTS` em busca de um token que não seja flag (qualquer argumento que não comece com `--`). Se encontrado, trate-o como caminho do diretório alvo.
     - Se o caminho for relativo, resolva-o contra o diretório de trabalho atual.
     - Verifique se o caminho resolvido existe e é um diretório (rode `test -d <path>`). Se não existir ou não for um diretório, reporte um erro ao usuário e **PARE**.
     - Defina `PROJECT_ROOT` como o caminho absoluto resolvido.
   - Se nenhum argumento de caminho for encontrado, defina `PROJECT_ROOT` como o diretório de trabalho atual.
   - **Redirecionamento de worktree.** Se `PROJECT_ROOT` está dentro de um git worktree (não o checkout principal), redirecione a saída para a raiz do repositório principal. Worktrees gerenciados pelo Claude Code são efêmeros — `.understand-anything/` gravado lá é destruído quando a sessão termina, levando junto o knowledge graph (issue #133). Detecte um worktree comparando `git rev-parse --git-dir` com `git rev-parse --git-common-dir`; em um checkout normal ou submódulo eles resolvem para o mesmo caminho, em um worktree eles diferem e o pai de `--git-common-dir` é a raiz do repo principal.

     ```bash
     COMMON_DIR=$(git -C "$PROJECT_ROOT" rev-parse --git-common-dir 2>/dev/null)
     GIT_DIR=$(git -C "$PROJECT_ROOT" rev-parse --git-dir 2>/dev/null)
     if [ -n "$COMMON_DIR" ] && [ -n "$GIT_DIR" ]; then
       COMMON_ABS=$(cd "$PROJECT_ROOT" && cd "$COMMON_DIR" 2>/dev/null && pwd -P)
       GIT_ABS=$(cd "$PROJECT_ROOT" && cd "$GIT_DIR" 2>/dev/null && pwd -P)
       if [ -n "$COMMON_ABS" ] && [ "$COMMON_ABS" != "$GIT_ABS" ]; then
         MAIN_ROOT=$(dirname "$COMMON_ABS")
         if [ -d "$MAIN_ROOT" ] && [ "${UNDERSTAND_NO_WORKTREE_REDIRECT:-0}" != "1" ]; then
           echo "[understand] Detected git worktree at $PROJECT_ROOT"
           echo "[understand] Redirecting output to main repo root: $MAIN_ROOT"
           echo "[understand] (Set UNDERSTAND_NO_WORKTREE_REDIRECT=1 to keep PROJECT_ROOT as the worktree.)"
           PROJECT_ROOT="$MAIN_ROOT"
         fi
       fi
     fi
     ```

     Defina `UNDERSTAND_NO_WORKTREE_REDIRECT=1` se intencionalmente quiser um grafo por worktree (raro — a maioria dos usuários quer o redirecionamento).
1.5. **Garanta que o plugin esteja construído.** Fases posteriores invocam scripts Node que importam `@understand-anything/core`. Em uma instalação nova, `packages/core/dist/` ainda não existe — faça o build uma vez.

   **Importante:** **não** assuma que a raiz do plugin está simplesmente dois diretórios acima da string do caminho da skill. Em muitas instalações, `~/.agents/skills/understand` é um symlink para o checkout real do plugin. Prefira raízes de plugin fornecidas em runtime primeiro (para o Claude), e então faça fallback para symlinks universais, resolução de symlink da skill e caminhos comuns de instalação por clone.

   Resolva a raiz do plugin assim:

   ```bash
   SKILL_REAL=$(realpath ~/.agents/skills/understand 2>/dev/null || readlink -f ~/.agents/skills/understand 2>/dev/null || echo "")
   SELF_RELATIVE=$([ -n "$SKILL_REAL" ] && cd "$SKILL_REAL/../.." 2>/dev/null && pwd || echo "")
   COPILOT_SKILL_REAL=$(realpath ~/.copilot/skills/understand 2>/dev/null || readlink -f ~/.copilot/skills/understand 2>/dev/null || echo "")
   COPILOT_SELF_RELATIVE=$([ -n "$COPILOT_SKILL_REAL" ] && cd "$COPILOT_SKILL_REAL/../.." 2>/dev/null && pwd || echo "")

   PLUGIN_ROOT=""
   for candidate in \
     "${CLAUDE_PLUGIN_ROOT}" \
     "$HOME/.understand-anything-plugin" \
     "$SELF_RELATIVE" \
     "$COPILOT_SELF_RELATIVE" \
     "$HOME/.codex/understand-anything/understand-anything-plugin" \
     "$HOME/.opencode/understand-anything/understand-anything-plugin" \
     "$HOME/.pi/understand-anything/understand-anything-plugin" \
     "$HOME/understand-anything/understand-anything-plugin"; do
     if [ -n "$candidate" ] && [ -f "$candidate/package.json" ] && [ -f "$candidate/pnpm-workspace.yaml" ]; then
       PLUGIN_ROOT="$candidate"
       break
     fi
   done

   if [ -z "$PLUGIN_ROOT" ]; then
     echo "Error: Cannot find the understand-anything plugin root."
     echo "Checked:"
     echo "  - ${CLAUDE_PLUGIN_ROOT:-<unset CLAUDE_PLUGIN_ROOT>}"
     echo "  - $HOME/.understand-anything-plugin"
     echo "  - ${SELF_RELATIVE:-<unresolved path derived from ~/.agents/skills/understand>}"
     echo "  - ${COPILOT_SELF_RELATIVE:-<unresolved path derived from ~/.copilot/skills/understand>}"
     echo "  - $HOME/.codex/understand-anything/understand-anything-plugin"
     echo "  - $HOME/.opencode/understand-anything/understand-anything-plugin"
     echo "  - $HOME/.pi/understand-anything/understand-anything-plugin"
     echo "  - $HOME/understand-anything/understand-anything-plugin"
     echo "Make sure the plugin is installed correctly."
     exit 1
   fi

   if [ ! -f "$PLUGIN_ROOT/packages/core/dist/index.js" ]; then
     cd "$PLUGIN_ROOT" && (pnpm install --frozen-lockfile 2>/dev/null || pnpm install) && pnpm --filter @understand-anything/core build
   fi
   ```

   Se `pnpm` estiver ausente, reporte ao usuário: "Install Node.js ≥ 22 and pnpm ≥ 10, then re-run `/understand`."

2. Obtenha o hash do commit git atual:
   ```bash
   git rev-parse HEAD
   ```
3. Crie os diretórios intermediários e de saída temporária:
   ```bash
   mkdir -p $PROJECT_ROOT/.understand-anything/intermediate
   mkdir -p $PROJECT_ROOT/.understand-anything/tmp
   ```
3.5. **Configuração de auto-update:**
    - Se `--auto-update` está em `$ARGUMENTS`: grave `{"autoUpdate": true}` em `$PROJECT_ROOT/.understand-anything/config.json`
    - Se `--no-auto-update` está em `$ARGUMENTS`: grave `{"autoUpdate": false}` em `$PROJECT_ROOT/.understand-anything/config.json`
    - Essas flags apenas definem a config — a análise prossegue normalmente em qualquer caso.

 3.6. **Configuração de idioma:**
    - Faça parse de `$ARGUMENTS` em busca da flag `--language <lang>`. Se encontrada, extraia o código de idioma.
    - **Normalização de código de idioma:** Mapeie nomes amigáveis para códigos ISO:
      - `chinese` → `zh`, `japanese` → `ja`, `korean` → `ko`, `english` → `en`, `spanish` → `es`, `french` → `fr`, `german` → `de`, `portuguese` → `pt`, `russian` → `ru`, `arabic` → `ar`, etc.
      - Variantes de locale: `zh-TW`, `zh-HK`, `zh-CN`, `pt-BR`, etc. são preservadas como estão.
    - Se `--language` NÃO for especificado:
      - Verifique `$PROJECT_ROOT/.understand-anything/config.json` em busca de um campo `outputLanguage` existente. Se presente, use-o.
      - Se não houver preferência armazenada, use o padrão `en` (Inglês).
    - Se `--language` FOR especificado:
      - Atualize `$PROJECT_ROOT/.understand-anything/config.json` com o novo idioma: mescle `{"outputLanguage": "<lang>"}` na config existente.
      - Armazene como `$OUTPUT_LANGUAGE` para uso em todas as fases.
    - **Template da diretiva de idioma:** Armazene como `$LANGUAGE_DIRECTIVE`:
      ```markdown
      > **Language directive**: Generate all textual content (summaries, descriptions, tags, titles, languageNotes, languageLesson) in **{language}**. Maintain technical accuracy while using natural, native-level phrasing in the target language. Keep technical terms in English when no standard translation exists (e.g., "middleware", "hook", "barrel").
      ```

 4. **Verifique knowledge graphs de subdomínio para mesclar:**
   Liste todos os arquivos `*knowledge-graph*.json` em `$PROJECT_ROOT/.understand-anything/` **excluindo** o próprio `knowledge-graph.json` (ex.: `frontend-knowledge-graph.json`, `backend-knowledge-graph.json`). Se houver grafos de subdomínio, execute o script de merge empacotado com esta skill (localizado ao lado deste SKILL.md — use o caminho do diretório da skill, não a raiz do projeto):
   ```bash
   python <SKILL_DIR>/merge-subdomain-graphs.py $PROJECT_ROOT
   ```
   O script descobre os grafos de subdomínio, carrega o `knowledge-graph.json` existente como base (se houver) e mescla tudo em `knowledge-graph.json` (deduplicando nós e arestas). Reporte o resumo do merge ao usuário e prossiga com o grafo mesclado.

5. Verifique se `$PROJECT_ROOT/.understand-anything/knowledge-graph.json` existe. Se sim, leia-o.
6. Verifique se `$PROJECT_ROOT/.understand-anything/meta.json` existe. Se sim, leia-o para obter `gitCommitHash`.
7. **Lógica de decisão:**

   | Condição | Ação |
   |---|---|
   | Flag `--full` em `$ARGUMENTS` | Análise completa (todas as fases) |
   | Sem grafo ou meta existente | Análise completa (todas as fases) |
   | Flag `--review` + grafo existente + hash de commit inalterado | Pule para a Fase 6 (apenas review — reuse o assembled graph existente) |
   | Grafo existente + hash de commit inalterado | Pergunte ao usuário: "The graph is up to date at this commit. Would you like to: **(a)** run a full rebuild (`--full`), **(b)** run the LLM graph reviewer (`--review`), or **(c)** do nothing?" Em seguida, siga a escolha. Se ele escolher (c), PARE. |
   | Grafo existente + arquivos alterados | Atualização incremental (reanalise apenas os arquivos alterados) |

   **Caminho apenas-review:** Copie o `knowledge-graph.json` existente para `$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json` e pule diretamente para o passo 3 da Fase 6.

   Para atualizações incrementais, obtenha a lista de arquivos alterados:
   ```bash
   git diff <lastCommitHash>..HEAD --name-only
   ```
   Se isso não retornar arquivos, reporte "Graph is up to date" e PARE.

8. **Colete contexto do projeto para injeção em subagentes:**
   - Leia `README.md` (ou `README.rst`, `readme.md`) de `$PROJECT_ROOT` se existir. Armazene como `$README_CONTENT` (primeiros 3000 caracteres).
   - Leia o manifesto principal de pacote (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`) se existir. Armazene como `$MANIFEST_CONTENT`.
   - Capture a árvore de diretórios de topo:
     ```bash
     find $PROJECT_ROOT -maxdepth 2 -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' | head -100
     ```
     Armazene como `$DIR_TREE`.
   - Detecte o entry-point do projeto verificando padrões comuns (em ordem): `src/index.ts`, `src/main.ts`, `src/App.tsx`, `index.js`, `main.py`, `manage.py`, `app.py`, `wsgi.py`, `asgi.py`, `run.py`, `__main__.py`, `main.go`, `cmd/*/main.go`, `src/main.rs`, `src/lib.rs`, `src/main/java/**/Application.java`, `Program.cs`, `config.ru`, `index.php`. Armazene o primeiro match como `$ENTRY_POINT`.

---

## Fase 0.5 — Configuração de Ignore

Configure e verifique o arquivo `.understandignore` antes da varredura.

1. Verifique se `$PROJECT_ROOT/.understand-anything/.understandignore` existe.
2. **Se NÃO existir**, gere um arquivo inicial:
   - Execute o seguinte one-liner em Node.js em `$PROJECT_ROOT` (lê `.gitignore` e deduplica contra defaults built-in):
     ```bash
     node -e "
     const fs = require('fs');
     const path = require('path');
     const root = process.cwd();
     const defaults = ['node_modules/','node_modules','.git/','vendor/','venv/','.venv/','__pycache__/','dist/','dist','build/','build','out/','coverage/','coverage','.next/','.cache/','.turbo/','target/','obj/','*.lock','package-lock.json','yarn.lock','pnpm-lock.yaml','*.png','*.jpg','*.jpeg','*.gif','*.svg','*.ico','*.woff','*.woff2','*.ttf','*.eot','*.mp3','*.mp4','*.pdf','*.zip','*.tar','*.gz','*.min.js','*.min.css','*.map','*.generated.*','.idea/','.vscode/','LICENSE','.gitignore','.editorconfig','.prettierrc','.eslintrc*','*.log'];
     const norm = p => p.replace(/\/+$/, '');
     const defaultSet = new Set(defaults.map(norm));
     const header = '# .understandignore — patterns for files/dirs to exclude from analysis\n# Syntax: same as .gitignore (globs, # comments, ! negation, trailing / for dirs)\n# Lines below are suggestions — uncomment to activate.\n# Use ! prefix to force-include something excluded by defaults.\n#\n# Built-in defaults (always excluded unless negated):\n#   node_modules/, .git/, dist/, build/, obj/, *.lock, *.min.js, etc.\n#\n';
     let body = '';
     const gitignorePath = path.join(root, '.gitignore');
     if (fs.existsSync(gitignorePath)) {
       const gi = fs.readFileSync(gitignorePath, 'utf-8').split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#')).filter(p => !defaultSet.has(norm(p)));
       if (gi.length) { body += '# --- From .gitignore (uncomment to exclude) ---\n\n' + gi.map(p => '# ' + p).join('\n') + '\n\n'; }
     }
     const dirs = ['__tests__','test','tests','fixtures','testdata','docs','examples','scripts','migrations','.storybook'];
     const found = dirs.filter(d => fs.existsSync(path.join(root, d)));
     if (found.length) { body += '# --- Detected directories (uncomment to exclude) ---\n\n' + found.map(d => '# ' + d + '/').join('\n') + '\n\n'; }
     body += '# --- Test file patterns (uncomment to exclude) ---\n\n# *.test.*\n# *.spec.*\n# *.snap\n';
     const outDir = path.join(root, '.understand-anything');
     if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
     fs.writeFileSync(path.join(outDir, '.understandignore'), header + body);
     "
     ```
   - Reporte ao usuário:
     > Generated `.understand-anything/.understandignore` with suggested exclusions based on your project structure. Please review it and uncomment any patterns you'd like to exclude from analysis. When ready, confirm to continue.
   - **Aguarde a confirmação do usuário antes de prosseguir.**
3. **Se já existir**, reporte:
   > Found `.understand-anything/.understandignore`. Review it if needed, then confirm to continue.
   - **Aguarde a confirmação do usuário antes de prosseguir.**
4. Após confirmação, prossiga para a Fase 1.

---

## Fase 1 — SCAN (apenas análise completa)

Despache um subagente usando a definição de agente `project-scanner` (em `agents/project-scanner.md`). Anexe o seguinte contexto adicional:

> **Additional context from main session:**
>
> Project README (first 3000 chars):
> ```
> $README_CONTENT
> ```
>
> Package manifest:
> ```
> $MANIFEST_CONTENT
> ```
>
> Use this context to produce more accurate project name, description, and framework detection. The README and manifest are authoritative — prefer their information over heuristics.
>
> $LANGUAGE_DIRECTIVE

Passe estes parâmetros no prompt de despacho:

> Scan this project directory to discover all project files (including non-code files like configs, docs, infrastructure), detect languages and frameworks.
> Project root: `$PROJECT_ROOT`
> Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/scan-result.json`

Após o subagente concluir, leia `$PROJECT_ROOT/.understand-anything/intermediate/scan-result.json` para obter:
- Nome do projeto, descrição
- Linguagens, frameworks
- Lista de arquivos com contagens de linha e `fileCategory` por arquivo (`code`, `config`, `docs`, `infra`, `data`, `script`, `markup`)
- Estimativa de complexidade
- Mapa de imports (`importMap`): imports internos do projeto pré-resolvidos por arquivo (arquivos não-código têm arrays vazios)

Armazene `importMap` em memória como `$IMPORT_MAP` para uso na construção de batches da Fase 2.
Armazene a lista de arquivos como `$FILE_LIST` com metadados de `fileCategory` para uso na construção de batches da Fase 2.

**Gate check:** Se houver >100 arquivos, informe o usuário e sugira escopar com um argumento de subdiretório. Prossiga apenas se o usuário confirmar ou avise que isso pode demorar.

Se o resultado do scan incluir `filteredByIgnore > 0`, reporte:
> Excluded {filteredByIgnore} files via `.understandignore`.

---

## Fase 2 — ANALYZE

### Caminho de análise completa

Faça batch da lista de arquivos da Fase 1 em grupos de **20 a 30 arquivos cada** (mire em ~25 arquivos por batch para tamanhos balanceados).

**Estratégia de batch para arquivos não-código:**
- Agrupe arquivos não-código relacionados no mesmo batch quando possível:
  - Dockerfile + docker-compose.yml + .dockerignore → mesmo batch
  - Arquivos de migration SQL → mesmo batch (ordenados por nome de arquivo)
  - Arquivos de config CI/CD (.github/workflows/*) → mesmo batch
  - Arquivos de documentação (docs/*.md) → mesmo batch
- Isso permite que o file-analyzer crie arestas cross-file (ex.: docker-compose `depends_on` Dockerfile)
- Arquivos não-código podem ser misturados com arquivos de código no mesmo batch se os tamanhos forem pequenos
- O `fileCategory` de cada arquivo, vindo da Fase 1, deve ser incluído na lista de arquivos do batch

Para cada batch, despache um subagente usando a definição de agente `file-analyzer` (em `agents/file-analyzer.md`). Execute até **5 subagentes concorrentemente** via despacho paralelo. Anexe o seguinte contexto adicional:

> **Additional context from main session:**
>
> Project: `<projectName>` — `<projectDescription>`
> Languages: `<languages from Phase 1>`
>
> $LANGUAGE_DIRECTIVE

Antes de despachar cada batch, construa `batchImportData` a partir de `$IMPORT_MAP`:
```json
batchImportData = {}
for each file in this batch:
  batchImportData[file.path] = $IMPORT_MAP[file.path] ?? []
```

Preencha os parâmetros específicos do batch abaixo e despache:

> Analyze these files and produce GraphNode and GraphEdge objects.
> Project root: `$PROJECT_ROOT`
> Project: `<projectName>`
> Languages: `<languages>`
> Batch index: `<batchIndex>`
> Skill directory (for bundled scripts): `<SKILL_DIR>`
> Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/batch-<batchIndex>.json`
>
> Pre-resolved import data for this batch (use this for all import edge creation — do NOT re-resolve imports from source):
> ```json
> <batchImportData JSON>
> ```
>
> Files to analyze in this batch (every entry MUST be passed through to `batchFiles` with all four fields — `path`, `language`, `sizeLines`, `fileCategory`):
> 1. `<path>` (<sizeLines> lines, language: `<language>`, fileCategory: `<fileCategory>`)
> 2. `<path>` (<sizeLines> lines, language: `<language>`, fileCategory: `<fileCategory>`)
> ...

Após TODOS os batches terminarem, execute o script de merge e normalização empacotado com esta skill (localizado ao lado deste SKILL.md — use o caminho do diretório da skill, não a raiz do projeto):
```bash
python <SKILL_DIR>/merge-batch-graphs.py $PROJECT_ROOT
```

Esse script lê todos os arquivos `batch-*.json` de `$PROJECT_ROOT/.understand-anything/intermediate/` e, em uma única passada:
- Combina todos os nós e arestas entre batches
- Normaliza IDs de nó (remove prefixos duplicados, prefixos de nome do projeto, adiciona prefixos faltantes)
- Normaliza valores de complexidade (`low`→`simple`, `medium`→`moderate`, `high`→`complex`, etc.)
- Reescreve referências de aresta para casar com os IDs de nó corrigidos
- Deduplica nós por ID (mantém a última ocorrência) e arestas por `(source, target, type)`
- Descarta arestas pendentes que referenciam nós ausentes
- Registra todas as correções e itens descartados no stderr

O script de merge também executa um linker `tested_by` que canoniza arestas de cobertura de teste em duas passadas. **Pass 1** percorre as arestas `tested_by` emitidas pelo LLM e inverte no lugar as que estão invertidas (o LLM sistematicamente emite `test → production` porque ele só vê o import quando analisa o arquivo de teste); arestas semanticamente quebradas (test↔test, prod↔prod, endpoints órfãos) são descartadas. **Pass 2** suplementa com pareamentos por convenção de caminho (`X.ts` ↔ `X.test.ts`, walk-out de `__tests__/` e `<dir>/test/` em JS/TS, `tests/` in-package em Python, sibling `_test.go` em Go, `src/test/...` ↔ `src/main/...` em Maven/Gradle, `<svc>/tests/` ↔ `<svc>/src/...` e `<App>.Tests/` ↔ `<App>/` em .NET). Nós de produção que acabam sendo origem de qualquer aresta `tested_by` recebem uma tag `"tested"`. Todas as arestas resultantes seguem `production → test`.

Saída: `$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json`

Inclua os warnings do script em `$PHASE_WARNINGS` para o reviewer.

### Caminho de atualização incremental

Use a lista de arquivos alterados da Fase 0. Faça batch e despache subagentes file-analyzer usando o mesmo processo acima (20 a 30 arquivos por batch, até 5 concorrentes, com batchImportData construído a partir de $IMPORT_MAP), mas apenas para arquivos alterados.

Após os batches concluírem:
1. Remova nós antigos cujo `filePath` casa com qualquer arquivo alterado a partir do grafo existente
2. Remova arestas antigas cujo `source` ou `target` referencia um nó removido
3. Grave os nós/arestas existentes podados como `batch-existing.json` no diretório intermediário
4. Execute o mesmo script de merge — ele combinará `batch-existing.json` com os arquivos `batch-*.json` novos:
   ```bash
   python <SKILL_DIR>/merge-batch-graphs.py $PROJECT_ROOT
   ```

---

## Fase 3 — ASSEMBLE REVIEW

Despache um subagente usando a definição de agente `assemble-reviewer` (em `agents/assemble-reviewer.md`).

Passe estes parâmetros no prompt de despacho:

> Review the assembled graph at `$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json`.
> Project root: `$PROJECT_ROOT`
> Batch files are at: `$PROJECT_ROOT/.understand-anything/intermediate/batch-*.json`
> Write review output to: `$PROJECT_ROOT/.understand-anything/intermediate/assemble-review.json`
>
> **Merge script report:**
> ```
> <paste the full stderr output from merge-batch-graphs.py>
> ```
>
> **Import map for cross-batch edge verification:**
> ```json
> $IMPORT_MAP
> ```

Após o subagente concluir, leia `$PROJECT_ROOT/.understand-anything/intermediate/assemble-review.json` e adicione quaisquer notas a `$PHASE_WARNINGS`.

---

## Fase 4 — ARCHITECTURE

**Construa o template de prompt combinado:**
 1. Use a definição de agente `architecture-analyzer` (em `agents/architecture-analyzer.md`).
 2. **Injeção de contexto de linguagem:** Para cada linguagem detectada na Fase 1 (ex.: `python`, `markdown`, `dockerfile`, `yaml`, `sql`, `terraform`, `graphql`, `protobuf`, `shell`, `html`, `css`), leia o arquivo em `./languages/<language-id>.md` (ex.: `./languages/python.md`, `./languages/dockerfile.md`) e anexe seu conteúdo após o template base sob um cabeçalho `## Language Context`. Se o arquivo não existir para uma linguagem detectada, pule silenciosamente e continue. Esses arquivos ficam no subdiretório `languages/` ao lado deste SKILL.md. **Inclua snippets de linguagem não-código** — eles fornecem padrões de aresta e estilos de summary para arquivos não-código.
 3. **Injeção de adendo de framework:** Para cada framework detectado na Fase 1 (ex.: `Django`), leia o arquivo em `./frameworks/<framework-id-lowercase>.md` (ex.: `./frameworks/django.md`) e anexe seu conteúdo completo após o contexto de linguagem. Se o arquivo não existir para um framework detectado, pule silenciosamente e continue. Esses arquivos ficam no subdiretório `frameworks/` ao lado deste SKILL.md.
 4. **Injeção de locale de saída:** Se `$OUTPUT_LANGUAGE` NÃO for `en` (Inglês), leia o arquivo de orientação de locale em `./locales/<language-code>.md` (ex.: `./locales/zh.md`, `./locales/ja.md`, `./locales/ko.md`) e anexe seu conteúdo após os adendos de framework sob um cabeçalho `## Output Language Guidelines`. Isso fornece orientações específicas de idioma para convenções de nomeação de tags, estilo de summary e traduções de nomes de camada. Se o arquivo de locale não existir para o idioma especificado, pule silenciosamente — o `$LANGUAGE_DIRECTIVE` continua em vigor. Esses arquivos ficam no subdiretório `locales/` ao lado deste SKILL.md.

Anexe o contexto de linguagem/framework e o seguinte contexto adicional ao prompt do agente:

> **Additional context from main session:**
>
> Frameworks detected: `<frameworks from Phase 1>`
>
> Directory tree (top 2 levels):
> ```
> $DIR_TREE
> ```
>
> Use the directory tree, language context, and framework addendums (appended above) to inform layer assignments. Directory structure is strong evidence for layer boundaries. Non-code files (config, docs, infrastructure, data) should be assigned to appropriate layers — see the prompt template for guidance.
>
> $LANGUAGE_DIRECTIVE

Passe estes parâmetros no prompt de despacho:

> Analyze this codebase's structure to identify architectural layers.
> Project root: `$PROJECT_ROOT`
> Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/layers.json`
> Project: `<projectName>` — `<projectDescription>`
>
> File nodes (all node types — includes code files, config, document, service, pipeline, table, schema, resource, endpoint):
> ```json
> [list of {id, type, name, filePath, summary, tags} for ALL file-level nodes — omit complexity, languageNotes]
> ```
>
> Import edges:
> ```json
> [list of edges with type "imports"]
> ```
>
> All edges (for cross-category analysis — includes configures, documents, deploys, triggers, etc.):
> ```json
> [list of ALL edges — include all edge types]
> ```

Após o subagente concluir, leia `$PROJECT_ROOT/.understand-anything/intermediate/layers.json` e normalize-o em um array `layers` final. Aplique estes passos **nesta ordem**:

1. **Desembrulhe o envelope:** Se o arquivo contiver `{ "layers": [...] }` em vez de um array puro, extraia o array interno. (O prompt pede um array puro, mas LLMs ainda podem produzir um envelope.)
2. **Renomeie campos legados:** Se algum objeto de camada tiver um campo `nodes` em vez de `nodeIds`, renomeie `nodes` → `nodeIds`. Se as entradas de `nodes` forem objetos com um campo `id` em vez de strings simples, extraia apenas os valores de `id` para `nodeIds`.
3. **Sintetize IDs ausentes:** Se alguma camada estiver sem `id`, gere um como `layer:<kebab-case-name>`.
4. **Converta caminhos de arquivo:** Se entradas de `nodeIds` forem caminhos de arquivo nus sem prefixo conhecido (`file:`, `config:`, `document:`, `service:`, `pipeline:`, `table:`, `schema:`, `resource:`, `endpoint:`), converta-os para `file:<relative-path>`.
5. **Descarte refs pendentes:** Remova quaisquer entradas de `nodeIds` que não existam no conjunto de nós mesclados.

Cada elemento do array final `layers` DEVE ter este formato:

```json
[
  {
    "id": "layer:<kebab-case-name>",
    "name": "<layer name>",
    "description": "<what belongs in this layer>",
    "nodeIds": ["file:src/App.tsx", "config:tsconfig.json", "document:README.md"]
  }
]
```

Os quatro campos (`id`, `name`, `description`, `nodeIds`) são obrigatórios.

**Para atualizações incrementais:** Sempre re-execute a análise de arquitetura sobre o conjunto completo de nós mesclados, já que as atribuições de camada podem mudar quando os arquivos mudam.

**Contexto para atualizações incrementais:** Ao re-executar a análise de arquitetura, injete também as definições anteriores de camada:

> Previous layer definitions (for naming consistency):
> ```json
> [previous layers from existing graph]
> ```
>
> Maintain the same layer names and IDs where possible. Only add/remove layers if the file structure has materially changed.

---

## Fase 5 — TOUR

Despache um subagente usando a definição de agente `tour-builder` (em `agents/tour-builder.md`). Anexe o seguinte contexto adicional:

> **Additional context from main session:**
>
> Project README (first 3000 chars):
> ```
> $README_CONTENT
> ```
>
> Project entry point: `$ENTRY_POINT`
>
> Use the README to align the tour narrative with the project's own documentation. Start the tour from the entry point if one was detected. The tour should tell the same story the README tells, but through the lens of actual code structure.
>
> $LANGUAGE_DIRECTIVE

Passe estes parâmetros no prompt de despacho:

> Create a guided learning tour for this codebase.
> Project root: `$PROJECT_ROOT`
> Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/tour.json`
> Project: `<projectName>` — `<projectDescription>`
> Languages: `<languages>`
>
> Nodes (all file-level nodes — includes code files, config, document, service, pipeline, table, schema, resource, endpoint):
> ```json
> [list of {id, name, filePath, summary, type} for ALL file-level nodes — do NOT include function or class nodes]
> ```
>
> Layers:
> ```json
> [list of {id, name, description} for each layer — omit nodeIds]
> ```
>
> Edges (all types — includes imports, calls, configures, documents, deploys, triggers, etc.):
> ```json
> [list of ALL edges — include all edge types for complete graph topology analysis]
> ```

Após o subagente concluir, leia `$PROJECT_ROOT/.understand-anything/intermediate/tour.json` e normalize-o em um array `tour` final. Aplique estes passos **nesta ordem**:

1. **Desembrulhe o envelope:** Se o arquivo contiver `{ "steps": [...] }` em vez de um array puro, extraia o array interno. (O prompt pede um array puro, mas LLMs ainda podem produzir um envelope.)
2. **Renomeie campos legados:** Se algum passo tiver `nodesToInspect` em vez de `nodeIds`, renomeie → `nodeIds`. Se algum passo tiver `whyItMatters` em vez de `description`, renomeie → `description`.
3. **Converta caminhos de arquivo:** Se entradas de `nodeIds` forem caminhos de arquivo nus sem prefixo conhecido (`file:`, `config:`, `document:`, `service:`, `pipeline:`, `table:`, `schema:`, `resource:`, `endpoint:`), converta-os para `file:<relative-path>`.
4. **Descarte refs pendentes:** Remova quaisquer entradas de `nodeIds` que não existam no conjunto de nós mesclados.
5. **Ordene** por `order` antes de salvar.

Cada elemento do array final `tour` DEVE ter este formato:

```json
[
  {
    "order": 1,
    "title": "Project Overview",
    "description": "Start with the README to understand the project's purpose and architecture.",
    "nodeIds": ["document:README.md"]
  },
  {
    "order": 2,
    "title": "Application Entry Point",
    "description": "This step explains how the frontend boots and mounts.",
    "nodeIds": ["file:src/main.tsx", "file:src/App.tsx"]
  }
]
```

Campos obrigatórios: `order`, `title`, `description`, `nodeIds`. Preserve `languageLesson` opcional quando presente.

---

## Fase 6 — REVIEW

Monte o objeto JSON completo do KnowledgeGraph:

```json
{
  "version": "1.0.0",
  "project": {
    "name": "<projectName>",
    "languages": ["<languages>"],
    "frameworks": ["<frameworks>"],
    "description": "<projectDescription>",
    "analyzedAt": "<ISO 8601 timestamp>",
    "gitCommitHash": "<commit hash from Phase 0>"
  },
  "nodes": [<all nodes from assembled-graph.json after Phase 3 review>],
  "edges": [<all edges from assembled-graph.json after Phase 3 review>],
  "layers": [<layers from Phase 4>],
  "tour": [<steps from Phase 5>]
}
```

1. Antes de gravar o assembled graph, valide que:
   - `layers` é um array de objetos com estes campos obrigatórios: `id`, `name`, `description`, `nodeIds`
   - `tour` é um array de objetos com estes campos obrigatórios: `order`, `title`, `description`, `nodeIds`
   - `tour[*].languageLesson` é permitido como campo opcional do tipo string
   - Toda entrada `layers[*].nodeIds` existe no conjunto de nós mesclados
   - Toda entrada `tour[*].nodeIds` existe no conjunto de nós mesclados

   Se a validação falhar, normalize automaticamente e regrave o grafo nesse formato antes de salvar. Se o grafo ainda falhar na validação final após o passo de normalização, salve-o com warnings mas marque o auto-launch do dashboard como pulado.

2. Grave o assembled graph em `$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json`.

3. **Verifique `$ARGUMENTS` pela flag `--review`.** Em seguida, execute o caminho de validação apropriado:

---

#### Caminho default (sem `--review`): validação determinística inline

Grave o seguinte script Node.js em `$PROJECT_ROOT/.understand-anything/tmp/ua-inline-validate.cjs`:

```javascript
#!/usr/bin/env node
const fs = require('fs');
const graphPath = process.argv[2];
const outputPath = process.argv[3];
try {
  const graph = JSON.parse(fs.readFileSync(graphPath, 'utf8'));
  const issues = [], warnings = [];
  if (!Array.isArray(graph.nodes)) { issues.push('graph.nodes is missing or not an array'); graph.nodes = []; }
  if (!Array.isArray(graph.edges)) { issues.push('graph.edges is missing or not an array'); graph.edges = []; }
  const nodeIds = new Set();
  const seen = new Map();
  graph.nodes.forEach((n, i) => {
    if (!n.id) { issues.push(`Node[${i}] missing id`); return; }
    if (!n.type) issues.push(`Node[${i}] '${n.id}' missing type`);
    if (!n.name) issues.push(`Node[${i}] '${n.id}' missing name`);
    if (!n.summary) issues.push(`Node[${i}] '${n.id}' missing summary`);
    if (!n.tags || !n.tags.length) issues.push(`Node[${i}] '${n.id}' missing tags`);
    if (seen.has(n.id)) issues.push(`Duplicate node ID '${n.id}' at indices ${seen.get(n.id)} and ${i}`);
    else seen.set(n.id, i);
    nodeIds.add(n.id);
  });
  graph.edges.forEach((e, i) => {
    if (!nodeIds.has(e.source)) issues.push(`Edge[${i}] source '${e.source}' not found`);
    if (!nodeIds.has(e.target)) issues.push(`Edge[${i}] target '${e.target}' not found`);
  });
  const fileLevelTypes = new Set(['file', 'config', 'document', 'service', 'pipeline', 'table', 'schema', 'resource', 'endpoint']);
  const fileNodes = graph.nodes.filter(n => fileLevelTypes.has(n.type)).map(n => n.id);
  const assigned = new Map();
  if (!Array.isArray(graph.layers)) { if (graph.layers) warnings.push('graph.layers is not an array'); graph.layers = []; }
  if (!Array.isArray(graph.tour)) { if (graph.tour) warnings.push('graph.tour is not an array'); graph.tour = []; }
  graph.layers.forEach(layer => {
    (layer.nodeIds || []).forEach(id => {
      if (!nodeIds.has(id)) issues.push(`Layer '${layer.id}' refs missing node '${id}'`);
      if (assigned.has(id)) issues.push(`Node '${id}' appears in multiple layers`);
      assigned.set(id, layer.id);
    });
  });
  fileNodes.forEach(id => {
    if (!assigned.has(id)) issues.push(`File node '${id}' not in any layer`);
  });
  graph.tour.forEach((step, i) => {
    (step.nodeIds || []).forEach(id => {
      if (!nodeIds.has(id)) issues.push(`Tour step[${i}] refs missing node '${id}'`);
    });
  });
  const withEdges = new Set([
    ...graph.edges.map(e => e.source),
    ...graph.edges.map(e => e.target)
  ]);
  graph.nodes.forEach(n => {
    if (!withEdges.has(n.id)) warnings.push(`Node '${n.id}' has no edges (orphan)`);
  });
  const stats = {
    totalNodes: graph.nodes.length,
    totalEdges: graph.edges.length,
    totalLayers: graph.layers.length,
    tourSteps: graph.tour.length,
    nodeTypes: graph.nodes.reduce((a, n) => { a[n.type] = (a[n.type]||0)+1; return a; }, {}),
    edgeTypes: graph.edges.reduce((a, e) => { a[e.type] = (a[e.type]||0)+1; return a; }, {})
  };
  fs.writeFileSync(outputPath, JSON.stringify({ issues, warnings, stats }, null, 2));
  process.exit(0);
} catch (err) { process.stderr.write(err.message + '\n'); process.exit(1); }
```

Execute-o:
```bash
node $PROJECT_ROOT/.understand-anything/tmp/ua-inline-validate.cjs \
  "$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json" \
  "$PROJECT_ROOT/.understand-anything/intermediate/review.json"
```

Se o script sair com código diferente de zero, leia o stderr, corrija o script e tente uma vez mais.

---

#### Caminho `--review`: reviewer LLM completo

Se `--review` ESTIVER em `$ARGUMENTS`, despache o subagente LLM graph-reviewer da seguinte forma:

Despache um subagente usando a definição de agente `graph-reviewer` (em `agents/graph-reviewer.md`). Anexe o seguinte contexto adicional:

> **Additional context from main session:**
>
> Phase 1 scan results (file inventory):
> ```json
> [list of {path, sizeLines} from scan-result.json]
> ```
>
> Phase warnings/errors accumulated during analysis:
> - [list any batch failures, skipped files, or warnings from Phases 2-5]
>
> Cross-validate: every file in the scan inventory should have a corresponding node in the graph (node types may vary: `file:`, `config:`, `document:`, `service:`, `pipeline:`, `table:`, `schema:`, `resource:`, `endpoint:`). Flag any missing files. Also flag any graph nodes whose `filePath` doesn't appear in the scan inventory.

Passe estes parâmetros no prompt de despacho:

> Validate the knowledge graph at `$PROJECT_ROOT/.understand-anything/intermediate/assembled-graph.json`.
> Project root: `$PROJECT_ROOT`
> Read the file and validate it for completeness and correctness.
> Write output to: `$PROJECT_ROOT/.understand-anything/intermediate/review.json`

---

4. Leia `$PROJECT_ROOT/.understand-anything/intermediate/review.json`.

5. **Se o array `issues` estiver não vazio:**
   - Revise a lista de `issues`
   - Aplique correções automatizadas onde for possível:
     - Remover arestas com referências pendentes
     - Preencher campos obrigatórios ausentes com defaults sensatos (ex.: `tags` vazio -> `["untagged"]`, `summary` vazio -> `"No summary available"`)
     - Remover nós com tipos inválidos
   - Re-execute a validação final do grafo após as correções automatizadas
   - Se problemas críticos persistirem após uma tentativa de correção, salve o grafo mesmo assim mas inclua os warnings no relatório final e marque o auto-launch do dashboard como pulado

6. **Se o array `issues` estiver vazio:** Prossiga para a Fase 7.

---

## Fase 7 — SAVE

1. Grave o knowledge graph final em `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`.

2. **Gere a baseline de fingerprints estruturais.** Isso cria a base para futuras atualizações incrementais automáticas e **deve ter sucesso antes que `meta.json` seja gravado** — caso contrário, o auto-update vê um hash de commit novo sem fingerprints para comparar, classifica todo arquivo como STRUCTURAL e escala para `FULL_UPDATE` em todo commit subsequente (issue #152).

   Grave o arquivo de entrada:
   ```bash
   cat > $PROJECT_ROOT/.understand-anything/intermediate/fingerprint-input.json <<EOF
   {
     "projectRoot": "$PROJECT_ROOT",
     "sourceFilePaths": [<all source file paths from Phase 1, as JSON array>],
     "gitCommitHash": "<current commit hash>"
   }
   EOF
   ```

   Em seguida, invoque o script empacotado (localizado ao lado deste SKILL.md):
   ```bash
   node <SKILL_DIR>/build-fingerprints.mjs \
     $PROJECT_ROOT/.understand-anything/intermediate/fingerprint-input.json
   ```

   O script usa `TreeSitterPlugin + PluginRegistry` exatamente como `extract-structure.mjs`, então a baseline casa com a lógica de comparação usada durante auto-updates.

   **Se o script sair com código diferente de zero ou o stdout não incluir `Fingerprints baseline:`, aborte a Fase 7 e reporte o erro. NÃO prossiga para o passo 3 (gravar `meta.json`).**

3. Grave os metadados em `$PROJECT_ROOT/.understand-anything/meta.json` (somente após o passo 2 ter sido bem-sucedido):
   ```json
   {
     "lastAnalyzedAt": "<ISO 8601 timestamp>",
     "gitCommitHash": "<commit hash>",
     "version": "1.0.0",
     "analyzedFiles": <number of files analyzed>
   }
   ```

4. Limpe os arquivos intermediários:
   ```bash
   rm -rf $PROJECT_ROOT/.understand-anything/intermediate
   rm -rf $PROJECT_ROOT/.understand-anything/tmp
   ```

5. Reporte um resumo ao usuário contendo:
   - Nome e descrição do projeto
   - Arquivos analisados / total de arquivos (com breakdown por fileCategory: code, config, docs, infra, data, script, markup)
   - Nós criados (com breakdown por tipo: file, function, class, config, document, service, table, endpoint, pipeline, schema, resource)
   - Arestas criadas (com breakdown por tipo)
   - Camadas identificadas (com nomes)
   - Passos de tour gerados (contagem)
   - Quaisquer warnings do reviewer
   - Caminho do arquivo de saída: `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`

6. Apenas inicie o dashboard automaticamente invocando a skill `/understand-dashboard` se a validação final do grafo passou após correções de normalização/review.
   Se a validação final não passou, reporte que o grafo foi salvo com warnings e que o launch do dashboard foi pulado.

---

## Tratamento de Erros

- Se o despacho de algum subagente falhar, tente novamente **uma vez** com o mesmo prompt mais contexto adicional sobre a falha.
- Acompanhe todos os warnings e erros de cada fase em uma lista `$PHASE_WARNINGS`. Quando usar `--review`, passe essa lista para o graph-reviewer na Fase 6. No caminho default, inclua os warnings acumulados no relatório final da Fase 7.
- Se falhar uma segunda vez, pule essa fase e continue com resultados parciais.
- SEMPRE salve resultados parciais — um grafo parcial é melhor que nenhum grafo.
- Reporte quaisquer fases puladas ou erros no resumo final para que o usuário saiba o que aconteceu.
- NUNCA descarte erros silenciosamente. Toda falha precisa ser visível no relatório final.

---

## Referência: Schema do KnowledgeGraph

### Tipos de Nó (13 no total)
| Tipo | Descrição | Convenção de ID |
|---|---|---|
| `file` | Arquivo de código-fonte | `file:<relative-path>` |
| `function` | Função ou método | `function:<relative-path>:<name>` |
| `class` | Classe, interface ou tipo | `class:<relative-path>:<name>` |
| `module` | Módulo ou pacote lógico | `module:<name>` |
| `concept` | Conceito ou padrão abstrato | `concept:<name>` |
| `config` | Arquivo de configuração (YAML, JSON, TOML, env) | `config:<relative-path>` |
| `document` | Arquivo de documentação (Markdown, RST, TXT) | `document:<relative-path>` |
| `service` | Definição de service deployável (Dockerfile, K8s) | `service:<relative-path>` |
| `table` | Tabela de banco ou migration | `table:<relative-path>:<table-name>` |
| `endpoint` | Definição de endpoint ou rota de API | `endpoint:<relative-path>:<endpoint-name>` |
| `pipeline` | Configuração de pipeline CI/CD | `pipeline:<relative-path>` |
| `schema` | Definição de schema (GraphQL, Protobuf, Prisma) | `schema:<relative-path>` |
| `resource` | Recurso de infraestrutura (Terraform, CloudFormation) | `resource:<relative-path>` |

### Tipos de Aresta (26 no total)
| Categoria | Tipos |
|---|---|
| Estrutural | `imports`, `exports`, `contains`, `inherits`, `implements` |
| Comportamental | `calls`, `subscribes`, `publishes`, `middleware` |
| Fluxo de dados | `reads_from`, `writes_to`, `transforms`, `validates` |
| Dependências | `depends_on`, `tested_by`, `configures` |
| Semântica | `related`, `similar_to` |
| Infraestrutura | `deploys`, `serves`, `provisions`, `triggers` |
| Schema/Data | `migrates`, `documents`, `routes`, `defines_schema` |

### Convenções de Peso de Aresta
| Tipo de Aresta | Peso |
|---|---|
| `contains` | 1.0 |
| `inherits`, `implements` | 0.9 |
| `calls`, `exports`, `defines_schema` | 0.8 |
| `imports`, `deploys`, `migrates` | 0.7 |
| `depends_on`, `configures`, `triggers` | 0.6 |
| `tested_by`, `documents`, `provisions`, `serves`, `routes` | 0.5 |
| Todos os demais | 0.5 (default) |
