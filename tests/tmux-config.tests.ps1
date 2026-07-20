#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot "home"

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [string] $Expected,
        [Parameter(Mandatory)] [string] $Message
    )

    Assert-True $Content.Contains($Expected) "$Message`nMissing: $Expected"
}

function Normalize-Newlines {
    param([Parameter(Mandatory)] [string] $Content)

    return (($Content -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd()
}

function Get-NormalizedSha256 {
    param([Parameter(Mandatory)] [string] $Content)

    $bytes = [Text.Encoding]::UTF8.GetBytes((Normalize-Newlines $Content))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Render-SourceTemplate {
    param(
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] [ValidateSet("windows", "linux", "darwin")] [string] $OperatingSystem
    )

    $path = Join-Path $sourceRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path) "Expected source template does not exist: $RelativePath"

    $override = @{ chezmoi = @{ os = $OperatingSystem } } | ConvertTo-Json -Compress
    $rendered = & chezmoi execute-template --override-data $override -f $path
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi failed to render $RelativePath for $OperatingSystem."
    }
    return ($rendered -join "`n")
}

$expectedUnixLocalHash = "132e1377e2ba4f027cf2c7056a96c6d647456f116692c469a0ef591028dd5e6b"

$linuxEntry = Render-SourceTemplate "symlink_dot_tmux.conf.tmpl" "linux"
$darwinEntry = Render-SourceTemplate "symlink_dot_tmux.conf.tmpl" "darwin"
Assert-True ($linuxEntry.Trim() -eq ".tmux/.tmux.conf") "Linux ~/.tmux.conf must point to oh-my-tmux."
Assert-True ($darwinEntry.Trim() -eq ".tmux/.tmux.conf") "macOS ~/.tmux.conf must point to oh-my-tmux."

$linuxLocal = Render-SourceTemplate "dot_tmux.conf.local.tmpl" "linux"
$darwinLocal = Render-SourceTemplate "dot_tmux.conf.local.tmpl" "darwin"
Assert-True ((Get-NormalizedSha256 $linuxLocal) -eq $expectedUnixLocalHash) "Linux ~/.tmux.conf.local changed unexpectedly."
Assert-True ((Get-NormalizedSha256 $darwinLocal) -eq $expectedUnixLocalHash) "macOS ~/.tmux.conf.local changed unexpectedly."

$linuxIgnore = Render-SourceTemplate ".chezmoiignore.tmpl" "linux"
$darwinIgnore = Render-SourceTemplate ".chezmoiignore.tmpl" "darwin"
foreach ($renderedIgnore in @($linuxIgnore, $darwinIgnore)) {
    Assert-Contains $renderedIgnore '.psmux.conf' "Non-Windows hosts must ignore the native PSMUX config."
    Assert-Contains $renderedIgnore '.psmux/**' "Non-Windows hosts must ignore the PSMUX implementation directory."
}

Write-Output "tmux configuration tests passed."
