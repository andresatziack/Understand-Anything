# Plano de Implementação do Sistema de Temas

> **Para o Claude:** SUB-SKILL OBRIGATÓRIA: Use superpowers:executing-plans para implementar este plano tarefa por tarefa.

**Objetivo:** Adicionar presets de tema curados com customização de accent ao dashboard.

**Arquitetura:** Injeção de variáveis CSS em runtime via uma engine de tema pura, contexto React para state, localStorage + meta.json para persistência. Cinco presets (4 dark + 1 light) com 8 swatches de accent cada.

**Stack Tecnológica:** React, TypeScript, TailwindCSS v4, Zustand (intocado), CSS custom properties.

**Spec de Design:** `docs/plans/2026-03-26-theme-system-design.md`

---

### Tarefa 1: Renomear `gold` para `accent` em variáveis CSS e classes Tailwind

Este é um find-and-replace mecânico sem mudança comportamental. Tem que ser feito primeiro para que todas as tarefas seguintes usem a nova nomeação.

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/index.css`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/CustomNode.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/NodeInfo.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/LearnPanel.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/ProjectOverview.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/SearchBar.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/LayerLegend.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/PersonaSelector.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/CodeViewer.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/App.tsx`

**Step 1: Renomear variáveis CSS no index.css**

No bloco `@theme`, renomeie:
- `--color-gold` -> `--color-accent`
- `--color-gold-dim` -> `--color-accent-dim`
- `--color-gold-bright` -> `--color-accent-bright`

Renomeie também o `@keyframes goldPulse` para `accentPulse` e `.animate-gold-pulse` para `.animate-accent-pulse`.

**Step 2: Renomear todas as referências a classes Tailwind nos componentes**

Faça find-and-replace em todos os arquivos de componente:
- `text-gold-bright` -> `text-accent-bright`
- `text-gold-dim` -> `text-accent-dim`
- `text-gold` -> `text-accent`
- `bg-gold` -> `bg-accent`
- `border-gold` -> `border-accent`
- `ring-gold-dim` -> `ring-accent-dim`
- `ring-gold-bright` -> `ring-accent-bright`
- `ring-gold` -> `ring-accent`
- `animate-gold-pulse` -> `animate-accent-pulse`

A ordem importa — substitua primeiro as variantes `-bright` e `-dim` mais longas para evitar matches parciais.

Substitua também qualquer `var(--color-gold` por `var(--color-accent` em estilos inline.

**Step 3: Verificar que o build compila**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido sem erros.

**Step 4: Verificar visualmente (opcional)**

Execute: `cd understand-anything-plugin && pnpm dev:dashboard`
Esperado: Dashboard tem aparência idêntica — mesmo accent gold, sem mudanças visuais.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(dashboard): rename gold CSS variables to accent"
```

---

### Tarefa 2: Consolidar valores RGBA hardcoded em variáveis CSS

Substitua valores de cor hardcoded espalhados pelos componentes por variáveis CSS para que respondam a mudanças de tema.

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/index.css`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/GraphView.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/CustomNode.tsx`
- Modificar: `understand-anything-plugin/packages/dashboard/src/components/CodeViewer.tsx`

**Step 1: Adicionar novas variáveis CSS ao bloco @theme do index.css**

Adicione estas novas variáveis após as variáveis de border existentes:

```css
/* Glass */
--glass-bg: rgba(20, 20, 20, 0.8);
--glass-bg-heavy: rgba(20, 20, 20, 0.95);
--glass-border: rgba(212, 165, 116, 0.1);
--glass-border-heavy: rgba(212, 165, 116, 0.15);

/* Scrollbar */
--scrollbar-thumb: rgba(212, 165, 116, 0.2);
--scrollbar-thumb-hover: rgba(212, 165, 116, 0.35);

/* Glow */
--glow-accent: rgba(212, 165, 116, 0.15);
--glow-accent-strong: rgba(212, 165, 116, 0.4);
--glow-accent-pulse: rgba(212, 165, 116, 0.6);

/* Edges */
--color-edge: rgba(212, 165, 116, 0.3);
--color-edge-dim: rgba(212, 165, 116, 0.08);
--color-edge-dot: rgba(212, 165, 116, 0.15);

/* Layer group (accent-based overlays) */
--color-accent-overlay-bg: rgba(212, 165, 116, 0.05);
--color-accent-overlay-border: rgba(212, 165, 116, 0.25);

