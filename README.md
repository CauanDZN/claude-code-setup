# claude-code-setup

Scripts para automatizar a configuração do [Claude Code](https://claude.com/claude-code) com um conjunto padrão de marketplaces e plugins:

- [`claude-mem`](https://github.com/thedotmack/claude-mem) — memória persistente entre sessões
- [`superpowers`](https://github.com/anthropics/claude-plugins-official) — hábitos de planejamento, teste e depuração
- [`ecc`](https://github.com/affaan-m/ECC) — agentes e skills especializados
- `chrome-devtools-mcp` — controle do navegador via Chrome DevTools
- `watch` (claude-video) — baixar e resumir vídeos

Os scripts são **idempotentes**: rode quantas vezes quiser, eles só instalam/habilitam o que ainda estiver faltando.

## Pré-requisitos

- [Claude Code](https://claude.com/claude-code) instalado (comando `claude` disponível)
- Node.js/npm (recomendado — alguns plugins, como o `claude-mem`, podem precisar)

Se o `claude` não estiver no PATH, os scripts tentam adicionar `~/.local/bin` automaticamente (só nesta sessão do terminal).

## Uso

### Windows (PowerShell)

```powershell
.\setup-claude.ps1
```

Funciona no PowerShell 5.1 (padrão do Windows) e também no PowerShell 7+ (`pwsh`).

### Linux / macOS / WSL / Git Bash

```bash
chmod +x setup-claude.sh
./setup-claude.sh
```

## O que o script faz

1. Verifica se `claude` está no PATH e mostra a versão instalada
2. Verifica se Node.js/npm estão disponíveis
3. Adiciona os marketplaces necessários (`claude-plugins-official`, `thedotmack`, `ecc`, `claude-video`), pulando os que já existem
4. Instala os plugins listados acima, habilitando os que estiverem desabilitados e pulando os que já estão prontos
5. Imprime um relatório final `[OK]` / `[FALTA]` por plugin

Ao final, **feche e reabra o Claude Code** para os plugins carregarem.

## Solução de problemas

- **`claude` não encontrado**: confirme que o Claude Code está instalado e que o diretório do executável está no PATH.
- **Falha ao instalar um plugin**: rode o script de novo — ele é idempotente e só tenta de novo o que falhou. Se persistir, tente manualmente dentro do Claude Code: `/plugin install <nome>@<marketplace>`.
