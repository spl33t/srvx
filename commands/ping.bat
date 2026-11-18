@echo off
REM @srvx id=ping
REM @srvx label=Проверка связи
REM @srvx aliases=
REM @srvx desc=Проверка SSH/TCP связи с сервером
REM @srvx order=60
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 exit /b 1

echo ==========================================
echo  srvx ping
echo ==========================================
echo.
echo Цель: %USER%@%SERVER%:%PORT%
echo.

where ssh.exe >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] ssh.exe не найден в PATH.
    exit /b 1
)

if exist "%SSH_KEY%" (
    call "%SRVX_ROOT%\shared\fix_key.bat" "%SSH_KEY%"
    echo Проверка по SSH-ключу...
    ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new %USER%@%SERVER% "echo OK; hostname; uptime" <nul
) else (
    echo [!] Ключ не найден: %SSH_KEY%
    echo Пробуем TCP-порт через PowerShell...
    powershell.exe -NoProfile -Command ^
      "try { $c = New-Object Net.Sockets.TcpClient; $c.ReceiveTimeout=3000; $c.SendTimeout=3000; $iar=$c.BeginConnect('%SERVER%',%PORT%,$null,$null); if(-not $iar.AsyncWaitHandle.WaitOne(3000,$false)){ throw 'timeout' }; $c.EndConnect($iar); $c.Close(); Write-Host '[OK] TCP %PORT% открыт на %SERVER%' } catch { Write-Host '[ОШИБКА]' $_.Exception.Message; exit 1 }"
)

set "EC=%ERRORLEVEL%"
echo.
if "%EC%"=="0" (
    echo [OK] Связь есть.
) else (
    echo [!] Связь не подтверждена, код: %EC%
)
endlocal & exit /b %EC%