/* kbd */
--kbd-bg: rgba(212, 165, 116, 0.1);
```

**Step 2: Atualizar classes .glass, .glass-heavy no index.css**

Substitua valores hardcoded pelas novas variáveis:

```css
.glass {
  background: var(--glass-bg);
  border: 1px solid var(--glass-border);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.glass-heavy {
  background: var(--glass-bg-heavy);
  border: 1px solid var(--glass-border-heavy);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
```

**Step 3: Atualizar estilos de scrollbar no index.css**

```css
::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--scrollbar-thumb-hover);
}
```

**Step 4: Atualizar classes de glow no index.css**

```css
.node-glow {
  box-shadow: 0 0 20px var(--glow-accent);
}
```

Atualize `@keyframes accentPulse` (renomeado na Tarefa 1):
```css
@keyframes accentPulse {
  0%, 100% {
    box-shadow: 0 0 8px var(--glow-accent-strong);
  }
  50% {
    box-shadow: 0 0 20px var(--glow-accent-pulse);
  }
}
```

**Step 5: Atualizar classe .kbd no index.css**

```css
.kbd {
  /* ... keep existing sizing/layout ... */
  color: var(--color-accent);
  background: var(--kbd-bg);
}
```

**Step 6: Atualizar cores hardcoded em GraphView.tsx**

Substitua estes valores de estilo inline:

| Local | Valor antigo | Valor novo |
|----------|-----------|-----------|
| Edge default style stroke | `"rgba(212,165,116,0.3)"` | `"var(--color-edge)"` |
| Edge diff-faded stroke | `"rgba(212,165,116,0.08)"` | `"var(--color-edge-dim)"` |
| Background dots color prop | `"rgba(212,165,116,0.15)"` | `"var(--color-edge-dot)"` |
| MiniMap nodeColor | `"#1a1a1a"` | `"var(--color-elevated)"` |
| MiniMap maskColor | `"rgba(10,10,10,0.7)"` | `"var(--glass-bg)"` |
| Group node backgroundColor | `"rgba(212,165,116,0.05)"` | `"var(--color-accent-overlay-bg)"` |
| Group node border | `"2px dashed rgba(212,165,116,0.25)"` | `"2px dashed var(--color-accent-overlay-border)"` |
| Group node label color | `"#d4a574"` | `"var(--color-accent)"` |
| Edge label fill (normal) | `"#a39787"` | `"var(--color-text-secondary)"` |
| Edge label fill (diff faded) | `"rgba(163,151,135,0.3)"` | `"var(--color-text-muted)"` |
| Classe de border do spinner | `border-gold` já renomeado para `border-accent` | Já feito na Tarefa 1 |

**Step 7: Atualizar cores hardcoded em CodeViewer.tsx**

Substitua estilos inline para o badge do tipo de arquivo:
- `color: "var(--color-node-file)"` — já usa variável CSS, manter
- `borderColor: "rgba(74,124,155,0.3)"` -> `"color-mix(in srgb, var(--color-node-file) 30%, transparent)"`
- `backgroundColor: "rgba(74,124,155,0.1)"` -> `"color-mix(in srgb, var(--color-node-file) 10%, transparent)"`

**Step 8: Atualizar shadow hardcoded em CustomNode.tsx**

Substitua `shadow-[0_2px_8px_rgba(0,0,0,0.3)]` — esta shadow preta funciona bem para temas dark mas mantenha. Deixe como está, já que funciona tanto em dark quanto em light.

**Step 9: Verificar build**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido.

**Step 10: Commit**

```bash
git add -A
git commit -m "refactor(dashboard): consolidate hardcoded colors into CSS variables"
```

---

### Tarefa 3: Criar definições de tipos do tema

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/themes/types.ts`

**Step 1: Escrever o arquivo de tipos**

```typescript
export type PresetId =
  | "dark-gold"
  | "dark-ocean"
  | "dark-forest"
  | "dark-rose"
  | "light-minimal";

export interface AccentSwatch {
  id: string;
  name: string;
  accent: string;
  accentDim: string;
  accentBright: string;
}

export interface ThemePreset {
  id: PresetId;
  name: string;
  isDark: boolean;
  colors: Record<string, string>;
  accentSwatches: AccentSwatch[];
  defaultAccentId: string;
}

export interface ThemeConfig {
  presetId: PresetId;
  accentId: string;
}

export const DEFAULT_THEME_CONFIG: ThemeConfig = {
  presetId: "dark-gold",
  accentId: "gold",
};
```

