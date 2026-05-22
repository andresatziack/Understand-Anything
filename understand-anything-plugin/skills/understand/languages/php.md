# Snippet de Prompt da Linguagem PHP

## Conceitos-Chave

- **Namespaces**: organizam o código e evitam colisões de nomenclatura usando caminhos delimitados por backslash
- **Traits**: mecanismo de reuso horizontal de código para compartilhar métodos entre classes não relacionadas
- **Type Declarations**: tipos de parâmetro, retorno e propriedade (tipos scalar, union, intersection)
- **Attributes (PHP 8+)**: anotações de metadados nativas que substituem configurações baseadas em docblocks
- **Enums (PHP 8.1+)**: tipos de enumeração de primeira classe com métodos e implementação de interface
- **Fibers**: primitivas leves de concorrência cooperativa para I/O não bloqueante
- **Closures/Funções Anônimas**: funções de primeira classe com `use` explícito para captura de variáveis
- **Magic Methods**: métodos especiais como `__construct`, `__get`, `__set`, `__call` para comportamento de objeto
- **Dependency Injection**: injeção via construtor gerenciada por containers compatíveis com PSR-11
- **Middleware**: padrão de pipeline de request/response central em frameworks PHP modernos

## Padrões de Importação

- `use Namespace\ClassName` — importa uma classe pelo seu nome totalmente qualificado
- `use Namespace\ClassName as Alias` — importa com um alias para evitar conflitos
- `namespace App\Http\Controllers` — declara o namespace do arquivo atual
- `use function Namespace\functionName` — importa uma função com namespace

## Padrões de Arquivos

- `composer.json` — gerenciamento de dependências e configuração de autoloading PSR-4
- `index.php` — ponto de entrada da aplicação web (front controller)
- `artisan` — ponto de entrada CLI do Laravel para comandos e migrations
- `routes/` — arquivos de definição de rotas (web.php, api.php no Laravel)
- O autoloading PSR-4 mapeia prefixos de namespace para caminhos de diretório

## Frameworks Comuns

- **Laravel** — framework completo com ORM Eloquent, templates Blade e queues
- **Symfony** — framework baseado em componentes que sustenta muitos projetos e bibliotecas PHP
- **WordPress** — plataforma CMS com arquitetura de plugins baseada em hooks
- **Slim** — micro-framework para APIs e pequenas aplicações
- **CodeIgniter** — framework MVC leve com configuração mínima

## Exemplo de Notas da Linguagem

> Usa attributes do PHP 8 `#[Route('/api/users')]` para mapeamento declarativo de
> rotas em métodos de controller. Attributes substituem o padrão antigo de anotações
> em docblock, fornecendo suporte nativo da linguagem para metadados que ferramentas
> podem inspecionar via reflection.
>
> O autoloading PSR-4 em `composer.json` mapeia `App\` para `src/`, então a classe
> `App\Http\Controllers\UserController` é carregada de `src/Http/Controllers/UserController.php`.
