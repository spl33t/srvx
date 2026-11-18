@echo off
REM @srvx id=vscode
REM @srvx label=Открыть в VS Code
REM @srvx aliases=code
REM @srvx desc=VS Code Remote-SSH
REM @srvx order=20
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"

REM ==========================================
REM СПРАВКА / АРГУМЕНТЫ
REM ==========================================

if /i "%~1"=="--help" goto SHOW_HELP
if /i "%~1"=="-h" goto SHOW_HELP
if /i "%~1"=="/?" goto SHOW_HELP
if /i "%~1"=="--update" goto DO_UPDATE
if /i "%~1"=="-u" goto DO_UPDATE
goto LOAD_CONFIG

:SHOW_HELP
echo ==========================================
echo VS Code Remote SSH Launcher
echo ==========================================
echo.
echo Использование:
echo   srvx vscode [путь_на_сервере]
echo   srvx vscode --update
echo.
echo Примеры:
echo   srvx vscode                 - интерактивный выбор профиля и папки
echo   srvx vscode /var/www        - открыть /var/www
echo   srvx vscode --update        - обновить расширение Remote - SSH
echo.
exit /b 0

:DO_UPDATE
call "%SRVX_ROOT%\shared\load_config.bat"
set "VSCODE_CMD="
if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" set "VSCODE_CMD=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
if not defined VSCODE_CMD (
    for /f "delims=" %%I in ('where code.cmd 2^>nul') do set "VSCODE_CMD=%%I"
)
if not defined VSCODE_CMD (
    echo [ОШИБКА] VS Code CLI: code.cmd не найден.
    pause
    exit /b 1
)
echo ==========================================
echo Принудительное обновление Remote - SSH...
echo ==========================================
call "%VSCODE_CMD%" --install-extension ms-vscode-remote.remote-ssh --force
echo.
echo [OK] Расширение обновлено.
echo.
pause
exit /b 0

:LOAD_CONFIG
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 goto ERROR_END

REM Host всегда из абсолютного пути проекта, не из config.bat
call "%SRVX_ROOT%\shared\resolve_ssh_alias.bat"
REM Папка на сервере только из меню / аргумента, не из config.bat
set "VSCODE_REMOTE_PATH="

REM ==========================================
REM ПОИСК VS CODE
REM ==========================================

set "VSCODE_EXE="
set "VSCODE_CMD="

if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" (
    set "VSCODE_EXE=%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe"
    set "VSCODE_CMD=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
    goto VSCODE_FOUND
)

if exist "%ProgramFiles%\Microsoft VS Code\Code.exe" (
    set "VSCODE_EXE=%ProgramFiles%\Microsoft VS Code\Code.exe"
    set "VSCODE_CMD=%ProgramFiles%\Microsoft VS Code\bin\code.cmd"
    goto VSCODE_FOUND
)

if exist "%ProgramFiles(x86)%\Microsoft VS Code\Code.exe" (
    set "VSCODE_EXE=%ProgramFiles(x86)%\Microsoft VS Code\Code.exe"
    set "VSCODE_CMD=%ProgramFiles(x86)%\Microsoft VS Code\bin\code.cmd"
    goto VSCODE_FOUND
)

where code.cmd >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%I in ('where code.cmd') do (
        set "VSCODE_CMD=%%I"
        goto VSCODE_FOUND
    )
)

where code.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%I in ('where code.exe') do (
        set "VSCODE_EXE=%%I"
        goto VSCODE_FOUND
    )
)

echo.
echo ==========================================
echo Visual Studio Code не найден
echo ==========================================
echo.
echo [1] Установить VS Code автоматически через winget
echo [2] Выход
echo.

choice /C 12 /N /M "Выберите [1/2]: "
if errorlevel 2 goto END

echo.
echo Устанавливаем Visual Studio Code...
winget install --id Microsoft.VisualStudioCode --exact --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo [ОШИБКА] Не удалось установить Visual Studio Code.
    goto ERROR_END
)

echo [OK] Visual Studio Code установлен.
goto LOAD_CONFIG

:VSCODE_FOUND

where ssh.exe >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ОШИБКА] Windows OpenSSH не найден: ssh.exe отсутствует в PATH.
    goto ERROR_END
)