**Step 2: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add theme type definitions"
```

---

### Tarefa 4: Criar presets de tema

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/themes/presets.ts`

**Step 1: Escrever o arquivo de presets**

```typescript
import type { AccentSwatch, ThemePreset } from "./types.ts";

const DARK_ACCENT_SWATCHES: AccentSwatch[] = [
  { id: "gold", name: "Gold", accent: "#d4a574", accentDim: "#c9a96e", accentBright: "#e8c49a" },
  { id: "ocean", name: "Ocean", accent: "#5ba4cf", accentDim: "#4e93ba", accentBright: "#7abce0" },
  { id: "emerald", name: "Emerald", accent: "#5ea67a", accentDim: "#4e9468", accentBright: "#78c492" },
  { id: "rose", name: "Rose", accent: "#cf7a8a", accentDim: "#b96e7e", accentBright: "#e094a4" },
  { id: "purple", name: "Purple", accent: "#9b7abf", accentDim: "#876bb0", accentBright: "#b494d4" },
  { id: "amber", name: "Amber", accent: "#c9963a", accentDim: "#b5862e", accentBright: "#ddb05c" },
  { id: "teal", name: "Teal", accent: "#4aab9a", accentDim: "#3d9686", accentBright: "#68c4b4" },
  { id: "silver", name: "Silver", accent: "#a0a8b0", accentDim: "#8e959c", accentBright: "#b8bfc6" },
];

const LIGHT_ACCENT_SWATCHES: AccentSwatch[] = [
  { id: "indigo", name: "Indigo", accent: "#4a6fa5", accentDim: "#3d5f8f", accentBright: "#6088bf" },
  { id: "ocean", name: "Ocean", accent: "#3a8ab5", accentDim: "#2e7aa0", accentBright: "#55a0cc" },
  { id: "emerald", name: "Emerald", accent: "#3a8a5c", accentDim: "#2e7a4e", accentBright: "#55a878" },
  { id: "rose", name: "Rose", accent: "#a5566a", accentDim: "#8f4a5c", accentBright: "#bf6e82" },
  { id: "purple", name: "Purple", accent: "#6b5a9e", accentDim: "#5c4d8a", accentBright: "#8474b5" },
  { id: "amber", name: "Amber", accent: "#9e7a30", accentDim: "#8a6a28", accentBright: "#b5923e" },
  { id: "teal", name: "Teal", accent: "#2e8a7a", accentDim: "#267a6c", accentBright: "#45a595" },
  { id: "slate", name: "Slate", accent: "#5a6570", accentDim: "#4e5860", accentBright: "#6e7a85" },
];

export const PRESETS: ThemePreset[] = [
  {
    id: "dark-gold",
    name: "Dark Gold",
    isDark: true,
    defaultAccentId: "gold",
    accentSwatches: DARK_ACCENT_SWATCHES,
    colors: {
      root: "#0a0a0a",
      surface: "#111111",
      elevated: "#1a1a1a",
      panel: "#141414",
      "text-primary": "#f5f0eb",
      "text-secondary": "#a39787",
      "text-muted": "#6b5f53",
      "node-file": "#4a7c9b",
      "node-function": "#5a9e6f",
      "node-class": "#8b6fb0",
      "node-module": "#c9a06c",
      "node-concept": "#b07a8a",
    },
  },
  {
    id: "dark-ocean",
    name: "Dark Ocean",
    isDark: true,
    defaultAccentId: "ocean",
    accentSwatches: DARK_ACCENT_SWATCHES,
    colors: {
      root: "#0a0e14",
      surface: "#111820",
      elevated: "#1a222c",
      panel: "#141c24",
      "text-primary": "#e8edf2",
      "text-secondary": "#87939f",
      "text-muted": "#536b7a",
      "node-file": "#4a7c9b",
      "node-function": "#5a9e6f",
      "node-class": "#8b6fb0",
      "node-module": "#c9a06c",
      "node-concept": "#b07a8a",
    },
  },
  {
    id: "dark-forest",
    name: "Dark Forest",
    isDark: true,
    defaultAccentId: "emerald",
    accentSwatches: DARK_ACCENT_SWATCHES,
    colors: {
      root: "#0a100a",
      surface: "#111811",
      elevated: "#1a241a",
      panel: "#141c14",
      "text-primary": "#ebf0eb",
      "text-secondary": "#87a38f",
      "text-muted": "#536b5a",
      "node-file": "#4a7c9b",
      "node-function": "#5a9e6f",
      "node-class": "#8b6fb0",
      "node-module": "#c9a06c",
      "node-concept": "#b07a8a",
    },
  },
  {
    id: "dark-rose",
    name: "Dark Rose",
    isDark: true,
    defaultAccentId: "rose",
    accentSwatches: DARK_ACCENT_SWATCHES,
    colors: {
      root: "#100a0a",
      surface: "#181111",
      elevated: "#221a1a",
      panel: "#1c1414",
      "text-primary": "#f2e8ea",
      "text-secondary": "#9f8790",
      "text-muted": "#6b535a",
      "node-file": "#4a7c9b",
      "node-function": "#5a9e6f",
      "node-class": "#8b6fb0",
      "node-module": "#c9a06c",
      "node-concept": "#b07a8a",
    },
  },
  {
    id: "light-minimal",
    name: "Light Minimal",
    isDark: false,
    defaultAccentId: "indigo",
    accentSwatches: LIGHT_ACCENT_SWATCHES,
    colors: {
      root: "#f5f3f0",
      surface: "#eae7e3",
      elevated: "#ffffff",
      panel: "#f0ede9",
      "text-primary": "#1a1a1a",
      "text-secondary": "#6b6b6b",
      "text-muted": "#a0a0a0",
      "node-file": "#3a6a87",
      "node-function": "#488a5b",
      "node-class": "#755d99",
      "node-module": "#a88a56",
      "node-concept": "#966674",
    },
  },
];

export function getPreset(id: string): ThemePreset {
  return PRESETS.find((p) => p.id === id) ?? PRESETS[0];
}

export function getAccent(preset: ThemePreset, accentId: string): AccentSwatch {
  return (
    preset.accentSwatches.find((s) => s.id === accentId) ??
    preset.accentSwatches.find((s) => s.id === preset.defaultAccentId) ??
    preset.accentSwatches[0]
  );
}
```

