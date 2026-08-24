#Requires -Version 7.1
$ErrorActionPreference = "Stop"

# Recreate sessions from a snapshot or a template.
#
# This is the shim that matters most: restoring happens *before* any Nushell
# exists, because what gets restored are the rmux sessions that host Nushell.
# Calling a Nushell-only command would be circular, so PowerShell drives it.
#
#   rmux-load --all              restore every captured session
#   rmux-load example               restore one
#   rmux-load example --template    build from ~/.config/rmux/templates/example.yaml
nu (Join-Path $HOME ".config\rmux\snapshot.nu") load @args

exit $LASTEXITCODE
