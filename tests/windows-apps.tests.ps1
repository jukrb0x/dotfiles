#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "scripts\install-windows-apps.ps1"
$manifestPath = Join-Path $repoRoot "packages\windows-winget-apps.psd1"
$script = Get-Content -LiteralPath $scriptPath -Raw

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [Parameter(Mandatory)] [string] $Message
    )

    $actualJson = ConvertTo-Json $Actual -Compress
    $expectedJson = ConvertTo-Json $Expected -Compress
    if ($actualJson -ne $expectedJson) {
        throw "$Message`nExpected: $expectedJson`nActual:   $actualJson"
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True (Test-Path -LiteralPath $manifestPath) "Optional Windows WinGet apps should live in packages/windows-winget-apps.psd1."

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$apps = @($manifest.Apps)
Assert-True ($apps.Count -gt 0) "Optional Windows WinGet apps manifest should not be empty."

$codexApp = @($apps | Where-Object { $_.PackageName -eq "Codex" -and $_.Source -eq "msstore" })[0]
Assert-Equal $codexApp.Name "Codex app" "Microsoft Store apps should preserve a friendly display name."

$forkApp = @($apps | Where-Object { $_.Id -eq "Fork.Fork" })[0]
Assert-Equal $forkApp.Id "Fork.Fork" "Manifest should preserve optional WinGet apps that were added to install-windows-apps.ps1."

Assert-True ($script -match 'Read-WinGetPackageSpecs') "install-windows-apps.ps1 should read optional apps through the shared WinGet manifest reader."
Assert-True ($script -match 'Install-WinGetPackageSpec') "install-windows-apps.ps1 should install apps through the shared WinGet spec installer."
Assert-True ($script -notmatch 'Google\.Chrome|Codex app|Fork\.Fork') "install-windows-apps.ps1 should not hardcode optional app package data."

Write-Host "windows-apps tests passed."
