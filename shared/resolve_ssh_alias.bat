@echo off
REM ==========================================
REM SSH_HOST_ALIAS = путь проекта, но только из букв, цифр, . _ -
REM Иначе VS Code склеивает C:/... с удалённой папкой и не находит её.
REM @ заранее меняется на _at_, чтобы не потерять его среди прочих символов.
REM ==========================================

setlocal DisableDelayedExpansion

if not defined PROJECT_DIR set "PROJECT_DIR=%CD%"

set "GEN="
for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$p=$env:PROJECT_DIR.Trim().TrimEnd('\');" ^
  "$p=[IO.Path]::GetFullPath($p);" ^
  "$p=$p.Replace('\','/').Replace('@','_at_');" ^
  "$p=[regex]::Replace($p,'[^A-Za-z0-9._-]','_');" ^
  "Write-Output $p"`) do set "GEN=%%A"

if not defined GEN set "GEN=srvx-unknown"

endlocal & set "SSH_HOST_ALIAS=%GEN%"
exit /b 0
