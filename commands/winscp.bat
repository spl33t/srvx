@echo off
REM @srvx id=winscp
REM @srvx label=Файлы (WinSCP)
REM @srvx aliases=sftp
REM @srvx desc=SFTP через WinSCP
REM @srvx order=30
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal DisableDelayedExpansion

call "%~dp0..\shared\resolve_root.bat"

call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 goto END

set "WINSCP_KEY=%PROJECT_DIR%\my_key.ppk"

:SEARCH_WINSCP

set "WINSCP="
set "WINSCP_COM="

if not exist "%ProgramFiles%\WinSCP\WinSCP.exe" goto SEARCH_WINSCP_X86
set "WINSCP=%ProgramFiles%\WinSCP\WinSCP.exe"
set "WINSCP_COM=%ProgramFiles%\WinSCP\WinSCP.com"
goto WINSCP_FOUND

:SEARCH_WINSCP_X86
if not exist "%ProgramFiles(x86)%\WinSCP\WinSCP.exe" goto SEARCH_WINSCP_LOCAL
set "WINSCP=%ProgramFiles(x86)%\WinSCP\WinSCP.exe"
set "WINSCP_COM=%ProgramFiles(x86)%\WinSCP\WinSCP.com"
goto WINSCP_FOUND

:SEARCH_WINSCP_LOCAL
if not exist "%LOCALAPPDATA%\Programs\WinSCP\WinSCP.exe" goto WINSCP_NOT_FOUND
set "WINSCP=%LOCALAPPDATA%\Programs\WinSCP\WinSCP.exe"
set "WINSCP_COM=%LOCALAPPDATA%\Programs\WinSCP\WinSCP.com"
goto WINSCP_FOUND

:WINSCP_NOT_FOUND
echo.
echo ==========================================
echo WinSCP не установлен
echo ==========================================
echo.
echo [1] Установить WinSCP автоматически
echo [2] Выход
echo.
choice /C 12 /N /M "Выберите [1/2]: "
if errorlevel 2 goto END
goto INSTALL_WINSCP

:INSTALL_WINSCP
echo.
echo ==========================================
echo Устанавливаем WinSCP...
echo ==========================================
echo.
where winget.exe >nul 2>&1
if errorlevel 1 goto WINGET_NOT_FOUND
winget install --id WinSCP.WinSCP --exact --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto INSTALL_FAILED
echo.
echo [OK] WinSCP установлен.
echo.
goto SEARCH_WINSCP

:WINGET_NOT_FOUND
echo [ОШИБКА] winget не найден.
goto END

:INSTALL_FAILED
echo.
echo [ОШИБКА] Не удалось установить WinSCP.
goto END

:WINSCP_FOUND
echo.
echo ==========================================
echo WinSCP
echo ==========================================
echo.
echo Сервер: %SERVER%
echo Порт:   %PORT%
echo User:   %USER%
echo.
echo WinSCP:
echo %WINSCP%
echo.

if exist "%SSH_KEY%" goto SSH_KEY_FOUND

echo [!] SSH-ключ отсутствует:
echo %SSH_KEY%
echo.
echo [!] Используем password.txt.
echo.
goto LOAD_PASSWORD

:SSH_KEY_FOUND
call "%SRVX_ROOT%\shared\fix_key.bat" "%SSH_KEY%"

echo ==========================================
echo [1/2] SSH KEY
echo ==========================================
echo.
echo SSH key:
echo %SSH_KEY%
echo.
goto TEST_KEY

:TEST_KEY
where ssh.exe >nul 2>&1
if errorlevel 1 goto SSH_NOT_FOUND

echo Быстро проверяем SSH-ключ...
echo Timeout: 5 секунд
echo.

ssh ^
    -i "%SSH_KEY%" ^
    -p %PORT% ^
    -o BatchMode=yes ^
    -o PasswordAuthentication=no ^
    -o KbdInteractiveAuthentication=no ^
    -o ConnectTimeout=5 ^
    -o ConnectionAttempts=1 ^
    -o StrictHostKeyChecking=accept-new ^
    "%USER%@%SERVER%" ^
    "exit"

set "KEY_RESULT=%ERRORLEVEL%"

echo.
echo SSH exit code: %KEY_RESULT%
echo.

if "%KEY_RESULT%"=="0" goto KEY_AUTH_OK

