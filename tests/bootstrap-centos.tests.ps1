#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "bootstrap\centos.sh"
$script = Get-Content -LiteralPath $scriptPath -Raw

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Needle,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Text.Contains($Needle)) {
        throw $Message
    }
}

Assert-Match `
    -Text $script `
    -Pattern 'chezmoi_bin="\$\(dirname -- "\$brew_bin"\)/chezmoi"' `
    -Message "CentOS bootstrap should keep an absolute chezmoi path from the Linuxbrew install location."

Assert-Match `
    -Text $script `
    -Pattern '"\$chezmoi_bin" init "\$repo_url"' `
    -Message "CentOS bootstrap should initialize with the absolute chezmoi path so PATH is not required."

Assert-Contains `
    -Text $script `
    -Needle 'eval \"\$($brew_bin shellenv)\"' `
    -Message "CentOS bootstrap should print the Linuxbrew shellenv command as the primary next step."

Assert-Match `
    -Text $script `
    -Pattern 'chezmoi diff' `
    -Message "CentOS bootstrap should print normal chezmoi commands after the shellenv step."

Assert-Match `
    -Text $script `
    -Pattern '\\"\$chezmoi_bin\\" diff' `
    -Message "CentOS bootstrap should also print absolute-path fallback commands."

Assert-Match `
    -Text $script `
    -Pattern 'eval "\$\("\$brew_bin" shellenv\)"' `
    -Message "CentOS bootstrap should still make brew available inside the bootstrap process."

Assert-Match `
    -Text $script `
    -Pattern 'ensure_zsh\(\) \{[\s\S]*command -v zsh' `
    -Message "CentOS bootstrap should ensure zsh is installed even when Linuxbrew already exists."

Assert-Match `
    -Text $script `
    -Pattern 'ensure_zsh\s*\n\s*if \[\[ ! -x "\$chezmoi_bin" \]\]' `
    -Message "CentOS bootstrap should verify zsh before printing the default-shell command."

Write-Host "bootstrap-centos tests passed."
