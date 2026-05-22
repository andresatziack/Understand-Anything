# Snippet de Prompt da Linguagem YAML

## Conceitos-Chave

- **Aninhamento Baseado em Indentação**: estrutura sensível a whitespace (apenas espaços, sem tabs) definindo a hierarquia
- **Anchors e Aliases**: `&anchor` define um bloco reutilizável, `*anchor` o referencia para evitar duplicação
- **Merge Keys**: `<<: *anchor` mescla o conteúdo de um anchor no mapping atual
- **Strings Multi-Linha**: bloco literal (`|`) preserva newlines, bloco folded (`>`) junta linhas
- **Separadores de Documento**: `---` inicia um novo documento, `...` encerra um (streams multi-documento)
- **Tags e Tipos**: `!!str`, `!!int`, `!!bool` para tipagem explícita; tags customizadas para tipos específicos da aplicação
- **Estilo Flow**: sintaxe inline estilo JSON `{key: value}` e `[item1, item2]` para notação compacta
- **Substituição de Variáveis de Ambiente**: padrões `${VAR}` usados em docker-compose e configs de CI

## Padrões de Arquivo Notáveis

- `docker-compose.yml` / `docker-compose.yaml` — definição de aplicação Docker multi-container
- `.github/workflows/*.yml` — definições de workflows do GitHub Actions para CI/CD
- `.gitlab-ci.yml` — configuração de pipeline CI/CD do GitLab
- `kubernetes/*.yaml` / `k8s/*.yaml` — manifestos de recursos do Kubernetes
- `*.config.yaml` — arquivos de configuração de aplicação
- `mkdocs.yml` — configuração de site de documentação MkDocs
- `serverless.yml` — configuração do Serverless Framework

## Padrões de Aresta

- Arquivos YAML de configuração `configures` os módulos de código que controlam (por exemplo, configurações de banco afetam a camada de dados)
- Arquivos YAML de CI/CD `triggers` pipelines de build e deploy
- YAML do docker-compose `deploys` serviços e `depends_on` Dockerfiles
- YAML do Kubernetes `deploys` e `provisions` serviços de aplicação

## Estilo de Resumo

> "Configuração Docker Compose definindo N serviços com networking, volumes e health checks."
> "Workflow do GitHub Actions executando testes em push e fazendo deploy em produção ao mergear na main."
> "Manifesto de deployment Kubernetes com N réplicas, limites de recurso e liveness probes."
