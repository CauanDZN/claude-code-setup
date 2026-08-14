#!/usr/bin/env bash
#
# setup-claude.sh
# Automates configuring Claude Code with a standard set of marketplaces/plugins:
# claude-mem, superpowers, ECC, chrome-devtools-mcp, watch (claude-video).
# Idempotent: safe to re-run, skips anything already installed/enabled.
#
# For Linux, macOS, WSL, Git Bash. Windows PowerShell users: use setup-claude.ps1.

set +e

if [ -t 1 ]; then
    COLOR_OK="\033[0;32m"
    COLOR_SKIP="\033[0;90m"
    COLOR_WARN="\033[0;33m"
    COLOR_ERR="\033[0;31m"
    COLOR_CYAN="\033[0;36m"
    COLOR_RESET="\033[0m"
else
    COLOR_OK="" COLOR_SKIP="" COLOR_WARN="" COLOR_ERR="" COLOR_CYAN="" COLOR_RESET=""
fi

section() { printf "\n${COLOR_CYAN}== %s ==${COLOR_RESET}\n" "$1"; }
ok()      { printf "  ${COLOR_OK}[OK]${COLOR_RESET}    %s\n" "$1"; }
skip()    { printf "  ${COLOR_SKIP}[SKIP]${COLOR_RESET}  %s\n" "$1"; }
warn()    { printf "  ${COLOR_WARN}[WARN]${COLOR_RESET}  %s\n" "$1"; }
err()     { printf "  ${COLOR_ERR}[ERRO]${COLOR_RESET}  %s\n" "$1"; }

# ---------------------------------------------------------------------------
# 1. Pre-requisites
# ---------------------------------------------------------------------------
section "Verificando pre-requisitos"

if ! command -v claude >/dev/null 2>&1; then
    LOCAL_BIN="$HOME/.local/bin"
    if [ -x "$LOCAL_BIN/claude" ]; then
        warn "'claude' nao encontrado no PATH. Adicionando '$LOCAL_BIN' ao PATH desta sessao..."
        export PATH="$PATH:$LOCAL_BIN"
    fi
fi

if ! command -v claude >/dev/null 2>&1; then
    err "Claude Code (comando 'claude') nao foi encontrado no PATH."
    echo "  Instale o Claude Code e rode este script novamente, ou adicione manualmente"
    echo "  o diretorio do executavel ao PATH."
    exit 1
fi

CLAUDE_VERSION="$(claude --version 2>&1)"
ok "Claude Code encontrado: $CLAUDE_VERSION"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    ok "Node.js $(node --version) / npm v$(npm --version) encontrados"
else
    warn "Node.js/npm nao encontrados no PATH. Alguns plugins (ex: claude-mem) podem precisar deles."
fi

# ---------------------------------------------------------------------------
# 2. Marketplaces
# ---------------------------------------------------------------------------
section "Configurando marketplaces"

MARKETPLACES="claude-plugins-official|anthropics/claude-plugins-official
thedotmack|thedotmack/claude-mem
ecc|https://github.com/affaan-m/ECC
claude-video|bradautomates/claude-video"

MARKETPLACE_LIST="$(claude plugin marketplace list 2>&1)"

while IFS='|' read -r name source; do
    [ -z "$name" ] && continue
    if echo "$MARKETPLACE_LIST" | grep -q -- "$name"; then
        skip "Marketplace '$name' ja configurado"
        continue
    fi

    echo "  Adicionando marketplace '$name' ($source)..."
    if claude plugin marketplace add "$source" >/dev/null 2>&1; then
        ok "Marketplace '$name' adicionado"
        MARKETPLACE_LIST="$(claude plugin marketplace list 2>&1)"
    else
        err "Falha ao adicionar marketplace '$name'"
    fi
done <<EOF
$MARKETPLACES
EOF

# ---------------------------------------------------------------------------
# 3. Plugins
# ---------------------------------------------------------------------------
section "Instalando/habilitando plugins"

PLUGINS="claude-mem@thedotmack|claude-mem
superpowers@claude-plugins-official|superpowers
ecc@ecc|ECC
chrome-devtools-mcp@claude-plugins-official|chrome-devtools-mcp
watch@claude-video|watch (claude-video)"

get_plugin_status() {
    plugin_id="$1"
    list_raw="$(claude plugin list 2>&1)"
    if ! echo "$list_raw" | grep -q -- "$plugin_id"; then
        echo "missing"
        return
    fi

    in_block=0
    is_enabled=0
    while IFS= read -r line; do
        case "$line" in
            *"❯"*)
                if [ "$in_block" -eq 1 ]; then
                    break
                fi
                case "$line" in
                    *"$plugin_id"*) in_block=1 ;;
                    *) in_block=0 ;;
                esac
                ;;
            *)
                if [ "$in_block" -eq 1 ]; then
                    case "$line" in
                        *nabled*) is_enabled=1 ;;
                    esac
                fi
                ;;
        esac
    done <<EOF2
$list_raw
EOF2

    if [ "$is_enabled" -eq 1 ]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

while IFS='|' read -r plugin_id label; do
    [ -z "$plugin_id" ] && continue
    status="$(get_plugin_status "$plugin_id")"

    case "$status" in
        enabled)
            skip "$label ja instalado e habilitado"
            ;;
        disabled)
            echo "  Habilitando $label..."
            if claude plugin enable "$plugin_id" >/dev/null 2>&1; then
                ok "$label habilitado"
            else
                err "Falha ao habilitar $label"
            fi
            ;;
        missing)
            echo "  Instalando $label..."
            if claude plugin install "$plugin_id" -y >/dev/null 2>&1; then
                ok "$label instalado"
            else
                err "Falha ao instalar $label"
            fi
            ;;
    esac
done <<EOF
$PLUGINS
EOF

# ---------------------------------------------------------------------------
# 4. Relatorio final
# ---------------------------------------------------------------------------
echo ""
printf "${COLOR_CYAN}========================================${COLOR_RESET}\n"
printf "${COLOR_CYAN}           CLAUDE CODE SETUP${COLOR_RESET}\n"
printf "${COLOR_CYAN}========================================${COLOR_RESET}\n"
printf "${COLOR_OK}[OK] Claude Code %s${COLOR_RESET}\n" "$CLAUDE_VERSION"

ALL_OK=1
while IFS='|' read -r plugin_id label; do
    [ -z "$plugin_id" ] && continue
    status="$(get_plugin_status "$plugin_id")"
    if [ "$status" = "enabled" ]; then
        printf "${COLOR_OK}[OK] %s${COLOR_RESET}\n" "$label"
    else
        printf "${COLOR_ERR}[FALTA] %s (status: %s)${COLOR_RESET}\n" "$label" "$status"
        ALL_OK=0
    fi
done <<EOF
$PLUGINS
EOF

printf "${COLOR_CYAN}========================================${COLOR_RESET}\n"
if [ "$ALL_OK" -eq 1 ]; then
    printf "${COLOR_OK}Setup concluido!${COLOR_RESET}\n"
else
    printf "${COLOR_WARN}Setup concluido com pendencias (veja [FALTA] acima).${COLOR_RESET}\n"
fi
printf "${COLOR_CYAN}========================================${COLOR_RESET}\n"
echo ""
printf "${COLOR_WARN}Feche e reabra o Claude Code para os plugins carregarem.${COLOR_RESET}\n"