**Step 2: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add theme preset definitions"
```

---

### Tarefa 5: Criar a engine de tema

Funções puras sem dependência do React. Lida com injeção de variáveis CSS e derivação de accent.

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/themes/theme-engine.ts`

**Step 1: Escrever a engine de tema**

```typescript
import type { ThemeConfig } from "./types.ts";
import { getAccent, getPreset } from "./presets.ts";

export function hexToRgb(hex: string): string {
  const h = hex.replace("#", "");
  const n = parseInt(h, 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

function deriveFromAccent(accentHex: string, isDark: boolean): Record<string, string> {
  const rgb = hexToRgb(accentHex);
  return {
    "color-border-subtle": `rgba(${rgb}, ${isDark ? 0.12 : 0.1})`,
    "color-border-medium": `rgba(${rgb}, ${isDark ? 0.25 : 0.18})`,
    "glass-bg": isDark ? "rgba(20, 20, 20, 0.8)" : "rgba(255, 255, 255, 0.8)",
    "glass-bg-heavy": isDark ? "rgba(20, 20, 20, 0.95)" : "rgba(255, 255, 255, 0.95)",
    "glass-border": `rgba(${rgb}, ${isDark ? 0.1 : 0.08})`,
    "glass-border-heavy": `rgba(${rgb}, ${isDark ? 0.15 : 0.12})`,
    "scrollbar-thumb": `rgba(${rgb}, 0.2)`,
    "scrollbar-thumb-hover": `rgba(${rgb}, 0.35)`,
    "glow-accent": `rgba(${rgb}, 0.15)`,
    "glow-accent-strong": `rgba(${rgb}, 0.4)`,
    "glow-accent-pulse": `rgba(${rgb}, 0.6)`,
    "color-edge": `rgba(${rgb}, 0.3)`,
    "color-edge-dim": `rgba(${rgb}, 0.08)`,
    "color-edge-dot": `rgba(${rgb}, 0.15)`,
    "color-accent-overlay-bg": `rgba(${rgb}, 0.05)`,
    "color-accent-overlay-border": `rgba(${rgb}, 0.25)`,
    "kbd-bg": `rgba(${rgb}, 0.1)`,
  };
}

export function applyTheme(config: ThemeConfig): void {
  const preset = getPreset(config.presetId);
  const accent = getAccent(preset, config.accentId);
  const style = document.documentElement.style;

  // 1. Apply base preset colors
  for (const [key, value] of Object.entries(preset.colors)) {
    style.setProperty(`--color-${key}`, value);
  }

  // 2. Apply accent colors from swatch
  style.setProperty("--color-accent", accent.accent);
  style.setProperty("--color-accent-dim", accent.accentDim);
  style.setProperty("--color-accent-bright", accent.accentBright);

  // 3. Apply derived values
  const derived = deriveFromAccent(accent.accent, preset.isDark);
  for (const [key, value] of Object.entries(derived)) {
    style.setProperty(`--${key}`, value);
  }

  // 4. Set data-theme for CSS-only selectors
  document.documentElement.setAttribute("data-theme", preset.isDark ? "dark" : "light");
}
```

