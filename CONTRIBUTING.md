# Contribuindo para Understand Anything

Obrigado pelo interesse em contribuir com o Understand Anything! Este documento traz orientações e instruções para contribuir com o projeto.

## 🌟 Formas de Contribuir

- **Reports de bug**: Encontrou um bug? Abra uma issue com passos detalhados para reproduzir
- **Pedidos de funcionalidade**: Tem uma ideia? Compartilhe na seção de issues
- **Documentação**: Melhore ou traduza a documentação
- **Código**: Corrija bugs, adicione funcionalidades ou melhore a performance
- **Testes**: Escreva testes para aumentar a cobertura

## 🚀 Começando

### Pré-requisitos

- Node.js >= 22 (desenvolvido na v24)
- pnpm >= 10 (fixado pelo campo `packageManager` no `package.json` da raiz)
- Git para versionamento

### Configuração

1. **Faça o fork e clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Understand-Anything.git
   cd Understand-Anything
   ```

2. **Instale as dependências**
   ```bash
   pnpm install
   ```

3. **Faça o build do pacote core**
   ```bash
   pnpm --filter @understand-anything/core build
   ```

4. **Rode os testes**
   ```bash
   pnpm --filter @understand-anything/core test
   pnpm --filter @understand-anything/skill test
   ```

5. **Suba o Dashboard (opcional)**
   ```bash
   pnpm dev:dashboard
   ```

## 📝 Fluxo de Desenvolvimento

### 1. Crie um Branch

Use um nome de branch descritivo:
```bash
git checkout -b feat/my-feature        # Para novas funcionalidades
git checkout -b fix/bug-description    # Para correções de bug
git checkout -b docs/update-readme     # Para documentação
```

### 2. Faça as Alterações

- Escreva código limpo e legível
- Siga o estilo e as convenções já presentes no código
- Adicione testes para o que for novo
- Atualize a documentação quando necessário

### 3. Teste Suas Alterações

```bash
# Roda todos os testes
pnpm --filter @understand-anything/core test
pnpm --filter @understand-anything/skill test

# Roda o linter
pnpm lint

# Faz o build dos pacotes
pnpm build
```

### 4. Faça o Commit

Escreva mensagens de commit claras e descritivas:
```bash
git add .
git commit -m "feat: add keyboard shortcuts to dashboard"
```

**Convenção de mensagens de commit:**
- `feat:` - nova funcionalidade
- `fix:` - correção de bug
- `docs:` - alteração na documentação
- `style:` - alterações de estilo de código (formatação, etc.)
- `refactor:` - refatoração de código
- `test:` - adição ou atualização de testes
- `chore:` - tarefas de manutenção

### 5. Faça o Push e Abra um Pull Request

```bash
git push origin your-branch-name
```

Em seguida, abra um Pull Request no GitHub com:
- Título claro descrevendo a mudança
- Descrição detalhada do que mudou e por quê
- Link para issues relacionadas (se houver)
- Screenshots (para mudanças de UI)

## 🧪 Diretrizes de Teste

### Escrevendo Testes

- Use Vitest para testar
- Coloque os testes em diretórios `__tests__` ou em arquivos `*.test.ts`
- Busque cobertura alta para funcionalidades novas
- Cubra edge cases e condições de erro

Estrutura de exemplo:
```typescript
import { describe, it, expect } from 'vitest';

describe('MyFeature', () => {
  it('should do something', () => {
    // Arrange
    const input = 'test';

    // Act
    const result = myFunction(input);

    // Assert
    expect(result).toBe('expected');
  });
});
```

### Rodando Testes

```bash
# Roda todos os testes
pnpm test

# Roda os testes de um pacote específico
pnpm --filter @understand-anything/core test

