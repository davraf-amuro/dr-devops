<#
.SYNOPSIS
    Installa il pacchetto dr-devops (Docker Swarm, Portainer, CI/CD GitLab) nel progetto corrente.
.DESCRIPTION
    Esegui dalla root del progetto host.

    Installazione (repo Public):
        irm https://raw.githubusercontent.com/davraf-amuro/dr-devops/main/dr-devops-install.ps1 | iex

    Installazione (repo Private, con gh autenticato):
        & ([scriptblock]::Create((gh api repos/davraf-amuro/dr-devops/contents/dr-devops-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String)))

    Aggiornamento (sovrascrive i file gia presenti):
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/davraf-amuro/dr-devops/main/dr-devops-install.ps1))) -Update

    Nessuna dipendenza.
.PARAMETER Update
    Sovrascrive i file gia presenti nel progetto con la versione corrente del pacchetto.
#>

[CmdletBinding()]
param([switch]$Update)

# --- Risoluzione della libreria condivisa ---
# La libreria vive solo in dr-guidelines. Tre tentativi, in ordine di preferenza:
#   1. raw pubblico       -> caso normale a repo Public
#   2. clone locale       -> dr-guidelines come cartella sorella nel workspace
#   3. gh api             -> repo Private con gh autenticato: l'unica via che scarica davvero da GitHub

$libName     = "dr-guidelines-install-lib.ps1"
$libRepo     = "davraf-amuro/dr-guidelines"
$libUrl      = "https://raw.githubusercontent.com/$libRepo/main/$libName"
$libLoaded   = $false
$libFailures = @()

try {
    $libContent = Invoke-RestMethod -Uri $libUrl -ErrorAction Stop
    Invoke-Expression $libContent
    $libLoaded = $true
} catch {
    $libFailures += "raw pubblico: $($_.Exception.Message)"
}

if (-not $libLoaded -and $PSScriptRoot) {
    $localLib = Join-Path (Split-Path $PSScriptRoot -Parent) "dr-guidelines\$libName"
    if (Test-Path $localLib) {
        . $localLib
        $libLoaded = $true
    } else {
        $libFailures += "clone locale: $libName non trovato accanto a $PSScriptRoot"
    }
} elseif (-not $libLoaded) {
    $libFailures += "clone locale: nessuno ($PSScriptRoot vuoto, script eseguito da stream)"
}

if (-not $libLoaded) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $libContent = gh api "repos/$libRepo/contents/$libName" -H "Accept: application/vnd.github.raw" 2>$null | Out-String
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($libContent)) {
                throw "gh api ha restituito exit $LASTEXITCODE (autenticato? 'gh auth status')"
            }
            Invoke-Expression $libContent
            $libLoaded = $true
        } catch {
            $libFailures += "gh api: $($_.Exception.Message)"
        }
    } else {
        $libFailures += "gh api: gh non installato o non nel PATH"
    }
}

if (-not $libLoaded) {
    Write-Host ""
    Write-Host "Impossibile caricare $libName. Tentativi:" -ForegroundColor Red
    $libFailures | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "Su repo Private serve gh autenticato: 'gh auth login' (scope repo)." -ForegroundColor Yellow
    throw "Caricamento di $libName fallito."
}

Install-DrPackage -PackageName "dr-devops" -Update:$Update