**Step 2: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add theme engine with CSS variable injection"
```

---

### Tarefa 6: Criar ThemeContext

Context React + provider que gerencia estado do tema, persistência e resolução.

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/themes/ThemeContext.tsx`

**Step 1: Escrever o context**

```typescript
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { PresetId, ThemeConfig, ThemePreset } from "./types.ts";
import { DEFAULT_THEME_CONFIG } from "./types.ts";
import { getPreset } from "./presets.ts";
import { applyTheme } from "./theme-engine.ts";

const STORAGE_KEY = "ua-theme";

interface ThemeContextValue {
  config: ThemeConfig;
  preset: ThemePreset;
  setPreset: (presetId: PresetId) => void;
  setAccent: (accentId: string) => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function loadFromLocalStorage(): ThemeConfig | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.presetId === "string" && typeof parsed.accentId === "string") {
      return parsed as ThemeConfig;
    }
    return null;
  } catch {
    return null;
  }
}

function saveToLocalStorage(config: ThemeConfig): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
  } catch {
    // Storage full or unavailable — ignore
  }
}

function resolveInitialTheme(metaTheme?: ThemeConfig | null): ThemeConfig {
  return loadFromLocalStorage() ?? metaTheme ?? DEFAULT_THEME_CONFIG;
}

interface ThemeProviderProps {
  metaTheme?: ThemeConfig | null;
  children: ReactNode;
}

export function ThemeProvider({ metaTheme, children }: ThemeProviderProps) {
  const [config, setConfig] = useState<ThemeConfig>(() => resolveInitialTheme(metaTheme));
  const initialized = useRef(false);

  // Apply theme on mount and config changes
  useEffect(() => {
    applyTheme(config);
    if (initialized.current) {
      saveToLocalStorage(config);
    }
    initialized.current = true;
  }, [config]);

  // Update if metaTheme arrives later (async fetch) and no localStorage preference exists
  useEffect(() => {
    if (metaTheme && !loadFromLocalStorage()) {
      setConfig(metaTheme);
    }
  }, [metaTheme]);

  const setPreset = useCallback((presetId: PresetId) => {
    setConfig((prev) => {
      const newPreset = getPreset(presetId);
      return { presetId, accentId: newPreset.defaultAccentId };
    });
  }, []);

  const setAccent = useCallback((accentId: string) => {
    setConfig((prev) => ({ ...prev, accentId }));
  }, []);

  const preset = getPreset(config.presetId);

  return (
    <ThemeContext.Provider value={{ config, preset, setPreset, setAccent }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}
```

**Step 2: Criar barrel export**

Crie: `understand-anything-plugin/packages/dashboard/src/themes/index.ts`

```typescript
export { ThemeProvider, useTheme } from "./ThemeContext.tsx";
export { PRESETS, getPreset, getAccent } from "./presets.ts";
export { applyTheme } from "./theme-engine.ts";
export type { PresetId, ThemeConfig, ThemePreset, AccentSwatch } from "./types.ts";
export { DEFAULT_THEME_CONFIG } from "./types.ts";
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add ThemeContext with localStorage persistence"
```

---

### Tarefa 7: Estender AnalysisMeta com campo de tema

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/core/src/types.ts`

**Step 1: Adicionar tipo ThemeConfig e estender AnalysisMeta**

Adicione perto do topo do arquivo (após imports/types existentes):

```typescript
export interface ThemeConfig {
  presetId: string;
  accentId: string;
}
```

Adicione o campo `theme` em `AnalysisMeta`:

```typescript
export interface AnalysisMeta {
  lastAnalyzedAt: string;
  gitCommitHash: string;
  version: string;
  analyzedFiles: number;
  theme?: ThemeConfig;
}
```

**Step 2: Verificar build do core**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/core build`
Esperado: Build é bem-sucedido.

