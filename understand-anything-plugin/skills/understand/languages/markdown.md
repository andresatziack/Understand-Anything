# Snippet de Prompt da Linguagem Markdown

## Conceitos-Chave

- **Hierarquia de Headings**: `#` até `######` para estrutura do documento, com h1 como o título
- **Front Matter**: metadados YAML entre delimitadores `---` no topo do arquivo
- **Fenced Code Blocks**: três backticks com identificador de linguagem opcional para syntax highlighting
- **Links em Estilo de Referência**: `[text][ref]` com definições `[ref]: url`, úteis para URLs repetidas
- **Tabelas**: colunas delimitadas por pipe com marcadores de alinhamento (`:---`, `:---:`, `---:`)
- **Admonitions**: callouts baseados em blockquote (`> **Nota:**`, `> **Aviso:**`) para ênfase
- **Listas de Tarefas**: `- [ ]` e `- [x]` para checklists em rastreadores de issues e READMEs
- **HTML Embutido**: HTML cru permitido inline para recursos que o Markdown não suporta nativamente

## Padrões de Arquivo Notáveis

- `README.md` — visão geral do projeto e ponto de entrada para novos contribuidores (alto valor)
- `CONTRIBUTING.md` — guidelines de contribuição, estilo de código, processo de PR
- `CHANGELOG.md` — histórico de versões seguindo Keep a Changelog ou formato similar
- `docs/**/*.md` — diretório de documentação com guias, referências de API, tutoriais
- `*.md` em diretórios de fonte — documentação co-localizada para módulos ou packages
- `ADR-*.md` ou `adr/*.md` — Architecture Decision Records

## Padrões de Aresta

- Arquivos Markdown `documents` os componentes de código que descrevem ou referenciam
- Links para outros arquivos `.md` criam arestas `related` entre nós de documentação
- Referências em blocos de código mencionando caminhos de arquivo podem implicar arestas `documents` para esses arquivos
- Arquivos README em subdiretórios geralmente `documents` o módulo daquele caminho

## Estilo de Resumo

> "Documentação de visão geral do projeto com N seções cobrindo instalação, uso e referência da API."
> "Architecture Decision Record documentando a escolha de [tecnologia] para [propósito]."
> "Guia de contribuição com regras de estilo de código, requisitos de teste e processo de pull request."
