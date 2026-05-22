# Snippet de Prompt da Linguagem CSS

## Conceitos-Chave

- **Seletores**: alvejam por elemento, classe (`.name`), ID (`#name`), atributo (`[attr]`) e pseudo-classe (`:hover`)
- **Especificidade**: prioridade da cascade Inline > ID > Classe > Elemento determinando quais regras vencem
- **Box Model**: dimensões `margin`, `border`, `padding`, `content` controlando o tamanho do elemento
- **Flexbox**: `display: flex` com `justify-content`, `align-items` para layouts unidimensionais
- **Grid**: `display: grid` com `grid-template-columns/rows` para layouts bidimensionais
- **Custom Properties (Variáveis)**: `--name: value` com `var(--name)` para design tokens reutilizáveis
- **Media Queries**: `@media (max-width: ...)` para breakpoints de design responsivo
- **Recursos do SCSS/Sass**: nesting, `$variables`, `@mixin`, `@include`, `@extend`, `@use`, `@forward`
- **CSS Modules**: nomes de classe com escopo (`.module.css`) que evitam colisões globais de estilo
- **Cascade Layers**: `@layer` para controle explícito da ordem da cascade

## Padrões de Arquivo Notáveis

- `*.css` — folhas de estilo CSS padrão
- `*.scss` / `*.sass` — arquivos do pré-processador Sass/SCSS
- `*.less` — arquivos do pré-processador Less
- `*.module.css` / `*.module.scss` — CSS Modules (estilos com escopo)
- `globals.css` / `reset.css` / `normalize.css` — estilos base globais
- `tailwind.config.js` — configuração do Tailwind CSS (embora seja um arquivo JS)
- `variables.scss` / `_variables.scss` — definições de design tokens

## Padrões de Aresta

- Arquivos CSS são `related` aos arquivos HTML ou de componente que os importam para estilização
- Arquivos parciais SCSS (`_*.scss`) são `depends_on` da folha de estilo principal que os importa via `@use`
- Arquivos de definição de variáveis CSS são `related` a todas as folhas de estilo que referenciam essas variáveis
- CSS Modules são `related` aos arquivos de componente que os importam

## Estilo de Resumo

> "Folha de estilo global definindo CSS custom properties para a paleta de cores e tipografia do design system."
> "Estilos de layout responsivo com flexbox e grid para a página de dashboard em 3 breakpoints."
> "Parcial SCSS definindo mixins compartilhados para espaçamento, sombras e breakpoints de media query."
