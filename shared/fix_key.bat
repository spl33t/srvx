@echo off
REM ==========================================
REM НАСТРОЙКА ПРАВ НА SSH-КЛЮЧ (ICACLS)
REM ==========================================

set "TARGET_KEY=%~1"
if not defined TARGET_KEY set "TARGET_KEY=%SSH_KEY%"

if not defined TARGET_KEY exit /b 0
if not exist "%TARGET_KEY%" exit /b 0

icacls "%TARGET_KEY%" /inheritance:r >nul 2>&1
icacls "%TARGET_KEY%" /remove:g "Users" >nul 2>&1
icacls "%TARGET_KEY%" /grant:r "%USERNAME%:(R)" >nul 2>&1

set "TARGET_KEY="
exit /b 0
