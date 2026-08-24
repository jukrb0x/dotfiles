#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Contains {
    param([string]$Content, [string]$Expected, [string]$Message)
    Assert-True $Content.Contains($Expected) "$Message`nMissing: $Expected"
}
function Assert-NotContains {
    param([string]$Content, [string]$Unexpected, [string]$Message)
    Assert-True (-not $Content.Contains($Unexpected)) "$Message`nUnexpected: $Unexpected"
}

$snapshot = Get-Content -Raw (Join-Path $repoRoot "home\dot_config\rmux\snapshot.nu")

# --- replay safety -------------------------------------------------------
# These are the assertions that matter most. rmux has no session persistence,
# so this module is the only thing standing between a restore and a replay of
# whatever commands were on screen -- clones, builds, deletions.
#
# The checks target *invocations* (`^rmux ...`), not mentions: the module
# deliberately discusses paste-buffer in a comment explaining why it is unsafe.

Assert-NotContains $snapshot '^rmux paste-buffer' "Restoring must never paste scrollback: paste-buffer injects text into the shell input line, so every captured command would execute."
Assert-NotContains $snapshot '^rmux send-keys' "Restoring must never send scrollback as keystrokes; captured commands would run."
Assert-NotContains $snapshot '^rmux load-buffer' "load-buffer only exists to feed paste-buffer, so it has no place in a restore path."
Assert-Contains $snapshot 'open --raw' "Scrollback must be replayed as printed output, which is inert."

# --- rmux quirks this module works around --------------------------------

Assert-Contains $snapshot '#{window_id}' "Restore must target stable window IDs: renumber-windows is on, so an index captured moments earlier can point at a different window."
Assert-Contains $snapshot '#{pane_id}' "Restore must target stable pane IDs for the same reason."
Assert-NotContains $snapshot 'nu -e "($escaped)" -i ; nu' "rmux execs the launch string directly rather than via a shell, so 'a ; b' kills the pane."
Assert-Contains $snapshot '-e' "Launching a command must use nu -e ... -i so the pane survives the command exiting."
Assert-Contains $snapshot "str replace --all '\' '/'" "Snapshot paths must use forward slashes; a literal C:\Users path trips Nushell escape parsing on \U."
Assert-Contains $snapshot 'capture-pane -p -J -S -' "Scrollback capture must request full history with wrapped lines rejoined."

# --- documented limitations ----------------------------------------------
# Both are rmux behaviours that cannot be worked around, so they must stay
# documented where the next reader will see them.

Assert-Contains $snapshot 'cwd_is_unreliable' "The manifest must record that cwd cannot be trusted."
Assert-Contains $snapshot 'reported_cwd' "Dumps must mark the captured cwd as merely reported: rmux returns the pane start directory, never the shell's current directory."

# --- retention -----------------------------------------------------------

Assert-Contains $snapshot 'KEEP_GENERATIONS = 5' "Snapshots must keep a bounded number of generations."
Assert-Contains $snapshot 'prune-generations' "Dumping must prune old generations."

# --- shims ---------------------------------------------------------------
# Restore has to run before any Nushell exists, because the sessions being
# restored are the ones that host Nushell. That makes the shims load-bearing,
# not a convenience.

foreach ($name in @("rmux-dump", "rmux-load")) {
    $ps1 = Get-Content -Raw (Join-Path $repoRoot "home\dot_local\bin\$name.ps1")
    $bat = Get-Content -Raw (Join-Path $repoRoot "home\dot_local\bin\$name.bat")

    Assert-Contains $ps1 '.config\rmux\snapshot.nu' "$name.ps1 must delegate to the single Nushell implementation."
    Assert-Contains $ps1 'exit $LASTEXITCODE' "$name.ps1 must propagate Nushell's exit code, or a failed scheduled run reports success."
    Assert-Contains $bat 'exit /b %ERRORLEVEL%' "$name.bat must propagate the exit code for the same reason."
}

# --- scheduled task ------------------------------------------------------

$register = Get-Content -Raw (Join-Path $repoRoot "scripts\register-windows-rmux-snapshot.ps1")
Assert-Contains $register 'New-TimeSpan -Days 3650' "Repetition duration must be finite: Task Scheduler rejects the XML for both TimeSpan MaxValue and Zero."
Assert-NotContains $register '-RepetitionDuration ([TimeSpan]::MaxValue)' "TimeSpan MaxValue serialises to P99999999DT23H59M59S, which Task Scheduler refuses. (The comment explaining this may name it; the argument must not use it.)"
Assert-Contains $register 'RunLevel Limited' "The snapshot task only reads rmux state and writes under the user profile; it must not request elevation."
Assert-Contains $register 'MultipleInstances IgnoreNew' "Overlapping dumps would race on the same generation directory."

$taskTemplate = Get-Content -Raw (Join-Path $repoRoot "home\.chezmoiscripts\run_onchange_after_26-windows-rmux-snapshot.ps1.tmpl")
Assert-Contains $taskTemplate 'eq .chezmoi.os "windows"' "The snapshot task is Windows-only."
Assert-Contains $taskTemplate 'register-windows-rmux-snapshot.ps1" | sha256sum' "The template must hash the installer so run_onchange re-runs when it changes."

# --- chezmoi gating ------------------------------------------------------

$ignore = Get-Content -Raw (Join-Path $repoRoot "home\.chezmoiignore.tmpl")
foreach ($entry in @(".local/bin/rmux-dump.ps1", ".local/bin/rmux-dump.bat", ".local/bin/rmux-load.ps1", ".local/bin/rmux-load.bat", ".config/rmux/**")) {
    Assert-Contains $ignore $entry "Non-Windows hosts must ignore $entry; rmux replaces tmux on Windows only."
}

# --- nushell wiring ------------------------------------------------------

$configNu = Get-Content -Raw (Join-Path $repoRoot "home\dot_config\nushell\config.nu")
Assert-Contains $configNu '$env.config.show_banner = false' "The banner must stay off, or it scrolls restored scrollback out of view in every new pane."
Assert-Contains $configNu 'rmux/snapshot.nu' "config.nu must expose the snapshot commands inside Nushell."

# --- template ------------------------------------------------------------

$template = Get-Content -Raw (Join-Path $repoRoot "home\dot_config\rmux\templates\example.yaml")
Assert-Contains $template 'cwd: D:\dev\example' "The template must carry an explicit cwd, since dumps cannot recover it."
Assert-Contains $template 'idempotent' "The template must warn that only idempotent commands belong in it."

Write-Host "rmux-snapshot: all assertions passed."
