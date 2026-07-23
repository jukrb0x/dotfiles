#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "bootstrap\wsl.sh"
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
    -Message "WSL bootstrap should keep an absolute chezmoi path from the Linuxbrew install location."

Assert-Match `
    -Text $script `
    -Pattern '"\$chezmoi_bin" init "\$repo_url"' `
    -Message "WSL bootstrap should initialize with the absolute chezmoi path so PATH is not required."

Assert-Contains `
    -Text $script `
    -Needle 'eval \"\$($brew_bin shellenv)\"' `
    -Message "WSL bootstrap should print the Linuxbrew shellenv command as the primary next step."

Assert-Match `
    -Text $script `
    -Pattern '\\"\$chezmoi_bin\\" diff' `
    -Message "WSL bootstrap should also print absolute-path fallback commands."

Assert-Match `
    -Text $script `
    -Pattern 'owner_group="\$\(id -gn "\$owner"\)"' `
    -Message "WSL bootstrap should chown Linuxbrew with the normal user's primary group."

Assert-Match `
    -Text $script `
    -Pattern 'ensure_zsh\(\) \{[\s\S]*command -v zsh' `
    -Message "WSL bootstrap should ensure zsh is installed even when Linuxbrew already exists."

Assert-Match `
    -Text $script `
    -Pattern 'ensure_zsh\s*\n\s*if \[\[ ! -x "\$chezmoi_bin" \]\]' `
    -Message "WSL bootstrap should verify zsh before printing the default-shell command."

Write-Host "bootstrap-wsl tests passed."
