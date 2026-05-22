# Snippet de Prompt da Linguagem Swift

## Conceitos-Chave

- **Optionals e Optional Chaining**: `Type?` envolve valores que podem ser nil; `?.` encadeia com segurança
- **Protocols e Protocol Extensions**: definem contratos com implementações padrão via extensions
- **Value Types vs Reference Types**: structs e enums são value types; classes são reference types
- **Closures**: blocos autocontidos de funcionalidade que capturam o contexto ao redor
- **Property Wrappers**: `@State`, `@Binding`, `@Published` encapsulam a lógica de armazenamento de propriedades
- **Result Builders**: `@ViewBuilder`, `@resultBuilder` habilitam sintaxe declarativa de DSL
- **Actors e Concorrência Estruturada**: tipos `actor` para isolamento de dados; `async let`, `TaskGroup`
- **Generics**: parâmetros de tipo com cláusulas `where` e constraints de associated type
- **Enums com Associated Values**: cada case pode carregar payloads tipados distintos
- **Extensions**: adicionam métodos, computed properties e conformance a protocolos a tipos existentes

## Padrões de Importação

- `import Foundation` — biblioteca core com tipos de dados, coleções, networking
- `import UIKit` — framework de UI iOS para arquitetura tradicional de view controllers
- `import SwiftUI` — framework de UI declarativo com gerenciamento reativo de estado
- `@testable import ModuleName` — import com acesso interno para testes unitários

## Padrões de Arquivos

- `Package.swift` — manifesto do Swift Package Manager definindo targets e dependências
- `*.xcodeproj` / `*.xcworkspace` — configuração de projeto e workspace do Xcode
- `AppDelegate.swift` — ponto de entrada do ciclo de vida da aplicação UIKit
- `App.swift` — ponto de entrada de aplicação SwiftUI usando `@main`
- `Tests/` — diretório de target de teste seguindo convenções do SPM ou Xcode

## Frameworks Comuns

- **SwiftUI** — framework de UI declarativo com fluxo de dados reativo
- **UIKit** — framework de UI imperativo usando view controllers e Auto Layout
- **Vapor** — framework web server-side em Swift com suporte async
- **Combine** — framework reativo para processar valores ao longo do tempo
- **Core Data** — framework de grafo de objetos e persistência

## Exemplo de Notas da Linguagem

> Usa o property wrapper `@Published` para notificar automaticamente as views SwiftUI
> sobre mudanças de estado. Quando o valor encapsulado é mutado, o property wrapper
> dispara `objectWillChange` no `ObservableObject` envolvente, fazendo com que as
> views dependentes sejam re-renderizadas.
>
> Protocol extensions fornecem implementações padrão, permitindo que tipos se conformem
> simplesmente declarando conformance — nenhum corpo de método é necessário se os
> defaults forem suficientes.