set "SRVX_SSH_USE_KEY=0"
if exist "%SSH_KEY%" (
    call "%SRVX_ROOT%\shared\fix_key.bat" "%SSH_KEY%"
    ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new %USER%@%SERVER% "exit" <nul >nul 2>&1
    if not errorlevel 1 (
        set "SRVX_SSH_USE_KEY=1"
    ) else (
        echo [!] SSH-ключ не подошёл. VS Code сможет спросить пароль.
        echo.
    )
) else (
    echo [!] SSH-ключ не найден: %SSH_KEY%
    echo     VS Code сможет спросить пароль ^(как srvx ssh^).
    echo.
)

if "!SRVX_SSH_USE_KEY!"=="0" (
    call "%SRVX_ROOT%\shared\load_passwords.bat"
)

dir /b "%USERPROFILE%\.vscode\extensions\ms-vscode-remote.remote-ssh*" >nul 2>&1
if errorlevel 1 (
    if defined VSCODE_CMD (
        echo.
        echo [*] Расширение Remote - SSH не найдено в VS Code.
        echo Устанавливаем ms-vscode-remote.remote-ssh...
        call "%VSCODE_CMD%" --install-extension ms-vscode-remote.remote-ssh <nul
        if errorlevel 1 (
            echo [*] Не удалось автоматически установить расширение Remote - SSH.
        ) else (
            echo [OK] Расширение Remote - SSH установлено.
        )
    )
)

echo.
echo ==========================================
echo  VS Code Remote SSH Launcher
echo ==========================================
echo Сервер: %SERVER%:%PORT%
echo.

echo Поиск доступных профилей на сервере...

set "TEMP_USERS=%TEMP%\srvx_users_%RANDOM%.tmp"
if "!SRVX_SSH_USE_KEY!"=="1" (
    ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new %USER%@%SERVER% "sh -c 'for u in root $(ls /home 2>/dev/null); do if id $u >/dev/null 2>&1; then h=$(getent passwd $u | cut -d: -f6); echo $u:$h; fi; done'" <nul > "%TEMP_USERS%" 2>nul
)

set "USER_COUNT=0"
if exist "%TEMP_USERS%" (
    for /f "usebackq tokens=1,2 delims=:" %%A in ("%TEMP_USERS%") do (
        if not "%%A"=="" (
            set /a USER_COUNT+=1
            set "USER_NAME_!USER_COUNT!=%%A"
            set "USER_HOME_!USER_COUNT!=%%B"
        )
    )
    del "%TEMP_USERS%" 2>nul
)

if !USER_COUNT! LSS 1 (
    set "USER_COUNT=2"
    set "USER_NAME_1=root"
    set "USER_HOME_1=/root"
    set "USER_NAME_2=%USER%"
    set "USER_HOME_2=/home/%USER%"
)

set "DEFAULT_USER_IDX=1"
if not "%AUTO_SUDO%"=="1" (
    for /l %%I in (1,1,!USER_COUNT!) do (
        for %%K in (%%I) do (
            if /i "!USER_NAME_%%K!"=="%USER%" set "DEFAULT_USER_IDX=%%I"
        )
    )
)

echo.
echo [1/2] Выберите профиль пользователя:
for /l %%I in (1,1,!USER_COUNT!) do (
    for %%K in (%%I) do (
        echo   [%%I] !USER_NAME_%%K!  -- домашняя папка: !USER_HOME_%%K!
    )
)
echo.

set "USER_CHOICE="
set /p "USER_CHOICE=Выберите профиль [1-!USER_COUNT!] (по умолчанию: !DEFAULT_USER_IDX!): "
if not defined USER_CHOICE set "USER_CHOICE=!DEFAULT_USER_IDX!"
set "USER_CHOICE=!USER_CHOICE: =!"
if not defined USER_CHOICE set "USER_CHOICE=!DEFAULT_USER_IDX!"

set "VALID_USER=0"
for /l %%I in (1,1,!USER_COUNT!) do (
    if "!USER_CHOICE!"=="%%I" set "VALID_USER=1"
)
if "!VALID_USER!"=="0" (
    echo [*] Некорректный выбор. Используется профиль по умолчанию [!DEFAULT_USER_IDX!].
    set "USER_CHOICE=!DEFAULT_USER_IDX!"
)

