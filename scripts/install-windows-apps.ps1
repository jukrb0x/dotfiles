#Requires -Version 7.1
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "lib\WindowsSetup.psm1") -Force -DisableNameChecking

$repoRoot = Split-Path -Parent $PSScriptRoot
$appManifestPath = Join-Path $repoRoot "packages\windows-winget-apps.psd1"
$appManifest = Import-PowerShellDataFile -LiteralPath $appManifestPath
$DefaultSource = "winget"
$Apps = @($appManifest.Apps)

foreach ($app in $Apps) {
    $id = $app.Id
    $packageName = $app.PackageName
    $source = if ($app.Source) { $app.Source } else { $DefaultSource }
    $name = if ($app.Name) { $app.Name } elseif ($packageName) { $packageName } else { $id }

    Install-WinGetPackage -Id $id -PackageName $packageName -Source $source -Name $name
}

& (Join-Path $PSScriptRoot "set-windows-user-environment.ps1")
& (Join-Path $PSScriptRoot "set-windows-user-path.ps1")
