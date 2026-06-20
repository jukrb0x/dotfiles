#Requires -Version 7.1

function Get-ManagedPathKey {
    param([Parameter(Mandatory)] [string] $Path)

    try {
        [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)).TrimEnd("\").ToLowerInvariant()
    } catch {
        $Path.Trim().TrimEnd("\").ToLowerInvariant()
    }
}

function Merge-ManagedPathEntries {
    param(
        [string[]] $ExistingEntries = @(),
        [string[]] $ManagedEntries = @()
    )

    $managed = @($ManagedEntries | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)) })
    $managedKeys = @($managed | ForEach-Object { Get-ManagedPathKey $_ })

    $remaining = @($ExistingEntries | Where-Object {
        if (-not $_) {
            return $false
        }

        $entryKey = Get-ManagedPathKey $_
        $managedKeys -notcontains $entryKey
    })

    @($managed + $remaining | Select-Object -Unique)
}

function Set-ManagedUserEnvironment {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Value
    )

    $expandedValue = [Environment]::ExpandEnvironmentVariables($Value)
    if ($expandedValue -match '[\\/]') {
        $expandedValue = [IO.Path]::GetFullPath($expandedValue)
    }

    $currentValue = [Environment]::GetEnvironmentVariable($Name, "User")
    if ($currentValue -eq $expandedValue) {
        Write-Host "User $Name is already $expandedValue."
    } else {
        [Environment]::SetEnvironmentVariable($Name, $expandedValue, "User")
        Write-Host "Set user $Name to $expandedValue."
    }

    Set-Item -Path "Env:$Name" -Value $expandedValue
}

function Add-ManagedUserPath {
    param([Parameter(Mandatory)] [string[]] $Path)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { $_ })
    $newEntries = Merge-ManagedPathEntries -ExistingEntries $entries -ManagedEntries $Path
    $newUserPath = $newEntries -join ";"

    if ($userPath -eq $newUserPath) {
        Write-Host "User PATH already contains managed entries."
    } else {
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Write-Host "Updated user PATH."
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:Path = @($machinePath, $newUserPath | Where-Object { $_ }) -join ";"
}

function Parse-WinGetPackageSpec {
    param([Parameter(Mandatory)] [string] $Spec)

    $trimmed = $Spec.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) {
        throw "WinGet package spec must not be empty or a comment."
    }

    if ($trimmed -notmatch '^(?<id>[^@\s]+)(?:@(?<version>[0-9][0-9A-Za-z.\-_]*))?$') {
        throw "Invalid WinGet package spec '$Spec'. Expected Package.Id, Package.Id@1.2, or Package.Id@1.2.3."
    }

    $id = $Matches.id
    $version = if ($Matches.version) { $Matches.version } else { $null }
    $versionMode = "Any"
    $pinVersion = $null

    if ($version) {
        $parts = @($version -split '\.')
        if ($parts.Count -lt 3) {
            $versionMode = "Prefix"
            $pinVersion = "$version.*"
        } else {
            $versionMode = "Exact"
            $pinVersion = $version
        }
    }

    [pscustomobject]@{
        Id          = $id
        Version     = $version
        VersionMode = $versionMode
        PinVersion  = $pinVersion
        Source      = "winget"
    }
}

function Read-WinGetPackageSpecs {
    param([Parameter(Mandatory)] [string] $Path)

    @(Get-Content -LiteralPath $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") } |
        ForEach-Object { Parse-WinGetPackageSpec $_ })
}

function Test-WinGetVersionSatisfiesSpec {
    param(
        [Parameter(Mandatory)] [string] $InstalledVersion,
        [Parameter(Mandatory)] [pscustomobject] $Spec
    )

    switch ($Spec.VersionMode) {
        "Any" { return $true }
        "Exact" { return $InstalledVersion -eq $Spec.Version }
        "Prefix" { return $InstalledVersion.StartsWith("$($Spec.Version).", [StringComparison]::OrdinalIgnoreCase) }
        default { throw "Unknown WinGet version mode '$($Spec.VersionMode)' for $($Spec.Id)." }
    }
}

function ConvertTo-VersionSortKey {
    param([Parameter(Mandatory)] [string] $Version)

    try {
        [version] $Version
    } catch {
        [version] "0.0.0.0"
    }
}

function Select-WinGetInstallVersion {
    param(
        [Parameter(Mandatory)] [string[]] $AvailableVersions,
        [Parameter(Mandatory)] [pscustomobject] $Spec
    )

    switch ($Spec.VersionMode) {
        "Any" { return $null }
        "Exact" {
            if ($AvailableVersions -contains $Spec.Version) {
                return $Spec.Version
            }
            throw "$($Spec.Id) version $($Spec.Version) is not available from WinGet."
        }
        "Prefix" {
            $matchingVersions = @($AvailableVersions | Where-Object { $_.StartsWith("$($Spec.Version).", [StringComparison]::OrdinalIgnoreCase) })
            if ($matchingVersions.Count -eq 0) {
                throw "$($Spec.Id) has no available WinGet versions matching $($Spec.Version).*."
            }

            return @($matchingVersions | Sort-Object @{ Expression = { ConvertTo-VersionSortKey $_ }; Descending = $true }, @{ Expression = { $_ }; Descending = $true })[0]
        }
        default { throw "Unknown WinGet version mode '$($Spec.VersionMode)' for $($Spec.Id)." }
    }
}

