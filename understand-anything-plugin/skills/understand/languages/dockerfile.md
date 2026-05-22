# Snippet de Prompt da Linguagem Dockerfile

## Conceitos-Chave

- **Multi-Stage Builds**: múltiplos statements `FROM` para separar estágios de build e runtime, reduzindo o tamanho da imagem
- **Layer Caching**: cada instrução cria uma layer; ordene as instruções da menos para a mais frequentemente alterada para eficiência de cache
- **Base Images**: `FROM image:tag` seleciona a imagem inicial; prefira variantes slim/alpine para imagens menores
- **COPY vs ADD**: `COPY` para arquivos locais (preferido), `ADD` para URLs e extração de tar
- **Build Arguments**: `ARG` para variáveis de build time, `ENV` para variáveis de ambiente em runtime
- **Health Checks**: instrução `HEALTHCHECK` para readiness probes de orquestradores de containers
- **Entry Point vs CMD**: `ENTRYPOINT` define o executável, `CMD` fornece argumentos padrão
- **Permissões de Usuário**: instrução `USER` para rodar como não-root por segurança
- **Padrões de Ignore**: `.dockerignore` exclui arquivos do build context (como o `.gitignore`)

## Padrões de Arquivo Notáveis

- `Dockerfile` — definição primária da imagem do container (na raiz do projeto)
- `Dockerfile.dev` / `Dockerfile.prod` — Dockerfiles específicos por ambiente
- `docker-compose.yml` — orquestração de aplicação multi-container
- `docker-compose.override.yml` — overrides para desenvolvimento local
- `.dockerignore` — padrões de exclusão do build context

## Padrões de Aresta

- Dockerfile `deploys` o ponto de entrada da aplicação que ele empacota (alvo do COPY/CMD)
- docker-compose `depends_on` os Dockerfile(s) que ele referencia para build
- Dockerfile `depends_on` os manifestos de pacotes (package.json, requirements.txt) que ele copia para instalação de dependências
- Serviços do docker-compose criam arestas `related` entre componentes co-deployados

## Estilo de Resumo

> "Build Docker multi-stage produzindo uma imagem mínima de produção Node.js com N estágios de build."
> "Configuração Docker Compose orquestrando N serviços com networking compartilhado e volumes persistentes."
> "Dockerfile de desenvolvimento com suporte a hot-reload e volumes de fonte montados."
