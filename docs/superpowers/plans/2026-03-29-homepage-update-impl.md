# Plano de Implementação da Atualização de Features da Homepage

> **Para o Claude:** SUB-SKILL OBRIGATÓRIA: Use superpowers:executing-plans para implementar este plano tarefa por tarefa.

**Objetivo:** Atualizar a homepage Astro para refletir as features dos releases v1.2.0–v2.0.0.

**Arquitetura:** Três edições de arquivo — expandir Features.astro de 3→6 cards, atualizar a nota de plataformas do Install.astro, atualizar a tagline do Footer.astro. Sem novos arquivos ou mudanças estruturais.

**Stack Tecnológica:** Astro 6, CSS grid

---

### Tarefa 1: Atualizar Features.astro — Substituir 3 Cards por 6

**Arquivos:**
- Modificar: `homepage/src/components/Features.astro`

**Step 1: Substituir o array de features (linhas 2–18)**

Substitua o array de features no frontmatter por:

```astro
---
const features = [
  {
    icon: '◈',
    title: 'Interactive Knowledge Graph',
    description: 'Visualize files, functions, and dependencies as an explorable graph with hierarchical drill-down and smart layout.',
  },
  {
    icon: '⬡',
    title: 'Beyond Code Analysis',
    description: 'Analyze your entire project — Dockerfiles, Terraform, SQL, Markdown, and 26+ file types mapped into one unified graph.',
  },
  {
    icon: '⊘',
    title: 'Smart Filtering & Search',
    description: 'Filter by node type, complexity, layer, or edge category. Fuzzy and semantic search to find anything instantly.',
  },
  {
    icon: '⎙',
    title: 'Export & Share',
    description: 'Export your knowledge graph as high-quality PNG, SVG, or filtered JSON — ready for docs, presentations, or further analysis.',
  },
  {
    icon: '⟿',
    title: 'Dependency Path Finder',
    description: 'Find the shortest path between any two components. Understand how parts of your system connect at a glance.',
  },
  {
    icon: '⟐',
    title: 'Guided Tours & Onboarding',
    description: 'AI-generated walkthroughs that teach the codebase step by step, plus onboarding guides for new team members.',
  },
];
---
```

**Step 2: Atualizar a lógica de delay do reveal (linha 24)**

O `reveal-delay-${i + 1}` atual só tem CSS para os delays 1–3. Com 6 cards em 2 linhas, use módulo para que cada linha escalone 1/2/3:

```astro
<div class={`feature-card reveal reveal-delay-${(i % 3) + 1}`}>
```

**Step 3: Atualizar o CSS do grid para tratar 2 linhas corretamente**

Sem mudança necessária — `grid-template-columns: repeat(3, 1fr)` já quebra para uma segunda linha. O breakpoint mobile `1fr` também funciona. Nenhuma mudança de CSS é necessária.

**Step 4: Verificar o build**

Execute: `cd homepage && npx astro build`
Esperado: Build completa sem erros.

**Step 5: Commit**

```bash
git add homepage/src/components/Features.astro
git commit -m "feat(homepage): expand features section to 6 cards for v2.0.0"
```

---

### Tarefa 2: Atualizar Install.astro — Nota Multi-Plataforma

**Arquivos:**
- Modificar: `homepage/src/components/Install.astro`

**Step 1: Substituir a nota de plataforma (linha 13)**

Substitua:
```html
<p class="install-note">Works with <strong>Claude Code</strong> — Anthropic's official CLI for Claude.</p>
```

Por:
```html
<p class="install-note">Works with <strong>Claude Code</strong>, <strong>Codex</strong>, <strong>OpenCode</strong>, <strong>Gemini CLI</strong>, and more.</p>
```

**Step 2: Commit**

```bash
git add homepage/src/components/Install.astro
git commit -m "feat(homepage): update install note for multi-platform support"
```

---

### Tarefa 3: Atualizar Footer.astro — Tagline

**Arquivos:**
- Modificar: `homepage/src/components/Footer.astro`

**Step 1: Substituir a tagline (linha 13)**

Substitua:
```html
<p class="footer-note">Built as a Claude Code plugin</p>
```

Por:
```html
<p class="footer-note">Built for AI coding assistants</p>
```

**Step 2: Verificar o build completo**

Execute: `cd homepage && npx astro build`
Esperado: Build limpo, sem erros.

**Step 3: Commit**

```bash
git add homepage/src/components/Footer.astro
git commit -m "feat(homepage): update footer tagline for multi-platform"
```