# Roda os testes em watch mode
pnpm --filter @understand-anything/core test --watch
```

## 📚 Diretrizes de Estilo de Código

### TypeScript

- Use TypeScript em strict mode
- Defina tipos explícitos para parâmetros de função e valores de retorno
- Evite o tipo `any` — use `unknown` quando o tipo for realmente desconhecido
- Use interfaces para descrever o formato de objetos
- Use type aliases para uniões e tipos complexos

### Formatação

- O projeto usa ESLint para qualidade de código
- Indentação consistente (2 espaços)
- Use nomes de variáveis e funções significativos
- Mantenha as funções pequenas e focadas

### React/Dashboard

- Use componentes funcionais com hooks
- Mantenha cada componente focado em um único papel
- Use Zustand para gerenciamento de estado
- Siga a estrutura de componentes existente

### Stack Técnica

TypeScript, pnpm workspaces, React 18, Vite, TailwindCSS v4, React Flow, Zustand, web-tree-sitter, Fuse.js, Zod, Dagre

### Organização de Arquivos

```
understand-anything-plugin/
├── packages/
│   ├── core/              # Core analysis engine
│   │   ├── src/
│   │   └── package.json
│   └── dashboard/         # React dashboard
│       ├── src/
│       │   ├── components/
│       │   ├── utils/
│       │   └── store.ts
│       └── package.json
├── src/                   # Plugin skills implementation
├── agents/                # AI agent prompts
└── skills/                # Skill definitions
```

## 🌍 Diretrizes de Tradução

### Adicionando um Novo Idioma

1. Crie `README.{language-code}.md` (por exemplo, `README.fr-FR.md`)
2. Traduza todas as seções mantendo a formatação
3. Atualize o `README.md` principal incluindo o link para o novo idioma
4. Mantenha termos técnicos em inglês quando fizer sentido
5. Garanta que todos os links continuem funcionando

Exemplo:
```markdown
<a href="README.md">English</a> | <a href="README.fr-FR.md">Français</a>
```

## 🐛 Reports de Bug

Ao reportar um bug, inclua:

- **Descrição**: descrição clara do problema
- **Passos para reproduzir**: passos detalhados que reproduzem o bug
- **Comportamento esperado**: o que você esperava que acontecesse
- **Comportamento real**: o que de fato aconteceu
- **Ambiente**: SO, versão do Node, versão do pnpm
- **Screenshots**: se aplicável
- **Mensagens de erro**: saída de erro completa

## 💡 Pedidos de Funcionalidade

Ao pedir uma funcionalidade nova:

- **Caso de uso**: descreva o problema que você está tentando resolver
- **Solução proposta**: como você imagina que a funcionalidade deve funcionar
- **Alternativas**: outras soluções que você já considerou
- **Contexto adicional**: qualquer outra informação relevante

## 📋 Checklist do Pull Request

Antes de submeter um PR, garanta que:

- [ ] O código segue as diretrizes de estilo do projeto
- [ ] Todos os testes passam (`pnpm test`)
- [ ] O código novo tem cobertura de testes
- [ ] A documentação foi atualizada (se necessário)
- [ ] As mensagens de commit seguem a convenção
- [ ] A descrição do PR explica claramente as mudanças
- [ ] Não ficou nenhum `console.log` ou código de debug perdido
- [ ] O branch está atualizado com o `main`

## 🤝 Processo de Code Review

1. **Checagens automatizadas**: a CI roda testes e lint
2. **Review do mantenedor**: os mantenedores do projeto revisam o código
3. **Feedback**: aplique as alterações solicitadas
4. **Aprovação**: depois de aprovado, o PR é mesclado
5. **Limpeza**: apague o seu branch após o merge

## 📞 Onde Pedir Ajuda

- **Issues**: para bugs e pedidos de funcionalidade
- **Discussions**: para perguntas e conversas em geral
- **Documentação**: cheque os documentos existentes primeiro

## 📄 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a MIT License.

## 🙏 Reconhecimento

Quem contribui é reconhecido em:
- Lista de contribuidores no GitHub
- Notas de release (para contribuições significativas)
- Menções especiais para contribuições excepcionais

---

**Obrigado por contribuir com o Understand Anything! Suas contribuições ajudam a tornar a compreensão de código acessível a todo mundo.** 🚀
