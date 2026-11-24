@echo off
REM @srvx id=rdp
REM @srvx label=Рабочий стол Windows (RDP)
REM @srvx aliases=mstsc
REM @srvx desc=Открыть Windows-сервер через удалённый рабочий стол
REM @srvx order=10
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 exit /b 1
if /i not "%SERVER_OS%"=="windows" (
    echo [ОШИБКА] RDP доступен для Windows-сервера.
    exit /b 1
)
where mstsc.exe >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] mstsc.exe не найден.
    exit /b 1
)

set "RDP_LOGIN=%RDP_USER%"
if not defined RDP_LOGIN set "RDP_LOGIN=%USER%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\save_rdp_credential.ps1" -Server "%SERVER%" -PasswordFile "%PASSWORD_FILE%"
if errorlevel 1 echo [!] Не удалось сохранить RDP-пароль. mstsc запросит его при подключении.

echo Открываем удалённый рабочий стол: %SERVER%
start "" mstsc.exe /v:%SERVER%
set "EC=%ERRORLEVEL%"
endlocal & exit /b %EC%
