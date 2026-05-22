# Design: Robustez do Dashboard — Carregamento Permissivo do Graph

## Problema

Quando o agent LLM produz um knowledge-graph.json que diverge do schema Zod estrito, o dashboard mostra uma tela em branco com paths de erro do Zod crípticos. Os usuários não sabem se é um bug do sistema ou um problema de geração do agent, e a única alternativa é uma re-execução completa do `/understand`.

## Objetivos

1. **Maximizar o que o usuário consegue ver** — carregar nodes/edges válidos mesmo se alguns estiverem quebrados
2. **Comunicar com clareza problemas de geração** — warnings âmbar (não erros vermelhos) com mensagens copy-paste-friendly
3. **Empoderar correções pontuais** — usuários podem copiar o relatório de issues e pedir ao agent para corrigir problemas específicos em vez de uma re-execução completa

## Design

### Pipeline de Robustez em Três Layers

```
Raw JSON → Sanitize (Tier 1) → Normalize + Auto-fix (Tier 2) → Validate per-item (Tier 3) → Fatal check (Tier 4) → Dashboard
```

### Tier 1: Sanitizar Silenciosamente

Esquisitices comuns do LLM que são puro ruído — corrigir sem reportar.

| Issue | Correção |
|-------|-----|
| `null` em campos opcionais (`filePath`, `lineRange`, `description`, `languageNotes`) | Converter para `undefined` |
| Strings de enum com case misturado (`"Forward"`, `"SIMPLE"`) | Lowercase antes de comparar |

### Tier 2: Auto-fix Com Aviso Informativo

Problemas recuperáveis — aplicar defaults sensatos, registrar como issues `auto-corrected`.

| Issue | Default | Notas |
|-------|---------|-------|
| `complexity` ausente | `"moderate"` | Omissão mais comum do LLM |
| `tags` ausentes | `[]` | Vazio é válido |
| `weight` ausente | `0.5` | Meio do range 0–1 |
| `weight` como string | Coerce para número | ex.: `"0.8"` → `0.8` |
| `direction` ausente | `"forward"` | Default seguro |
| `summary` ausente | Usar `name` do node | Melhor que vazio |
| `tour: null` / `layers: null` | `[]` | Null vs array vazio |
| Aliases de complexity | `low/easy→simple`, `medium/intermediate→moderate`, `high/hard→complex` | |
| Aliases de direction | `to/outbound→forward`, `from/inbound→backward`, `both→bidirectional` | |
| Aliases existentes de tipo de node/edge | Já tratados por `normalizeGraph` | Sem mudança necessária |
| `type` de node ausente | `"file"` | Fallback seguro |
| `type` de edge ausente | `"depends_on"` | Fallback genérico |

### Tier 3: Descartar Com Warning

Não dá para adivinhar com segurança — remover o item, registrar como issue `dropped`.

| Issue | Ação |
|-------|--------|
| Edge referencia ID de node inexistente | Descartar edge |
| Node sem `id` | Descartar node |
| Node sem `name` | Descartar node |
| Edge sem `source` ou `target` | Descartar edge |
| Valor de `type` irreconhecível (não está nem na lista canônica nem na de aliases) | Descartar item |
| `weight` não coercível para número | Descartar edge |

### Tier 4: Fatal

Graph é insalvável — mostrar banner vermelho de erro.

| Condição | Mensagem |
|-----------|---------|
| 0 nodes válidos após filtragem | "No valid nodes found in knowledge graph" |
| Falta `project` metadata por completo | "Missing project metadata" |
| Input não é objeto / não é JSON válido | "Invalid input format" |

### Tipo de Retorno

```typescript
interface GraphIssue {
  level: 'auto-corrected' | 'dropped' | 'fatal';
  category: string;      // e.g., "missing-field", "invalid-reference", "type-coercion"
  message: string;       // human-readable, copy-paste friendly
  path?: string;         // e.g., "nodes[3].complexity"
}

interface ValidationResult {
  success: boolean;
  data?: KnowledgeGraph;
  issues: GraphIssue[];
  fatal?: string;
}
```

### UI do Dashboard: Componente WarningBanner

**Novo componente** em `packages/dashboard/src/components/WarningBanner.tsx`.

**Design visual:**
- **Tema âmbar/dourado** — `bg-amber-900/20`, `border-amber-700`, `text-amber-200`
- Combina com a estética de accent dourado do dashboard; sinaliza "problema de qualidade de geração", não "crash do sistema"
- **Collapsed por padrão** — linha de resumo: "Knowledge graph loaded with 5 auto-corrections and 2 dropped items"
- **Expansível** — clique para revelar lista de issues categorizada
- **Botão de copiar** — copia em um clique o relatório de issues completo como mensagem pré-formatada
- **Footer acionável** — diz aos usuários para copiarem as issues e pedirem ao agent para corrigi-las

**Formato de saída para copy-paste:**
```
The following issues were found in your knowledge-graph.json.
These are LLM generation errors — not a system bug.
You can ask your agent to fix these specific issues in the knowledge-graph.json file:

[Auto-corrected] nodes[3] ("AuthService"): missing "complexity" — defaulted to "moderate"
[Auto-corrected] nodes[7] ("utils.ts"): missing "tags" — defaulted to []
[Auto-corrected] edges[12]: weight was string "0.8" — coerced to number
[Dropped] edges[5]: target "file:src/nonexistent.ts" does not exist in nodes
[Dropped] nodes[14]: missing required "id" field — cannot recover
```

**Erros fatais** permanecem em vermelho (`bg-red-900/30`) com a mensagem: "Knowledge graph is unsalvageable: [reason]. Please re-run `/understand` to generate a new one."

**O banner vermelho de erro existente** para erros de rede/JSON-parse permanece como está (esses SÃO problemas de sistema/infra).

### Mudanças no App.tsx

- Em `result.success === true` com `result.issues.length > 0`: mostrar `WarningBanner` com as issues, carregar o graph normalmente
- Em `result.fatal`: mostrar o banner vermelho existente com a mensagem fatal
- `console.warn` para itens auto-corrected, `console.error` para itens dropped

### Cobertura de Testes

Tudo em `packages/core/src/__tests__/schema.test.ts`:

- **Tier 1:** campos opcionais `null` viram silenciosamente `undefined`
- **Tier 2:** `complexity`/`tags`/`weight`/`direction`/`summary` ausentes recebem defaults; issues registradas
- **Tier 2:** `weight` em string sofre coerce; aliases de complexity/direction mapeados
- **Tier 3:** referências de edge penduradas são descartadas; nodes sem `id` descartados; issues registradas
- **Tier 4:** graph vazio após filtragem → fatal; `project` ausente → fatal
- **Integração:** graph com nodes mistos (bons/ruins) → carrega com a contagem correta de nodes + lista de issues correta

### Arquivos Modificados

| Arquivo | Mudança |
|------|--------|
| `packages/core/src/schema.ts` | Sanitize, normalize expandido, validate permissivo, novos tipos |
| `packages/dashboard/src/components/WarningBanner.tsx` | Novo componente |
| `packages/dashboard/src/App.tsx` | Conectar issues ao WarningBanner |
| `packages/core/src/__tests__/schema.test.ts` | Testes para todos os tiers |

### Arquivos NÃO Modificados

- Prompts dos agents (podem ser apertados depois como esforço separado)
- Lógica do GraphView / store (eles já lidam com objetos `KnowledgeGraph` válidos)
- Mapas de alias de tipo de node/edge existentes (preservados, estendidos ao redor)
