@echo off
REM ==========================================
REM ЗАГРУЗКА CONFIG.BAT ИЗ ПАПКИ ПРОЕКТА (%CD%)
REM ==========================================

if not defined PROJECT_DIR set "PROJECT_DIR=%CD%"

set "CONFIG=%PROJECT_DIR%\config.bat"

if not exist "%CONFIG%" (
    echo [ОШИБКА] Не найден config.bat в папке проекта:
    echo %CONFIG%
    echo.
    echo Запустите: srvx init
    echo.
    exit /b 1
)

call "%CONFIG%"

if not defined SERVER (
    echo [ОШИБКА] SERVER не указан в config.bat
    echo.
    exit /b 1
)

if not defined USER (
    echo [ОШИБКА] USER не указан в config.bat
    echo.
    exit /b 1
)

if not defined PORT set "PORT=22"
if not defined SSH_KEY set "SSH_KEY=%PROJECT_DIR%\my_key"
if not defined PASSWORD_FILE set "PASSWORD_FILE=%PROJECT_DIR%\password.txt"
if not defined SERVER_ALIVE_INTERVAL set "SERVER_ALIVE_INTERVAL=15"
if not defined SERVER_ALIVE_COUNT_MAX set "SERVER_ALIVE_COUNT_MAX=20"
if not defined AUTO_SUDO set "AUTO_SUDO=1"

REM Не берём alias из config.bat — всегда путь проекта
set "SSH_HOST_ALIAS="
call "%~dp0resolve_ssh_alias.bat"
if errorlevel 1 (
    echo [ОШИБКА] Не удалось вычислить SSH_HOST_ALIAS
    exit /b 1
)

if not defined LXQT_HTTPS_USER set "LXQT_HTTPS_USER=desktop"

exit /b 0
