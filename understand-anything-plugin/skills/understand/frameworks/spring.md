# Adendo do Framework Spring Boot

> Injetado nos prompts do file-analyzer e do architecture-analyzer quando Spring Boot é detectado.
> NÃO use como prompt independente — sempre anexado ao template de prompt base.

## Estrutura de Projeto Spring Boot

Ao analisar um projeto Spring Boot, aplique estas convenções adicionais sobre as regras base de análise.

### Funções Canônicas de Arquivos

| Arquivo / Padrão | Função | Tags |
|---|---|---|
| `*Application.java`, `*Application.kt` | Ponto de entrada da aplicação — classe `@SpringBootApplication` com método `main()` | `entry-point`, `config` |
| `*Controller.java`, `*RestController.java` | Controllers REST — lidam com requisições HTTP e delegam para services | `api-handler` |
| `*Service.java` | Interfaces de service — definem contratos de operações de negócio | `service` |
| `*ServiceImpl.java` | Implementações de service — contêm a lógica de negócio | `service` |
| `*Repository.java` | Repositories do Spring Data — interfaces de acesso a dados que estendem JpaRepository/CrudRepository | `data-model` |
| `*Entity.java` | Entidades JPA — mapeiam para tabelas do banco via annotation `@Entity` | `data-model` |
| `*DTO.java`, `*Request.java`, `*Response.java` | Data transfer objects — payloads de request/response | `type-definition` |
| `*Config.java`, `*Configuration.java` | Classes de configuração — beans `@Configuration`, configuração de segurança, configuração web | `config` |
| `*Filter.java` | Filtros de servlet — interceptam requisições antes que cheguem aos controllers | `middleware` |
| `*Interceptor.java` | Handler interceptors — pré e pós processamento ao redor de métodos de controller | `middleware` |
| `*Advice.java`, `*ExceptionHandler.java` | Controller advice — tratamento global de exceções e wrapping de respostas | `middleware` |
| `*Mapper.java` | Mappers de objetos — convertem entre entidades e DTOs (MapStruct, ModelMapper) | `utility` |
| `application.yml`, `application.properties` | Configuração da aplicação — profiles, datasource, configurações do servidor | `config` |
| `*Test.java`, `*Tests.java`, `*IT.java` | Testes unitários, testes de integração | `test` |

### Padrões de Aresta a Procurar

**Injeção via @Autowired** — Quando uma classe injeta uma dependência via `@Autowired`, injeção via construtor ou `@Inject`, crie arestas `depends_on` do consumidor para o bean injetado. Injeção via construtor é preferida e a mais comum no Spring moderno.

**Cadeia Controller-Service-Repository** — A cadeia de chamadas canônica é `@RestController` -> `@Service` -> `@Repository`. Crie arestas `depends_on` ao longo dessa cadeia para mostrar a arquitetura em camadas.

**Relacionamentos de @Entity** — Quando entidades definem annotations `@OneToMany`, `@ManyToOne`, `@OneToOne` ou `@ManyToMany`, crie arestas `depends_on` entre as classes de entidade com descrições indicando o tipo e a direção do relacionamento.

**Definições de bean em @Configuration** — Quando uma classe `@Configuration` define métodos `@Bean`, crie arestas `configures` da classe de configuração para os tipos que ela produz. Esses beans ficam disponíveis para injeção em toda a aplicação.

### Camadas Arquiteturais para Spring Boot

Atribua nós a estas camadas quando detectadas:

| ID da Camada | Nome da Camada | O Que Vai Aqui |
|---|---|---|
| `layer:api` | API Layer | `*Controller.java`, endpoints REST, documentação de API |
| `layer:service` | Service Layer | `*Service.java`, `*ServiceImpl.java`, lógica de negócio |
| `layer:data` | Data Layer | `*Repository.java`, `*Entity.java`, mapeamentos JPA, migrations de banco |
| `layer:types` | Types Layer | `*DTO.java`, `*Request.java`, `*Response.java`, value objects compartilhados |
| `layer:config` | Config Layer | `*Configuration.java`, `application.yml`, configuração de segurança, `*Application.java` |
| `layer:middleware` | Middleware Layer | `*Filter.java`, `*Interceptor.java`, `*Advice.java`, filtros de segurança |
| `layer:test` | Test Layer | `*Test.java`, `*Tests.java`, `*IT.java`, configuração de teste |

### Padrões Notáveis a Capturar em languageLesson

- **Injeção de dependências via construtor**: o Spring favorece injeção via construtor em vez de injeção em campo (`@Autowired` em campos) — torna as dependências explícitas, suporta imutabilidade e simplifica testes
- **Arquitetura em camadas (Controller -> Service -> Repository)**: aplicações Spring Boot seguem um padrão estrito em camadas em que controllers lidam com HTTP, services contêm lógica de negócio e repositories gerenciam persistência
- **Cadeia de filtros do Spring Security**: a segurança é implementada como uma cadeia de filtros de servlet — beans `SecurityFilterChain` configuram autenticação, autorização, CORS e proteção contra CSRF
- **Ciclo de vida de entidades JPA**: entidades transitam por estados (transient, managed, detached, removed) — entender esse ciclo de vida é essencial para rastrear o fluxo de dados pela camada de persistência
- **AOP para preocupações transversais**: classes `@Aspect` com advice `@Before`, `@After` e `@Around` injetam comportamento em pontos de junção — usadas para logging, transações (`@Transactional`) e cache (`@Cacheable`)
