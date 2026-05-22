# Design do Sistema de Temas

## Visão Geral

Adicionar um sistema curado de presets de tema com customização de cor de destaque ao dashboard. Os usuários selecionam entre 5 presets de tema desenhados à mão e opcionalmente trocam a accent color dentro de cada preset por um conjunto de 8-10 swatches testados.

### Objetivos
- Suportar 5 presets de tema: Dark Gold (atual), Dark Ocean, Dark Forest, Dark Rose, Light Minimal
- Permitir customização de accent color dentro de cada preset (apenas swatches curados, sem free picker)
- Persistir a preferência de tema tanto em `localStorage` (pessoal) quanto em `meta.json` (nível de projeto)
- Manter coerência visual — sem combinações de cores que o usuário possa quebrar
- Troca de tema sem reload via injeção de variáveis CSS em runtime

### Não-Objetivos
- Free color picker (risco de combos feios/ilegíveis)
- Overrides de cor por componente
- Múltiplos temas simultâneos

---

## 1. Presets de Tema e Sistema de Cores

### 1.1 Definições dos Presets

Cada preset é um mapeamento completo de nomes de variáveis CSS para valores. Os 5 presets:

| Token | Dark Gold | Dark Ocean | Dark Forest | Dark Rose | Light Minimal |
|-------|-----------|------------|-------------|-----------|---------------|
| `--color-root` | `#0a0a0a` | `#0a0e14` | `#0a100a` | `#100a0a` | `#f5f3f0` |
| `--color-surface` | `#111111` | `#111820` | `#111811` | `#181111` | `#eae7e3` |
| `--color-elevated` | `#1a1a1a` | `#1a222c` | `#1a241a` | `#221a1a` | `#ffffff` |
| `--color-panel` | `#141414` | `#141c24` | `#141c14` | `#1c1414` | `#f0ede9` |
| `--color-gold`* | `#d4a574` | `#5ba4cf` | `#5ea67a` | `#cf7a8a` | `#4a6fa5` |
| `--color-gold-dim`* | `#c9a96e` | `#4e93ba` | `#4e9468` | `#b96e7e` | `#3d5f8f` |
| `--color-gold-bright`* | `#e8c49a` | `#7abce0` | `#78c492` | `#e094a4` | `#6088bf` |
| `--color-text-primary` | `#f5f0eb` | `#e8edf2` | `#ebf0eb` | `#f2e8ea` | `#1a1a1a` |
| `--color-text-secondary` | `#a39787` | `#87939f` | `#87a38f` | `#9f8790` | `#6b6b6b` |
| `--color-text-muted` | `#6b5f53` | `#536b7a` | `#536b5a` | `#6b535a` | `#a0a0a0` |
| `--color-border-subtle` | `rgba(212,165,116,0.12)` | `rgba(91,164,207,0.12)` | `rgba(94,166,122,0.12)` | `rgba(207,122,138,0.12)` | `rgba(74,111,165,0.10)` |
| `--color-border-medium` | `rgba(212,165,116,0.25)` | `rgba(91,164,207,0.25)` | `rgba(94,166,122,0.25)` | `rgba(207,122,138,0.25)` | `rgba(74,111,165,0.18)` |

*\* Os nomes das variáveis CSS continuam como `--color-gold`, `--color-gold-dim`, `--color-gold-bright` mesmo para temas não-dourados. Eles representam "a accent color" de forma genérica. Renomeá-los para `--color-accent` é um refactor que podemos fazer, mas não é obrigatório — o nome da variável é um detalhe de implementação invisível para os usuários.*

**Decisão: Renomear `--color-gold*` para `--color-accent*`** para evitar confusão. Isto é um find-and-replace pelo codebase sem mudança comportamental.

### 1.2 Glass Effects

Os glass effects derivam das cores base e precisam de valores por preset:

