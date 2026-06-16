$ErrorActionPreference = "Stop"

$paths = @(
    (Join-Path $env:APPDATA "..\bin"),
    (Join-Path $HOME ".local\bin"),
    (Join-Path $HOME "scoop\shims"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
    "C:\msys64\ucrt64\bin"
)

function Get-PathKey {
    param([Parameter(Mandatory)] [string] $Path)

    try {
        [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)).TrimEnd("\").ToLowerInvariant()
    } catch {
        $Path.Trim().TrimEnd("\").ToLowerInvariant()
    }
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$entries = @($userPath -split ";" | Where-Object { $_ })
$managedPaths = @($paths | ForEach-Object { [IO.Path]::GetFullPath($_) })
$managedPathKeys = @($managedPaths | ForEach-Object { Get-PathKey $_ })

$remainingEntries = @($entries | Where-Object {
    $entryKey = Get-PathKey $_
    $managedPathKeys -notcontains $entryKey
})

$newUserPath = @($managedPaths + $remainingEntries | Select-Object -Unique) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$env:Path = @($machinePath, $newUserPath | Where-Object { $_ }) -join ";"

Write-Host "Updated user PATH. Restart terminals to inherit it."
