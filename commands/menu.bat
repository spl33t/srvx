@echo off
REM @srvx id=menu
REM @srvx label=Все действия (Меню)...
REM @srvx aliases=
REM @srvx desc=Интерактивное меню доступных действий
REM @srvx order=80
REM @srvx menu=0
REM @srvx default=1
REM @srvx needs_config=0
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"

echo ==========================================
echo  srvx — меню действий
echo ==========================================
echo.
echo Проект: %PROJECT_DIR%
if not exist "%PROJECT_DIR%\config.bat" (
    echo.
    echo [!] Нет config.bat — команды подключения скрыты.
)
echo.

set "IDX=0"
for /f "usebackq tokens=1,2,3 delims=	" %%A in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action menu`) do (
    set /a IDX+=1
    set "CMD_%%A=%%B"
    echo   [%%A] %%C
)

if "!IDX!"=="0" (
    echo [!] Нет команд с menu=1 и валидным контрактом @srvx.
    goto END
)

echo   [0] Выход
echo.

set "CHOICE="
echo Выберите действие:
set /p "CHOICE=> "
if not defined CHOICE goto END
if "%CHOICE%"=="0" goto END

set "SELECTED="
for /f "usebackq tokens=1,2 delims=	" %%A in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\command_meta.ps1" -Root "%SRVX_ROOT%" -Action menu`) do (
    if "!CHOICE!"=="%%A" set "SELECTED=%%B"
)

if not defined SELECTED (
    echo [!] Некорректный выбор.
    goto END
)

echo.
echo Запуск: srvx !SELECTED!
echo.
call "%SRVX_ROOT%\srvx.bat" !SELECTED!

:END
endlocal
exit /b 0
