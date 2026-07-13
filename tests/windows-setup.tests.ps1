#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot "scripts\lib\WindowsSetup.psm1"
Import-Module $modulePath -Force -DisableNameChecking

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

$mergedPath = Merge-ManagedPathEntries `
    -ExistingEntries @(
        "C:\UserTools",
        "C:\Users\jabriel\scoop\shims\",
        "C:\OtherTool"
    ) `
    -ManagedEntries @(
        "C:\Users\jabriel\.local\bin",
        "C:\Users\jabriel\scoop\shims"
    )

Assert-Equal `
    -Actual $mergedPath `
    -Expected @(
        "C:\Users\jabriel\.local\bin",
        "C:\Users\jabriel\scoop\shims",
        "C:\UserTools",
        "C:\OtherTool"
    ) `
    -Message "Managed PATH entries should be placed first without reordering user-owned entries."

$exactSpec = Parse-WinGetPackageSpec "Neovim.Neovim@0.9.0"
Assert-Equal $exactSpec.Id "Neovim.Neovim" "Exact spec should parse the package id."
Assert-Equal $exactSpec.Version "0.9.0" "Exact spec should parse the version."
Assert-Equal $exactSpec.PinVersion "0.9.0" "Exact spec should use an exact pin."
Assert-Equal $exactSpec.VersionMode "Exact" "Exact spec should be marked exact."

$minorSpec = Parse-WinGetPackageSpec "Neovim.Neovim@0.9"
Assert-Equal $minorSpec.Id "Neovim.Neovim" "Minor spec should parse the package id."
Assert-Equal $minorSpec.Version "0.9" "Minor spec should parse the version prefix."
Assert-Equal $minorSpec.PinVersion "0.9.*" "Minor spec should use a wildcard pin."
Assert-Equal $minorSpec.VersionMode "Prefix" "Minor spec should be marked prefix."

$unversionedSpec = Parse-WinGetPackageSpec "Neovim.Neovim"
Assert-Equal $unversionedSpec.Id "Neovim.Neovim" "Unversioned spec should parse the package id."
Assert-Equal $unversionedSpec.Version $null "Unversioned spec should not have a version."
Assert-Equal $unversionedSpec.PinVersion $null "Unversioned spec should not have a pin."
Assert-Equal $unversionedSpec.VersionMode "Any" "Unversioned spec should be marked any."

Assert-True (Test-WinGetVersionSatisfiesSpec -InstalledVersion "0.9.5" -Spec $minorSpec) "0.9.5 should satisfy @0.9."
Assert-True (-not (Test-WinGetVersionSatisfiesSpec -InstalledVersion "0.10.0" -Spec $minorSpec)) "0.10.0 should not satisfy @0.9."
Assert-True (Test-WinGetVersionSatisfiesSpec -InstalledVersion "0.9.0" -Spec $exactSpec) "0.9.0 should satisfy @0.9.0."
Assert-True (-not (Test-WinGetVersionSatisfiesSpec -InstalledVersion "0.9.1" -Spec $exactSpec)) "0.9.1 should not satisfy @0.9.0."

Assert-Equal `
    -Actual (Get-WinGetPackageVersionFromListOutput -Id "Git.Git" -OutputLines @(
        "",
        "   - ",
        "                                                                                                                        ",
        "Name Id      Version",
        "--------------------",
        "Git  Git.Git 2.54.0"
    )) `
    -Expected "2.54.0" `
    -Message "Installed WinGet package detection should parse single-space table columns."

Assert-Equal `
    -Actual (Select-WinGetInstallVersion -AvailableVersions @("0.8.9", "0.9.0", "0.9.5", "0.10.0") -Spec $minorSpec) `
    -Expected "0.9.5" `
    -Message "Prefix specs should select the latest available matching version."
Assert-Equal `
    -Actual (Select-WinGetInstallVersion -AvailableVersions @("0.9.0", "0.9.1") -Spec $exactSpec) `
    -Expected "0.9.0" `
    -Message "Exact specs should select the requested exact version."

