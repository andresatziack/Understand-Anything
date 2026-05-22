# Snippet de Prompt da Linguagem Java

## Conceitos-Chave

- **Generics (com Erasure)**: tipos parametrizados apagados em runtime; segurança apenas em tempo de compilação
- **Annotations**: marcadores de metadados (`@Override`, `@Autowired`) processados em tempo de compilação ou runtime
- **Interfaces e Classes Abstratas**: contratos com default methods (Java 8+) e implementações parciais
- **Streams API**: operações em pipeline em estilo funcional sobre coleções (filter, map, reduce)
- **Lambdas**: sintaxe concisa de função anônima para functional interfaces
- **Sealed Classes**: hierarquias de classe restritas com subclasses permitidas explicitamente (Java 17+)
- **Records**: carriers de dados imutáveis com accessors, equals e hashCode auto-gerados (Java 16+)
- **Dependency Injection**: padrão IoC central no Spring; injeção via construtor, campo ou método
- **Checked vs Unchecked Exceptions**: checked devem ser declaradas ou capturadas; unchecked estendem RuntimeException
- **Optional**: container para valores nuláveis incentivando tratamento explícito em vez de null checks

## Padrões de Importação

- `import package.Class` — importa uma classe específica
- `import package.*` — import wildcard de todas as classes em um package
- `import static package.Class.method` — static import para acesso direto a métodos/constantes

## Padrões de Arquivos

- `src/main/java/` — raiz dos fontes seguindo o layout padrão do Maven/Gradle
- `src/test/java/` — raiz dos fontes de teste com estrutura de package equivalente
- `pom.xml` — configuração do projeto Maven e gerenciamento de dependências
- `build.gradle` — script de build do Gradle (DSL Groovy ou Kotlin)
- `Application.java` — ponto de entrada do Spring Boot com `@SpringBootApplication`

## Frameworks Comuns

- **Spring Boot** — framework opinionado para aplicações Spring prontas para produção
- **Jakarta EE** — padrões de Java empresarial (anteriormente Java EE) para desenvolvimento server-side
- **Quarkus** — framework cloud-native otimizado para GraalVM e containers
- **Micronaut** — framework de DI em tempo de compilação para microsserviços e serverless
- **Hibernate** — framework ORM que implementa a especificação JPA

## Exemplo de Notas da Linguagem

> Usa a annotation `@Autowired` para injeção via construtor, seguindo o padrão de
> container IoC do Spring. Injeção via construtor é preferida em relação à injeção
> em campo porque torna as dependências explícitas e habilita imutabilidade.
>
> O layout de diretórios padrão do Maven (`src/main/java`, `src/test/java`) é uma
> convenção forte — a maioria das ferramentas de build e IDEs espera essa estrutura
> por padrão.
