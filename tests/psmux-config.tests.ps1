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

function Assert-PsmuxWorkaroundAnnotations {
    param([Parameter(Mandatory)] [string] $PsmuxSource)

    Assert-Contains $PsmuxSource '# PSMUX annotation legend:' "The PSMUX template must explain its compatibility markers."

    $beginCount = ([regex]::Matches($PsmuxSource, '(?m)^# PSMUX-WORKAROUND-BEGIN:')).Count
    $endCount = ([regex]::Matches($PsmuxSource, '(?m)^# PSMUX-WORKAROUND-END$')).Count
    Assert-True ($beginCount -eq $endCount) "Every PSMUX workaround marker must have a matching end marker."

    $blocks = [regex]::Matches(
        $PsmuxSource,
        '(?ms)^# PSMUX-WORKAROUND-BEGIN: (?<id>[^\r\n]+)\r?\n(?<body>.*?)^# PSMUX-WORKAROUND-END$'
    )
    Assert-True ($blocks.Count -eq 3) "Expected exactly three documented PSMUX workaround blocks."

    $expectedIds = @('nested-prefix-fallback', 'root-ctrl-c-dispatch', 'status-layout-adapter')
    foreach ($block in $blocks) {
        Assert-Contains $block.Groups['body'].Value '# Why:' "Workaround '$($block.Groups['id'].Value)' must explain why it exists."
        Assert-Contains $block.Groups['body'].Value '# Remove when:' "Workaround '$($block.Groups['id'].Value)' must define its removal test."
    }

    $blockIds = @($blocks | ForEach-Object { $_.Groups['id'].Value })
    foreach ($id in $expectedIds) {
        Assert-True ($blockIds -contains $id) "Missing PSMUX workaround annotation: $id"
    }
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
$psmuxTemplatePath = Join-Path $sourceRoot "dot_psmux.conf.tmpl"
Assert-True (Test-Path -LiteralPath $dataPath) "Shared tmux data must live in home/.chezmoidata.toml."
Assert-True (Test-Path -LiteralPath $psmuxTemplatePath) "Windows must own a native ~/.psmux.conf template."

$psmuxSource = Get-Content -LiteralPath $psmuxTemplatePath -Raw
$psmuxConfig = Render-SourceTemplate "dot_psmux.conf.tmpl" "windows"
Assert-Contains $psmuxConfig 'bind e new-window -n .psmux.conf nvim ~/.psmux.conf' "The edit binding must open the native PSMUX config."
Assert-Contains $psmuxConfig 'bind r source-file ~/.psmux.conf' "The reload binding must reload the native PSMUX config."
Assert-True (-not $psmuxConfig.Contains('source-file ~/.tmux.conf')) "PSMUX must not source tmux configuration."
Assert-True (-not $psmuxConfig.Contains('~/.tmux.conf.local')) "PSMUX must not source tmux local configuration."
Assert-True (-not (Test-Path (Join-Path $sourceRoot "remove_dot_psmux.conf"))) "The native PSMUX config must no longer be an explicitly removed target."
Assert-PsmuxWorkaroundAnnotations $psmuxSource

Assert-Contains $psmuxConfig 'bind -n C-c if-shell -F "#{client_prefix}" "new-session" "send-keys 0x03"' "Root Ctrl-C must distinguish prefixed new-session from bare raw ETX."
Assert-True (-not $psmuxConfig.Contains('bind -n C-c send-keys 0x03')) "The unconditional root Ctrl-C binding would shadow Prefix+C-c."
Assert-Contains $psmuxConfig 'bind C-c new-session' "Prefix+C-c must keep the oh-my-tmux new-session binding."
Assert-Contains $psmuxConfig 'bind C-a send-prefix -2' "Prefix+C-a must retain secondary-prefix passthrough."
Assert-Contains $psmuxConfig 'bind a send-prefix -2' "Prefix+a must retain the PSMUX fallback."
Assert-Contains $psmuxConfig 'bind b list-buffers' "Prefix+b must retain the buffer-list binding."
Assert-Contains $psmuxConfig 'set -g automatic-rename on' "Direct-Nu panes must use foreground-process rename."
Assert-Contains $psmuxConfig 'set -g status-left' "PSMUX must render the shared status-left."
Assert-Contains $psmuxConfig '#d70000' "PSMUX must use the shared oh-my-tmux red user colour."
Assert-Contains $psmuxConfig '#{?window_last_flag,#[none,fg=#00afff,bg=#303030] #I #W #[none,fg=#8a8a8a,bg=#080808]' "The recent window must retain its complete style."
Assert-True (-not $psmuxConfig.Contains('#{pane_current_command}')) "Status must not replace #W with a custom foreground-command expression."
Assert-True (-not $psmuxSource.Contains('$windowLabel')) "Window naming must remain native to PSMUX automatic rename."
Assert-True (-not $psmuxConfig.Contains('tmux_conf_theme_colour_1=')) "PSMUX must not emit POSIX assignments."

foreach ($token in @('.tmux.timeFormat', '.tmux.dateFormat', '.tmux.windowStatusFormat', '.tmux.statusLeft', '.tmux.prefixIndicator', '.tmux.mouseIndicator', '.tmux.pairingIndicator', '.tmux.synchronizedIndicator', '.tmux.clockStyle')) {
    Assert-Contains $psmuxSource $token "The native PSMUX template must consume shared token $token."
}

$windowsIgnore = Render-SourceTemplate ".chezmoiignore.tmpl" "windows"
Assert-True (-not ($windowsIgnore -split "`n").Contains(".psmux.conf")) "Windows must manage ~/.psmux.conf."

$windowsRemovalList = Render-SourceTemplate ".chezmoiremove.tmpl" "windows"
$linuxRemovalList = Render-SourceTemplate ".chezmoiremove.tmpl" "linux"
Assert-True ($windowsRemovalList.Trim() -eq ".psmux/.tmux.conf") "Windows must remove only the obsolete nested compatibility file."
Assert-True ([string]::IsNullOrWhiteSpace($linuxRemovalList)) "Non-Windows hosts must not remove PSMUX paths."
Assert-True (-not $windowsRemovalList.Contains('.psmux/**')) "Migration must never recursively remove ~/.psmux."
Assert-True (-not (Test-Path (Join-Path $sourceRoot "dot_psmux/dot_tmux.conf.tmpl"))) "The old nested compatibility source must be gone."
Assert-True (-not (Test-Path (Join-Path $sourceRoot "remove_dot_psmux.conf"))) "The old native-config removal entry must be gone."

if ($IsWindows -and (Get-Command psmux -ErrorAction SilentlyContinue) -and (Get-Command nu -ErrorAction SilentlyContinue)) {
    $runtimeId = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $runtimeHome = Join-Path $env:TEMP "chezmoi-psmux-test-$runtimeId"
    $serverName = "chezmoi-test-$runtimeId"
    $configPath = Join-Path $runtimeHome ".psmux.conf"
    $oldHome = $env:HOME
    $oldUserProfile = $env:USERPROFILE

    try {
        New-Item -ItemType Directory -Path $runtimeHome | Out-Null
        [IO.File]::WriteAllText($configPath, $psmuxConfig, [Text.UTF8Encoding]::new($false))

        $env:HOME = $runtimeHome
        $env:USERPROFILE = $runtimeHome
        $startOutput = (& psmux -L $serverName new-session -d -s verify -- nu 2>&1 | Out-String)
        $null = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) ([regex]::Matches($content, '(?m)^❯')).Count -ge 1 } `
            "the initial Nushell prompt"

        $bindings = (& psmux -L $serverName list-keys 2>&1 | Out-String)
        Assert-True ($startOutput -notmatch '(?i)warning|error|unknown') "Rendered PSMUX configuration must load without warnings."
        Assert-True ($bindings -match 'root\s+C-c\s+if-shell.*client_prefix.*new-session.*send-keys 0x03') "PSMUX must register the prefix-aware root Ctrl-C dispatcher."
        Assert-True ($bindings -match 'prefix\s+C-c\s+new-session') "PSMUX must retain Prefix+C-c for new-session."
        Assert-True ($bindings -match 'prefix\s+C-a\s+send-prefix\s+-2') "PSMUX must retain the standard secondary-prefix passthrough binding."
        Assert-True ($bindings -match 'prefix\s+a\s+send-prefix\s+-2') "PSMUX must register Prefix+a as the fallback."
        Assert-True ($bindings -match 'prefix\s+b\s+list-buffers') "PSMUX must retain Prefix+b for buffer listing."
        Assert-True ($bindings -match 'prefix\s+f\s+command-prompt.*find-window.*%%') "PSMUX must register Prefix+f."
        Assert-True ($bindings -match 'prefix\s+~\s+show-messages') "PSMUX must register Prefix+~."

        & psmux -L $serverName send-keys -t "verify:1" -l "INTERRUPT_ME"
        & psmux -L $serverName send-keys -t "verify:1" "0x03"
        $promptCapture = Wait-ForPsmuxPane $serverName "verify:1" `
            { param($content) ([regex]::Matches($content, '(?m)^❯')).Count -ge 2 } `
            "the prompt after raw ETX"
        Assert-True ($promptCapture -notmatch 'Operation interrupted') "Raw ETX must not interrupt Starship prompt redraw."

        & psmux -L $serverName send-keys -t "verify:1" -l "ping -t 127.0.0.1"
        & psmux -L $serverName send-keys -t "verify:1" Enter
        $null = Wait-ForPsmuxPane $serverName "verify:1" { param($content) $content -match 'Reply from 127\.0\.0\.1' } "ping output"
        $foregroundLabel = (& psmux -L $serverName display-message -p -t "verify:1" '#{?#{!=:#{window_name},nu},#{window_name},#{?#{==:#{pane_current_command},starship},nu,#{pane_current_command}}}' 2>&1 | Out-String).Trim()
        Assert-True ($foregroundLabel -eq "ping") "The computed PSMUX window label must report a foreground child process; got '$foregroundLabel'."
        & psmux -L $serverName send-keys -t "verify:1" "0x03"
        $null = Wait-ForPsmuxPane $serverName "verify:1" { param($content) $content -match 'Control-C' } "ping interruption"
        & psmux -L $serverName send-keys -t "verify:1" -l "echo PSMUX_ETX_OK"
        & psmux -L $serverName send-keys -t "verify:1" Enter
        $pingCapture = Wait-ForPsmuxPane $serverName "verify:1" { param($content) $content -match '(?m)^PSMUX_ETX_OK\r?$' } "the prompt after interrupting ping"
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

Write-Output "PSMUX configuration tests passed."
