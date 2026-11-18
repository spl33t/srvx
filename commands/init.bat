@echo off
REM @srvx id=init
REM @srvx label=Инициализировать (создать конфиг)
REM @srvx aliases=
REM @srvx desc=Создать config.bat и password.txt в проекте
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
        echo Отмена.
        endlocal
        exit /b 0
    )
)

set "IN_SERVER="
set "IN_PORT=22"
set "IN_USER="
set "IN_AUTO_SUDO=1"

set /p "IN_SERVER=IP / hostname сервера: "
if not defined IN_SERVER (
    echo [ОШИБКА] SERVER обязателен.
    endlocal
    exit /b 1
)

set /p "IN_PORT=SSH порт [22]: "
if not defined IN_PORT set "IN_PORT=22"

set /p "IN_USER=SSH пользователь: "
if not defined IN_USER (
    echo [ОШИБКА] USER обязателен.
    endlocal
    exit /b 1
)

set /p "IN_AUTO_SUDO=AUTO_SUDO 1/0 [1]: "
if not defined IN_AUTO_SUDO set "IN_AUTO_SUDO=1"

> "%CONFIG_FILE%" (
    echo @echo off
    echo.
    echo REM ==========================================
    echo REM СЕРВЕР
    echo REM ==========================================
    echo.
    echo set "SERVER=%IN_SERVER%"
    echo set "PORT=%IN_PORT%"
    echo set "USER=%IN_USER%"
    echo.
    echo REM ==========================================
    echo REM CREDENTIALS
    echo REM ==========================================
    echo.
    echo set "SSH_KEY=%%~dp0my_key"
    echo set "PASSWORD_FILE=%%~dp0password.txt"
    echo.
    echo REM ==========================================
    echo REM SUDO
    echo REM ==========================================
    echo.
    echo REM 1 - auto sudo, 0 - обычный пользователь
    echo set "AUTO_SUDO=%IN_AUTO_SUDO%"
    echo.
    echo REM ==========================================
    echo REM KEEPALIVE
    echo REM ==========================================
    echo.
    echo set "SERVER_ALIVE_INTERVAL=15"
    echo set "SERVER_ALIVE_COUNT_MAX=20"
)

echo.
echo [OK] Создан: %CONFIG_FILE%

if exist "%PASS_FILE%" (
    echo [!] password.txt уже есть — не трогаем.
) else (
    > "%PASS_FILE%" (
        echo # Пароли для srvx
        echo # Можно одной строкой: пароль
        echo # Или ключами:
        echo # SSH=ваш_ssh_пароль
        echo # SUDO=ваш_sudo_пароль
        echo.
        echo SSH=placeholder
        echo SUDO=placeholder
    )
    echo [OK] Создан шаблон: %PASS_FILE%
)

echo.
echo Положите приватный ключ сюда ^(опционально^):
echo   %PROJECT_DIR%\my_key
echo   %PROJECT_DIR%\my_key.ppk  ^(для WinSCP, создастся сам^)
echo.
echo Готово. Дальше: srvx / srvx code / srvx menu
echo.
endlocal
exit /b 0
