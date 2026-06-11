$ErrorActionPreference = "Stop"

$paths = @(
    (Join-Path $HOME ".local\bin"),
    (Join-Path $HOME "scoop\shims"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
    "C:\msys64\ucrt64\bin"
)

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$entries = @($userPath -split ";" | Where-Object { $_ })

foreach ($path in $paths) {
    if ($entries -notcontains $path) {
        $entries += $path
    }
}

$newUserPath = ($entries | Select-Object -Unique) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$env:Path = @($machinePath, $newUserPath | Where-Object { $_ }) -join ";"

Write-Host "Updated user PATH. Restart terminals to inherit it."
