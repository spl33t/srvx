@echo off
REM ==========================================
REM UPDATE ~/.ssh/config FOR VS CODE
REM Host всегда = абсолютный путь проекта (не из config.bat)
REM SRVX_SSH_USE_KEY=1 — ключ; иначе password (VS Code спросит пароль)
REM ==========================================

if not defined SERVER exit /b 1
if not defined TARGET_USER set "TARGET_USER=%USER%"
if not defined PORT set "PORT=22"
call "%~dp0resolve_ssh_alias.bat"
if not defined SERVER_ALIVE_INTERVAL set "SERVER_ALIVE_INTERVAL=15"
if not defined SERVER_ALIVE_COUNT_MAX set "SERVER_ALIVE_COUNT_MAX=20"
if not defined SRVX_SSH_USE_KEY set "SRVX_SSH_USE_KEY=0"

where powershell.exe >nul 2>&1
if errorlevel 1 exit /b 1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_ssh_config.ps1"
exit /b %ERRORLEVEL%
