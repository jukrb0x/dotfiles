Set-Alias -Name g -Value git
Set-Alias -Name l -Value Get-ChildItem
Set-Alias -Name open -Value Start-Process
Set-Alias -Name which -Value Get-Command

function lvim {
    & "$HOME\.local\bin\lvim.ps1" @args
}

$env:EDITOR = "$HOME\.local\bin\lvim.bat"
$env:VISUAL = $env:EDITOR

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

$localProfile = Join-Path $HOME ".config\powershell\profile.local.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
