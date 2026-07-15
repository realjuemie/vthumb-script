@echo off
setlocal
set "TOOL_DIR=%~dp0"
set "TOOL_DIR=%TOOL_DIR:~0,-1%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOL_DIR%\install-windows.ps1"
exit /b %ERRORLEVEL%
