#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot "scripts\lib\RmuxInstaller.psm1"
Import-Module $modulePath -Force -DisableNameChecking

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [Parameter(Mandatory)][string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message`nExpected: $Expected`nActual:   $Actual"
    }
}

function Assert-ThrowsLike {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    try {
        & $Action
    } catch {
        if ($_.Exception.Message -notmatch $Pattern) {
            throw "$Message`nUnexpected error: $($_.Exception.Message)"
        }
        return
    }
    throw "$Message`nExpected an exception matching: $Pattern"
}

function Copy-FixturePackage {
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$InstallDir
    )
    $installRoot = Split-Path -Parent $InstallDir
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $installRoot "libexec\rmux") | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot "rmux.exe") -Destination (Join-Path $InstallDir "rmux.exe") -Force
    Copy-Item -LiteralPath (Join-Path $PackageRoot "libexec\rmux\rmux.exe") -Destination (Join-Path $installRoot "libexec\rmux\rmux.exe") -Force
    Copy-Item -LiteralPath (Join-Path $PackageRoot "rmux-daemon.exe") -Destination (Join-Path $InstallDir "rmux-daemon.exe") -Force
}

function New-RmuxFixture {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$Omit = ""
    )
    $packageName = "rmux-0.9.0-windows-x86_64"
    $packageRoot = Join-Path $Root $packageName
    New-Item -ItemType Directory -Force -Path (Join-Path $packageRoot "libexec\rmux") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $packageRoot "share\rmux") | Out-Null

    $files = [ordered]@{
        "rmux.exe" = "public-shim"
        "libexec\rmux\rmux.exe" = "full-helper"
        "rmux-daemon.exe" = "daemon"
        "install.ps1" = "Write-Output 'fixture installer'"
    }
    foreach ($entry in $files.GetEnumerator()) {
        if ($entry.Key -eq $Omit) { continue }
        $path = Join-Path $packageRoot $entry.Key
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        Set-Content -LiteralPath $path -Value $entry.Value -Encoding utf8NoBOM
    }

    $publicHash = if (Test-Path (Join-Path $packageRoot "rmux.exe")) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot "rmux.exe")).Hash.ToLowerInvariant()
    } else { "0" * 64 }
    $helperHash = if (Test-Path (Join-Path $packageRoot "libexec\rmux\rmux.exe")) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot "libexec\rmux\rmux.exe")).Hash.ToLowerInvariant()
    } else { "0" * 64 }
    $daemonHash = if (Test-Path (Join-Path $packageRoot "rmux-daemon.exe")) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot "rmux-daemon.exe")).Hash.ToLowerInvariant()
    } else { "0" * 64 }
    $commit = "a" * 40
    [ordered]@{
        schema = 1
        artifact_kind = "windows-package-binary"
        binary_path = "rmux.exe"
        binary_sha256 = $publicHash
        helper_binary_path = "libexec/rmux/rmux.exe"
        helper_binary_sha256 = $helperHash
        daemon_binary_path = "rmux-daemon.exe"
        daemon_binary_sha256 = $daemonHash
        rmux_version = "0.9.0"
        git_commit = $commit
        git_dirty = $false
        package_layout = "rmux-windows-package-v2"
        release_artifact = $true
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $packageRoot "share\rmux\artifact-metadata.json") -Encoding utf8NoBOM

    $archive = Join-Path $Root "$packageName.zip"
    Compress-Archive -Path $packageRoot -DestinationPath $archive -Force
    $assetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()

    [pscustomobject]@{
        Root = $Root
        PackageRoot = $packageRoot
        Archive = $archive
        Spec = [pscustomobject]@{
            Repository = "jukrb0x/rmux"
            Tag = "v0.9.0-jukrb0x.3"
            GitCommit = $commit
            Version = "0.9.0"
            Asset = "$packageName.zip"
            AssetSha256 = $assetHash
            PackageRoot = $packageName
            PublicBinarySha256 = $publicHash
            HelperBinarySha256 = $helperHash
            DaemonBinarySha256 = $daemonHash
            InstallRelativePath = ".local/bin"
        }
    }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) "chezmoi-rmux-installer-$PID"
Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
    $fixture = New-RmuxFixture -Root (Join-Path $testRoot "base")
    $manifestPath = Join-Path $testRoot "windows-rmux.psd1"
    @"
