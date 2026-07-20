#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Contains {
    param([string]$Content, [string]$Expected, [string]$Message)
    Assert-True $Content.Contains($Expected) "$Message`nMissing: $Expected"
}

$manifestPath = Join-Path $repoRoot "packages\windows-rmux.psd1"
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
Assert-True ($manifest.Repository -eq "jukrb0x/rmux") "RMUX must come from the personal fork."
Assert-True ($manifest.Tag -eq "v0.9.0-jukrb0x.3") "RMUX must use the immutable personal tag."
Assert-True ($manifest.Asset -eq "rmux-0.9.0-windows-x86_64.zip") "RMUX must use the supported package archive."
Assert-True ($manifest.PackageRoot -eq "rmux-0.9.0-windows-x86_64") "RMUX package root must match the archive."
Assert-True ($manifest.InstallRelativePath -eq ".local/bin") "RMUX must install into the managed user PATH."
Assert-True ($manifest.GitCommit -match '^[0-9a-f]{40}$') "RMUX pin must include its exact Git commit."
foreach ($name in @("AssetSha256", "PublicBinarySha256", "HelperBinarySha256", "DaemonBinarySha256")) {
    Assert-True ([string]$manifest[$name] -match '^[0-9a-f]{64}$') "RMUX $name must be a lowercase SHA-256 digest."
}

$winget = Get-Content -Raw (Join-Path $repoRoot "packages\windows-winget-required.psd1")
Assert-True (-not $winget.Contains("Helvesec.RMUX")) "Official RMUX must not be owned by Winget."
Assert-Contains $winget 'marlocarlo.psmux' "The unrelated required psmux package must remain."

$template = Get-Content -Raw (Join-Path $repoRoot "home\.chezmoiscripts\run_onchange_after_25-windows-rmux.ps1.tmpl")
Assert-Contains $template '{{ if eq .chezmoi.os "windows" -}}' "RMUX installation must be Windows-only."
Assert-Contains $template '{{ include "../packages/windows-rmux.psd1" | sha256sum }}' "Manifest changes must retrigger installation."
Assert-Contains $template '{{ include "../scripts/install-windows-rmux.ps1" | sha256sum }}' "Wrapper changes must retrigger installation."
Assert-Contains $template '{{ include "../scripts/lib/RmuxInstaller.psm1" | sha256sum }}' "Module changes must retrigger installation."
Assert-Contains $template 'install-windows-rmux.ps1' "The hook must call the dedicated installer."

$wrapper = Get-Content -Raw (Join-Path $repoRoot "scripts\install-windows-rmux.ps1")
Assert-Contains $wrapper 'RmuxInstaller.psm1' "The wrapper must use the tested installer module."
Assert-True (-not $wrapper.Contains('releases/latest')) "The wrapper must never resolve a rolling latest release."

$windowsDoc = Get-Content -Raw (Join-Path $repoRoot "docs\windows.md")
Assert-Contains $windowsDoc 'v0.9.0-jukrb0x.3' "Windows documentation must name the current immutable fork pin."
Assert-Contains $windowsDoc 'gh auth login' "Windows documentation must explain authenticated fallback setup."
Assert-Contains $windowsDoc 'close RMUX' "Windows documentation must explain locked-binary updates."

Write-Host "windows-rmux-wiring tests passed."
