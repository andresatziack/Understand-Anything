# Snippet de Prompt da Linguagem Shell

## Conceitos-Chave

- **Linha Shebang**: `#!/bin/bash` ou `#!/usr/bin/env bash` especificando o interpretador
- **Variáveis**: atribuição `VAR=value`, expansão `$VAR` ou `${VAR}`, sem espaços ao redor de `=`
- **Funções**: `function name()` ou `name()` para grupos de comandos reutilizáveis
- **Condicionais**: `if [[ condition ]]; then ... fi` com `[[ ]]` para testes estendidos
- **Loops**: padrões de iteração `for item in list`, `while condition`, `until condition`
- **Pipes e Redirecionamento**: `|` para encadear comandos, `>` / `>>` / `2>&1` para redirecionamento de saída
- **Códigos de Saída**: `$?` captura o status do último comando; `set -e` sai em qualquer falha
- **Strict Mode**: `set -euo pipefail` para tratamento robusto de erros (sai em erro, variáveis indefinidas, falhas de pipe)
- **Substituição de Comando**: `$(command)` captura a saída do comando como uma string
- **Here Documents**: `<<EOF ... EOF` para entrada de string multi-linha em comandos

## Padrões de Arquivo Notáveis

- `*.sh` / `*.bash` — arquivos de script shell
- `scripts/*.sh` — scripts de automação do projeto (build, deploy, setup)
- `entrypoint.sh` — script de ponto de entrada de container Docker
- `install.sh` / `setup.sh` — scripts de setup de ambiente
- `.bashrc` / `.bash_profile` / `.zshrc` — arquivos de configuração de shell

## Padrões de Aresta

- Scripts shell `triggers` outros scripts ou processos de build que invocam
- Scripts de entry point `deploys` a aplicação que iniciam
- Scripts de setup `configures` o ambiente de desenvolvimento
- Scripts de build `depends_on` os arquivos de fonte que compilam ou empacotam

## Estilo de Resumo

> "Script de automação de build compilando TypeScript, executando testes e empacotando o artefato de release."
> "Script de entry point Docker tratando encaminhamento de sinais e shutdown gracioso."
> "Script de setup de ambiente instalando dependências e configurando ferramentas de desenvolvimento."
