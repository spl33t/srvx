# srvx

[Русский](#русский) · [English](#english)

## Русский

**srvx** — набор команд для подключения к Linux-серверу из Windows. Он открывает SSH-терминал, удалённую папку в VS Code, SFTP в WinSCP и рабочий стол LXQt через браузер. Настройки хранятся отдельно в каждой папке проекта.

### Требования

- Windows с `cmd.exe` и Windows PowerShell.
- Windows OpenSSH (`ssh.exe`) для SSH-подключений.
- VS Code с расширением Remote - SSH для команды `vscode` и WinSCP для команды `winscp`. Скрипты предлагают установить недостающие приложения; для автоматической установки нужен `winget`.
- Для установки LXQt на сервере: Ubuntu, пользователь с правами `sudo` или `root` и доступ по SSH.

### Установка и первый запуск

1. Скачайте репозиторий или клонируйте его в постоянную папку.
2. Запустите `install.bat`. Он добавит эту папку в пользовательский `PATH` и пункт `srvx` в контекстное меню Проводника. После установки откройте новый терминал.
3. Перейдите в папку проекта, для которого нужен сервер, и выполните:

   ```bat
   srvx init
   ```

4. Введите адрес сервера, SSH-порт, пользователя и настройку автоматического `sudo`. Команда создаст в текущей папке `config.bat` и шаблон `password.txt`. При первом запуске команды, требующей конфигурацию, `init` вызывается автоматически.
5. При необходимости положите приватный OpenSSH-ключ в `my_key` или заполните `password.txt`. Проверьте подключение командой `srvx ping`, затем запустите `srvx ssh`.

Если добавлять `PATH` и контекстное меню не нужно, вызывайте `srvx.bat` по полному пути из папки проекта.

### Команды

Запускайте команды **из папки проекта**: именно там `srvx` ищет `config.bat` и связанные файлы.

| Команда | Назначение |
| --- | --- |
| `srvx` или `srvx menu` | Интерактивное меню |
| `srvx help` | Список команд и справка |
| `srvx init` | Создать конфигурацию текущей папки |
| `srvx ssh` | Открыть SSH-терминал |
| `srvx ssh --exec "hostname"` | Выполнить команду на сервере |
| `srvx vscode [путь]` или `srvx code [путь]` | Открыть удалённую папку в VS Code; без пути предложит выбрать папку |
| `srvx vscode --update` | Обновить расширение Remote - SSH |
| `srvx winscp` или `srvx sftp` | Открыть SFTP в WinSCP |
| `srvx ping` | Проверить SSH по ключу либо доступность TCP-порта |
| `srvx lxqt` или `srvx desktop` | Открыть LXQt/noVNC в браузере |
| `srvx install-lxqt` | Установить LXQt, TigerVNC и noVNC на Ubuntu-сервере |

### Конфигурация и доступ

`config.bat` создаётся в текущей папке. Основные параметры:

```bat
@echo off
set "SERVER=example.com"
set "PORT=22"
set "USER=deploy"
set "SSH_KEY=%~dp0my_key"
set "PASSWORD_FILE=%~dp0password.txt"
set "AUTO_SUDO=0"
set "SERVER_ALIVE_INTERVAL=15"
set "SERVER_ALIVE_COUNT_MAX=20"
```

`SERVER` и `USER` обязательны. По умолчанию порт — `22`, а `AUTO_SUDO=1`: SSH-команда пытается перейти в `sudo`; задайте `0`, чтобы остаться обычным пользователем. При успешной проверке используется ключ `my_key`, иначе команды пробуют пароль. `password.txt` может содержать один пароль для SSH и `sudo` или отдельные строки:

```text
SSH=ssh_password
SUDO=sudo_password
```

Не публикуйте `config.bat`, `password.txt`, `my_key` и созданный WinSCP-файл `my_key.ppk`, если они содержат адреса, учётные данные или ключи. `srvx vscode` добавляет запись для проекта в `%USERPROFILE%\.ssh\config`.

Для `srvx install-lxqt` понадобятся отдельные пароли VNC и HTTPS: установщик запросит их перед запуском. После установки `srvx lxqt` открывает `https://<сервер>:6080/vnc.html`.

### Удаление

Запустите `uninstall.bat`, чтобы убрать путь `srvx` из пользовательского `PATH` и его пункт контекстного меню. Затем откройте новый терминал. Файлы проекта удаляйте отдельно.

## English

**srvx** is a Windows command-line tool for connecting to a Linux server. It opens an SSH terminal, a remote folder in VS Code, SFTP in WinSCP, and an LXQt desktop in the browser. Each project directory has its own connection settings.

### Requirements

- Windows with `cmd.exe` and Windows PowerShell.
- Windows OpenSSH (`ssh.exe`) for SSH connections.
- VS Code with Remote - SSH for `vscode`, and WinSCP for `winscp`. The scripts offer to install missing applications; automatic installation requires `winget`.
- To install LXQt on the server: Ubuntu, an SSH connection, and a user with `sudo` or `root` access.

### Install and get started

1. Download or clone the repository into a permanent directory.
2. Run `install.bat`. It adds that directory to your user `PATH` and adds an `srvx` entry to the File Explorer context menu. Open a new terminal afterward.
3. Change to the directory of the project you want to connect from, then run:

   ```bat
   srvx init
   ```

4. Enter the server address, SSH port, user, and automatic `sudo` setting. This creates `config.bat` and a `password.txt` template in the current directory. Running a command that needs configuration also starts `init` automatically if the configuration is missing.
5. Optionally place an OpenSSH private key in `my_key` or fill in `password.txt`. Check the connection with `srvx ping`, then run `srvx ssh`.

You can call `srvx.bat` by its full path from the project directory if you do not want to install the `PATH` and context menu entries.

### Commands

Run commands **from the project directory**. That is where `srvx` reads `config.bat` and related files.

| Command | Purpose |
| --- | --- |
| `srvx` or `srvx menu` | Interactive menu |
| `srvx help` | List commands and show help |
| `srvx init` | Create configuration in the current directory |
| `srvx ssh` | Open an SSH terminal |
| `srvx ssh --exec "hostname"` | Run a command on the server |
| `srvx vscode [path]` or `srvx code [path]` | Open a remote folder in VS Code; prompts for a folder when omitted |
| `srvx vscode --update` | Update the Remote - SSH extension |
| `srvx winscp` or `srvx sftp` | Open SFTP in WinSCP |
| `srvx ping` | Check key-based SSH or TCP port availability |
| `srvx lxqt` or `srvx desktop` | Open LXQt/noVNC in a browser |
| `srvx install-lxqt` | Install LXQt, TigerVNC, and noVNC on an Ubuntu server |

### Configuration and credentials

`config.bat` lives in the current project directory. Its main settings are:

```bat
@echo off
set "SERVER=example.com"
set "PORT=22"
set "USER=deploy"
set "SSH_KEY=%~dp0my_key"
set "PASSWORD_FILE=%~dp0password.txt"
set "AUTO_SUDO=0"
set "SERVER_ALIVE_INTERVAL=15"
set "SERVER_ALIVE_COUNT_MAX=20"
```

`SERVER` and `USER` are required. The default port is `22`, and `AUTO_SUDO=1` by default: the SSH command attempts to enter `sudo`; set it to `0` to stay as the regular user. Commands use `my_key` when key authentication succeeds and otherwise try a password. `password.txt` can contain one password for both SSH and `sudo`, or separate entries:

```text
SSH=ssh_password
SUDO=sudo_password
```

Keep `config.bat`, `password.txt`, `my_key`, and the generated WinSCP key `my_key.ppk` out of public repositories if they contain server details, credentials, or private keys. `srvx vscode` adds a project entry to `%USERPROFILE%\.ssh\config`.

`srvx install-lxqt` prompts for separate VNC and HTTPS passwords before installing. After installation, `srvx lxqt` opens `https://<server>:6080/vnc.html`.

### Uninstall

Run `uninstall.bat` to remove the `srvx` user `PATH` entry and File Explorer context menu item. Open a new terminal afterward. Remove project files separately.
