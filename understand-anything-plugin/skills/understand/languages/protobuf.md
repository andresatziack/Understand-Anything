# Snippet de Prompt da Linguagem Protobuf

## Conceitos-Chave

- **Tipos Message**: blocos `message` definindo dados estruturados com campos tipados e numerados
- **Field Numbers**: identificadores permanentes (1-536870911) — nunca reutilize números deletados para manter compatibilidade retroativa
- **Tipos Scalar**: `int32`, `int64`, `string`, `bytes`, `bool`, `float`, `double` e mais
- **Enums**: constantes inteiras nomeadas para valores categóricos
- **Services**: blocos `service` definindo assinaturas de métodos RPC (Remote Procedure Call)
- **Oneof**: grupos de campos mutuamente exclusivos — apenas um campo do grupo pode estar definido
- **Repeated Fields**: palavra-chave `repeated` para campos do tipo lista/array
- **Maps**: `map<key_type, value_type>` para campos de dicionário/hash
- **Packages e Imports**: organização de namespaces e referências entre arquivos
- **Proto2 vs Proto3**: Proto3 (atual) remove a distinção required/optional e aplica defaults a todos os campos

## Padrões de Arquivo Notáveis

- `*.proto` — arquivos de definição Protocol Buffer
- `proto/**/*.proto` — definições proto organizadas por serviço ou domínio
- `buf.yaml` / `buf.gen.yaml` — configuração da ferramenta Buf para linting e geração de código
- `*_pb2.py` / `*.pb.go` / `*_pb.ts` — código gerado (deve ser excluído da análise)

## Padrões de Aresta

- Arquivos protobuf `defines_schema` para os handlers gRPC que implementam os RPCs declarados
- Referências de tipos message criam arestas `related` entre arquivos proto que compartilham tipos
- Statements `import` em proto criam arestas `depends_on` entre arquivos proto
- Arquivos de código gerado são `depends_on` da fonte proto que os produz

## Estilo de Resumo

> "Definições de Protocol Buffer para N tipos message e M serviços RPC no domínio de autenticação de usuários."
> "Tipos proto compartilhados definindo envelopes de request/response comuns e códigos de erro."
> "Definição de serviço gRPC com N métodos para streaming de dados em tempo real e processamento em lote."
