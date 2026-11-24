@echo off
REM @srvx id=install-openssh
REM @srvx label=Настроить OpenSSH на Windows
REM @srvx aliases=setup-ssh
REM @srvx desc=Установить OpenSSH через WinRM или подготовить установку через RDP
REM @srvx order=55
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 exit /b 1
if /i not "%SERVER_OS%"=="windows" (
    echo [ОШИБКА] Эта команда предназначена для Windows-сервера.
    exit /b 1
)

echo Проверка удалённой установки через WinRM...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\install_openssh_remote.ps1" -Server "%SERVER%"
if not errorlevel 1 (
    echo.
    echo [OK] OpenSSH настроен на сервере. Добавьте USER в config.bat для SSH-команд.
    exit /b 0
)

echo.
echo Переходим к установке через RDP.
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\prepare_openssh.ps1"
set "PREPARE_EC=%ERRORLEVEL%"
if not "%PREPARE_EC%"=="0" if not "%PREPARE_EC%"=="2" if not "%PREPARE_EC%"=="3" if not "%PREPARE_EC%"=="4" if not "%PREPARE_EC%"=="5" (
    echo [ОШИБКА] Не удалось подготовить файлы OpenSSH. Удалённый рабочий стол не открыт.
    exit /b 1
)

echo.
echo ==========================================
echo Через WinRM не удалось установить OpenSSH. Установка НЕ началась.
echo ==========================================
echo 1. Войдите в открывшийся удалённый рабочий стол.
if "%PREPARE_EC%"=="4" (
    echo 2. Файлы уже скопированы на общий рабочий стол удалённого компьютера через SMB.
    echo 3. Откройте srvx-open-me-*.txt и запустите srvx-install-openssh-*.cmd.
) else if "%PREPARE_EC%"=="3" (
    echo 2. Файлы уже отправлены через Tailscale Taildrop в папку «Загрузки» на удалённом компьютере.
    echo 3. Откройте srvx-open-me-*.txt и запустите srvx-install-openssh-*.cmd из этой папки.
) else if "%PREPARE_EC%"=="0" (
    echo 2. На удалённом рабочем столе нажмите Ctrl+V: появятся три файла.
    echo 3. Откройте srvx-open-me-*.txt и запустите srvx-install-openssh-*.cmd.
) else if "%PREPARE_EC%"=="2" (
    echo 2. На удалённом сервере запустите PowerShell от имени администратора.
    echo 3. Вставьте скрипт из буфера обмена и нажмите Enter.
) else (
    echo 2. На удалённом сервере запустите PowerShell от имени администратора.
    echo 3. Вставьте показанный выше скрипт и нажмите Enter.
)
echo 4. Подтвердите запрос UAC и дождитесь OpenSSH Server: Running.
echo.
call "%SRVX_ROOT%\commands\rdp.bat"
set "EC=%ERRORLEVEL%"
endlocal & exit /b %EC%
