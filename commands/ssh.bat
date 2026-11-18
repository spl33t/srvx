@echo off
REM @srvx id=ssh
REM @srvx label=Терминал (SSH)
REM @srvx aliases=
REM @srvx desc=SSH-подключение к серверу
REM @srvx order=10
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"

REM ==========================================
REM ПАРСИНГ АРГУМЕНТОВ
REM ==========================================

set "EXEC_CMD="
if /i "%~1"=="--exec" set "EXEC_CMD=%~2"
if /i "%~1"=="-e" set "EXEC_CMD=%~2"

REM ==========================================
REM ЗАГРУЗКА КОНФИГА
REM ==========================================

call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 exit /b 1

REM ==========================================
REM ЗАГРУЗКА ПАРОЛЕЙ
REM ==========================================

call "%SRVX_ROOT%\shared\load_passwords.bat"

REM ==========================================
REM НАСТРОЙКА ПЕРЕХОДА В SUDO / ВЫПОЛНЕНИЯ КОМАНДЫ
REM ==========================================

set "REMOTE_CMD="
set "SSH_TTY_FLAG="
set "B64_EXEC_CMD="

if defined EXEC_CMD (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($env:EXEC_CMD))"`) do set "B64_EXEC_CMD=%%A"
)

if defined B64_EXEC_CMD goto SETUP_EXEC_CMD

REM --- ИНТЕРАКТИВНЫЙ РЕЖИМ ---
if not "%AUTO_SUDO%"=="1" goto CMD_SETUP_DONE

set "SSH_TTY_FLAG=-tt"

if not defined B64_SUDO_PASS goto SUDO_NO_PASS

set "REMOTE_CMD=AP=$(mktemp); chmod 700 $AP; printf '#!/bin/sh\nrm -f $0\necho %B64_SUDO_PASS% | base64 -d\n' > $AP; OK=$(mktemp); SUDO_ASKPASS=$AP sudo -A -k -i bash -c 'rm -f '$OK'; exec bash -l'; if [ -f $OK ]; then rm -f $OK; echo '[!] Не удалось перейти в sudo: неверный пароль. Сессия обычного пользователя:'; exec ${SHELL:-bash} -l; fi; rm -f $AP"
goto CMD_SETUP_DONE

:SUDO_NO_PASS
set "REMOTE_CMD=OK=$(mktemp); sudo -n -i bash -c 'rm -f '$OK'; exec bash -l' 2>/dev/null; if [ -f $OK ]; then rm -f $OK; echo '[!] Sudo требует пароль: пароль не указан в password.txt. Сессия обычного пользователя:'; exec ${SHELL:-bash} -l; fi"
goto CMD_SETUP_DONE

REM --- РЕЖИМ ВЫПОЛНЕНИЯ КОМАНДЫ (--exec) ---
:SETUP_EXEC_CMD
set "SSH_TTY_FLAG=-tt"

if not "%AUTO_SUDO%"=="1" goto EXEC_NO_SUDO
if not defined B64_SUDO_PASS goto EXEC_SUDO_NOPASS

set "REMOTE_CMD=AP=$(mktemp); chmod 700 $AP; printf '#!/bin/sh\nrm -f $0\necho %B64_SUDO_PASS% | base64 -d\n' > $AP; echo %B64_EXEC_CMD% | base64 -d | SUDO_ASKPASS=$AP sudo -A -k bash; EC=$?; rm -f $AP; exit $EC"
goto CMD_SETUP_DONE

:EXEC_SUDO_NOPASS
set "REMOTE_CMD=echo %B64_EXEC_CMD% | base64 -d | sudo -n bash"
goto CMD_SETUP_DONE

:EXEC_NO_SUDO
set "REMOTE_CMD=echo %B64_EXEC_CMD% | base64 -d | bash"

:CMD_SETUP_DONE

REM ==========================================
REM ПРОВЕРЯЕМ OPENSSH
REM ==========================================

where ssh.exe >nul 2>&1

if errorlevel 1 (
    echo [ОШИБКА] Windows OpenSSH не найден.
    echo.
    echo Не найден ssh.exe в PATH.
    echo.
    if not defined EXEC_CMD pause
    exit /b 1
)

REM ==========================================
REM ИНФОРМАЦИЯ
REM ==========================================

echo ==========================================
if defined EXEC_CMD (
    echo SSH выполнение команды
) else (
    echo SSH подключение
)
echo ==========================================
echo.
echo Сервер:    %SERVER%
echo Порт:      %PORT%
echo User:      %USER%
if defined EXEC_CMD (
    echo Команда:   "%EXEC_CMD%"
)
if "%AUTO_SUDO%"=="1" (
    if defined B64_SUDO_PASS (
        echo AutoSudo:  Включено [пароль из password.txt]
    ) else (
        echo AutoSudo:  Включено [без пароля / NOPASSWD]
    )
) else (
    echo AutoSudo:  Выключено
)
echo KeepAlive: %SERVER_ALIVE_INTERVAL% сек.
echo MaxMissed: %SERVER_ALIVE_COUNT_MAX%
echo.

REM ==========================================
REM 1. ПРОБУЕМ SSH-КЛЮЧ
REM ==========================================

if not exist "%SSH_KEY%" (
    echo [!] SSH-ключ не найден:
    echo     %SSH_KEY%
    echo.
    goto TRY_PASSWORD
)

call "%SRVX_ROOT%\shared\fix_key.bat" "%SSH_KEY%"

echo [1/2] Пробуем SSH-ключ...
echo.

