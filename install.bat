@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

set "SRVX_ROOT=%~dp0"
if "%SRVX_ROOT:~-1%"=="\" set "SRVX_ROOT=%SRVX_ROOT:~0,-1%"
set "SRVX_BAT=%SRVX_ROOT%\srvx.bat"

if not exist "%SRVX_BAT%" (
    echo [ОШИБКА] Не найден srvx.bat рядом с install.bat
    pause
    exit /b 1
)

echo ==========================================
echo  Установка srvx
echo ==========================================
echo.
echo Путь: %SRVX_ROOT%
echo.

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] PowerShell не найден — нельзя обновить PATH.
    goto REG_MENU
)

REM ------------------------------------------
REM PATH (пользовательский)
REM ------------------------------------------

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root = $env:SRVX_ROOT;" ^
  "$userPath = [Environment]::GetEnvironmentVariable('Path','User');" ^
  "if ($null -eq $userPath) { $userPath = '' };" ^
  "$parts = $userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' };" ^
  "if ($parts -contains $root) { Write-Host '[OK] PATH уже содержит srvx.'; exit 0 };" ^
  "$newPath = if ($userPath.Trim() -eq '') { $root } else { $userPath.TrimEnd(';') + ';' + $root };" ^
  "[Environment]::SetEnvironmentVariable('Path',$newPath,'User');" ^
  "Write-Host '[OK] Добавлено в пользовательский PATH:' $root"

set "PATH=%SRVX_ROOT%;%PATH%"

:REG_MENU

REM ------------------------------------------
REM Контекстное меню: один пункт = голый srvx
REM Win11: слой «Показать дополнительные параметры»
REM ------------------------------------------

set "MENU_BG=HKCU\Software\Classes\Directory\Background\shell\srvx"
set "MENU_DIR=HKCU\Software\Classes\Directory\shell\srvx"

REM В реестр должны попасть литералы %V и %1 (подставляет Explorer).
REM Нельзя передавать их через call/set: cmd съедает проценты,
REM и в реестре оказывается cd /d "V" или cd /d "" — окно сразу закрывается.
call :REGISTER_SRVX "%MENU_BG%" "V"
call :REGISTER_SRVX "%MENU_DIR%" "1"

echo [OK] Контекстное меню: srvx -^> запуск без аргументов ^(то же, что srvx в терминале^)
echo.
echo Откройте новый терминал и выполните: srvx help
echo Или ПКМ в папке -^> Доп. параметры -^> srvx
echo.
pause
endlocal
exit /b 0

:REGISTER_SRVX
set "BASE=%~1"
set "TOKEN=%~2"
reg add "%BASE%" /ve /d "srvx" /f >nul
reg add "%BASE%" /v "Icon" /d "cmd.exe" /f >nul
reg add "%BASE%\command" /ve /d "cmd.exe /c cd /d \"%%%TOKEN%\" && \"%SRVX_BAT%\"" /f >nul
exit /b 0
