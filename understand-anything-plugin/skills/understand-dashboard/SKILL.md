---
name: understand-dashboard
description: Launch the interactive web dashboard to visualize a codebase's knowledge graph
argument-hint: [project-path]
---

# /understand-dashboard

Inicie o dashboard do Understand Anything para visualizar o knowledge graph do projeto atual.

## Instruções

1. Determine o diretório do projeto:
   - Se `$ARGUMENTS` contém um caminho, use-o como diretório do projeto
   - Caso contrário, use o diretório de trabalho atual

2. Verifique se `.understand-anything/knowledge-graph.json` existe no diretório do projeto. Se não existir, diga ao usuário:
   ```
   No knowledge graph found. Run /understand first to analyze this project.
   ```

3. Localize o código do dashboard. O dashboard fica em `packages/dashboard/` relativo à raiz deste plugin. Verifique estes caminhos em ordem e use o primeiro que existir:
   - `${CLAUDE_PLUGIN_ROOT}/packages/dashboard/` (raiz de runtime do Claude Code, prioridade máxima)
   - `~/.understand-anything-plugin/packages/dashboard/` (symlink universal, todas as instalações)
   - Dois níveis acima do caminho real de `~/.agents/skills/understand-dashboard` (fallback auto-relativo)
   - Dois níveis acima do caminho real de `~/.copilot/skills/understand-dashboard` (fallback de skills pessoais do Copilot)
   - Raízes comuns de instalação por clone:
     - `~/.codex/understand-anything/understand-anything-plugin/packages/dashboard/`
     - `~/.opencode/understand-anything/understand-anything-plugin/packages/dashboard/`
     - `~/.pi/understand-anything/understand-anything-plugin/packages/dashboard/`
     - `~/understand-anything/understand-anything-plugin/packages/dashboard/`

   Use a ferramenta Bash para resolver:
   ```bash
   SKILL_REAL=$(realpath ~/.agents/skills/understand-dashboard 2>/dev/null || readlink -f ~/.agents/skills/understand-dashboard 2>/dev/null || echo "")
   SELF_RELATIVE=$([ -n "$SKILL_REAL" ] && cd "$SKILL_REAL/../.." 2>/dev/null && pwd || echo "")
   COPILOT_SKILL_REAL=$(realpath ~/.copilot/skills/understand-dashboard 2>/dev/null || readlink -f ~/.copilot/skills/understand-dashboard 2>/dev/null || echo "")
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
     if [ -n "$candidate" ] && [ -d "$candidate/packages/dashboard" ]; then
       PLUGIN_ROOT="$candidate"; break
     fi
   done

   if [ -z "$PLUGIN_ROOT" ]; then
     echo "Error: Cannot find the understand-anything plugin root."
     echo "Checked:"
     echo "  - ${CLAUDE_PLUGIN_ROOT:-<unset CLAUDE_PLUGIN_ROOT>}"
     echo "  - $HOME/.understand-anything-plugin"
     echo "  - ${SELF_RELATIVE:-<unresolved path derived from ~/.agents/skills/understand-dashboard>}"
     echo "  - ${COPILOT_SELF_RELATIVE:-<unresolved path derived from ~/.copilot/skills/understand-dashboard>}"
     echo "  - $HOME/.codex/understand-anything/understand-anything-plugin"
     echo "  - $HOME/.opencode/understand-anything/understand-anything-plugin"
     echo "  - $HOME/.pi/understand-anything/understand-anything-plugin"
     echo "  - $HOME/understand-anything/understand-anything-plugin"
     echo "Make sure you followed the installation instructions for your platform."
     exit 1
   fi
   ```

4. Instale dependências e faça o build se necessário:
   ```bash
   cd <dashboard-dir> && pnpm install --frozen-lockfile 2>/dev/null || pnpm install
   ```
   Em seguida, garanta que o pacote core esteja construído (o dashboard depende dele):
   ```bash
   cd <plugin-root> && pnpm --filter @understand-anything/core build
   ```

5. Inicie o servidor de dev do Vite apontando para o knowledge graph do projeto:
   ```bash
   cd <dashboard-dir> && GRAPH_DIR=<project-dir> npx vite --host 127.0.0.1
   ```
   Execute em background para que o usuário possa continuar trabalhando.

6. **Capture a URL com token de acesso da saída do servidor.** O servidor Vite imprime uma linha como:
   ```
   🔑  Dashboard URL: http://127.0.0.1:<PORT>?token=<TOKEN>
   ```
   Extraia a URL completa, incluindo o parâmetro `?token=`. O token é obrigatório para acessar os dados do knowledge graph — sem ele, o dashboard mostrará um portal "Access Token Required".

7. Reporte ao usuário, incluindo a URL completa com token:
   ```
   Dashboard started at http://127.0.0.1:<PORT>?token=<TOKEN>
   Viewing: <project-dir>/.understand-anything/knowledge-graph.json

   The dashboard is running in the background. Press Ctrl+C in the terminal to stop it.
   ```
   **Importante:** Sempre inclua o parâmetro `?token=` na URL que você compartilha. Se você omitir, o usuário será bloqueado pelo gate do token e terá que encontrar manualmente o token na saída do terminal.

## Notas

- O dashboard abre automaticamente no navegador padrão via `--open`
- Se a porta 5173 já estiver em uso, o Vite escolhe a próxima porta disponível
- A variável de ambiente `GRAPH_DIR` indica ao dashboard onde encontrar o knowledge graph