| Token | Temas dark | Light Minimal |
|-------|-------------|---------------|
| `--glass-bg` | `rgba(20,20,20,0.8)` | `rgba(255,255,255,0.8)` |
| `--glass-bg-heavy` | `rgba(20,20,20,0.95)` | `rgba(255,255,255,0.95)` |
| `--glass-border` | `rgba(accent,0.1)` | `rgba(accent,0.08)` |
| `--glass-border-heavy` | `rgba(accent,0.15)` | `rgba(accent,0.12)` |

As classes CSS `.glass` e `.glass-heavy` referenciarão essas variáveis em vez de valores hardcoded.

### 1.3 Cores de Scrollbar e Glow

Estas também derivam da accent color e precisam virar variáveis CSS:

| Token | Propósito |
|-------|---------|
| `--scrollbar-thumb` | `rgba(accent, 0.2)` |
| `--scrollbar-thumb-hover` | `rgba(accent, 0.35)` |
| `--glow-color` | `rgba(accent, 0.4)` para glow de seleção de nó |
| `--glow-pulse` | `rgba(accent, 0.6)` para o pulse de destaque do tour |

### 1.4 Cores de Tipo de Nó e Diff

Estas são **semânticas** e permanecem fixas em todos os temas dark:

| Variável | Valor | Propósito |
|----------|-------|---------|
| `--color-node-file` | `#4a7c9b` | Nós File |
| `--color-node-function` | `#5a9e6f` | Nós Function |
| `--color-node-class` | `#8b6fb0` | Nós Class |
| `--color-node-module` | `#c9a06c` | Nós Module |
| `--color-node-concept` | `#b07a8a` | Nós Concept |
| `--color-diff-changed` | `#e05252` | Nós alterados |
| `--color-diff-affected` | `#d4a030` | Nós afetados |

Apenas para o **Light Minimal**, estes são levemente desaturados/escurecidos para manter a legibilidade em fundos claros:

| Variável | Valor Light Minimal |
|----------|-------------------|
| `--color-node-file` | `#3a6a87` |
| `--color-node-function` | `#488a5b` |
| `--color-node-class` | `#755d99` |
| `--color-node-module` | `#a88a56` |
| `--color-node-concept` | `#966674` |

### 1.5 Accent Swatches

Cada preset oferece 8 opções de accent color. A primeira é o "native" default daquele preset. Cada swatch fornece 3 valores (accent, accent-dim, accent-bright) mais opacidades de borda e glass derivadas automaticamente.

**Accent swatches dos temas dark** (compartilhadas entre os 4 presets dark):

| Nome | Accent | Dim | Bright |
|------|--------|-----|--------|
| Gold | `#d4a574` | `#c9a96e` | `#e8c49a` |
| Ocean | `#5ba4cf` | `#4e93ba` | `#7abce0` |
| Emerald | `#5ea67a` | `#4e9468` | `#78c492` |
| Rose | `#cf7a8a` | `#b96e7e` | `#e094a4` |
| Purple | `#9b7abf` | `#876bb0` | `#b494d4` |
| Amber | `#c9963a` | `#b5862e` | `#ddb05c` |
| Teal | `#4aab9a` | `#3d9686` | `#68c4b4` |
| Silver | `#a0a8b0` | `#8e959c` | `#b8bfc6` |

**Accent swatches do Light Minimal:**

| Nome | Accent | Dim | Bright |
|------|--------|-----|--------|
| Indigo | `#4a6fa5` | `#3d5f8f` | `#6088bf` |
| Ocean | `#3a8ab5` | `#2e7aa0` | `#55a0cc` |
| Emerald | `#3a8a5c` | `#2e7a4e` | `#55a878` |
| Rose | `#a5566a` | `#8f4a5c` | `#bf6e82` |
| Purple | `#6b5a9e` | `#5c4d8a` | `#8474b5` |
| Amber | `#9e7a30` | `#8a6a28` | `#b5923e` |
| Teal | `#2e8a7a` | `#267a6c` | `#45a595` |
| Slate | `#5a6570` | `#4e5860` | `#6e7a85` |

### 1.6 Derivação de Borda e Glass

