#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "home/dot_rmux.conf"
$config = Get-Content -LiteralPath $configPath -Raw

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

Assert-Contains $config 'set -g default-command "nu"' "rmux panes must launch native Nushell."
Assert-True (-not $config.Contains("cmd /c nu")) "The cmd.exe wrapper hides foreground titles and is no longer needed."
Assert-True (-not $config.Contains('set -as terminal-features')) "Windows Terminal leaves outer TERM empty, so rmux 0.9 skips terminal-features patterns; do not retain a dead truecolor workaround."
Assert-Contains $config 'set-environment -g CLAUDE_CODE_TMUX_TRUECOLOR 1' "Claude must keep its 24-bit palette when rmux exposes tmux compatibility."
Assert-Contains $config 'set-environment -g COLORTERM truecolor' "WT-backed rmux panes must advertise their 24-bit colour capability to other applications."
Assert-Contains $config 'bind -n C-d send-keys -H 04' "Bare Ctrl-D must bypass rmux 0.8.0's Windows Ctrl-D token gate."

Assert-Contains $config 'set-hook -g after-new-session' "New sessions need an attached-client switch hook."
Assert-Contains $config '#{client_name}' "The new-session hook must be a no-op for detached CLI callers."
Assert-Contains $config 'switch-client -t #{session_name}' "The new-session hook must switch to its newly created session target."

Assert-Contains $config 'set -g automatic-rename-format "#{pane_current_command}"' "rmux must use its standard pane-command window label."
Assert-True (-not $config.Contains('#{pane_title}')) "rmux must not derive window labels from full terminal titles or paths."
Assert-Contains $config '#[none fg=#8a8a8a bg=#080808]#{?window_last_flag,#[fg=#00afff bg=#303030],}' "The explicit rmux status format must emit normal and recent-window colours without nested style expansion."
Assert-Contains $config '#[list=focus none fg=#080808 bg=#00afff bold]' "The explicit rmux status format must emit the active-window style and list focus together."
Assert-True (-not $config.Contains('#[#{E:')) "rmux 0.9 copies style clauses atomically, so expanded style options cannot be nested directly inside #[...]."
$windowRangeCount = ([regex]::Matches($config, [regex]::Escape('range=window|#{window_index}'))).Count
Assert-True ($windowRangeCount -eq 0) "Clickable status tabs must target stable window IDs, not renumbered window indexes."
$stableWindowRange = '#{l:#[range=window|}#{s/@//:window_id}]'
$stableWindowRangeCount = ([regex]::Matches($config, [regex]::Escape($stableWindowRange))).Count
Assert-True ($stableWindowRangeCount -eq 2) "Both active and inactive status tabs must open a click range for their stable window ID."
$closedWindowRangeCount = ([regex]::Matches($config, [regex]::Escape('#[norange list=on]'))).Count
Assert-True ($closedWindowRangeCount -ge 2) "Every clickable status tab must close its range without leaving the flexible list."

if ($IsWindows -and (Get-Command rmux -ErrorAction SilentlyContinue) -and (Get-Command nu -ErrorAction SilentlyContinue)) {
    $serverName = "chezmoi-rmux-test-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    $oldHome = $env:HOME
    try {
        # rmux expands ~/.rmux.conf while parsing the reload binding.
        $env:HOME = $env:USERPROFILE
        # rmux resolves the very first daemon pane before applying default-command,
        # so name Nu explicitly here; static assertions cover subsequent panes.
        # Do not pipe startup output: the background daemon inherits redirected
        # handles on Windows and would keep Out-String waiting for EOF.
        & rmux -L $serverName -f $configPath new-session -d -s eot -x 80 -y 24 nu
        Assert-True ($LASTEXITCODE -eq 0) "rmux must load the managed configuration."
        Start-Sleep -Milliseconds 500

        $paneCommand = (& rmux -L $serverName list-panes -t eot -F '#{pane_current_command}' 2>&1 | Out-String).Trim()
        $claudeTruecolor = (& rmux -L $serverName show-environment -g CLAUDE_CODE_TMUX_TRUECOLOR 2>&1 | Out-String).Trim()
        $colorTerm = (& rmux -L $serverName show-environment -g COLORTERM 2>&1 | Out-String).Trim()
        Assert-True ($paneCommand -eq "nu") "rmux must start native Nu; got '$paneCommand'."
        Assert-True ($claudeTruecolor -eq "CLAUDE_CODE_TMUX_TRUECOLOR=1") "rmux panes must inherit Claude's tmux truecolor opt-in; got '$claudeTruecolor'."
        Assert-True ($colorTerm -eq "COLORTERM=truecolor") "rmux panes must inherit the WT truecolor capability; got '$colorTerm'."

        $bindings = (& rmux -L $serverName list-keys 2>&1 | Out-String)
        Assert-True ($bindings -match 'root\s+C-d\s+send-keys\s+-H\s+04') "rmux must register the hexadecimal EOT root binding."

        $hooks = (& rmux -L $serverName show-hooks -g after-new-session 2>&1 | Out-String)
        Assert-True ($hooks -match 'after-new-session') "rmux must register the guarded new-session switch hook."

        & rmux -L $serverName send-keys -t eot -H 04
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds 100
            & rmux -L $serverName has-session -t eot 2>$null
            $sessionExists = $LASTEXITCODE -eq 0
        } while ($sessionExists -and $stopwatch.ElapsedMilliseconds -lt 5000)
        Assert-True (-not $sessionExists) "Hexadecimal EOT must exit a direct Nushell pane."
    }
    finally {
        try { & rmux -L $serverName kill-server 2>$null | Out-Null } catch { }
        $env:HOME = $oldHome
    }
}

Write-Output "rmux configuration tests passed."
