#Requires -Version 7.1

<#
.SYNOPSIS
Register the scheduled task that periodically snapshots rmux sessions.

.DESCRIPTION
rmux has no session persistence of its own, so snapshots only exist if
something takes them. This registers a per-user task that runs rmux-dump on an
interval, giving an unexpected reboot or daemon crash something to restore from.

The task is registered under the current user with no elevation: it only reads
rmux state and writes under the user profile.
#>

param(
    [int] $IntervalMinutes = 15,
    [string] $TaskName = "rmux-snapshot",
    [switch] $Unregister
)

$ErrorActionPreference = "Stop"

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Unregistered scheduled task '$TaskName'."
    }
    else {
        Write-Host "Scheduled task '$TaskName' is not registered."
    }
    return
}

$shim = Join-Path $HOME ".local\bin\rmux-dump.ps1"
if (-not (Test-Path -LiteralPath $shim)) {
    throw "Cannot register '$TaskName': $shim is missing. Run chezmoi apply first."
}

$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshCommand) {
    throw "Cannot register '$TaskName': pwsh is not on PATH."
}
$pwsh = $pwshCommand.Source

# -NonInteractive because nothing is attached to read prompts; -NoProfile keeps
# the run cheap and independent of profile changes. --quiet suppresses the
# progress line that would otherwise go nowhere.
$action = New-ScheduledTaskAction -Execute $pwsh `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$shim`" --quiet"

# Repeat from a fixed daily anchor. The duration must be a finite, in-range
# value: Task Scheduler rejects the XML for both [TimeSpan]::MaxValue
# ("P99999999DT23H59M59S") and [TimeSpan]::Zero, so this uses ten years, which
# is effectively forever for a dotfiles task.
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

# StartWhenAvailable catches up after sleep. The task is pointless without a
# running rmux daemon, and rmux-dump exits quietly in that case, so there is no
# need to gate on idle or network state.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Interactive-token principal: dumps belong to the logged-in user's session, and
# this avoids storing credentials or requiring elevation.
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Snapshot rmux sessions every $IntervalMinutes minutes so layouts survive a reboot." `
    -Force | Out-Null

Write-Host "Registered scheduled task '$TaskName' (every $IntervalMinutes minutes)."