$badSpecFailed = $false
try {
    Parse-WinGetPackageSpec "Neovim.Neovim@"
} catch {
    $badSpecFailed = $true
}
Assert-True $badSpecFailed "Malformed WinGet specs should fail instead of being guessed."

$manifestPath = Join-Path ([IO.Path]::GetTempPath()) "windows-winget-test-packages-$PID.psd1"
try {
    @'
@{
    Packages = @(
        @{ Id = "Git.Git" }
        @{ Id = "tree-sitter.tree-sitter-cli"; Version = "0.26" }
        @{ PackageName = "Codex"; Source = "msstore"; Name = "Codex app" }
        @{ Id = "Microsoft.VisualStudioCode"; Scope = "machine" }
        @{ Id = "Microsoft.PowerShell"; InstallerType = "wix" }
    )
}
'@ | Set-Content -LiteralPath $manifestPath -Encoding utf8

    $manifestSpecs = @(Read-WinGetPackageSpecs -Path $manifestPath)
    Assert-Equal $manifestSpecs[0].Id "Git.Git" "Manifest entries should parse WinGet ids."
    Assert-Equal $manifestSpecs[0].Source "winget" "Manifest entries should default to the winget source."
    Assert-Equal $manifestSpecs[1].Id "tree-sitter.tree-sitter-cli" "Manifest entries should parse versioned ids."
    Assert-Equal $manifestSpecs[1].Version "0.26" "Manifest entries should parse version prefixes from the Version property."
    Assert-Equal $manifestSpecs[1].PinVersion "0.26.*" "Manifest version prefixes should keep existing pin behavior."
    Assert-Equal $manifestSpecs[2].PackageName "Codex" "Manifest entries should support PackageName installs."
    Assert-Equal $manifestSpecs[2].Source "msstore" "Manifest entries should preserve non-default sources."
    Assert-Equal $manifestSpecs[2].Name "Codex app" "Manifest entries should preserve friendly display names."
    Assert-Equal $manifestSpecs[3].Scope "machine" "Manifest entries should preserve opt-in install scopes."
    Assert-Equal $manifestSpecs[4].InstallerType "wix" "Manifest entries should preserve opt-in installer types."
} finally {
    if (Test-Path -LiteralPath $manifestPath) {
        Remove-Item -LiteralPath $manifestPath
    }
}

$script:wingetInvocations = @()
function global:winget {
    $script:wingetInvocations += ,@($args)
    if ($args[0] -eq "list") {
        $global:LASTEXITCODE = 1
        return
    }

    $global:LASTEXITCODE = 0
}

try {
    Install-WinGetPackageSpec -Spec ([pscustomobject]@{
        Id          = "Microsoft.VisualStudioCode"
        PackageName = $null
        Name        = $null
        Version     = $null
        VersionMode = "Any"
        PinVersion  = $null
        Source      = "winget"
        Scope       = "machine"
        InstallerType = "wix"
    })

    $installInvocation = @($script:wingetInvocations | Where-Object { $_[0] -eq "install" })[0]
    Assert-True ($installInvocation -contains "--scope") "Scoped WinGet package installs should pass --scope."
    $scopeIndex = [array]::IndexOf($installInvocation, "--scope")
    Assert-Equal $installInvocation[$scopeIndex + 1] "machine" "Scoped WinGet package installs should pass the requested scope value."
    Assert-True ($installInvocation -contains "--installer-type") "Installer-typed WinGet package installs should pass --installer-type."
    $installerTypeIndex = [array]::IndexOf($installInvocation, "--installer-type")
    Assert-Equal $installInvocation[$installerTypeIndex + 1] "wix" "Installer-typed WinGet package installs should pass the requested installer type value."
} finally {
    Remove-Item -Path Function:\winget -ErrorAction SilentlyContinue
}

$installSpecText = (Get-Command Install-WinGetPackageSpec).ScriptBlock.ToString()
Assert-True ($installSpecText -match 'Get-WinGetPackageVersion') "WinGet spec installs should print installed version information when an id is already present."
Assert-True ($installSpecText -notmatch '\bupgrade\b') "WinGet spec installs should not attempt to upgrade existing packages."

Write-Host "windows-setup tests passed."