@{
    Repository = "$($fixture.Spec.Repository)"
    Tag = "$($fixture.Spec.Tag)"
    GitCommit = "$($fixture.Spec.GitCommit)"
    Version = "$($fixture.Spec.Version)"
    Asset = "$($fixture.Spec.Asset)"
    AssetSha256 = "$($fixture.Spec.AssetSha256)"
    PackageRoot = "$($fixture.Spec.PackageRoot)"
    PublicBinarySha256 = "$($fixture.Spec.PublicBinarySha256)"
    HelperBinarySha256 = "$($fixture.Spec.HelperBinarySha256)"
    DaemonBinarySha256 = "$($fixture.Spec.DaemonBinarySha256)"
    InstallRelativePath = "$($fixture.Spec.InstallRelativePath)"
}
"@ | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    $parsed = Read-RmuxReleaseSpec -Path $manifestPath
    Assert-Equal $parsed.Tag "v0.9.0-jukrb0x.3" "Manifest tag should parse."
    Assert-Equal $parsed.AssetSha256 $fixture.Spec.AssetSha256 "Manifest hash should normalize."

    $directRoot = Join-Path $testRoot "direct"
    $directFixture = New-RmuxFixture -Root (Join-Path $directRoot "fixture")
    $directHome = Join-Path $directRoot "home"
    $directCalls = [pscustomobject]@{ Count = 0 }
    $directDownloader = {
        param($Uri, $Destination)
        $directCalls.Count++
        Copy-Item -LiteralPath $directFixture.Archive -Destination $Destination
    }.GetNewClosure()
    $ghMustNotRun = { param($Spec, $Directory) throw "gh must not run" }
    $fixtureInstaller = {
        param($PackageRoot, $InstallDir)
        Copy-FixturePackage -PackageRoot $PackageRoot -InstallDir $InstallDir
    }
    $directResult = Install-RmuxRelease `
        -Spec $directFixture.Spec `
        -HomePath $directHome `
        -DirectDownloader $directDownloader `
        -GhDownloader $ghMustNotRun `
        -PackageInstaller $fixtureInstaller
    Assert-True $directResult.Changed "A missing install should be installed."
    Assert-Equal $directResult.Source "Direct" "Direct download should be reported."
    Assert-Equal $directCalls.Count 1 "Direct download should run exactly once."
    Assert-True (Test-Path -LiteralPath (Join-Path $directHome ".local/libexec/rmux/rmux.exe")) "The full helper should use RMUX's sibling libexec layout."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $directHome ".local/bin/libexec/rmux/rmux.exe"))) "The full helper must not be nested under bin."
    Assert-True (Test-RmuxInstallationCurrent -Spec $directFixture.Spec -InstallDir (Join-Path $directHome ".local/bin")) "Installed fixture hashes should match."

    $noOpCalls = [pscustomobject]@{ Count = 0 }
    $noOpDownloader = {
        param($Uri, $Destination)
        $noOpCalls.Count++
        throw "download should not run for a current install"
    }.GetNewClosure()
    $noOpResult = Install-RmuxRelease `
        -Spec $directFixture.Spec `
        -HomePath $directHome `
        -DirectDownloader $noOpDownloader `
        -GhDownloader $ghMustNotRun `
        -PackageInstaller { throw "installer should not run" }
    Assert-True (-not $noOpResult.Changed) "Matching component hashes should be a no-op."
    Assert-Equal $noOpResult.Source "Current" "No-op source should be Current."
    Assert-Equal $noOpCalls.Count 0 "No-op should not touch the network."

    $fallbackRoot = Join-Path $testRoot "fallback"
    $fallbackFixture = New-RmuxFixture -Root (Join-Path $fallbackRoot "fixture")
    $fallbackHome = Join-Path $fallbackRoot "home"
    $fallbackGhCalls = [pscustomobject]@{ Count = 0 }
    $failingDirect = { param($Uri, $Destination) throw "anonymous rate limit" }
    $workingGh = {
        param($Spec, $Directory)
        $fallbackGhCalls.Count++
        Copy-Item -LiteralPath $fallbackFixture.Archive -Destination (Join-Path $Directory $Spec.Asset)
    }.GetNewClosure()
    $fallbackResult = Install-RmuxRelease `
        -Spec $fallbackFixture.Spec `
        -HomePath $fallbackHome `
        -DirectDownloader $failingDirect `
        -GhDownloader $workingGh `
        -PackageInstaller $fixtureInstaller
    Assert-Equal $fallbackResult.Source "GitHubCli" "A direct failure should use gh."
    Assert-Equal $fallbackGhCalls.Count 1 "gh should run exactly once."

    $mismatchRoot = Join-Path $testRoot "mismatch-fallback"
    $mismatchFixture = New-RmuxFixture -Root (Join-Path $mismatchRoot "fixture")
    $mismatchHome = Join-Path $mismatchRoot "home"
    $corruptDirect = {
        param($Uri, $Destination)
        Set-Content -LiteralPath $Destination -Value "rate-limit html" -Encoding utf8NoBOM
    }
    $recoveringGh = {
        param($Spec, $Directory)
        Copy-Item -LiteralPath $mismatchFixture.Archive -Destination (Join-Path $Directory $Spec.Asset)
    }.GetNewClosure()
    $mismatchResult = Install-RmuxRelease `
        -Spec $mismatchFixture.Spec `
        -HomePath $mismatchHome `
        -DirectDownloader $corruptDirect `
        -GhDownloader $recoveringGh `
        -PackageInstaller $fixtureInstaller
    Assert-Equal $mismatchResult.Source "GitHubCli" "A bad direct checksum should use gh."

    $failureRoot = Join-Path $testRoot "both-fail"
    $failureFixture = New-RmuxFixture -Root (Join-Path $failureRoot "fixture")
    Assert-ThrowsLike `
        -Action {
            Install-RmuxRelease `
                -Spec $failureFixture.Spec `
                -HomePath (Join-Path $failureRoot "home") `
                -DirectDownloader { throw "anonymous failed" } `
                -GhDownloader { throw "gh is not authenticated" } `
                -PackageInstaller $fixtureInstaller
        } `
        -Pattern "anonymous failed.*gh is not authenticated" `
        -Message "Both acquisition errors should remain actionable."

    $preserveRoot = Join-Path $testRoot "preserve"
    $preserveFixture = New-RmuxFixture -Root (Join-Path $preserveRoot "fixture")
    $preserveHome = Join-Path $preserveRoot "home"
    $preserveInstall = Join-Path $preserveHome ".local/bin"
    New-Item -ItemType Directory -Force -Path $preserveInstall | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $preserveHome ".local\libexec\rmux") | Out-Null
    Set-Content -LiteralPath (Join-Path $preserveInstall "rmux.exe") -Value "old-public" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $preserveHome ".local\libexec\rmux\rmux.exe") -Value "old-helper" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $preserveInstall "rmux-daemon.exe") -Value "old-daemon" -Encoding utf8NoBOM
    $oldPublic = Get-Content -Raw (Join-Path $preserveInstall "rmux.exe")
    $badComponentSpec = $preserveFixture.Spec.PSObject.Copy()
    $badComponentSpec.PublicBinarySha256 = "0" * 64
    $preserveDirect = {
        param($Uri, $Destination)
        Copy-Item -LiteralPath $preserveFixture.Archive -Destination $Destination
    }.GetNewClosure()
    Assert-ThrowsLike `
        -Action {
            Install-RmuxRelease `
                -Spec $badComponentSpec `
                -HomePath $preserveHome `
                -DirectDownloader $preserveDirect `
                -GhDownloader $ghMustNotRun `
                -PackageInstaller $fixtureInstaller
        } `
        -Pattern "rmux.exe.*SHA-256" `
        -Message "A bad component pin should fail before package installation."
    Assert-Equal (Get-Content -Raw (Join-Path $preserveInstall "rmux.exe")) $oldPublic "Validation failure must preserve the old executable."

    $missingRoot = Join-Path $testRoot "missing-daemon"
    $missingFixture = New-RmuxFixture -Root (Join-Path $missingRoot "fixture") -Omit "rmux-daemon.exe"
    $missingDirect = {
        param($Uri, $Destination)
        Copy-Item -LiteralPath $missingFixture.Archive -Destination $Destination
    }.GetNewClosure()
    Assert-ThrowsLike `
        -Action {
            Install-RmuxRelease `
                -Spec $missingFixture.Spec `
                -HomePath (Join-Path $missingRoot "home") `
                -DirectDownloader $missingDirect `
                -GhDownloader $ghMustNotRun `
                -PackageInstaller $fixtureInstaller
        } `
        -Pattern "missing required file.*rmux-daemon.exe" `
        -Message "Incomplete archives must fail closed."

    Write-Host "windows-rmux-installer tests passed."
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
