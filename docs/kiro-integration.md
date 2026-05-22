# Integração com Kiro

Guia em português do Brasil para usar o plugin **Understand Anything** dentro do Kiro. Comandos, paths, nomes de ferramentas e snippets de código permanecem em inglês.

## O que é o Kiro

Kiro é o IDE/agente de IA construído pela AWS. Ele lê arquivos markdown em `.kiro/steering/*.md` (escopo do projeto) e em `~/.kiro/steering/*.md` (escopo global do usuário) como contexto persistente: cada vez que o agente responde, ele já parte daquele conjunto de instruções. Isso significa que, se você instalar o steering file deste plugin, o Kiro saberá *quando* e *como* invocar cada slash command sem precisar de recordatório a cada sessão.

## Pré-requisitos

- Kiro IDE ou Kiro Web instalado (qualquer versão recente que suporte steering files).
- Este repositório clonado **ou** acesso a `curl`/`PowerShell` para rodar o instalador remoto.
- Node 18+ e `pnpm` apenas se você for buildar/contribuir; para uso final do plugin não é necessário.

## Instalação rápida

Existem dois caminhos suportados.

**1) Auto-discovery (recomendado para um único repositório)**

```bash
git clone https://github.com/Lum1104/Understand-Anything
cd Understand-Anything
# abra a pasta no Kiro
```

O Kiro detecta `.kiro-plugin/plugin.json` na raiz e carrega skills e agents automaticamente. Em paralelo, o arquivo `.kiro/steering/understand-anything.md` (também na raiz do repositório) é lido pelo escopo padrão de steering do Kiro, o que faz com que o agente já saiba quando e como invocar cada slash command sem nenhuma instalação extra.

**2) Instalação global (skills disponíveis em todos os projetos)**

macOS / Linux:

```bash
./install.sh kiro
# ou via curl:
curl -fsSL https://raw.githubusercontent.com/Lum1104/Understand-Anything/main/install.sh | bash -s kiro
```

Windows (PowerShell):

```powershell
./install.ps1 kiro
```

Reinicie o Kiro depois da instalação para que ele leia o steering file recém-copiado.

## Limite de confiança (curl-pipe vs. clone-then-install)

O steering file não é apenas documentação: ele molda como o agente interpreta os prompts **antes** de você digitar qualquer coisa, mapeando intenções em linguagem natural para slash commands específicos. A instalação via curl-pipe (`curl -fsSL ... | bash -s kiro`) faz três coisas em sequência sem nenhuma checagem de integridade — sem checksum, sem assinatura GPG, sem pin de versão:

1. clona o repositório em `~/.understand-anything/repo`;
2. cria symlinks de cada skill em `~/.kiro/skills/`;
3. copia o steering file para `~/.kiro/steering/understand-anything.md`.

Isso é equivalente, em termos de superfície de ataque, a executar qualquer outro `curl ... | bash`. A diferença é que o passo (3) é qualitativamente distinto: ele não só *adiciona* skills disponíveis, ele *muda* como o agente decide invocá-las em sessões futuras. Para ambientes de maior confiança (máquinas corporativas, clientes pagos, projetos sensíveis), prefira o fluxo:

```bash
git clone https://github.com/Lum1104/Understand-Anything
cd Understand-Anything
# revise .kiro/steering/understand-anything.md antes de prosseguir
./install.sh kiro
```

Assim você consegue inspecionar exatamente o conteúdo do steering file (e dos `SKILL.md` de cada skill) antes que eles sejam copiados para `~/.kiro/steering/` e ligados em `~/.kiro/skills/`.

## Estrutura criada pelo instalador

O instalador faz duas coisas distintas em uma única execução:

| Caminho | Tipo | Origem |
|---------|------|--------|
| `~/.kiro/skills/<skill-name>` | symlink (Unix) ou junction (Windows) | `understand-anything-plugin/skills/<skill-name>/` |
| `~/.kiro/steering/understand-anything.md` | cópia de arquivo | `understand-anything-plugin/.kiro/steering/understand-anything.md` |
| `~/.understand-anything-plugin` | symlink/junction universal | `understand-anything-plugin/` |