function Get-WinGetAvailableVersions {
    param(
        [Parameter(Mandatory)] [string] $Id,
        [string] $Source = "winget"
    )

    $output = winget show --id $Id --exact --source $Source --versions --disable-interactivity 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "winget show --versions failed for $Id with exit code $LASTEXITCODE"
    }

    @($output |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^(Found|Version|-+)' })
}

function Get-WinGetPackageVersion {
    param(
        [Parameter(Mandatory)] [string] $Id,
        [string] $Source = "winget"
    )

    $output = winget list --id $Id --exact --source $Source --disable-interactivity 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    foreach ($line in @($output)) {
        if ($line -match [regex]::Escape($Id)) {
            $columns = @($line -split '\s{2,}' | Where-Object { $_ })
            if ($columns.Count -ge 3) {
                return $columns[2].Trim()
            }
        }
    }

    $null
}

function Test-WinGetPackageInstalled {
    param(
        [string] $Id,
        [string] $Name,
        [string] $Source = "winget"
    )

    $arguments = @(
        "list"
        "--exact"
        "--source", $Source
        "--disable-interactivity"
    )

    if ($Id) {
        $arguments += @("--id", $Id)
    } elseif ($Name) {
        $arguments += @("--name", $Name)
    } else {
        throw "Either Id or Name is required to test a WinGet package."
    }

    winget @arguments | Out-Null
    $LASTEXITCODE -eq 0
}

function Add-WinGetPackagePin {
    param([Parameter(Mandatory)] [pscustomobject] $Spec)

    if (-not $Spec.PinVersion) {
        return
    }

    winget pin add --id $Spec.Id --exact --source $Spec.Source --version $Spec.PinVersion --accept-source-agreements --disable-interactivity --force | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "winget pin add failed for $($Spec.Id)@$($Spec.PinVersion) with exit code $LASTEXITCODE"
    }
}

function Install-WinGetPackage {
    param(
        [string] $Id,
        [string] $PackageName,
        [string] $Source = "winget",
        [string] $Name
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required to install Windows packages, but winget was not found on PATH."
    }

    $displayName = if ($Name) { $Name } elseif ($PackageName) { $PackageName } else { $Id }
    if (Test-WinGetPackageInstalled -Id $Id -Name $PackageName -Source $Source) {
        Write-Host "$displayName is already installed."
        return
    }

    Write-Host "Installing $displayName from $Source..."
    $arguments = @(
        "install"
        "--exact"
        "--source", $Source
        "--silent"
        "--disable-interactivity"
        "--accept-source-agreements"
        "--accept-package-agreements"
    )

    if ($Id) {
        $arguments += @("--id", $Id)
    } elseif ($PackageName) {
        $arguments += @($PackageName)
    } else {
        throw "Either Id or PackageName is required to install a WinGet package."
    }

    winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $displayName with exit code $LASTEXITCODE"
    }
}

function Install-WinGetPackageSpec {
    param([Parameter(Mandatory)] [pscustomobject] $Spec)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required to install Windows packages, but winget was not found on PATH."
    }

    $installedVersion = Get-WinGetPackageVersion -Id $Spec.Id -Source $Spec.Source
    if ($installedVersion) {
        if (-not (Test-WinGetVersionSatisfiesSpec -InstalledVersion $installedVersion -Spec $Spec)) {
            throw "$($Spec.Id) is installed at $installedVersion, which does not satisfy requested spec $($Spec.Id)@$($Spec.Version)."
        }

        Write-Host "$($Spec.Id) is already installed: $installedVersion."
        Add-WinGetPackagePin -Spec $Spec
        return
    }

    Write-Host "Installing $($Spec.Id) from $($Spec.Source)..."
    $arguments = @(
        "install"
        "--id", $Spec.Id
        "--exact"
        "--source", $Spec.Source
        "--silent"
        "--disable-interactivity"
        "--accept-source-agreements"
        "--accept-package-agreements"
    )

    if ($Spec.VersionMode -ne "Any") {
        $availableVersions = Get-WinGetAvailableVersions -Id $Spec.Id -Source $Spec.Source
        $installVersion = Select-WinGetInstallVersion -AvailableVersions $availableVersions -Spec $Spec
        $arguments += @("--version", $installVersion)
    }

    winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed for $($Spec.Id) with exit code $LASTEXITCODE"
    }

    Add-WinGetPackagePin -Spec $Spec
}

Export-ModuleMember -Function `
    Add-ManagedUserPath, `
    Add-WinGetPackagePin, `
    Get-ManagedPathKey, `
    Get-WinGetPackageVersion, `
    Install-WinGetPackage, `
    Install-WinGetPackageSpec, `
    Merge-ManagedPathEntries, `
    Parse-WinGetPackageSpec, `
    Read-WinGetPackageSpecs, `
    Select-WinGetInstallVersion, `
    Set-ManagedUserEnvironment, `
    Test-WinGetPackageInstalled, `
    Test-WinGetVersionSatisfiesSpec
