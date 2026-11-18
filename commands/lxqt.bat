@echo off
REM @srvx id=lxqt
REM @srvx label=Рабочий стол (LXQt)
REM @srvx aliases=desktop
REM @srvx desc=LXQt noVNC в браузере
REM @srvx order=40
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

call "%~dp0..\shared\resolve_root.bat"
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 (
  echo [ОШИБКА] Не удалось загрузить config.bat
  pause
  exit /b 1
)
if not defined SERVER (
  echo [ОШИБКА] SERVER не задан в config.bat
  pause
  exit /b 1
)

set "URL=https://%SERVER%:6080/vnc.html"
set "LXQT_INSTALLED="
set "LXQT_CHECKED="

echo ==========================================
echo  LXQt / noVNC
echo ==========================================
echo Сервер: %SERVER%
echo.

REM --- Проверка по SSH (предпочтительно) ---
if exist "%SSH_KEY%" (
  call "%SRVX_ROOT%\shared\fix_key.bat" "%SSH_KEY%"
  where ssh.exe >nul 2>&1
  if not errorlevel 1 (
  echo Проверка сервисов lxqt-vnc / lxqt-novnc по SSH...
  ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new %USER%@%SERVER% "systemctl is-active --quiet lxqt-vnc.service && systemctl is-active --quiet lxqt-novnc.service" <nul >nul 2>&1
  if not errorlevel 1 (
    set "LXQT_INSTALLED=1"
    set "LXQT_CHECKED=1"
    echo [OK] Сервисы активны.
    echo.
  ) else (
    ssh -n -p %PORT% -i "%SSH_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new %USER%@%SERVER% "test -f /etc/systemd/system/lxqt-novnc.service" <nul >nul 2>&1
    if not errorlevel 1 (
      echo [!] Юниты есть, но сервисы не запущены.
    ) else (
      echo [!] LXQt / noVNC не установлен ^(нет юнитов^).
    )
    set "LXQT_INSTALLED=0"
    set "LXQT_CHECKED=1"
    echo.
  )
  )
)

REM --- Запасная проверка: TCP 6080 с Windows ---
if not "%LXQT_CHECKED%"=="1" (
  for /f "delims=" %%R in (`powershell -NoProfile -Command ^
    "try {" ^
    "  $c=New-Object Net.Sockets.TcpClient;" ^
    "  $iar=$c.BeginConnect('%SERVER%',6080,$null,$null);" ^
    "  if(-not $iar.AsyncWaitHandle.WaitOne(4000,$false)){ throw 'timeout' };" ^
    "  $c.EndConnect($iar); $c.Close(); Write-Output 'OPEN'" ^
    "} catch { Write-Output 'CLOSED' }"`) do (
    if /i "%%R"=="OPEN" set "LXQT_INSTALLED=1"
    if /i "%%R"=="CLOSED" set "LXQT_INSTALLED=0"
  )
  if defined LXQT_INSTALLED (
    set "LXQT_CHECKED=1"
    echo [*] Проверка по порту 6080 ^(SSH недоступен или без ключа^).
    echo.
  )
)

if not defined LXQT_INSTALLED (
  echo [!] Не удалось проверить состояние LXQt на сервере.
  echo     Будем считать, что установка нужна, если браузер не откроется.
  set "LXQT_INSTALLED=0"
)

if "%LXQT_INSTALLED%"=="1" goto OPEN_BROWSER

echo [!] LXQt / noVNC на сервере не найден или сервисы не запущены.
echo.
echo [1] Установить сейчас ^(srvx install-lxqt^)
echo [2] Всё равно открыть URL в браузере
echo [3] Выход
echo.

choice /C 123 /N /M "Выберите [1/2/3]: "
if errorlevel 3 exit /b 0
if errorlevel 2 goto OPEN_BROWSER
if errorlevel 1 goto RUN_INSTALL

:RUN_INSTALL
echo.
call "%SRVX_ROOT%\commands\install-lxqt.bat"
set "INSTALL_EC=%ERRORLEVEL%"
if not "%INSTALL_EC%"=="0" exit /b %INSTALL_EC%
echo.
echo [OK] Установка завершена. Открываем noVNC...
goto OPEN_BROWSER

:OPEN_BROWSER
echo.
echo URL: %URL%
echo HTTPS login: %LXQT_HTTPS_USER%
start "" "%URL%"
if errorlevel 1 (
  echo [ОШИБКА] Не удалось открыть браузер.
  pause
  exit /b 1
)
exit /b 0
