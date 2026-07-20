Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RmuxSha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-RmuxSha256 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    $actual = Get-RmuxSha256 -Path $Path
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "$Label SHA-256 mismatch: expected $Expected, got $actual"
    }
}

function Read-RmuxReleaseSpec {
    param([Parameter(Mandatory)][string]$Path)
    $data = Import-PowerShellDataFile -LiteralPath $Path
    $required = @(
        "Repository", "Tag", "GitCommit", "Version", "Asset", "AssetSha256",
        "PackageRoot", "PublicBinarySha256", "HelperBinarySha256",
        "DaemonBinarySha256", "InstallRelativePath"
    )
    foreach ($name in $required) {
        if (-not $data.ContainsKey($name) -or [string]::IsNullOrWhiteSpace([string]$data[$name])) {
            throw "RMUX release spec is missing $name"
        }
    }
    if ([string]$data.Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "Invalid RMUX repository: $($data.Repository)"
    }
    if ([string]$data.Tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+-jukrb0x\.[1-9][0-9]*$') {
        throw "Invalid RMUX tag: $($data.Tag)"
    }
    if ([string]$data.GitCommit -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Invalid RMUX Git commit: $($data.GitCommit)"
    }
    if ([string]$data.Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "Invalid RMUX version: $($data.Version)"
    }
    foreach ($name in @("Asset", "PackageRoot")) {
        $value = [string]$data[$name]
        if ([IO.Path]::GetFileName($value) -ne $value) {
            throw "RMUX $name must be a single file or directory name: $value"
        }
    }
    foreach ($name in @("AssetSha256", "PublicBinarySha256", "HelperBinarySha256", "DaemonBinarySha256")) {
        if ([string]$data[$name] -notmatch '^[0-9a-fA-F]{64}$') {
            throw "RMUX $name is not a SHA-256 digest"
        }
    }
    $relative = [string]$data.InstallRelativePath
    if ([IO.Path]::IsPathRooted($relative) -or @($relative -split '[\\/]+') -contains '..') {
        throw "RMUX InstallRelativePath must remain under HOME: $relative"
    }

    [pscustomobject][ordered]@{
        Repository = [string]$data.Repository
        Tag = [string]$data.Tag
        GitCommit = ([string]$data.GitCommit).ToLowerInvariant()
        Version = [string]$data.Version
        Asset = [string]$data.Asset
        AssetSha256 = ([string]$data.AssetSha256).ToLowerInvariant()
        PackageRoot = [string]$data.PackageRoot
        PublicBinarySha256 = ([string]$data.PublicBinarySha256).ToLowerInvariant()
        HelperBinarySha256 = ([string]$data.HelperBinarySha256).ToLowerInvariant()
        DaemonBinarySha256 = ([string]$data.DaemonBinarySha256).ToLowerInvariant()
        InstallRelativePath = $relative
    }
}

function Get-RmuxInstallationPaths {
    param([Parameter(Mandatory)][string]$InstallDir)
    $installRoot = Split-Path -Parent $InstallDir
    [ordered]@{
        Public = Join-Path $InstallDir "rmux.exe"
        Helper = Join-Path $installRoot "libexec\rmux\rmux.exe"
        Daemon = Join-Path $InstallDir "rmux-daemon.exe"
    }
}

function Test-RmuxInstallationCurrent {
    param(
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$InstallDir
    )
    $paths = Get-RmuxInstallationPaths -InstallDir $InstallDir
    $expected = [ordered]@{
        Public = $Spec.PublicBinarySha256
        Helper = $Spec.HelperBinarySha256
        Daemon = $Spec.DaemonBinarySha256
    }
    foreach ($name in $expected.Keys) {
        $path = $paths[$name]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-RmuxSha256 -Path $path) -ne $expected[$name]) { return $false }
    }
    $true
}

function Invoke-RmuxDirectDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination
    )
    Invoke-WebRequest -Headers @{ "User-Agent" = "chezmoi-rmux-installer" } -Uri $Uri -OutFile $Destination
}

function Test-RmuxGhAuthentication {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
    & gh auth status --hostname github.com *> $null
    $LASTEXITCODE -eq 0
}

function Invoke-RmuxGhDownload {
    param(
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$Directory
    )
    if (-not (Test-RmuxGhAuthentication)) {
        throw "gh is unavailable or not authenticated; run gh auth login"
    }
    & gh release download $Spec.Tag `
        --repo $Spec.Repository `
        --pattern $Spec.Asset `
        --dir $Directory `
        --clobber
    if ($LASTEXITCODE -ne 0) {
        throw "gh release download failed with exit code $LASTEXITCODE"
    }
}

