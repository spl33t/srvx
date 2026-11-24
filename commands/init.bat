@echo off
REM @srvx id=init
REM @srvx label=Инициализировать (создать конфиг)
REM @srvx aliases=
REM @srvx desc=Создать config.bat и password.txt; при запущенном Tailscale — выбор узла
REM @srvx order=90
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=0
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"

echo ==========================================
echo  srvx init — настройки проекта
echo ==========================================
echo.
echo Папка проекта: %PROJECT_DIR%
echo.

set "CONFIG_FILE=%PROJECT_DIR%\config.bat"
set "PASS_FILE=%PROJECT_DIR%\password.txt"

if exist "%CONFIG_FILE%" (
    echo [!] config.bat уже существует.
    choice /C YN /N /M "Перезаписать? [Y/N]: "
    if errorlevel 2 (
        echo config.bat оставлен без изменений.
        call :ENSURE_PASSWORD_FILE
        if errorlevel 1 (
            endlocal
            exit /b 1
        )
        call :HOLD_IF_NEW_WINDOW
        endlocal
        exit /b 0
    )
)

set "IN_SERVER="
set "IN_PORT=22"
set "IN_USER="
set "IN_AUTO_SUDO=1"
set "IN_TAILSCALE=0"
set "IN_SERVER_OS="
set "SSH_PROBE_FAILED="
set "TS_MODE="
set "TS_RESULT=%TEMP%\srvx-tailscale-%RANDOM%%RANDOM%.txt"
if exist "%TS_RESULT%" del /f /q "%TS_RESULT%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\tailscale.ps1" -Action pick -ResultFile "%TS_RESULT%"
if exist "%TS_RESULT%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%TS_RESULT%") do (
        if /i "%%A"=="MODE" set "TS_MODE=%%B"
        if /i "%%A"=="SERVER" set "IN_SERVER=%%B"
        if /i "%%A"=="SERVER_OS" set "IN_SERVER_OS=%%B"
    )
    del /f /q "%TS_RESULT%" >nul 2>&1
)

if /i "%TS_MODE%"=="tailscale" goto SERVER_CHOSEN

echo.
echo IP / hostname сервера:
set /p "IN_SERVER=> "
if not defined IN_SERVER (
    echo [ОШИБКА] SERVER обязателен.
    goto FAIL
)
goto ASK_OS

:SERVER_CHOSEN
set "IN_TAILSCALE=1"
echo.
echo Сервер Tailscale: %IN_SERVER%
if not defined IN_SERVER (
    echo [ОШИБКА] SERVER обязателен.
    goto FAIL
)

:ASK_OS
if not defined IN_SERVER_OS (
    echo Тип сервера [1] Linux [2] Windows:
    choice /C 12 /N /M "Выберите [1/2]: "
    if errorlevel 2 (set "IN_SERVER_OS=windows") else (set "IN_SERVER_OS=linux")
)
if /i "%IN_SERVER_OS%"=="windows" (
    set "IN_AUTO_SUDO=0"
    goto WRITE_CONFIG
)

echo SSH порт [22]:
set /p "IN_PORT=> "
if not defined IN_PORT set "IN_PORT=22"

echo SSH пользователь:
set /p "IN_USER=> "
if not defined IN_USER (
    echo [ОШИБКА] USER обязателен.
    goto FAIL
)

echo AUTO_SUDO 1/0 [1]:
set /p "IN_AUTO_SUDO=> "
if not defined IN_AUTO_SUDO set "IN_AUTO_SUDO=1"

:WRITE_CONFIG
if /i "%IN_TAILSCALE%"=="1" (
    echo.
    echo Проверка OpenSSH на выбранном узле Tailscale...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\probe_ssh.ps1" -Server "%IN_SERVER%" -Port "%IN_PORT%"
    if errorlevel 1 if not errorlevel 2 set "SSH_PROBE_FAILED=1"
)
if /i "%IN_SERVER_OS%"=="windows" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\write_config.ps1" -Path "%CONFIG_FILE%" -Server "%IN_SERVER%" -ServerOS windows -Tailscale "%IN_TAILSCALE%" -Port "%IN_PORT%" -AutoSudo "%IN_AUTO_SUDO%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\write_config.ps1" -Path "%CONFIG_FILE%" -Server "%IN_SERVER%" -ServerOS linux -Tailscale "%IN_TAILSCALE%" -User "%IN_USER%" -Port "%IN_PORT%" -AutoSudo "%IN_AUTO_SUDO%"
)
if errorlevel 1 goto FAIL

echo.
echo [OK] Создан: %CONFIG_FILE%

call :ENSURE_PASSWORD_FILE
if errorlevel 1 goto FAIL

if /i "%IN_SERVER_OS%"=="windows" (
    echo.
    echo Готово. Для подключения: srvx rdp
    if defined SSH_PROBE_FAILED (
        echo OpenSSH на порту 22 не отвечает. Можно попробовать установку через WinRM или RDP.
        choice /C YN /N /M "Настроить OpenSSH на сервере? [Y/N]: "
        if not errorlevel 2 call "%SRVX_ROOT%\commands\install-openssh.bat"
    )
    echo.
    call :HOLD_IF_NEW_WINDOW
    endlocal
    exit /b 0
)

echo.
echo Положите приватный ключ сюда ^(опционально^):
echo   %PROJECT_DIR%\my_key
echo   %PROJECT_DIR%\my_key.ppk  ^(для WinSCP, создастся сам^)
echo.
echo Готово. Дальше: srvx / srvx code / srvx menu
echo.
call :HOLD_IF_NEW_WINDOW
endlocal
exit /b 0

:FAIL
echo.
pause
endlocal
exit /b 1

:HOLD_IF_NEW_WINDOW
setlocal EnableDelayedExpansion
set "CMDLINE=!CMDCMDLINE!"
echo(!CMDLINE!| findstr /i /c:" /c " >nul
if not errorlevel 1 (
    echo.
    pause
)
endlocal
exit /b 0

:ENSURE_PASSWORD_FILE
if exist "%PASS_FILE%" (
    echo [!] password.txt уже есть — не трогаем.
    exit /b 0
)
> "%PASS_FILE%" (
    echo # Пароли для srvx. Заполните только нужные строки.
    echo # Одна строка без ключа используется для SSH, SUDO и RDP.
    echo # Для разных паролей используйте ключи ниже.
    echo # RDP использует SSH-пароль, если RDP_PASSWORD не заполнен и логин тот же.
    echo SSH=placeholder
    echo SUDO=placeholder
    echo RDP_PASSWORD=placeholder
)
if not exist "%PASS_FILE%" (
    echo [ОШИБКА] Не удалось создать password.txt.
    exit /b 1
)
echo [OK] Создан шаблон: %PASS_FILE%
exit /b 0