for %%K in (!USER_CHOICE!) do (
    set "TARGET_USER=!USER_NAME_%%K!"
    set "TARGET_HOME=!USER_HOME_%%K!"
)

echo.
echo Выбран профиль: !TARGET_USER! [!TARGET_HOME!]

set "PASSED_PATH=%~1"
if not defined PASSED_PATH goto CHOOSE_FOLDER
set "PASSED_PATH=!PASSED_PATH:\=/!"
set "TARGET_PATH=!PASSED_PATH!"
echo.
echo [2/2] Рабочая папка: !TARGET_PATH! (задана аргументом)
goto FOLDER_DONE

:CHOOSE_FOLDER

set "DEFAULT_FOLDER=!TARGET_HOME!"

echo.
echo [2/2] Выберите рабочую папку на сервере:
echo   [1] Домашняя папка пользователя [!DEFAULT_FOLDER!]
echo   [2] Корень файловой системы [/]
echo   [3] Ввести свой путь вручную...
echo.

set "DIR_CHOICE="
set /p "DIR_CHOICE=Выберите папку [1-3] (по умолчанию: 1): "
if not defined DIR_CHOICE set "DIR_CHOICE=1"
set "DIR_CHOICE=!DIR_CHOICE: =!"
if not defined DIR_CHOICE set "DIR_CHOICE=1"

if "!DIR_CHOICE!"=="2" goto DIR_ROOT
if "!DIR_CHOICE!"=="3" goto DIR_CUSTOM
goto DIR_DEFAULT

:DIR_ROOT
set "TARGET_PATH=/"
goto FOLDER_DONE

:DIR_CUSTOM
set "CUSTOM_PATH="
set /p "CUSTOM_PATH=Введите путь на сервере (например, /var/www): "
if not defined CUSTOM_PATH goto DIR_DEFAULT
set "CUSTOM_PATH=!CUSTOM_PATH: =!"
if not defined CUSTOM_PATH goto DIR_DEFAULT
set "TARGET_PATH=!CUSTOM_PATH:\=/!"
goto FOLDER_DONE

:DIR_DEFAULT
set "TARGET_PATH=!DEFAULT_FOLDER!"
goto FOLDER_DONE

:FOLDER_DONE

if "!TARGET_USER!"=="root" if "!SRVX_SSH_USE_KEY!"=="1" (
    ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new root@%SERVER% "exit" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo [*] Настраиваем доступ root по SSH-ключу через srvx ssh...
        if exist "%SRVX_ROOT%\commands\ssh.bat" (
            call "%SRVX_ROOT%\commands\ssh.bat" --exec "mkdir -p /root/.ssh && chmod 700 /root/.ssh && cat /home/%USER%/.ssh/authorized_keys >> /root/.ssh/authorized_keys 2>/dev/null; sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys 2>/dev/null; chmod 600 /root/.ssh/authorized_keys" >nul 2>&1
        )
    )
)

call "%SRVX_ROOT%\shared\sync_ssh_config.bat"
if errorlevel 1 (
    echo [*] Предупреждение: не удалось обновить ~/.ssh/config.
)

echo.
echo ==========================================
echo Подключение: !TARGET_USER!@%SERVER%:%PORT%
echo Папка:       !TARGET_PATH!
echo Host Alias:  %SSH_HOST_ALIAS%
if "!SRVX_SSH_USE_KEY!"=="1" (
    echo Auth:        SSH-ключ
) else (
    echo Auth:        пароль ^(VS Code спросит, если нужно^)
)
echo ==========================================
echo.
echo Запуск VS Code...

REM URI собирается в PowerShell: в пути проекта есть символы вроде @,
REM и percent-encoding (%3A, %40) cmd иначе разбирает как свои %%-переменные.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SRVX_ROOT%\shared\open_vscode.ps1"
if errorlevel 1 (
    echo [ОШИБКА] Не удалось запустить VS Code.
    goto ERROR_END
)

echo.
echo [OK] VS Code запущен в папке: !TARGET_PATH!
echo.

ping 127.0.0.1 -n 3 >nul
goto END

:ERROR_END
echo.
pause

:END
endlocal
exit /b 0
