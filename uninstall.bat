@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

set "SRVX_ROOT=%~dp0"
if "%SRVX_ROOT:~-1%"=="\" set "SRVX_ROOT=%SRVX_ROOT:~0,-1%"

echo ==========================================
echo  Удаление srvx
echo ==========================================
echo.
echo Путь: %SRVX_ROOT%
echo.

where powershell.exe >nul 2>&1
if errorlevel 1 goto CLEAN_REG

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root = $env:SRVX_ROOT;" ^
  "$userPath = [Environment]::GetEnvironmentVariable('Path','User');" ^
  "if ($null -eq $userPath) { Write-Host '[*] Пользовательский PATH пуст.'; exit 0 };" ^
  "$parts = $userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ne $root.TrimEnd('\')) };" ^
  "$newPath = ($parts -join ';').Trim(';');" ^
  "[Environment]::SetEnvironmentVariable('Path',$newPath,'User');" ^
  "Write-Host '[OK] srvx удалён из пользовательского PATH.'"

:CLEAN_REG

reg delete "HKCU\Software\Classes\Directory\Background\shell\srvx" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\srvx" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Folder\shell\srvx" /f >nul 2>&1

REM На случай старых установок с твиком Win11
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f >nul 2>&1
reg delete "HKCU\Software\srvx" /f >nul 2>&1

echo [OK] Контекстное меню удалено.
echo.
echo Перезапустите терминал, чтобы PATH обновился.
echo.
pause
endlocal
exit /b 0
