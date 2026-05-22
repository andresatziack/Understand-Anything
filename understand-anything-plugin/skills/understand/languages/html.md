# Snippet de Prompt da Linguagem HTML

## Conceitos-Chave

- **Elementos Semânticos**: `<main>`, `<nav>`, `<header>`, `<footer>`, `<article>`, `<section>` para estrutura significativa
- **Estrutura do Documento**: `<!DOCTYPE html>`, `<html>`, `<head>`, `<body>` formando o esqueleto da página
- **Forms**: `<form>`, `<input>`, `<select>`, `<textarea>` para coleta de dados do usuário com atributos de validação
- **Acessibilidade**: atributos `aria-*`, `role`, texto `alt` e marcação semântica para leitores de tela
- **Meta Tags**: `<meta>` para viewport, charset, description, Open Graph e metadados de SEO
- **Carregamento de Script e Style**: `<script>`, `<link>`, `<style>` para inclusão de JavaScript e CSS
- **Atributos de Dados**: atributos customizados `data-*` para armazenar dados específicos do elemento
- **Sintaxe de Template**: templating específico de framework (`{{ }}` para Jinja/Django, `<%= %>` para ERB)
- **Web Components**: `<template>`, `<slot>`, Custom Elements para componentes reutilizáveis encapsulados

## Padrões de Arquivo Notáveis

- `index.html` — ponto de entrada da aplicação ou shell de SPA
- `*.html` / `*.htm` — páginas HTML estáticas
- `templates/**/*.html` — arquivos de template renderizados no servidor (Django, Jinja2, templates do Go)
- `public/index.html` — documento raiz de SPA (React, Vue)
- `*.ejs` / `*.hbs` / `*.pug` — arquivos de templating engines

## Padrões de Aresta

- Arquivos HTML `depends_on` os arquivos JavaScript e CSS que incluem via tags `<script>` e `<link>`
- Arquivos de template HTML `depends_on` o código no servidor que os renderiza
- Pontos de entrada HTML são alvos `deploys` para sistemas de build e servidores web
- Arquivos HTML são `related` aos componentes ou rotas que renderizam

## Estilo de Resumo

> "Shell de single-page application com viewport meta, CSS reset e ponto de montagem da raiz do React."
> "Template renderizado no servidor com navegação, área de conteúdo e footer usando herança de templates do Django."
> "Página de landing estática com layout responsivo, formulário e integrações de scripts de terceiros."
