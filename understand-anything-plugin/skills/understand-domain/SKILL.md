---
name: understand-domain
description: Extract business domain knowledge from a codebase and generate an interactive domain flow graph. Works standalone (lightweight scan) or derives from an existing /understand knowledge graph.
argument-hint: [--full]
---

# /understand-domain

Extrai conhecimento de domínio de negócio — domínios, fluxos de negócio e passos de processo — de um codebase e produz um grafo de fluxo horizontal interativo no dashboard.

## Como Funciona

- Se um knowledge graph já existir (`.understand-anything/knowledge-graph.json`), deriva o conhecimento de domínio a partir dele (barato, sem varredura de arquivos)
- Se não existir knowledge graph, faz uma varredura leve: árvore de arquivos + detecção de entry-points + arquivos amostrados
- Use a flag `--full` para forçar uma nova varredura mesmo que exista um knowledge graph

## Instruções

### Fase 0: Resolver `PROJECT_ROOT`

Defina `PROJECT_ROOT` como o diretório de trabalho atual.

**Redirecionamento de worktree.** Se `PROJECT_ROOT` está dentro de um git worktree (não o checkout principal), redirecione a saída para a raiz do repositório principal. Worktrees gerenciados pelo Claude Code são efêmeros — `.understand-anything/` gravado lá é destruído quando a sessão termina, levando junto o domain graph (issue #133). Detecte um worktree comparando `git rev-parse --git-dir` com `git rev-parse --git-common-dir`; em um checkout normal ou submódulo eles resolvem para o mesmo caminho, em um worktree eles diferem e o pai de `--git-common-dir` é a raiz do repo principal.

```bash
COMMON_DIR=$(git -C "$PROJECT_ROOT" rev-parse --git-common-dir 2>/dev/null)
GIT_DIR=$(git -C "$PROJECT_ROOT" rev-parse --git-dir 2>/dev/null)
if [ -n "$COMMON_DIR" ] && [ -n "$GIT_DIR" ]; then
  COMMON_ABS=$(cd "$PROJECT_ROOT" && cd "$COMMON_DIR" 2>/dev/null && pwd -P)
  GIT_ABS=$(cd "$PROJECT_ROOT" && cd "$GIT_DIR" 2>/dev/null && pwd -P)
  if [ -n "$COMMON_ABS" ] && [ "$COMMON_ABS" != "$GIT_ABS" ]; then
    MAIN_ROOT=$(dirname "$COMMON_ABS")
    if [ -d "$MAIN_ROOT" ] && [ "${UNDERSTAND_NO_WORKTREE_REDIRECT:-0}" != "1" ]; then
      echo "[understand-domain] Detected git worktree at $PROJECT_ROOT"
      echo "[understand-domain] Redirecting output to main repo root: $MAIN_ROOT"
      echo "[understand-domain] (Set UNDERSTAND_NO_WORKTREE_REDIRECT=1 to keep PROJECT_ROOT as the worktree.)"
      PROJECT_ROOT="$MAIN_ROOT"
    fi
  fi
fi
```

Use `$PROJECT_ROOT` (não o CWD nu) para toda referência ao "projeto atual" / `<project-root>` nas fases seguintes.

**Importante:** **não** assuma que a raiz do plugin está simplesmente dois diretórios acima da string do caminho da skill. Em muitas instalações, `~/.agents/skills/understand-domain` é um symlink para o checkout real do plugin. Prefira raízes de plugin fornecidas em runtime primeiro (para o Claude), e então faça fallback para symlinks universais, resolução de symlink da skill e caminhos comuns de instalação por clone.

Resolva a raiz do plugin assim:

```bash
SKILL_REAL=$(realpath ~/.agents/skills/understand-domain 2>/dev/null || readlink -f ~/.agents/skills/understand-domain 2>/dev/null || echo "")
SELF_RELATIVE=$([ -n "$SKILL_REAL" ] && cd "$SKILL_REAL/../.." 2>/dev/null && pwd || echo "")
COPILOT_SKILL_REAL=$(realpath ~/.copilot/skills/understand-domain 2>/dev/null || readlink -f ~/.copilot/skills/understand-domain 2>/dev/null || echo "")
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
  echo "  - ${SELF_RELATIVE:-<unresolved path derived from ~/.agents/skills/understand-domain>}"
  echo "  - ${COPILOT_SELF_RELATIVE:-<unresolved path derived from ~/.copilot/skills/understand-domain>}"
  echo "  - $HOME/.codex/understand-anything/understand-anything-plugin"
  echo "  - $HOME/.opencode/understand-anything/understand-anything-plugin"
  echo "  - $HOME/.pi/understand-anything/understand-anything-plugin"
  echo "  - $HOME/understand-anything/understand-anything-plugin"
  echo "Make sure the plugin is installed correctly."
  exit 1
fi
```

Use `$PLUGIN_ROOT` para toda referência a definições de agente nas fases seguintes.

### Fase 1: Detectar Grafo Existente

1. Verifique se `$PROJECT_ROOT/.understand-anything/knowledge-graph.json` existe
2. Se existir E `--full` NÃO foi passado → prossiga para a Fase 3 (derivar do grafo)
3. Caso contrário → prossiga para a Fase 2 (varredura leve)

### Fase 2: Varredura Leve (Caminho 1)

O script de pré-processamento NÃO produz um domain graph — ele produz **matéria-prima** (árvore de arquivos, entry-points, exports/imports) para que o agente domain-analyzer possa focar na análise de domínio em si, em vez de gastar dezenas de chamadas de ferramenta explorando o codebase. Pense nele como uma cola: pré-processamento Python barato → o LLM caro recebe uma entrada limpa e pequena → resultados melhores por menos custo.

1. Execute o script de pré-processamento empacotado com esta skill, passando o `$PROJECT_ROOT` da Fase 0:
   ```
   python ./extract-domain-context.py "$PROJECT_ROOT"
   ```
   Isso gera `$PROJECT_ROOT/.understand-anything/intermediate/domain-context.json` contendo:
   - Árvore de arquivos (respeitando `.gitignore`)
   - Entry-points detectados (rotas HTTP, comandos CLI, event handlers, cron jobs, handlers exportados)
   - Assinaturas de arquivo (exports, imports por arquivo)
   - Trechos de código para cada entry-point (assinatura + primeiras linhas)
   - Metadados do projeto (package.json, README, etc.)
2. Leia o `domain-context.json` gerado como contexto para a Fase 4
3. Prossiga para a Fase 4

### Fase 3: Derivar do Grafo Existente (Caminho 2)

1. Leia `$PROJECT_ROOT/.understand-anything/knowledge-graph.json`
2. Formate os dados do grafo como contexto estruturado:
   - Todos os nós com seus tipos, nomes, resumos e tags
   - Todas as arestas com seus tipos (especialmente `calls`, `imports`, `contains`)
   - Todas as camadas com suas descrições
   - Passos do tour, se disponíveis
3. Esse é o contexto para o domain-analyzer — não é necessário ler arquivos
4. Prossiga para a Fase 4

### Fase 4: Análise de Domínio

1. Leia o prompt do agente domain-analyzer em `$PLUGIN_ROOT/agents/domain-analyzer.md`
2. Despache um subagente com o prompt do domain-analyzer + o contexto da Fase 2 ou 3
3. O agente grava sua saída em `$PROJECT_ROOT/.understand-anything/intermediate/domain-analysis.json`

### Fase 5: Validar e Salvar

1. Leia a saída da análise de domínio
2. Valide usando o pipeline padrão de validação de grafo (o schema agora suporta os tipos domain/flow/step)
3. Se a validação falhar, registre warnings mas salve o que for válido (tolerância a erros)
4. Salve em `$PROJECT_ROOT/.understand-anything/domain-graph.json`
5. Limpe `$PROJECT_ROOT/.understand-anything/intermediate/domain-analysis.json` e `$PROJECT_ROOT/.understand-anything/intermediate/domain-context.json`

### Fase 6: Iniciar Dashboard

1. Auto-dispare `/understand-dashboard` para visualizar o domain graph
2. O dashboard detecta `domain-graph.json` e exibe a visão de domínio por padrão