Quando uma accent swatch é selecionada, as bordas e glass effects são auto-derivados:

```typescript
function deriveFromAccent(accentHex: string, isDark: boolean) {
  return {
    borderSubtle: `rgba(${hexToRgb(accentHex)}, ${isDark ? 0.12 : 0.10})`,
    borderMedium: `rgba(${hexToRgb(accentHex)}, ${isDark ? 0.25 : 0.18})`,
    glassBorder: `rgba(${hexToRgb(accentHex)}, ${isDark ? 0.1 : 0.08})`,
    glassBorderHeavy: `rgba(${hexToRgb(accentHex)}, ${isDark ? 0.15 : 0.12})`,
    scrollbarThumb: `rgba(${hexToRgb(accentHex)}, 0.2)`,
    scrollbarThumbHover: `rgba(${hexToRgb(accentHex)}, 0.35)`,
    glowColor: `rgba(${hexToRgb(accentHex)}, 0.4)`,
    glowPulse: `rgba(${hexToRgb(accentHex)}, 0.6)`,
  };
}
```

---

## 2. Arquitetura e Fluxo de Dados

### 2.1 Estrutura de Arquivos

```
packages/dashboard/src/
  themes/
    types.ts          # ThemePreset, AccentSwatch, ThemeConfig types
    presets.ts         # 5 preset definitions + accent swatch arrays
    theme-engine.ts   # applyTheme(), deriveFromAccent(), hexToRgb()
    ThemeContext.tsx    # React context + provider + useTheme() hook
  components/
    ThemePicker.tsx    # Popover UI for preset + accent selection
```

### 2.2 Definições de Tipos

```typescript
// themes/types.ts

export type PresetId = 'dark-gold' | 'dark-ocean' | 'dark-forest' | 'dark-rose' | 'light-minimal';

export interface ThemePreset {
  id: PresetId;
  name: string;           // Display name: "Dark Gold"
  isDark: boolean;         // true for dark themes, false for light
  colors: Record<string, string>;  // CSS variable name -> value (without --)
  accentSwatches: AccentSwatch[];
  defaultAccentId: string; // Which swatch is the native default
}

export interface AccentSwatch {
  id: string;              // e.g. 'gold', 'ocean'
  name: string;            // Display name: "Gold"
  accent: string;          // Primary accent hex
  accentDim: string;       // Dimmed accent hex
  accentBright: string;    // Bright accent hex
}

export interface ThemeConfig {
  presetId: PresetId;
  accentId: string;        // Selected accent swatch ID
}
```

### 2.3 Theme Engine

O theme engine é uma camada de funções puras (sem dependência do React):

```typescript
// themes/theme-engine.ts

export function applyTheme(config: ThemeConfig): void {
  const preset = getPreset(config.presetId);
  const accent = getAccent(preset, config.accentId);

  // 1. Apply base preset colors
  for (const [key, value] of Object.entries(preset.colors)) {
    document.documentElement.style.setProperty(`--color-${key}`, value);
  }

  // 2. Override accent colors from swatch
  document.documentElement.style.setProperty('--color-accent', accent.accent);
  document.documentElement.style.setProperty('--color-accent-dim', accent.accentDim);
  document.documentElement.style.setProperty('--color-accent-bright', accent.accentBright);

  // 3. Apply derived values (borders, glass, scrollbar, glow)
  const derived = deriveFromAccent(accent.accent, preset.isDark);
  for (const [key, value] of Object.entries(derived)) {
    document.documentElement.style.setProperty(`--${key}`, value);
  }

  // 4. Set data-theme attribute for any CSS-only selectors needed
  document.documentElement.setAttribute('data-theme', preset.isDark ? 'dark' : 'light');
}
```

### 2.4 React Context

```typescript
// themes/ThemeContext.tsx

interface ThemeContextValue {
  config: ThemeConfig;
  preset: ThemePreset;
  setPreset: (presetId: PresetId) => void;
  setAccent: (accentId: string) => void;
}
```

