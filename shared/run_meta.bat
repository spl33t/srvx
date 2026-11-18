@echo off
REM Тонкая обёртка: shared\run_meta.bat <action> [name]
REM Требует SRVX_ROOT. Печатает stdout парсера, код возврата = код PowerShell.

if not defined SRVX_ROOT (
    echo [ОШИБКА] SRVX_ROOT не задан.
    exit /b 1
)

set "SRVX_META_ACTION=%~1"
set "SRVX_META_NAME=%~2"

if not defined SRVX_META_ACTION (
    echo [ОШИБКА] usage: run_meta.bat ^<action^> [name]
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action "%SRVX_META_ACTION%" -Name "%SRVX_META_NAME%"
exit /b %ERRORLEVEL%
