@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

REM ==========================================
REM srvx — CLI Router
REM Имена / алиасы / подписи — только из REM @srvx в commands\*.bat
REM ==========================================

set "SRVX_ROOT=%~dp0"
if "%SRVX_ROOT:~-1%"=="\" set "SRVX_ROOT=%SRVX_ROOT:~0,-1%"
if not defined PROJECT_DIR set "PROJECT_DIR=%CD%"

set "RAW=%~1"
set "ARGS="
set "CMD="
set "NEEDS_CONFIG=1"

if /i "%RAW%"=="help" goto SHOW_HELP
if /i "%RAW%"=="--help" goto SHOW_HELP
if /i "%RAW%"=="-h" goto SHOW_HELP
if /i "%RAW%"=="/?" goto SHOW_HELP

if not defined RAW (
    for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action default`) do set "CMD=%%A"
    if not defined CMD (
        echo [ОШИБКА] Нет команды с default=1
        endlocal
        exit /b 1
    )
    goto LOAD_FLAGS
)

shift
set "ARGS=%*"

for /f "usebackq tokens=1,2 delims=	" %%A in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action info -Name "%RAW%"`) do (
    set "CMD=%%A"
    set "NEEDS_CONFIG=%%B"
)

if not defined CMD (
    echo [ОШИБКА] Неизвестная команда: %RAW%
    echo.
    echo Список: srvx help
    endlocal
    exit /b 1
)
goto CHECK_CONFIG

:LOAD_FLAGS
for /f "usebackq tokens=1,2 delims=	" %%A in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action info -Name "%CMD%"`) do (
    set "CMD=%%A"
    set "NEEDS_CONFIG=%%B"
)

:CHECK_CONFIG

if "%NEEDS_CONFIG%"=="0" goto RUN_CMD
if exist "%PROJECT_DIR%\config.bat" goto RUN_CMD

echo.
echo [!] В этой папке ещё нет config.bat
echo     %PROJECT_DIR%
echo.
echo Запускаем инициализацию...
echo.
call "%SRVX_ROOT%\commands\init.bat"
if errorlevel 1 (
    endlocal
    exit /b 1
)
if not exist "%PROJECT_DIR%\config.bat" (
    echo [!] config.bat не создан — отмена.
    endlocal
    exit /b 1
)
echo.
echo Продолжаем: srvx %CMD%
echo.

:RUN_CMD

if not exist "%SRVX_ROOT%\commands\%CMD%.bat" (
    echo [ОШИБКА] Файл команды не найден: commands\%CMD%.bat
    endlocal
    exit /b 1
)

call "%SRVX_ROOT%\commands\%CMD%.bat" %ARGS%
set "EC=%ERRORLEVEL%"
endlocal & exit /b %EC%

:SHOW_HELP
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action help
endlocal
exit /b 0
