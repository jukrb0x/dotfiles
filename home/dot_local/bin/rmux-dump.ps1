#Requires -Version 7.1
$ErrorActionPreference = "Stop"

# Capture every live rmux session. The implementation is snapshot.nu; this shim
# exists so the scheduled task and plain PowerShell can reach it without a
# Nushell session, which matters because the sessions being captured are the
# ones hosting Nushell.
nu (Join-Path $HOME ".config\rmux\snapshot.nu") dump @args

# Propagate Nushell's exit code. Without this the shim always succeeds, and a
# scheduled run that failed to write a snapshot still reports LastTaskResult 0 --
# which is exactly how a broken dump would go unnoticed until a restore needed it.
exit $LASTEXITCODE