Por que cópia (e não symlink) para o steering file? Porque o Kiro usa o steering file como configuração global do usuário; se o repositório clonado for movido ou removido, queremos que a orientação persistente continue funcionando. Skills podem ser symlinks porque ficam atrelados ao checkout: se o checkout sumir, o skill também deve sumir.

## Como invocar o plugin no Kiro

Há dois fluxos típicos.

**Fluxo 1 — slash command direto.** Digite o comando e deixe o Kiro localizar o `SKILL.md` correspondente:

```
/understand
/understand-dashboard
/understand-chat How does the auth flow work?
/understand-diff
/understand-explain src/server.ts
/understand-onboard
/understand-domain
/understand-knowledge ~/wikis/my-wiki
```

**Fluxo 2 — linguagem natural.** Descreva o objetivo em PT-BR e deixe o Kiro escolher a skill certa a partir do steering file:

```
"Quero entender este repositório do zero — gere o knowledge graph e abra o dashboard."
"Explique o arquivo src/auth/login.ts em detalhes."
"Compare a branch atual com main e me diga o impacto."
```

O steering file mapeia intenções comuns para o slash command apropriado, então o Kiro consegue redirecionar a conversa para a skill correta sem que você decore os nomes.

## Saída em Português do Brasil

Para gerar nós do grafo, sumários e UI do dashboard em PT-BR:

```bash
/understand --language pt-BR
/understand-dashboard --language pt-BR
/understand-knowledge ~/wikis/my-wiki --language pt-BR
```

A flag `--language pt-BR` faz com que o pipeline carregue `understand-anything-plugin/skills/understand/locales/pt-BR.md` como guia de estilo (tags, sumários, nomes de camadas, glossário). Termos técnicos consagrados (`middleware`, `hook`, `entry-point`, `ORM`, `REST API`, `CI/CD`, `CRUD`, `singleton`, `factory`, `observer`, `interceptor`, `guard`) permanecem em inglês.

A preferência de idioma é gravada em `.understand-anything/config.json` na raiz do projeto analisado, então execuções subsequentes (`/understand-chat`, `/understand-diff`, `/understand-explain`) continuam respondendo em PT-BR sem a flag.

## Solução de problemas

**Skills não aparecem no Kiro.**
- Reinicie o Kiro completamente (não apenas a janela do projeto).
- Confirme que `~/.kiro/skills/` existe e contém os links: `ls -la ~/.kiro/skills/`.
- Se você instalou via repositório local, confirme que `.kiro-plugin/plugin.json` está presente na raiz do repo aberto.

**Steering file ignorado.**
- Verifique se `~/.kiro/steering/understand-anything.md` existe e está legível: `ls -la ~/.kiro/steering/understand-anything.md`.
- Confirme que o arquivo **não** começa com `---` (steering files não usam YAML front-matter).
- Reinicie o Kiro depois de qualquer alteração no diretório `steering/`.

**`pt-BR` não é reconhecido.**
- Confirme que a versão instalada é a 2.7.5 ou superior: `cat ~/.understand-anything-plugin/package.json | grep version`.
- Se você fez auto-discovery, atualize o repositório: `git pull` na pasta do clone.
- Se você fez instalação global, rode `./install.sh --update` para puxar as últimas mudanças.

**O comando reclama que não encontra `SKILL.md`.**
- Liste os skills disponíveis: `ls ~/.kiro/skills/`.
- Se algum skill estiver faltando, reinstale: `./install.sh --uninstall kiro && ./install.sh kiro`.

## Desinstalação

macOS / Linux:

```bash
./install.sh --uninstall kiro
```

Windows (PowerShell):

```powershell
./install.ps1 -Uninstall kiro
```

A desinstalação remove:

- todos os symlinks/junctions sob `~/.kiro/skills/` que apontam para este plugin;
- a cópia do steering file em `~/.kiro/steering/understand-anything.md`;
- o link universal `~/.understand-anything-plugin` (se outras plataformas não estiverem mais usando o checkout).

O clone em `~/.understand-anything/repo` é preservado, porque outras plataformas instaladas podem depender dele. Para remover por completo:

```bash
rm -rf ~/.understand-anything/repo
```

```powershell
Remove-Item -Recurse -Force "$HOME\.understand-anything\repo"
```