O provider:
1. No mount: resolve o tema a partir de `localStorage` > campo `meta.json` no grafo carregado > default (`dark-gold`)
2. Chama `applyTheme()` em toda mudança de config
3. Persiste em `localStorage` em toda mudança
4. NÃO escreve em `meta.json` a partir do dashboard (o dashboard é read-only para meta.json; o meta.json é escrito pelo lado CLI/plugin)

### 2.5 Integração com a Zustand Store

O sistema de temas é **separado da Zustand store** — usa seu próprio React context. Razões:
- O estado do tema é ortogonal ao estado de grafo/UI
- O tema precisa ser aplicado antes mesmo do grafo carregar (evita flash do tema errado)
- Mantém a store focada na interação com o grafo

A store NÃO ganha nenhum campo relacionado a tema.

---

## 3. Componentes de UI

### 3.1 Botão Theme Picker (Header)

Um pequeno botão com ícone de paleta na barra de cabeçalho do topo, posicionado após os controles existentes (PersonaSelector, DiffToggle, etc.).

- O clique abre um painel popover/dropdown
- O popover tem duas seções:
  - **Presets**: 5 cards/botões mostrando o nome do preset + pequenos círculos de preview de cor
  - **Accent Colors**: linha de 8 círculos coloridos para o preset ativo
- O preset e accent ativos são destacados com um anel/check
- Selecionar um preset o aplica instantaneamente; selecionar um accent o aplica instantaneamente
- Clicar fora ou pressionar Escape fecha o popover

### 3.2 Preview do Preset

Cada card de preset mostra:
- Nome (ex: "Dark Gold")
- 3-4 pequenos círculos mostrando cores root, surface e accent como preview visual
- Marca de check ou anel no ativo

### 3.3 Linha de Accent Swatches

- 8 pequenos círculos preenchidos em uma linha horizontal
- Tooltip ou label no hover mostrando o nome do accent
- O ativo tem um indicador de anel/borda

### 3.4 Transições

Ao trocar temas:
- As variáveis CSS atualizam instantaneamente (sem necessidade de transição para a maioria das propriedades)
- Opcionalmente adicionar um `transition: background-color 0.2s, color 0.2s` sutil em `html` para uma sensação suave
- Sem necessidade de reload da página

---

## 4. Persistência e Resolução

### 4.1 Locais de Armazenamento

| Localização | Formato | Escrito por | Lido por |
|----------|--------|-----------|---------|
| Chave do `localStorage`: `ua-theme` | `JSON.stringify(ThemeConfig)` | Dashboard (em toda mudança) | Dashboard (no mount) |
| `.understand-anything/meta.json` | `{ ..., theme?: ThemeConfig }` | CLI/plugin (durante a análise ou set explícito) | Dashboard (no mount, como fallback) |

### 4.2 Ordem de Resolução

```
1. localStorage('ua-theme')     → user's personal preference (wins)
2. meta.json.theme              → project-level default (fallback)
3. { presetId: 'dark-gold', accentId: 'gold' }  → hard default
```

### 4.3 Extensão do Schema do meta.json

Estender `AnalysisMeta` em `packages/core/src/types.ts`:

```typescript
export interface AnalysisMeta {
  lastAnalyzedAt: string;
  gitCommitHash: string;
  version: string;
  analyzedFiles: number;
  theme?: ThemeConfig;      // NEW — optional, project-level theme preference
}
```

### 4.4 Dashboard Lê o Tema do meta.json

O dashboard atualmente carrega `/knowledge-graph.json` no mount. Ele também precisa carregar `/meta.json` (ou o campo theme pode ser embutido em `knowledge-graph.json`).

**Decisão:** Carregar `/meta.json` separadamente — é um arquivo pequeno e mantém as responsabilidades separadas. O dashboard busca `/meta.json` no mount, extrai o campo `theme` se presente e o usa como fallback quando o `localStorage` não tem tema.

---

## 5. Consolidação de Cores Hardcoded

### 5.1 Problema