**Step 3: Verificar que os testes do core passam**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/core test`
Esperado: Todos os testes passam.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(core): add optional theme field to AnalysisMeta"
```

---

### Tarefa 8: Criar componente ThemePicker

A UI de popover com seleção de preset e linha de swatches de accent.

**Arquivos:**
- Criar: `understand-anything-plugin/packages/dashboard/src/components/ThemePicker.tsx`

**Step 1: Escrever o componente**

```tsx
import { useCallback, useEffect, useRef, useState } from "react";
import { useTheme, PRESETS } from "../themes/index.ts";

export function ThemePicker() {
  const { config, preset, setPreset, setAccent } = useTheme();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  // Close on Escape
  useEffect(() => {
    if (!open) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [open]);

  const handlePreset = useCallback(
    (id: string) => {
      setPreset(id as Parameters<typeof setPreset>[0]);
    },
    [setPreset],
  );

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-1.5 px-2 py-1 rounded text-xs text-text-secondary hover:text-text-primary transition-colors"
        title="Change theme"
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <circle cx="12" cy="12" r="10" />
          <path d="M12 2a7 7 0 0 0 0 14 4 4 0 0 1 0 8 10 10 0 0 0 0-20z" />
          <circle cx="8" cy="10" r="1.5" fill="currentColor" />
          <circle cx="12" cy="7" r="1.5" fill="currentColor" />
          <circle cx="16" cy="10" r="1.5" fill="currentColor" />
        </svg>
        <span className="hidden sm:inline">Theme</span>
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 w-64 rounded-lg glass-heavy shadow-xl z-50 p-3 space-y-3">
          {/* Presets */}
          <div>
            <div className="text-[10px] font-semibold text-text-muted uppercase tracking-wider mb-2">
              Theme
            </div>
            <div className="space-y-1">
              {PRESETS.map((p) => (
                <button
                  key={p.id}
                  onClick={() => handlePreset(p.id)}
                  className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded text-xs transition-colors ${
                    p.id === config.presetId
                      ? "bg-accent/15 text-accent"
                      : "text-text-secondary hover:text-text-primary hover:bg-elevated"
                  }`}
                >
                  {/* Color preview dots */}
                  <div className="flex gap-1">
                    <span
                      className="w-3 h-3 rounded-full border border-border-subtle"
                      style={{ backgroundColor: p.colors.root }}
                    />
                    <span
                      className="w-3 h-3 rounded-full border border-border-subtle"
                      style={{ backgroundColor: p.colors.surface }}
                    />
                    <span
                      className="w-3 h-3 rounded-full border border-border-subtle"
                      style={{
                        backgroundColor:
                          p.accentSwatches.find((s) => s.id === p.defaultAccentId)?.accent ??
                          p.accentSwatches[0].accent,
                      }}
                    />
                  </div>
                  <span>{p.name}</span>
                  {p.id === config.presetId && (
                    <svg
                      className="ml-auto w-3.5 h-3.5 text-accent"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="3"
                    >
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Accent swatches */}
          <div>
            <div className="text-[10px] font-semibold text-text-muted uppercase tracking-wider mb-2">
              Accent Color
            </div>
            <div className="flex gap-2 flex-wrap">
              {preset.accentSwatches.map((swatch) => (
                <button
                  key={swatch.id}
                  onClick={() => setAccent(swatch.id)}
                  className={`w-6 h-6 rounded-full transition-transform hover:scale-110 ${
                    swatch.id === config.accentId
                      ? "ring-2 ring-text-primary ring-offset-1 ring-offset-root"
                      : ""
                  }`}
                  style={{ backgroundColor: swatch.accent }}
                  title={swatch.name}
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

**Step 2: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add ThemePicker popover component"
```

---

### Tarefa 9: Integrar ThemeProvider e ThemePicker no App

Conecte tudo no componente raiz.

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/App.tsx`

**Step 1: Adicionar imports**

Adicione aos imports no topo do App.tsx:

```typescript
import { ThemeProvider } from "./themes/index.ts";
import { ThemePicker } from "./components/ThemePicker.tsx";
import type { ThemeConfig } from "./themes/index.ts";
```

**Step 2: Adicionar carregamento de tema do meta.json**

Dentro do componente App, adicione state e effect para tema do meta.json:

```typescript
const [metaTheme, setMetaTheme] = useState<ThemeConfig | null>(null);

useEffect(() => {
  fetch("/meta.json")
    .then((r) => (r.ok ? r.json() : null))
    .then((meta) => {
      if (meta?.theme) setMetaTheme(meta.theme);
    })
    .catch(() => {});
}, []);
```

**Step 3: Envolver o JSX de retorno com ThemeProvider**

Envolva todo o valor de retorno do App com `<ThemeProvider metaTheme={metaTheme}>...</ThemeProvider>`.

**Step 4: Adicionar ThemePicker ao header**

Na barra do header (o `<header>` ou linha flex superior), adicione `<ThemePicker />` após os controles existentes (PersonaSelector, DiffToggle, LayerLegend) e antes do botão de help.

**Step 5: Verificar build**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(dashboard): integrate ThemeProvider and ThemePicker into App"
```

---

### Tarefa 10: Ajustes do CSS para tema light

Lida com edge cases onde apenas variáveis CSS não são suficientes para o tema light.

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/index.css`

**Step 1: Adicionar seletores data-theme para overrides do tema light**

Adicione no final do index.css:

```css
/* Light theme overrides */
[data-theme="light"] {
  color-scheme: light;
}

[data-theme="light"] .diff-faded {
  opacity: 0.35;
}

[data-theme="light"] ::-webkit-scrollbar-track {
  background: rgba(0, 0, 0, 0.05);
}

[data-theme="dark"] {
  color-scheme: dark;
}
```

**Step 2: Adicionar transition para troca suave de tema**

Adicione aos estilos base do `html`:

```css
html {
  transition: background-color 0.2s ease, color 0.2s ease;
}
```

**Step 3: Atualizar a consideração do WarningBanner**

WarningBanner usa cores amber/orange do Tailwind diretamente (ex.: `bg-amber-900/20`). Estas são cores semânticas de warning e NÃO devem mudar com o tema. Porém, para o tema light, as cores amber sobre fundo claro precisam de ajuste.

Adicione aos overrides do tema light se necessário:

```css
[data-theme="light"] .warning-banner {
  background: rgba(180, 130, 30, 0.1);
  border-color: rgba(180, 130, 30, 0.3);
  color: #92600a;
}
```

Nota: Adicione isto apenas se o WarningBanner ficar quebrado no tema light durante o teste visual. Pode funcionar bem como está com as cores amber do Tailwind.

**Step 4: Verificar build**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(dashboard): add light theme CSS overrides"
```

---

### Tarefa 11: Remover defaults @theme do index.css

Agora que a engine de tema define todas as variáveis CSS em runtime, o bloco `@theme` no index.css serve como valores iniciais/fallback antes do React montar. Mantenha mas atualize para usar o naming accent.

**Arquivos:**
- Modificar: `understand-anything-plugin/packages/dashboard/src/index.css`

**Step 1: Atualizar bloco @theme**

O bloco `@theme` já deve ter `--color-accent` (do rename da Tarefa 1). Garanta que as novas variáveis adicionadas na Tarefa 2 também estejam presentes no bloco `@theme` como defaults:

```css
@theme {
  /* Base */
  --color-root: #0a0a0a;
  --color-surface: #111111;
  --color-elevated: #1a1a1a;
  --color-panel: #141414;

  /* Accent */
  --color-accent: #d4a574;
  --color-accent-dim: #c9a96e;
  --color-accent-bright: #e8c49a;

  /* Text */
  --color-text-primary: #f5f0eb;
  --color-text-secondary: #a39787;
  --color-text-muted: #6b5f53;

  /* Borders */
  --color-border-subtle: rgba(212, 165, 116, 0.12);
  --color-border-medium: rgba(212, 165, 116, 0.25);

  /* Node types */
  --color-node-file: #4a7c9b;
  --color-node-function: #5a9e6f;
  --color-node-class: #8b6fb0;
  --color-node-module: #c9a06c;
  --color-node-concept: #b07a8a;

  /* Diff */
  --color-diff-changed: #e05252;
  --color-diff-affected: #d4a030;
  --color-diff-changed-dim: rgba(224, 82, 82, 0.25);
  --color-diff-affected-dim: rgba(212, 160, 48, 0.25);

  /* Glass */
  --glass-bg: rgba(20, 20, 20, 0.8);
  --glass-bg-heavy: rgba(20, 20, 20, 0.95);
  --glass-border: rgba(212, 165, 116, 0.1);
  --glass-border-heavy: rgba(212, 165, 116, 0.15);

  /* Scrollbar */
  --scrollbar-thumb: rgba(212, 165, 116, 0.2);
  --scrollbar-thumb-hover: rgba(212, 165, 116, 0.35);

  /* Glow */
  --glow-accent: rgba(212, 165, 116, 0.15);
  --glow-accent-strong: rgba(212, 165, 116, 0.4);
  --glow-accent-pulse: rgba(212, 165, 116, 0.6);

  /* Edges */
  --color-edge: rgba(212, 165, 116, 0.3);
  --color-edge-dim: rgba(212, 165, 116, 0.08);
  --color-edge-dot: rgba(212, 165, 116, 0.15);

  /* Accent overlays */
  --color-accent-overlay-bg: rgba(212, 165, 116, 0.05);
  --color-accent-overlay-border: rgba(212, 165, 116, 0.25);

  /* Kbd */
  --kbd-bg: rgba(212, 165, 116, 0.1);

  /* Typography */
  --font-serif: 'DM Serif Display', Georgia, serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
  --font-sans: 'Inter', system-ui, sans-serif;
}
```

Isto garante:
- O Tailwind v4 gera todas as classes utilitárias corretas a partir do bloco `@theme`
- Antes do React montar, a página mostra o default Dark Gold (sem flash de conteúdo sem estilo)
- A engine de tema sobrescreve esses valores em runtime

**Step 2: Verificar build**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido.

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor(dashboard): align @theme defaults with theme engine variables"
```

---

### Tarefa 12: Build completo + verificação visual

**Arquivos:** Nenhum (somente verificação)

**Step 1: Build do core**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/core build`
Esperado: Build é bem-sucedido.

**Step 2: Build do dashboard**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/dashboard build`
Esperado: Build é bem-sucedido.

**Step 3: Executar testes do core**

Execute: `cd understand-anything-plugin && pnpm --filter @understand-anything/core test`
Esperado: Todos os testes passam.

**Step 4: Executar lint**

Execute: `cd understand-anything-plugin && pnpm lint`
Esperado: Sem erros de lint.

**Step 5: Iniciar dev server e verificar visualmente**

Execute: `cd understand-anything-plugin && pnpm dev:dashboard`

Verifique:
1. Dashboard carrega com tema Dark Gold (default) — aparência idêntica ao atual
2. Botão do theme picker visível no header
3. Clique no theme picker — popover abre com 5 presets e 8 swatches de accent
4. Selecione Dark Ocean — backgrounds ficam navy-blue, accent vira cyan
5. Selecione Dark Forest — backgrounds ficam dark green, accent vira emerald
6. Selecione Dark Rose — backgrounds ficam dark warm, accent vira rose
7. Selecione Light Minimal — backgrounds ficam light, texto fica dark, accent vira indigo
8. Selecione swatches de accent diferentes em cada preset — accent color, borders, glass, glow atualizam
9. Recarregue a página — tema persiste no localStorage
10. Clique fora do popover — ele fecha
11. Pressione Escape — popover fecha

**Step 6: Commit (se forem necessárias correções)**

```bash
git add -A
git commit -m "fix(dashboard): theme system visual adjustments"
```

---

## Grafo de Dependências

```
Task 1 (rename gold→accent) ─┐
                              ├─> Task 3 (types) ──┐
Task 2 (consolidate colors) ──┤                     │
                              │   Task 4 (presets) ─┤
                              │                     ├─> Task 6 (context) ─┐
                              │   Task 5 (engine) ──┘                     │
                              │                                           ├─> Task 8 (picker) ─┐
                              │   Task 7 (core types) ────────────────────┘                    │
                              │                                                                │
                              └───────────────────────────────────────────> Task 9 (integrate) ─┤
                                                                                               │
                                                                           Task 10 (light CSS) ┤
                                                                                               │
                                                                           Task 11 (defaults) ─┤
                                                                                               │
                                                                           Task 12 (verify) ───┘
```

**Grupos paralelizáveis:**
- Tarefas 1 + 2 podem ser feitas sequencialmente (ambas tocam index.css)
- Tarefas 3, 4, 5 podem ser feitas em paralelo (arquivos novos independentes)
- Tarefa 6 depende de 3, 4, 5
- Tarefa 7 é independente (pacote core)
- Tarefa 8 depende de 6
- Tarefa 9 depende de 1, 2, 7, 8
- Tarefas 10, 11 podem ser feitas após 9
- Tarefa 12 é a verificação final
