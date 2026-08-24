@echo off
setlocal

rem See rmux-dump.ps1 for why this shim exists, including the exit-code passthrough.
nu "%USERPROFILE%\.config\rmux\snapshot.nu" dump %*
exit /b %ERRORLEVEL%
