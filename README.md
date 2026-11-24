# srvx

[Русский](#русский) · [English](#english)

## Русский

**srvx** — набор команд для подключения из Windows к Linux- и Windows-серверам, в том числе через Tailscale. Для Windows он открывает удалённый рабочий стол через RDP (`mstsc`); для Linux доступны SSH, VS Code, SFTP и рабочий стол LXQt через браузер. Настройки хранятся отдельно в каждой папке проекта.

### Требования

- Windows с `cmd.exe` и Windows PowerShell.
- Windows OpenSSH (`ssh.exe`) для SSH-подключений.
- Windows Remote Desktop (`mstsc.exe`) для RDP-подключений.
- Для автоматической настройки OpenSSH на Windows-сервере: включённый WinRM и учётная запись администратора. Если WinRM недоступен, srvx создаст установочный скрипт, файл запуска и инструкцию. При доступе к административной папке `C$` он скопирует файлы на общий рабочий стол удалённого компьютера; иначе попробует Taildrop, который доставляет файлы в «Загрузки» и должен быть разрешён для узла. Если оба способа недоступны, файлы можно вставить через RDP (`Ctrl+V`). Файл запуска запросит права администратора. При установке через RDP удалённый скрипт попробует отправить имя Windows-пользователя обратно через Taildrop; srvx автоматически добавит его в локальный `config.bat` после получения. Если ожидание закончилось, имя будет импортировано при следующем запуске srvx. Если обратная отправка недоступна, `USER` нужно указать вручную. Если передача файлов в RDP отключена, текст скрипта также показан в консоли.
- Для WinRM по Tailscale IP может понадобиться настроенный HTTPS WinRM или добавление IP в `TrustedHosts` на клиенте. Сценарий установки не меняет `TrustedHosts` автоматически.
- VS Code с расширением Remote - SSH для команды `vscode` и WinSCP для команды `winscp`. Скрипты предлагают установить недостающие приложения; для автоматической установки нужен `winget`.
- Для установки LXQt на сервере: Ubuntu, пользователь с правами `sudo` или `root` и доступ по SSH.

### Установка и первый запуск

1. Скачайте репозиторий или клонируйте его в постоянную папку.
2. Запустите `install.bat`. Он добавит эту папку в пользовательский `PATH` и пункт `srvx` в контекстное меню Проводника. После установки откройте новый терминал.
3. Перейдите в папку проекта, для которого нужен сервер, и выполните:

   ```bat
   srvx init
   ```

4. Если клиент Tailscale запущен и выполнен вход, выберите узел Windows или Linux из списка. Иначе введите адрес и тип ОС сервера вручную. Для Windows мастер создаст конфигурацию RDP без запроса SSH-пользователя и порта; подключайтесь через `srvx rdp`. Для Linux укажите SSH-порт, пользователя и настройку `sudo`; при необходимости добавьте ключ `my_key` или пароль в `password.txt`, затем запустите `srvx ssh`. При выборе узла Tailscale мастер также проверяет приветствие OpenSSH: для Windows на порту 22, для Linux на указанном SSH-порту. Проверка не подтверждает возможность входа. Проверить доступность можно командой `srvx ping`.

Если добавлять `PATH` и контекстное меню не нужно, вызывайте `srvx.bat` по полному пути из папки проекта.

### Команды

Запускайте команды **из папки проекта**: именно там `srvx` ищет `config.bat` и связанные файлы.

| Команда | Назначение |
| --- | --- |
| `srvx` или `srvx menu` | Интерактивное меню |
| `srvx help` | Список команд и справка |
| `srvx init` | Создать конфигурацию текущей папки |
| `srvx rdp` или `srvx mstsc` | Открыть Windows-сервер через удалённый рабочий стол |
| `srvx install-openssh` или `srvx setup-ssh` | Настроить OpenSSH на Windows через WinRM или RDP |
| `srvx ssh` | Открыть SSH-терминал |
| `srvx ssh --exec "hostname"` | Выполнить команду на сервере |
| `srvx vscode [путь]` или `srvx code [путь]` | Открыть удалённую папку в VS Code; без пути предложит выбрать папку |
| `srvx vscode --update` | Обновить расширение Remote - SSH |
| `srvx winscp` или `srvx sftp` | Открыть SFTP в WinSCP |
| `srvx ping` | Проверить SSH/TCP или порт RDP 3389 |
| `srvx lxqt` или `srvx desktop` | Открыть LXQt/noVNC в браузере |
| `srvx install-lxqt` | Установить LXQt, TigerVNC и noVNC на Ubuntu-сервере |

### Конфигурация и доступ

`config.bat` создаётся в текущей папке. `srvx init` записывает все поддерживаемые настройки с текущими значениями по умолчанию и комментариями; порядок строк одинаковый для Windows и Linux. При повторном `init` для того же сервера сохраняются `USER` и `RDP_USER`. Основные параметры:

```bat
@echo off
set "SERVER=example.com"
set "PORT=22"
set "USER=deploy"
set "SERVER_OS=linux"
set "TAILSCALE=0"
set "SSH_KEY=%~dp0my_key"
set "PASSWORD_FILE=%~dp0password.txt"
set "AUTO_SUDO=1"
set "SERVER_ALIVE_INTERVAL=15"
set "SERVER_ALIVE_COUNT_MAX=20"
```

Для Windows через Tailscale достаточно:

```bat
set "SERVER=100.75.52.98"
set "SERVER_OS=windows"
set "TAILSCALE=1"
```

`SERVER` обязателен. `SERVER_OS=windows` открывает `srvx rdp` через `mstsc /v:<SERVER>` без обязательного `USER`, `PORT` и SSH-ключа; без RDP-пароля в `password.txt` учётные данные запрашивает Windows. `SERVER_OS=linux` использует SSH: нужен `USER`, порт по умолчанию — `22`. Для старых конфигураций без `SERVER_OS` применяется Linux. На Linux `AUTO_SUDO=1` пытается перейти в `sudo`; задайте `0`, чтобы остаться обычным пользователем. При выборе узла Tailscale ставится `TAILSCALE=1`: Windows-узел сохраняется по Tailscale IPv4, Linux — по MagicDNS-имени или IP. Перед подключением srvx проверяет, что клиент Tailscale запущен, а узел online. Для RDP на Windows-сервере должен быть включён удалённый рабочий стол. Чтобы в том же проекте использовать `srvx ssh`, `srvx vscode` и `srvx winscp`, включите OpenSSH Server/SFTP на сервере и добавьте `set "USER=имя_пользователя"` в `config.bat`; `PORT=22` можно не указывать. При SSH используется ключ `my_key` или пароль из `password.txt`:

```text
SSH=ssh_password
SUDO=sudo_password
RDP_PASSWORD=windows_account_password
```

Для автоматического входа RDP укажите пароль в `SSH` или `RDP_PASSWORD` в `password.txt` и `USER` в `config.bat`; если имя для RDP отличается, задайте `RDP_USER` в `config.bat`. Перед запуском `mstsc` srvx сохранит пароль для адреса `SERVER` в Windows Credential Manager. Если `RDP_PASSWORD` не заполнен и логин RDP совпадает с `USER`, используется пароль из `SSH`. Одна строка без ключа также подходит для RDP.

Не публикуйте `config.bat`, `password.txt`, `my_key` и созданный WinSCP-файл `my_key.ppk`, если они содержат адреса, учётные данные или ключи. `srvx vscode` добавляет запись для проекта в `%USERPROFILE%\.ssh\config`.

Для `srvx install-lxqt` понадобятся отдельные пароли VNC и HTTPS: установщик запросит их перед запуском. После установки `srvx lxqt` открывает `https://<сервер>:6080/vnc.html`.

### Удаление

Запустите `uninstall.bat`, чтобы убрать путь `srvx` из пользовательского `PATH` и его пункт контекстного меню. Затем откройте новый терминал. Файлы проекта удаляйте отдельно.

## English

**srvx** is a Windows command-line tool for connecting to Linux and Windows servers, including over Tailscale. For Windows it opens Remote Desktop via RDP (`mstsc`); for Linux it supports SSH, VS Code, SFTP, and LXQt in the browser. Each project directory has its own connection settings.

### Requirements

- Windows with `cmd.exe` and Windows PowerShell.
- Windows OpenSSH (`ssh.exe`) for SSH connections.
- Windows Remote Desktop (`mstsc.exe`) for RDP connections.
- For automatic OpenSSH setup on a Windows server: WinRM and administrator credentials. If WinRM is unavailable, srvx creates a setup script, launcher, and instructions. If the administrative `C$` share is accessible, it copies the files to the remote Public Desktop. Otherwise, it tries Taildrop, which sends files to the remote PC's Downloads folder and must be enabled for the peer. If both methods are unavailable, paste the files over RDP (`Ctrl+V`). The launcher requests administrator privileges. When installing over RDP, the remote script tries to send the Windows username back through Taildrop; srvx adds it to the local `config.bat` when it arrives. If the wait has ended, the next srvx command imports it. If the reverse transfer fails, set `USER` manually. If RDP file transfer is disabled, the script text is also printed in the console.
- WinRM over a Tailscale IP may require configured WinRM HTTPS or adding the IP to the client's `TrustedHosts`. The setup does not change `TrustedHosts` automatically.
- VS Code with Remote - SSH for `vscode`, and WinSCP for `winscp`. The scripts offer to install missing applications; automatic installation requires `winget`.
- To install LXQt on the server: Ubuntu, an SSH connection, and a user with `sudo` or `root` access.

### Install and get started

1. Download or clone the repository into a permanent directory.
2. Run `install.bat`. It adds that directory to your user `PATH` and adds an `srvx` entry to the File Explorer context menu. Open a new terminal afterward.
3. Change to the directory of the project you want to connect from, then run:

   ```bat
   srvx init
   ```

4. If the Tailscale client is running and logged in, pick a Windows or Linux node from the list. Otherwise enter the server address and OS manually. For Windows, the wizard configures RDP without asking for an SSH user or port; connect with `srvx rdp`. For Linux, enter the SSH port, user, and `sudo` setting; optionally add a key in `my_key` or a password in `password.txt`, then run `srvx ssh`. For a selected Tailscale node, the wizard also checks the OpenSSH banner: port 22 on Windows, or the chosen SSH port on Linux. This does not verify login. Use `srvx ping` to check reachability.

You can call `srvx.bat` by its full path from the project directory if you do not want to install the `PATH` and context menu entries.

### Commands

Run commands **from the project directory**. That is where `srvx` reads `config.bat` and related files.

| Command | Purpose |
| --- | --- |
| `srvx` or `srvx menu` | Interactive menu |
| `srvx help` | List commands and show help |
| `srvx init` | Create configuration in the current directory |
| `srvx rdp` or `srvx mstsc` | Open a Windows server in Remote Desktop |
| `srvx install-openssh` or `srvx setup-ssh` | Set up OpenSSH on Windows through WinRM or RDP |
| `srvx ssh` | Open an SSH terminal |
| `srvx ssh --exec "hostname"` | Run a command on the server |
| `srvx vscode [path]` or `srvx code [path]` | Open a remote folder in VS Code; prompts for a folder when omitted |
| `srvx vscode --update` | Update the Remote - SSH extension |
| `srvx winscp` or `srvx sftp` | Open SFTP in WinSCP |
| `srvx ping` | Check SSH/TCP or RDP port 3389 |
| `srvx lxqt` or `srvx desktop` | Open LXQt/noVNC in a browser |
| `srvx install-lxqt` | Install LXQt, TigerVNC, and noVNC on an Ubuntu server |

### Configuration and credentials

`config.bat` lives in the current project directory. `srvx init` writes every supported setting with its current default and a comment, in the same order for Windows and Linux. Re-running `init` for the same server preserves `USER` and `RDP_USER`. Its main settings are:

```bat
@echo off
set "SERVER=example.com"
set "PORT=22"
set "USER=deploy"
set "SERVER_OS=linux"
set "TAILSCALE=0"
set "SSH_KEY=%~dp0my_key"
set "PASSWORD_FILE=%~dp0password.txt"
set "AUTO_SUDO=1"
set "SERVER_ALIVE_INTERVAL=15"
set "SERVER_ALIVE_COUNT_MAX=20"
```

For Windows over Tailscale, this is sufficient:

```bat
set "SERVER=100.75.52.98"
set "SERVER_OS=windows"
set "TAILSCALE=1"
```

`SERVER` is required. `SERVER_OS=windows` opens `srvx rdp` through `mstsc /v:<SERVER>` without requiring `USER`, `PORT`, or an SSH key; Windows prompts for credentials unless an RDP password is configured in `password.txt`. `SERVER_OS=linux` uses SSH: `USER` is required and port `22` is the default. Older configs without `SERVER_OS` default to Linux. On Linux, `AUTO_SUDO=1` attempts to enter `sudo`; set it to `0` to stay as the regular user. Selecting a Tailscale node sets `TAILSCALE=1`: a Windows node uses its Tailscale IPv4, while a Linux node uses its MagicDNS name or IP. Before connecting, srvx checks that the Tailscale client is running and the node is online. Remote Desktop must be enabled on the Windows server. To use `srvx ssh`, `srvx vscode`, and `srvx winscp` in the same project, enable OpenSSH Server/SFTP and add `set "USER=username"` to `config.bat`; port `22` is the default. SSH uses `my_key` or a password from `password.txt`:

```text
SSH=ssh_password
SUDO=sudo_password
RDP_PASSWORD=windows_account_password
```

For automatic RDP sign-in, put the password in `SSH` or `RDP_PASSWORD` in `password.txt` and set `USER` in `config.bat`. Use `RDP_USER` in `config.bat` if the RDP login differs. Before launching `mstsc`, srvx saves the password for `SERVER` in Windows Credential Manager. If `RDP_PASSWORD` is unset and the RDP login matches `USER`, srvx uses the `SSH` password. A single unlabelled line also works for RDP.

Keep `config.bat`, `password.txt`, `my_key`, and the generated WinSCP key `my_key.ppk` out of public repositories if they contain server details, credentials, or private keys. `srvx vscode` adds a project entry to `%USERPROFILE%\.ssh\config`.

`srvx install-lxqt` prompts for separate VNC and HTTPS passwords before installing. After installation, `srvx lxqt` opens `https://<server>:6080/vnc.html`.

### Uninstall

Run `uninstall.bat` to remove the `srvx` user `PATH` entry and File Explorer context menu item. Open a new terminal afterward. Remove project files separately.
