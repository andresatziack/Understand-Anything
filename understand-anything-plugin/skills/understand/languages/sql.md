# Snippet de Prompt da Linguagem SQL

## Conceitos-Chave

- **DDL (Data Definition)**: `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE` para gerenciamento de schema
- **DML (Data Manipulation)**: `SELECT`, `INSERT`, `UPDATE`, `DELETE` para operações sobre dados
- **Normalização**: organização de tabelas para reduzir redundância via relacionamentos 1NF, 2NF, 3NF
- **Foreign Keys**: constraints `REFERENCES` aplicando integridade referencial entre tabelas
- **Indexes**: `CREATE INDEX` para otimização de performance de queries em colunas frequentemente consultadas
- **Migrations**: mudanças de schema numeradas e sequenciais aplicadas em ordem para controle de versão
- **Transactions**: `BEGIN`/`COMMIT`/`ROLLBACK` para operações multi-statement atômicas
- **Views**: queries nomeadas (`CREATE VIEW`) que fornecem tabelas virtuais para joins complexos
- **Stored Procedures**: funções server-side para encapsular lógica de negócio no banco
- **Constraints**: `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT` para regras de integridade dos dados

## Padrões de Arquivo Notáveis

- `migrations/*.sql` — arquivos de migration numerados (por exemplo, `001_create_users.sql`, `002_add_orders.sql`)
- `schema.sql` — definição completa do schema do banco (frequentemente gerada a partir das migrations)
- `seeds/*.sql` — dados de seed para ambientes de desenvolvimento e teste
- `*.up.sql` / `*.down.sql` — pares reversíveis de migration (up aplica, down reverte)
- `init.sql` — script de inicialização de banco para Docker ou setup novo
- `procedures/*.sql` — definições de stored procedures

## Padrões de Aresta

- Arquivos de migration SQL `migrates` as tabelas que criam ou alteram
- Arquivos de definição de schema `defines_schema` para os modelos do ORM ou código da camada de dados que os lê
- Definições de tabela criam arestas `related` implícitas entre tabelas conectadas por foreign keys
- Arquivos de seed `depends_on` os arquivos de migration que criam as tabelas que populam

## Estilo de Resumo

> "Migration de banco criando a tabela users com colunas de email, nome e autenticação."
> "Definição de schema com N tabelas cobrindo gerenciamento de usuários, pedidos e processamento de pagamentos."
> "Seed data populando N tabelas com fixtures de desenvolvimento para testes."