if not defined REMOTE_CMD (
    ssh ^
        -p %PORT% ^
        -i "%SSH_KEY%" ^
        -o IdentitiesOnly=yes ^
        -o BatchMode=yes ^
        -o PreferredAuthentications=publickey ^
        -o PasswordAuthentication=no ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER%
) else (
    ssh ^
        %SSH_TTY_FLAG% ^
        -p %PORT% ^
        -i "%SSH_KEY%" ^
        -o IdentitiesOnly=yes ^
        -o BatchMode=yes ^
        -o PreferredAuthentications=publickey ^
        -o PasswordAuthentication=no ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER% ^
        "%REMOTE_CMD%"
)

set "SSH_EXIT_CODE=%ERRORLEVEL%"

if "%SSH_EXIT_CODE%"=="0" goto SUCCESS

if defined EXEC_CMD (
    if not "%SSH_EXIT_CODE%"=="255" goto EXEC_DONE
)

echo.
echo [!] Подключение по ключу не удалось.
echo.

REM ==========================================
REM 2. FALLBACK НА ПАРОЛЬ
REM ==========================================

:TRY_PASSWORD

echo [2/2] Пробуем пароль...
echo.

if not defined PASSWORD goto MANUAL_PASSWORD

set "ASKPASS_FILE=%TEMP%\ssh-askpass-%RANDOM%-%RANDOM%.cmd"

> "%ASKPASS_FILE%" echo @echo off
>>"%ASKPASS_FILE%" echo echo %%SSH_PASSWORD%%

set "SSH_PASSWORD=%PASSWORD%"
set "SSH_ASKPASS=%ASKPASS_FILE%"
set "SSH_ASKPASS_REQUIRE=force"
set "DISPLAY=1"

echo Используем Windows OpenSSH.
echo.

if not defined REMOTE_CMD (
    ssh ^
        -p %PORT% ^
        -o PreferredAuthentications=password ^
        -o PubkeyAuthentication=no ^
        -o PasswordAuthentication=yes ^
        -o KbdInteractiveAuthentication=no ^
        -o NumberOfPasswordPrompts=1 ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER%
) else (
    ssh ^
        %SSH_TTY_FLAG% ^
        -p %PORT% ^
        -o PreferredAuthentications=password ^
        -o PubkeyAuthentication=no ^
        -o PasswordAuthentication=yes ^
        -o KbdInteractiveAuthentication=no ^
        -o NumberOfPasswordPrompts=1 ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER% ^
        "%REMOTE_CMD%"
)

set "SSH_EXIT_CODE=%ERRORLEVEL%"

call :CLEANUP_ASKPASS

if "%SSH_EXIT_CODE%"=="0" goto SUCCESS

if defined EXEC_CMD (
    if not "%SSH_EXIT_CODE%"=="255" goto EXEC_DONE
)

echo.
echo [!] Автоматическое подключение по паролю завершилось с кодом %SSH_EXIT_CODE%.
echo.

goto FAILED

:MANUAL_PASSWORD

call :CLEANUP_ASKPASS

echo ==========================================
echo Ручное подключение
echo ==========================================
echo.
echo Сейчас OpenSSH попросит пароль вручную.
echo.

if not defined REMOTE_CMD (
    ssh ^
        -p %PORT% ^
        -o PreferredAuthentications=password ^
        -o PubkeyAuthentication=no ^
        -o PasswordAuthentication=yes ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER%
) else (
    ssh ^
        %SSH_TTY_FLAG% ^
        -p %PORT% ^
        -o PreferredAuthentications=password ^
        -o PubkeyAuthentication=no ^
        -o PasswordAuthentication=yes ^
        -o ConnectTimeout=10 ^
        -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
        -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
        -o TCPKeepAlive=yes ^
        %USER%@%SERVER% ^
        "%REMOTE_CMD%"
)

set "SSH_EXIT_CODE=%ERRORLEVEL%"

if "%SSH_EXIT_CODE%"=="0" goto SUCCESS

if defined EXEC_CMD (
    if not "%SSH_EXIT_CODE%"=="255" goto EXEC_DONE
)

goto FAILED

:CLEANUP_ASKPASS

if defined ASKPASS_FILE (
    if exist "%ASKPASS_FILE%" (
        del /f /q "%ASKPASS_FILE%" >nul 2>&1
    )
)

set "SSH_PASSWORD="
set "SSH_ASKPASS="
set "SSH_ASKPASS_REQUIRE="
set "DISPLAY="
set "PASSWORD="
set "SUDO_PASS="
set "ASKPASS_FILE="
set "B64_SUDO_PASS="
set "B64_EXEC_CMD="
set "REMOTE_CMD="
set "SSH_TTY_FLAG="

exit /b 0

:EXEC_DONE

call :CLEANUP_ASKPASS

echo.
if "%SSH_EXIT_CODE%"=="0" (
    echo [OK] Команда успешно выполнена.
    goto END
) else (
    echo [!] Команда завершилась с ошибкой, код: %SSH_EXIT_CODE%
    if not defined EXEC_CMD pause
    exit /b %SSH_EXIT_CODE%
)

:SUCCESS

call :CLEANUP_ASKPASS

echo.
if defined EXEC_CMD (
    echo [OK] Команда успешно выполнена.
) else (
    echo SSH-сессия завершена.
)
goto END

:FAILED

call :CLEANUP_ASKPASS

echo.
echo [ОШИБКА] Не удалось подключиться или выполнить команду.
echo.
if not defined EXEC_CMD pause
exit /b 1

:END

call :CLEANUP_ASKPASS
endlocal
exit /b 0
