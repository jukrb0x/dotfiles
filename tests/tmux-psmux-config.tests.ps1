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

function Wait-ForPsmuxPane {
    param(
        [Parameter(Mandatory)] [string] $ServerName,
        [Parameter(Mandatory)] [string] $Target,
        [Parameter(Mandatory)] [scriptblock] $Condition,
        [Parameter(Mandatory)] [string] $Description,
        [int] $TimeoutMilliseconds = 10000
    )

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $capture = (& psmux -L $ServerName capture-pane -p -t $Target -S -30 2>&1 | Out-String)
        if (& $Condition $capture) {
            return $capture
        }
        Start-Sleep -Milliseconds 100
    } while ($stopwatch.ElapsedMilliseconds -lt $TimeoutMilliseconds)

    throw "Timed out waiting for $Description after $TimeoutMilliseconds ms.`nLast pane capture:`n$capture"
}

$dataPath = Join-Path $sourceRoot ".chezmoidata.toml"
Assert-True (Test-Path -LiteralPath $dataPath) "Shared tmux data must live in home/.chezmoidata.toml."

$windowsEntry = Render-SourceTemplate "symlink_dot_tmux.conf.tmpl" "windows"
$linuxEntry = Render-SourceTemplate "symlink_dot_tmux.conf.tmpl" "linux"
$darwinEntry = Render-SourceTemplate "symlink_dot_tmux.conf.tmpl" "darwin"
Assert-True ($windowsEntry.Trim() -eq ".psmux/.tmux.conf") "Windows ~/.tmux.conf must point at the static psmux configuration."
Assert-True ($linuxEntry.Trim() -eq ".tmux/.tmux.conf") "Linux ~/.tmux.conf must continue pointing at oh-my-tmux."
Assert-True ($darwinEntry.Trim() -eq ".tmux/.tmux.conf") "macOS ~/.tmux.conf must continue pointing at oh-my-tmux."

$linuxLocal = Render-SourceTemplate "dot_tmux.conf.local.tmpl" "linux"
$darwinLocal = Render-SourceTemplate "dot_tmux.conf.local.tmpl" "darwin"
$expectedUnixLocalHash = "132e1377e2ba4f027cf2c7056a96c6d647456f116692c469a0ef591028dd5e6b"
Assert-True `
    ((Get-NormalizedSha256 $linuxLocal) -eq $expectedUnixLocalHash) `
    "Linux ~/.tmux.conf.local must retain the existing custom oh-my-tmux content."
Assert-True `
    ((Get-NormalizedSha256 $darwinLocal) -eq $expectedUnixLocalHash) `
    "macOS ~/.tmux.conf.local must retain the existing custom oh-my-tmux content."

$windowsLocal = Render-SourceTemplate "dot_tmux.conf.local.tmpl" "windows"
Assert-Contains $windowsLocal 'set -g status-left' "Windows local config must render psmux/tmux commands."
Assert-Contains $windowsLocal '#d70000' "Windows local config must use the shared oh-my-tmux red user colour."
Assert-True (-not $windowsLocal.Contains("tmux_conf_theme_colour_1=")) "Windows local config must not emit POSIX assignments."

$localTemplateSource = Get-Content -LiteralPath (Join-Path $sourceRoot "dot_tmux.conf.local.tmpl") -Raw
Assert-True `
    (([regex]::Matches($localTemplateSource, [regex]::Escape('{{ .tmux.timeFormat }}'))).Count -ge 3) `
    "Both platform renderings must consume the shared status time format."
Assert-True `
    (([regex]::Matches($localTemplateSource, [regex]::Escape('{{ .tmux.dateFormat }}'))).Count -ge 3) `
    "Both platform renderings must consume the shared status date format."
Assert-True `
    (([regex]::Matches($localTemplateSource, [regex]::Escape('.tmux.windowStatusFormat'))).Count -ge 3) `
    "Both platform renderings must derive their labels from the shared window format."

$psmuxBase = Render-SourceTemplate "dot_psmux/dot_tmux.conf.tmpl" "windows"
Assert-Contains $psmuxBase 'source-file ~/.tmux.conf.local' "The static psmux base must load the common local-config entry."
Assert-Contains $psmuxBase 'bind -n C-c if-shell -F "#{client_prefix}" "new-session" "send-keys 0x03"' "Root Ctrl-C must distinguish prefixed new-session from bare raw ETX."
Assert-True (-not $psmuxBase.Contains('bind -n C-c send-keys 0x03')) "The unconditional root Ctrl-C binding would shadow Prefix+C-c in psmux 3.3.6."
Assert-Contains $psmuxBase 'bind C-c new-session' "Prefix+C-c must keep the oh-my-tmux new-session binding."
Assert-Contains $psmuxBase 'bind C-a send-prefix -2' "The standard Prefix+C-a binding must remain ready to pass the secondary prefix after psmux fixes repeated-prefix dispatch."
Assert-Contains $psmuxBase 'bind a send-prefix -2' "Prefix+a must provide the psmux-compatible secondary-prefix passthrough fallback."
Assert-Contains $psmuxBase 'bind b list-buffers' "Prefix+b must retain the oh-my-tmux buffer-list binding."
Assert-Contains $psmuxBase 'set -g automatic-rename on' "Direct-Nu psmux panes must use the built-in foreground-process rename path."
Assert-True (-not $psmuxBase.Contains("~/.psmux.conf")) "The unified config must not refer to the obsolete ~/.psmux.conf entry."