Muitos componentes usam valores RGBA hardcoded em vez de variáveis CSS:
- `rgba(212,165,116,0.3)` espalhado em GraphView, CustomNode, etc.
- `rgba(20,20,20,0.8)` em glass effects
- `rgba(224,82,82,0.25)` em diff overlays

Estes não responderão a mudanças de tema.

### 5.2 Solução

Antes de implementar a troca de tema, consolidar todas as referências de cor hardcoded:

1. **Auditoria**: grep por valores hex/rgba hardcoded em arquivos de componentes
2. **Substituir por variáveis CSS**: criar novas variáveis onde necessário (ex: `--edge-color`, `--edge-color-dim`)
3. **Glass classes**: atualizar `.glass` e `.glass-heavy` em `index.css` para usar variáveis
4. **Scrollbar**: atualizar estilos de scrollbar para usar variáveis
5. **Glow effects**: atualizar `.node-glow`, `.diff-changed-glow`, `.diff-affected-glow` para usar variáveis

Padrões hardcoded principais a consolidar:

| Valor Hardcoded | Substituir Por |
|-----------------|-------------|
| `rgba(212,165,116,X)` | `var(--color-accent)` com modificador de opacidade ou variável dedicada |
| `rgba(20,20,20,0.8)` | `var(--glass-bg)` |
| `rgba(20,20,20,0.95)` | `var(--glass-bg-heavy)` |
| `color="rgba(212,165,116,0.15)"` no React Flow | Referência por variável |
| Cores Amber em WarningBanner | Manter como está (cor semântica de warning, independente de tema) |

### 5.3 Renomeação de Variáveis CSS

Renomear pelo codebase:
- `--color-gold` -> `--color-accent`
- `--color-gold-dim` -> `--color-accent-dim`
- `--color-gold-bright` -> `--color-accent-bright`
- Todos os usos de classe Tailwind: `text-gold` -> `text-accent`, `bg-gold` -> `bg-accent`, etc.

---

## 6. Considerações para o Light Theme

O Light Minimal exige atenção especial:

### 6.1 Contraste Invertido

- Texto é escuro em fundos claros (invertido em relação aos temas dark)
- Bordas precisam de opacidade menor para não parecerem agressivas
- Glass effects usam rgba baseado em branco em vez de baseado em preto

### 6.2 Cores de Nó

Variantes ligeiramente mais escuras/desaturadas para legibilidade em fundos claros (veja a Seção 1.4).

### 6.3 Atributo data-theme

Definir `data-theme="light"` no `<html>` para qualquer estilo que não possa ser tratado puramente via variáveis CSS (ex: overrides de componentes de terceiros, direções de box-shadow).

### 6.4 React Flow

O background, minimap e edge colors do React Flow precisam respeitar o tema. O override `!important` existente em `.react-flow__background` já usa `var(--color-root)`, o que é bom. As cores do MiniMap em GraphView.tsx estão atualmente hardcoded e precisam ser atualizadas.

---

## 7. Resumo das Mudanças por Pacote

### packages/core
- Estender o tipo `AnalysisMeta` com `theme?: ThemeConfig` opcional
- Exportar os tipos `ThemeConfig` e `PresetId` do subpath `./types`

### packages/dashboard
- Novo diretório `themes/` com types, presets, engine e context
- Novo componente `ThemePicker` no header
- Renomear `--color-gold*` para `--color-accent*` em todos os arquivos
- Consolidar valores RGBA hardcoded em variáveis CSS
- Atualizar `index.css`: classes glass, scrollbar, glow effects para usarem variáveis
- Atualizar `App.tsx`: envolver com ThemeProvider, adicionar ThemePicker ao header, buscar meta.json
- Atualizar componentes com cores hardcoded: GraphView, CustomNode, LayerLegend, etc.

---

## 8. Fora do Escopo

- Importação/exportação de tema
- UI de criação de tema customizado
- Customização de cor por nó
- Transições animadas de tema além de transições CSS simples
- Sincronizar o tema entre abas do navegador (nice-to-have para depois)
