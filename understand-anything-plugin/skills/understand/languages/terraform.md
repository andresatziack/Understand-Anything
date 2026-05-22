# Snippet de Prompt da Linguagem Terraform

## Conceitos-Chave

- **Infraestrutura Declarativa**: define o estado desejado; o Terraform calcula e aplica o diff
- **Providers**: plugins que conectam a APIs de cloud (AWS, GCP, Azure, Kubernetes, etc.)
- **Resources**: blocos `resource "type" "name"` declarando componentes de infraestrutura
- **Data Sources**: blocos `data "type" "name"` lendo o estado de infraestrutura existente
- **Variables**: blocos `variable` para parametrizar configurações com defaults e validação
- **Outputs**: blocos `output` expondo valores para referências entre módulos ou consumo humano
- **Modules**: pacotes de infraestrutura reutilizáveis e composáveis com suas próprias variables e outputs
- **Gerenciamento de State**: arquivos `.tfstate` rastreando o mapeamento de recursos do mundo real (nunca commite no git)
- **Workspaces**: ambientes de state isolados para gerenciar dev/staging/prod a partir de um único codebase
- **Plan e Apply**: `terraform plan` pré-visualiza mudanças, `terraform apply` as executa

## Padrões de Arquivo Notáveis

- `main.tf` — definições primárias de resources
- `variables.tf` — declarações de input variables com tipos e defaults
- `outputs.tf` — definições de output values
- `providers.tf` — configuração de providers e constraints de versão
- `backend.tf` — configuração de remote state backend (S3, GCS, etc.)
- `modules/**/*.tf` — módulos de infraestrutura reutilizáveis
- `*.tfvars` — arquivos de valores de variables para diferentes ambientes
- `terraform.lock.hcl` — arquivo de lock de versão dos providers

## Padrões de Aresta

- Arquivos terraform `provisions` os recursos de infraestrutura que definem
- Referências entre módulos criam arestas `depends_on` entre arquivos terraform
- Terraform `deploys` código de aplicação ao referenciar imagens de container ou alvos de deploy
- Arquivos de variables `configures` os módulos terraform que parametrizam

## Estilo de Resumo

> "Configuração Terraform provisionando N recursos AWS, incluindo VPC, cluster ECS e instância RDS."
> "Módulo de infraestrutura definindo um namespace Kubernetes reutilizável com RBAC e network policies."
> "Definições de variables para N configurações específicas de ambiente (region, instance type, scaling)."