Assert-True (-not $windowsLocal.Contains('#{pane_current_command}')) "Windows status must not replace #W with a custom foreground-command expression."
Assert-True (-not $localTemplateSource.Contains('$windowLabel')) "Windows status must leave window naming to psmux automatic rename."
Assert-Contains $windowsLocal '#{?window_last_flag,#[none,fg=#00afff,bg=#303030] #I #W #[none,fg=#8a8a8a,bg=#080808]' "The previously active window must include coloured left/right padding and reset before the separator."

$windowsIgnore = Render-SourceTemplate ".chezmoiignore.tmpl" "windows"
$linuxIgnore = Render-SourceTemplate ".chezmoiignore.tmpl" "linux"
Assert-True (-not ($windowsIgnore -split "`n").Contains(".tmux.conf")) "Windows must manage ~/.tmux.conf."
Assert-True (-not ($windowsIgnore -split "`n").Contains(".tmux.conf.local")) "Windows must manage ~/.tmux.conf.local."
Assert-Contains $linuxIgnore '.psmux/**' "Non-Windows hosts must ignore the generated psmux implementation directory."
Assert-Contains $linuxIgnore '.psmux.conf' "Non-Windows hosts must not apply the Windows-only removal of ~/.psmux.conf."
Assert-True `
    (Test-Path -LiteralPath (Join-Path $sourceRoot "remove_dot_psmux.conf")) `
    "Windows source state must explicitly remove the obsolete ~/.psmux.conf that would shadow ~/.tmux.conf."

if ($IsWindows -and (Get-Command psmux -ErrorAction SilentlyContinue) -and (Get-Command nu -ErrorAction SilentlyContinue)) {
    $runtimeId = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $runtimeHome = Join-Path $env:TEMP "chezmoi-psmux-test-$runtimeId"
    $serverName = "chezmoi-test-$runtimeId"
    $basePath = Join-Path $runtimeHome ".tmux.conf"
    $localPath = Join-Path $runtimeHome ".tmux.conf.local"
    $oldHome = $env:HOME
    $oldUserProfile = $env:USERPROFILE

    try {
        New-Item -ItemType Directory -Path $runtimeHome | Out-Null
        [IO.File]::WriteAllText($basePath, $psmuxBase, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($localPath, $windowsLocal, [Text.UTF8Encoding]::new($false))

        $env:HOME = $runtimeHome
        $env:USERPROFILE = $runtimeHome
        $startOutput = (& psmux -L $serverName -f $basePath new-session -d -s verify -- nu 2>&1 | Out-String)
        $null = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) ([regex]::Matches($content, '(?m)^❯')).Count -ge 1 } `
            "the initial Nushell prompt"

        $bindings = (& psmux -L $serverName list-keys 2>&1 | Out-String)
        Assert-True ($startOutput -notmatch '(?i)warning|error|unknown') "Rendered psmux configuration must load without warnings."
        Assert-True ($bindings -match 'root\s+C-c\s+if-shell.*client_prefix.*new-session.*send-keys 0x03') "psmux must register the prefix-aware root Ctrl-C dispatcher."
        Assert-True ($bindings -match 'prefix\s+C-c\s+new-session') "psmux must retain Prefix+C-c for new-session."
        Assert-True ($bindings -match 'prefix\s+C-a\s+send-prefix\s+-2') "psmux must retain the standard secondary-prefix passthrough binding."
        Assert-True ($bindings -match 'prefix\s+a\s+send-prefix\s+-2') "psmux must register Prefix+a as the working secondary-prefix passthrough fallback."
        Assert-True ($bindings -match 'prefix\s+b\s+list-buffers') "psmux must retain Prefix+b for buffer listing."

        & psmux -L $serverName send-keys -t "verify:1" -l "INTERRUPT_ME"
        & psmux -L $serverName send-keys -t "verify:1" "0x03"
        $promptCapture = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) ([regex]::Matches($content, '(?m)^❯')).Count -ge 2 } `
            "the prompt after raw ETX"
        Assert-True ($promptCapture -notmatch 'Operation interrupted') "Raw ETX must not interrupt the subsequent Starship prompt redraw."

        & psmux -L $serverName send-keys -t "verify:1" -l "ping -t 127.0.0.1"
        & psmux -L $serverName send-keys -t "verify:1" Enter
        $null = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) $content -match 'Reply from 127\.0\.0\.1' } `
            "ping output"
        $foregroundLabel = (& psmux -L $serverName display-message -p -t "verify:1" '#{?#{!=:#{window_name},nu},#{window_name},#{?#{==:#{pane_current_command},starship},nu,#{pane_current_command}}}' 2>&1 | Out-String).Trim()
        Assert-True ($foregroundLabel -eq "ping") "The computed psmux window label must report a foreground child process; got '$foregroundLabel'."
        & psmux -L $serverName send-keys -t "verify:1" "0x03"
        $null = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) $content -match 'Control-C' } `
            "ping interruption"
        & psmux -L $serverName send-keys -t "verify:1" -l "echo PSMUX_ETX_OK"
        & psmux -L $serverName send-keys -t "verify:1" Enter
        $pingCapture = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) $content -match '(?m)^PSMUX_ETX_OK\r?$' } `
            "the Nushell prompt after interrupting ping"
        Assert-True ($pingCapture -match 'Control-C') "Raw ETX must interrupt a Windows console child process."
        Assert-True ($pingCapture -match '(?m)^PSMUX_ETX_OK\r?$') "Nushell prompt must return after interrupting the child process."
    }
    finally {
        & psmux -L $serverName kill-server 2>$null | Out-Null
        $env:HOME = $oldHome
        $env:USERPROFILE = $oldUserProfile
        if (Test-Path -LiteralPath $runtimeHome) {
            Remove-Item -LiteralPath $runtimeHome -Recurse -Force
        }
    }
}

Write-Output "tmux/psmux cross-platform configuration tests passed."
