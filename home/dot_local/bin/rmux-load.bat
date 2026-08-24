@echo off
setlocal

rem See rmux-load.ps1 for why this shim exists, including the exit-code passthrough.
nu "%USERPROFILE%\.config\rmux\snapshot.nu" load %*
exit /b %ERRORLEVEL%
