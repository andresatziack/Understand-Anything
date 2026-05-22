# Snippet de Prompt da Linguagem Go

## Conceitos-Chave

- **Goroutines**: funções concorrentes leves disparadas com a palavra-chave `go`
- **Channels**: condutos tipados para comunicação e sincronização entre goroutines
- **Interfaces**: contratos satisfeitos implicitamente — não é necessária a palavra-chave `implements`
- **Struct Embedding**: mecanismo de composição que oferece promoção de campos e métodos
- **Tratamento de Erros**: valores de erro retornados explicitamente (interface `error`) em vez de exceções
- **Defer/Panic/Recover**: cleanup adiado, erros irrecuperáveis e mecanismo de recuperação
- **Slices vs Arrays**: arrays têm tamanho fixo e são valores; slices são views dinâmicas apoiadas por arrays
- **Pointers**: tipos de pointer explícitos para semântica de pass-by-reference (sem aritmética de ponteiros)
- **Propagação de Context**: `context.Context` carrega deadlines, cancelamento e valores escopados à requisição
- **Init Functions**: `init()` em nível de package roda automaticamente antes de `main()` para setup

## Padrões de Importação

- `import "package"` — importação de um único package
- `import alias "package"` — importação com alias para evitar conflitos de nome
- `import ( ... )` — bloco de imports agrupados (biblioteca padrão, depois externos, depois internos)
- `import _ "package"` — import em branco apenas para efeitos colaterais (por exemplo, registro de driver)

## Padrões de Arquivos

- `*_test.go` — arquivos de teste no mesmo package (ou em um package `_test` para testes black-box)
- `cmd/` — diretório contendo packages main (pontos de entrada de binários)
- `internal/` — packages importáveis apenas pelo módulo pai (imposto pelo compilador)
- `pkg/` — packages de biblioteca pública (convenção, não imposta)
- `go.mod` — definição do módulo com versões de dependências
- `go.sum` — checksums criptográficos das dependências

## Frameworks Comuns

- **Gin** — framework HTTP de alta performance com suporte a middleware
- **Echo** — framework web minimalista com middleware embutido
- **Fiber** — framework inspirado no Express construído sobre fasthttp
- **Chi** — router HTTP leve e composável
- **GORM** — biblioteca ORM com associations, hooks e migrations

## Exemplo de Notas da Linguagem

> Implementa a interface `io.Reader` implicitamente — nenhuma declaração explícita é
> necessária, apenas assinaturas de método correspondentes. Isso permite que qualquer
> tipo com um método `Read([]byte) (int, error)` seja usado onde quer que `io.Reader`
> seja esperado.
>
> O diretório `internal/` impõe encapsulamento no nível do compilador, impedindo que
> packages externos importem detalhes de implementação — mais forte do que uma
> convenção de nomenclatura.