echo [!] SSH-ключ не подошёл.
echo [!] Переключаемся на password.txt.
echo.
goto LOAD_PASSWORD

:SSH_NOT_FOUND
echo [!] Windows OpenSSH не найден.
echo [!] Проверить ключ автоматически невозможно.
echo [!] Используем password.txt.
echo.
goto LOAD_PASSWORD

:KEY_AUTH_OK
echo [OK] Авторизация по SSH-ключу работает.
echo.
goto PREPARE_PPK

:PREPARE_PPK
if exist "%WINSCP_KEY%" goto PPK_READY

echo PPK ещё не создан.
echo Конвертируем OpenSSH-ключ для WinSCP...
echo.

if exist "%WINSCP_COM%" goto WINSCP_COM_OK

echo [!] WinSCP.com не найден:
echo %WINSCP_COM%
echo.
echo [!] Не можем конвертировать ключ.
echo [!] Используем password.txt.
echo.
goto LOAD_PASSWORD

:WINSCP_COM_OK
"%WINSCP_COM%" /keygen "%SSH_KEY%" /output="%WINSCP_KEY%"
set "KEYGEN_RESULT=%ERRORLEVEL%"
echo.
echo Keygen exit code: %KEYGEN_RESULT%
echo.
if "%KEYGEN_RESULT%"=="0" goto KEYGEN_OK
echo [!] Конвертация ключа не удалась.
echo [!] Используем password.txt.
echo.
goto LOAD_PASSWORD

:KEYGEN_OK
if exist "%WINSCP_KEY%" goto PPK_READY
echo [!] WinSCP сообщил об успешной конвертации,
echo [!] но PPK-файл не появился:
echo %WINSCP_KEY%
echo.
echo [!] Используем password.txt.
echo.
goto LOAD_PASSWORD

:PPK_READY
echo [OK] PPK готов:
echo %WINSCP_KEY%
echo.
goto OPEN_WITH_KEY

:OPEN_WITH_KEY
echo ==========================================
echo ОТКРЫВАЕМ WINSCP ПО КЛЮЧУ
echo ==========================================
echo.
echo Сервер: %SERVER%
echo Порт:   %PORT%
echo User:   %USER%
echo Key:    %WINSCP_KEY%
echo.

start "" "%WINSCP%" ^
    "sftp://%USER%@%SERVER%:%PORT%/" ^
    /privatekey="%WINSCP_KEY%"

set "START_RESULT=%ERRORLEVEL%"
if "%START_RESULT%"=="0" goto SUCCESS
echo [ОШИБКА] Не удалось запустить WinSCP.
goto END

:LOAD_PASSWORD
echo ==========================================
echo [2/2] PASSWORD FALLBACK
echo ==========================================
echo.

call "%SRVX_ROOT%\shared\load_passwords.bat" "%PASSWORD_FILE%"

if not defined PASSWORD (
    echo [ОШИБКА] В password.txt не указан пароль SSH.
    goto END
)

echo [OK] password.txt найден:
echo %PASSWORD_FILE%
echo.
echo [OK] Открываем WinSCP по паролю.
echo.
goto OPEN_WITH_PASSWORD

:OPEN_WITH_PASSWORD
echo ==========================================
echo ОТКРЫВАЕМ WINSCP ПО ПАРОЛЮ
echo ==========================================
echo.
echo Сервер: %SERVER%
echo Порт:   %PORT%
echo User:   %USER%
echo.

start "" "%WINSCP%" ^
    "sftp://%SERVER%:%PORT%/" ^
    /username="%USER%" ^
    /password="%PASSWORD%"

set "START_RESULT=%ERRORLEVEL%"
set "PASSWORD="
if "%START_RESULT%"=="0" goto SUCCESS
echo [ОШИБКА] Не удалось запустить WinSCP.
goto END

:SUCCESS
echo.
echo ==========================================
echo SUCCESS
echo ==========================================
echo.
echo WinSCP запущен.
echo.
echo Нажми любую клавишу для закрытия консоли.
echo.
pause >nul
endlocal
exit /b 0

:END
echo.
echo ==========================================
echo ERROR
echo ==========================================
echo.
echo Вывод выше показывает причину ошибки.
echo.
echo Нажми любую клавишу для выхода.
echo.
pause >nul
endlocal
exit /b 1