function Get-RmuxReleaseArchive {
    param(
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$TempDir,
        [scriptblock]$DirectDownloader,
        [scriptblock]$GhDownloader
    )
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $destination = Join-Path $TempDir $Spec.Asset
    $uri = "https://github.com/$($Spec.Repository)/releases/download/$($Spec.Tag)/$($Spec.Asset)"
    if ($null -eq $DirectDownloader) {
        $DirectDownloader = { param($Uri, $Destination) Invoke-RmuxDirectDownload -Uri $Uri -Destination $Destination }
    }
    if ($null -eq $GhDownloader) {
        $GhDownloader = { param($Spec, $Directory) Invoke-RmuxGhDownload -Spec $Spec -Directory $Directory }
    }

    $directError = $null
    try {
        & $DirectDownloader $uri $destination | Out-Null
        Assert-RmuxSha256 -Path $destination -Expected $Spec.AssetSha256 -Label $Spec.Asset
        return [pscustomobject]@{ Path = $destination; Source = "Direct" }
    } catch {
        $directError = $_.Exception.Message
        Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
    }

    try {
        & $GhDownloader $Spec $TempDir | Out-Null
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw "gh did not produce $($Spec.Asset)"
        }
        Assert-RmuxSha256 -Path $destination -Expected $Spec.AssetSha256 -Label $Spec.Asset
        return [pscustomobject]@{ Path = $destination; Source = "GitHubCli" }
    } catch {
        $ghError = $_.Exception.Message
        Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        throw "Direct RMUX download failed: $directError; authenticated gh fallback failed: $ghError"
    }
}

function Assert-RmuxPackage {
    param(
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$ExtractRoot
    )
    $packageRoot = Join-Path $ExtractRoot $Spec.PackageRoot
    $required = @(
        "rmux.exe",
        "libexec\rmux\rmux.exe",
        "rmux-daemon.exe",
        "install.ps1",
        "share\rmux\artifact-metadata.json"
    )
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $relative) -PathType Leaf)) {
            throw "RMUX package is missing required file: $relative"
        }
    }

    Assert-RmuxSha256 -Path (Join-Path $packageRoot "rmux.exe") -Expected $Spec.PublicBinarySha256 -Label "rmux.exe"
    Assert-RmuxSha256 -Path (Join-Path $packageRoot "libexec\rmux\rmux.exe") -Expected $Spec.HelperBinarySha256 -Label "full helper"
    Assert-RmuxSha256 -Path (Join-Path $packageRoot "rmux-daemon.exe") -Expected $Spec.DaemonBinarySha256 -Label "rmux-daemon.exe"

    $metadataPath = Join-Path $packageRoot "share\rmux\artifact-metadata.json"
    $metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding utf8 | ConvertFrom-Json
    $checks = [ordered]@{
        schema = "1"
        artifact_kind = "windows-package-binary"
        package_layout = "rmux-windows-package-v2"
        binary_path = "rmux.exe"
        helper_binary_path = "libexec/rmux/rmux.exe"
        daemon_binary_path = "rmux-daemon.exe"
        rmux_version = $Spec.Version
        git_commit = $Spec.GitCommit
        binary_sha256 = $Spec.PublicBinarySha256
        helper_binary_sha256 = $Spec.HelperBinarySha256
        daemon_binary_sha256 = $Spec.DaemonBinarySha256
    }
    foreach ($name in $checks.Keys) {
        if ([string]$metadata.$name -ne [string]$checks[$name]) {
            throw "RMUX artifact metadata $name does not match the pinned release"
        }
    }
    if ($metadata.git_dirty -ne $false -or $metadata.release_artifact -ne $true) {
        throw "RMUX artifact metadata does not describe a clean release artifact"
    }
    $packageRoot
}

function Install-RmuxRelease {
    param(
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$HomePath,
        [scriptblock]$DirectDownloader,
        [scriptblock]$GhDownloader,
        [scriptblock]$PackageInstaller
    )
    $installDir = [IO.Path]::GetFullPath((Join-Path $HomePath $Spec.InstallRelativePath))
    if (Test-RmuxInstallationCurrent -Spec $Spec -InstallDir $installDir) {
        return [pscustomobject]@{ Changed = $false; Source = "Current"; InstallDir = $installDir }
    }

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("chezmoi-rmux-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $download = Get-RmuxReleaseArchive `
            -Spec $Spec `
            -TempDir $tempDir `
            -DirectDownloader $DirectDownloader `
            -GhDownloader $GhDownloader
        $extractRoot = Join-Path $tempDir "extract"
        Expand-Archive -LiteralPath $download.Path -DestinationPath $extractRoot
        $packageRoot = Assert-RmuxPackage -Spec $Spec -ExtractRoot $extractRoot

        if ($null -eq $PackageInstaller) {
            $PackageInstaller = {
                param($PackageRoot, $InstallDir)
                $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
                & $pwsh -NoLogo -NoProfile -File (Join-Path $PackageRoot "install.ps1") -InstallDir $InstallDir
                if ($LASTEXITCODE -ne 0) {
                    throw "RMUX package installer failed with exit code $LASTEXITCODE"
                }
            }
        }
        & $PackageInstaller $packageRoot $installDir | Out-Host
        if (-not (Test-RmuxInstallationCurrent -Spec $Spec -InstallDir $installDir)) {
            throw "RMUX package installer returned success but installed component hashes do not match"
        }
        [pscustomobject]@{ Changed = $true; Source = $download.Source; InstallDir = $installDir }
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function `
    Read-RmuxReleaseSpec, `
    Get-RmuxSha256, `
    Test-RmuxInstallationCurrent, `
    Get-RmuxReleaseArchive, `
    Assert-RmuxPackage, `
    Install-RmuxRelease
