@echo off
REM ==========================================
REM ПАРСИНГ PASSWORD.TXT ПО СХЕМЕ
REM ==========================================

set "TARGET_PASS_FILE=%~1"
if not defined TARGET_PASS_FILE set "TARGET_PASS_FILE=%PASSWORD_FILE%"

set "PASSWORD="
set "SUDO_PASS="
set "B64_SUDO_PASS="

if not defined TARGET_PASS_FILE exit /b 0
if not exist "%TARGET_PASS_FILE%" exit /b 0

for /f "usebackq eol=# tokens=1* delims==" %%A in ("%TARGET_PASS_FILE%") do (
    if "%%B"=="" (
        if not defined PASSWORD set "PASSWORD=%%A"
        if not defined SUDO_PASS set "SUDO_PASS=%%A"
    ) else (
        if /i "%%A"=="SSH" set "PASSWORD=%%B"
        if /i "%%A"=="SSH_PASSWORD" set "PASSWORD=%%B"
        if /i "%%A"=="USER" set "PASSWORD=%%B"
        if /i "%%A"=="SUDO" set "SUDO_PASS=%%B"
        if /i "%%A"=="SUDO_PASSWORD" set "SUDO_PASS=%%B"
        if /i "%%A"=="ROOT" set "SUDO_PASS=%%B"
    )
)

if "%PASSWORD%"=="placeholder" set "PASSWORD="
if "%SUDO_PASS%"=="placeholder" set "SUDO_PASS="

if not defined SUDO_PASS set "SUDO_PASS=%PASSWORD%"
if not defined PASSWORD set "PASSWORD=%SUDO_PASS%"

if defined SUDO_PASS (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($env:SUDO_PASS))"`) do set "B64_SUDO_PASS=%%A"
)

set "TARGET_PASS_FILE="
exit /b 0
