<#
  setup-claude.ps1
  Automates configuring Claude Code with a standard set of marketplaces/plugins:
  claude-mem, superpowers, ECC, chrome-devtools-mcp, watch (claude-video).
  Idempotent: safe to re-run, skips anything already installed/enabled.

  Works on Windows PowerShell 5.1+ and on PowerShell 7+ (pwsh) on Linux/macOS.
  On Linux/macOS without pwsh, use setup-claude.sh instead.
#>

$ErrorActionPreference = 'Stop'

function Write-Section($text) {
    Write-Host ""
    Write-Host "== $text ==" -ForegroundColor Cyan
}

function Write-Ok($text)   { Write-Host "  [OK]    $text" -ForegroundColor Green }
function Write-Skip($text) { Write-Host "  [SKIP]  $text" -ForegroundColor DarkGray }
function Write-Warn($text) { Write-Host "  [WARN]  $text" -ForegroundColor Yellow }
function Write-Err($text)  { Write-Host "  [ERRO]  $text" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Pre-requisites
# ---------------------------------------------------------------------------
Write-Section "Verificando pre-requisitos"

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    $localBin = Join-Path (Join-Path $HOME ".local") "bin"
    if (Test-Path $localBin) {
        Write-Warn "'claude' nao encontrado no PATH. Adicionando '$localBin' ao PATH desta sessao..."
        $env:Path += [System.IO.Path]::PathSeparator + $localBin
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    }
}

if (-not $claudeCmd) {
    Write-Err "Claude Code (comando 'claude') nao foi encontrado no PATH."
    Write-Host "  Instale o Claude Code e rode este script novamente, ou adicione manualmente" -ForegroundColor Red
    Write-Host "  o diretorio do executavel ao PATH." -ForegroundColor Red
    exit 1
}

$claudeVersion = (claude --version 2>&1 | Out-String).Trim()
Write-Ok "Claude Code encontrado: $claudeVersion"

$node = Get-Command node -ErrorAction SilentlyContinue
$npm  = Get-Command npm -ErrorAction SilentlyContinue
if ($node -and $npm) {
    Write-Ok "Node.js $(node --version) / npm v$(npm --version) encontrados"
} else {
    Write-Warn "Node.js/npm nao encontrados no PATH. Alguns plugins (ex: claude-mem) podem precisar deles."
}

# ---------------------------------------------------------------------------
# 2. Marketplaces
# ---------------------------------------------------------------------------
Write-Section "Configurando marketplaces"

$marketplaces = @(
    @{ Name = "claude-plugins-official"; Source = "anthropics/claude-plugins-official" },
    @{ Name = "thedotmack";              Source = "thedotmack/claude-mem" },
    @{ Name = "ecc";                     Source = "https://github.com/affaan-m/ECC" },
    @{ Name = "claude-video";            Source = "bradautomates/claude-video" }
)

$marketplaceListRaw = (claude plugin marketplace list 2>&1 | Out-String)

foreach ($m in $marketplaces) {
    if ($marketplaceListRaw -match [regex]::Escape($m.Name)) {
        Write-Skip "Marketplace '$($m.Name)' ja configurado"
        continue
    }

    Write-Host "  Adicionando marketplace '$($m.Name)' ($($m.Source))..."
    claude plugin marketplace add $m.Source 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Marketplace '$($m.Name)' adicionado"
        $marketplaceListRaw = (claude plugin marketplace list 2>&1 | Out-String)
    } else {
        Write-Err "Falha ao adicionar marketplace '$($m.Name)'"
    }
}

# ---------------------------------------------------------------------------
# 3. Plugins
# ---------------------------------------------------------------------------
Write-Section "Instalando/habilitando plugins"

$plugins = @(
    @{ Id = "claude-mem@thedotmack";              Label = "claude-mem" },
    @{ Id = "superpowers@claude-plugins-official"; Label = "superpowers" },
    @{ Id = "ecc@ecc";                             Label = "ECC" },
    @{ Id = "chrome-devtools-mcp@claude-plugins-official"; Label = "chrome-devtools-mcp" },
    @{ Id = "watch@claude-video";                  Label = "watch (claude-video)" }
)

function Get-PluginStatus($pluginId) {
    $listRaw = (claude plugin list 2>&1 | Out-String)
    if ($listRaw -notmatch [regex]::Escape($pluginId)) {
        return "missing"
    }
    $block = ($listRaw -split "(?=❯)") | Where-Object { $_ -match [regex]::Escape($pluginId) }
    if ($block -match "enabled") {
        return "enabled"
    }
    return "disabled"
}

foreach ($p in $plugins) {
    $status = Get-PluginStatus $p.Id

    switch ($status) {
        "enabled" {
            Write-Skip "$($p.Label) ja instalado e habilitado"
        }
        "disabled" {
            Write-Host "  Habilitando $($p.Label)..."
            claude plugin enable $p.Id 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$($p.Label) habilitado" }
            else { Write-Err "Falha ao habilitar $($p.Label)" }
        }
        "missing" {
            Write-Host "  Instalando $($p.Label)..."
            claude plugin install $p.Id -y 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$($p.Label) instalado" }
            else { Write-Err "Falha ao instalar $($p.Label)" }
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Relatorio final
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           CLAUDE CODE SETUP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[OK] Claude Code $claudeVersion" -ForegroundColor Green

$finalListRaw = (claude plugin list 2>&1 | Out-String)
$allOk = $true

foreach ($p in $plugins) {
    $status = Get-PluginStatus $p.Id
    if ($status -eq "enabled") {
        Write-Host "[OK] $($p.Label)" -ForegroundColor Green
    } else {
        Write-Host "[FALTA] $($p.Label) (status: $status)" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host "========================================" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "Setup concluido!" -ForegroundColor Green
} else {
    Write-Host "Setup concluido com pendencias (veja [FALTA] acima)." -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Feche e reabra o Claude Code para os plugins carregarem." -ForegroundColor Yellow
