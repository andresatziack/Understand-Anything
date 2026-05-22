# Snippet de Prompt da Linguagem C++

## Conceitos-Chave

- **Templates**: templates de função, classe e variádicos para polimorfismo genérico em tempo de compilação
- **RAII**: Resource Acquisition Is Initialization — vincula o tempo de vida do recurso ao escopo do objeto
- **Smart Pointers**: `unique_ptr` (exclusivo), `shared_ptr` (com contagem de referências), `weak_ptr` (não proprietário)
- **Move Semantics**: rvalue references (`&&`) e `std::move` para transferência eficiente de recursos
- **Operator Overloading**: define comportamento customizado de operadores em tipos definidos pelo usuário
- **Funções Virtuais e Vtable**: polimorfismo em runtime via tabelas de despacho de métodos virtuais
- **Namespaces**: organizam símbolos e evitam colisões de nomes entre translation units
- **Constexpr**: avaliação em tempo de compilação de funções e variáveis para computação de custo zero em runtime
- **Lambda Expressions**: funções anônimas com listas de captura para closures
- **STL Containers e Algoritmos**: containers padrão (vector, map, set) e algoritmos genéricos
- **Concepts (C++20)**: restrições nomeadas em parâmetros de template, substituindo padrões SFINAE

## Padrões de Importação

- `#include <system_header>` — inclui headers da biblioteca padrão ou do sistema
- `#include "local_header.h"` — inclui arquivos de header locais ao projeto
- `using namespace std` — traz todos os nomes de std para o escopo (evite em headers)
- `using std::vector` — traz seletivamente nomes específicos para o escopo

## Padrões de Arquivos

- `.h` / `.hpp` — arquivos de header contendo declarações, templates e definições inline
- `.cpp` / `.cc` — arquivos de implementação com definições de função e dados estáticos
- `CMakeLists.txt` — configuração do sistema de build CMake
- `Makefile` — regras e targets de build baseados em Make
- `main.cpp` — ponto de entrada do programa contendo `int main()`

## Frameworks Comuns

- **Qt** — framework cross-platform de aplicações com mecanismo de signal/slot
- **Boost** — coleção extensa de bibliotecas portáveis revisadas por pares
- **Catch2** — framework de testes header-only com sintaxe estilo BDD
- **Google Test** — framework de testes com fixtures, asserções e mocking
- **gRPC** — framework RPC de alta performance para comunicação entre serviços

## Exemplo de Notas da Linguagem

> Usa `std::unique_ptr<T>` para posse baseada em RAII, garantindo limpeza determinística
> ao sair do escopo. O unique pointer não pode ser copiado, apenas movido, tornando a
> transferência de posse explícita e prevenindo erros acidentais de double-free.
>
> A separação entre header e implementação (`.h`/`.cpp`) controla as fronteiras de
> compilação — alterações em um arquivo `.cpp` recompilam apenas aquela translation
> unit, não todos os includers.
