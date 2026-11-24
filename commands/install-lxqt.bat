@echo off
REM @srvx id=install-lxqt
REM @srvx label=Установить LXQt/VNC
REM @srvx aliases=install_lxqt,installlxqt
REM @srvx desc=Установить LXQt + TigerVNC + noVNC на сервере
REM @srvx order=50
REM @srvx menu=1
REM @srvx default=0
REM @srvx needs_config=1
chcp 65001 >nul
setlocal DisableDelayedExpansion
call "%~dp0..\shared\resolve_root.bat"
call "%SRVX_ROOT%\shared\load_config.bat"
if errorlevel 1 (
  echo [ОШИБКА] load_config не удался
  pause
  exit /b 1
)
if /i "%SERVER_OS%"=="windows" (
  echo [ОШИБКА] Установка LXQt поддерживается только на Linux-сервере.
  exit /b 1
)
if not exist "%SRVX_ROOT%\commands\ssh.bat" (
  echo [ERROR] srvx ssh.bat not found.
  pause
  exit /b 1
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Windows PowerShell is missing.
  pause
  exit /b 1
)

REM Prompt on Windows before SSH; never display the password.
REM TigerVNC VncAuth only supports the first 8 password bytes.
set "INSTALLER_FILE=%~f0"
set "PAYLOAD="
for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $p=Read-Host 'New VNC password (exactly 8 ASCII characters)' -AsSecureString; $q=Read-Host 'Confirm VNC password' -AsSecureString; $h=Read-Host 'New HTTPS password (12-128 ASCII characters)' -AsSecureString; $j=Read-Host 'Confirm HTTPS password' -AsSecureString; $a=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($q); $c=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($h); $d=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($j); try { $v=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($a); $w=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b); $x=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($c); $y=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($d); if($v -cne $w){throw 'VNC passwords do not match'}; if($v -cnotmatch '^[\x21-\x7E]{8}$'){throw 'VNC password must be exactly 8 printable ASCII characters (no spaces)'}; if($x -cne $y){throw 'HTTPS passwords do not match'}; if($x -cnotmatch '^[\x21-\x7E]{12,128}$'){throw 'HTTPS password must be 12-128 printable ASCII characters (no spaces)'}; $s=[IO.File]::ReadAllText($env:INSTALLER_FILE); $mark=':__EMBEDDED_BASH__'; $i=$s.LastIndexOf($mark); if($i -lt 0){throw 'Installer payload not found'}; $script=$s.Substring($i+$mark.Length).TrimStart([char]13,[char]10); $script=$script.Replace([string][char]13+[char]10,[string][char]10); $script=$script.Replace('__VNC_PASSWORD_B64__',[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($v))); $script=$script.Replace('__HTTPS_PASSWORD_B64__',[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($x))); $bytes=[Text.Encoding]::UTF8.GetBytes($script); $m=New-Object IO.MemoryStream; $z=New-Object IO.Compression.GZipStream($m,[IO.Compression.CompressionMode]::Compress); $z.Write($bytes,0,$bytes.Length); $z.Close(); [Convert]::ToBase64String($m.ToArray()) } catch { [Console]::Error.WriteLine('[ERROR] '+$_.Exception.Message); exit 1 } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($a); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($c); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($d) }"`) do set "PAYLOAD=%%A"
if not defined PAYLOAD (
  echo [ERROR] Cannot extract embedded installer.
  pause
  exit /b 1
)

REM Split the compressed installer into short commands for srvx ssh.
REM A temporary local file contains base64-encoded passwords: delete it on exit.
set "CHUNKS_FILE=%TEMP%\lxqt_chunks_%RANDOM%_%RANDOM%.txt"
set "REMOTE_B64=/tmp/lxqt_installer_%RANDOM%_%RANDOM%.b64"
set "PAYLOAD_B64=%PAYLOAD%"
set "PAYLOAD="
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $p=$env:PAYLOAD_B64; $out=$env:CHUNKS_FILE; $lines=New-Object 'System.Collections.Generic.List[string]'; for($i=0;$i -lt $p.Length;$i+=700){$lines.Add($p.Substring($i,[Math]::Min(700,$p.Length-$i)))}; [IO.File]::WriteAllLines($out,$lines,[Text.Encoding]::ASCII)"
if errorlevel 1 goto :transfer_failed
set "PAYLOAD_B64="
echo ==============================================
echo LXQt + TigerVNC + noVNC HTTPS installer
echo Transferring installer in short chunks...
echo ==============================================
call "%SRVX_ROOT%\commands\ssh.bat" --exec "umask 077; : > %REMOTE_B64%"
if errorlevel 1 goto :transfer_failed
for /f "usebackq delims=" %%C in ("%CHUNKS_FILE%") do (
  call "%SRVX_ROOT%\commands\ssh.bat" --exec "echo %%C>>%REMOTE_B64%"
  if errorlevel 1 goto :transfer_failed
)
del /q "%CHUNKS_FILE%" >nul 2>&1
set "CHUNKS_FILE="
echo [INFO] Running installer...
call "%SRVX_ROOT%\commands\ssh.bat" --exec "export DESKTOP_USER='%USER%'; base64 -d %REMOTE_B64% | gzip -d | bash; result=$?; rm -f %REMOTE_B64%; exit $result"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo [ERROR] Installation failed, exit code %RESULT%.
  pause
  exit /b %RESULT%
)
echo [OK] Installation completed.
pause
endlocal
exit /b 0

:transfer_failed
if defined CHUNKS_FILE del /q "%CHUNKS_FILE%" >nul 2>&1
set "PAYLOAD_B64="
echo [ERROR] Could not transfer installer to the server.
pause
exit /b 1

:__EMBEDDED_BASH__
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -z "${DESKTOP_USER:-}" ]]; then echo '[ERROR] DESKTOP_USER not set (expected USER from config.bat)' >&2; exit 1; fi
DISPLAY_NUMBER=1

if [[ "$(id -u)" -ne 0 ]]; then echo '[ERROR] Requires root (AUTO_SUDO=1 or SSH root).' >&2; exit 1; fi
if ! id "$DESKTOP_USER" >/dev/null 2>&1; then echo "[ERROR] User $DESKTOP_USER not found" >&2; exit 1; fi
if [[ ! -f /etc/os-release ]]; then echo '[ERROR] Unsupported system'; exit 1; fi
. /etc/os-release
if [[ "$ID" != ubuntu ]]; then echo "[ERROR] Expected Ubuntu, got $ID"; exit 1; fi

export DEBIAN_FRONTEND=noninteractive
printf '\n[1/6] Installing desktop, themes and fonts...\n'
apt-get update
apt-get install -y --no-install-recommends \
  lxqt-core lxqt-menu-data openbox tigervnc-standalone-server tigervnc-tools \
  novnc websockify dbus-x11 xauth \
  lxqt-themes lxqt-qtplugin breeze-icon-theme papirus-icon-theme \
  qt6ct fonts-dejavu-core fonts-noto-core curl ca-certificates python3-venv


printf '\n[Chrome] Installing Google Chrome Stable...\n'
if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
  echo '[ERROR] Google Chrome .deb requires amd64 architecture.' >&2
  exit 1
fi
CHROME_DEB="$(mktemp /tmp/google-chrome-stable.XXXXXXXX.deb)"
curl -fL --retry 3 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$CHROME_DEB"
apt-get install -y "$CHROME_DEB"
rm -f "$CHROME_DEB"

systemctl stop lxqt-novnc.service lxqt-vnc.service 2>/dev/null || true
HOME_DIR="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"
VNC_DIR="$HOME_DIR/.config/tigervnc"
LEGACY_VNC_DIR="$HOME_DIR/.vnc"
DESKTOP_GROUP="$(id -gn "$DESKTOP_USER")"
install -d -m 700 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$HOME_DIR/.config"
install -d -m 700 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$VNC_DIR"
if [[ -d "$LEGACY_VNC_DIR" ]]; then
  if [[ -f "$LEGACY_VNC_DIR/passwd" && ! -s "$VNC_DIR/passwd" ]]; then
    install -m 600 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$LEGACY_VNC_DIR/passwd" "$VNC_DIR/passwd"
  fi
  BACKUP_DIR="$HOME_DIR/.vnc.backup.$(date +%Y%m%d%H%M%S)"
  mv "$LEGACY_VNC_DIR" "$BACKUP_DIR"
  echo "[INFO] Legacy VNC directory backed up: $BACKUP_DIR"
fi
BIN_DIR="$HOME_DIR/.local/bin"
install -d -m 755 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$BIN_DIR"

# Repair ownership of the user-local directory created by previous root runs.
chown -R "$DESKTOP_USER:$DESKTOP_GROUP" "$HOME_DIR/.local"
install -d -m 755 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$HOME_DIR/.local/share"

printf '\n[2/6] Configuring LXQt session...\n'
cat > "$BIN_DIR/start-lxqt-vnc" <<'SESSION'
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
exec dbus-run-session -- startlxqt
SESSION
chmod 755 "$BIN_DIR/start-lxqt-vnc"
chown "$DESKTOP_USER:$DESKTOP_GROUP" "$BIN_DIR/start-lxqt-vnc"

# Use the stock LXQt panel configuration; change only the application menu
# presentation and remove the unwanted desktop switcher / quick launch.
PANEL_DIR="$HOME_DIR/.config/lxqt"
install -d -m 755 -o "$DESKTOP_USER" -g "$DESKTOP_GROUP" "$PANEL_DIR"
PANEL_CONFIG="$PANEL_DIR/panel.conf"
if [[ -f "$PANEL_CONFIG" ]]; then
  cp -a "$PANEL_CONFIG" "$PANEL_CONFIG.before-installer.$(date +%Y%m%d%H%M%S)"
else
  cp /usr/share/lxqt/panel.conf "$PANEL_CONFIG"
fi
# LXQt uses an INI-like format with keys before any section: avoid configparser.
python3 - "$PANEL_CONFIG" <<'PY_PANEL'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = re.sub(r'(?m)^(plugins\s*=).*$', r'\1fancymenu,taskbar,statusnotifier,tray,worldclock,showdesktop', s, count=1)
match = re.search(r'(?ms)^\[fancymenu\]\s*\n(.*?)(?=^\[|\Z)', s)
if not match:
    s += '\n[fancymenu]\ntype=fancymenu\n'
    match = re.search(r'(?ms)^\[fancymenu\]\s*\n(.*?)(?=^\[|\Z)', s)
section = match.group(0)
for key, value in [('ownIcon','false'), ('showText','true'), ('text','Пуск')]:
    if re.search(r'(?m)^' + key + r'\s*=', section):
        section = re.sub(r'(?m)^' + key + r'\s*=.*$', key + '=' + value, section)
    else:
        section = section.rstrip('\n') + '\n' + key + '=' + value + '\n'
s = s[:match.start()] + section + s[match.end():]
p.write_text(s)
PY_PANEL
chown "$DESKTOP_USER:$DESKTOP_GROUP" "$PANEL_CONFIG"

printf '\n[3/6] Setting new VNC password...\n'
VNC_PASSWORD_B64="__VNC_PASSWORD_B64__"
if [[ -z "$VNC_PASSWORD_B64" || "$VNC_PASSWORD_B64" == *'_'* ]]; then
  echo '[ERROR] Password was not supplied by Windows installer' >&2; exit 1
fi
TEMP_PASSWD="$(mktemp "$VNC_DIR/passwd.XXXXXXXX")"
trap 'rm -f "$TEMP_PASSWD"' EXIT
printf '%s' "$VNC_PASSWORD_B64" | base64 -d | tigervncpasswd -f > "$TEMP_PASSWD"
chmod 600 "$TEMP_PASSWD"
chown "$DESKTOP_USER:$DESKTOP_GROUP" "$TEMP_PASSWD"
mv -f "$TEMP_PASSWD" "$VNC_DIR/passwd"
trap - EXIT
unset VNC_PASSWORD_B64
chmod 600 "$VNC_DIR/passwd"
chown "$DESKTOP_USER:$DESKTOP_GROUP" "$VNC_DIR/passwd"

printf '\n[4/6] Configuring systemd services...\n'
cat > /etc/systemd/system/lxqt-vnc.service <<UNIT
[Unit]
Description=TigerVNC LXQt desktop on display :1
After=network.target

[Service]
Type=forking
User=$DESKTOP_USER
Group=$DESKTOP_GROUP
Environment=HOME=$HOME_DIR
WorkingDirectory=$HOME_DIR
ExecStart=/usr/bin/tigervncserver :$DISPLAY_NUMBER -localhost yes -geometry 1440x900 -depth 24 -SecurityTypes VncAuth -PasswordFile $VNC_DIR/passwd -xstartup $BIN_DIR/start-lxqt-vnc
ExecStop=-/usr/bin/tigervncserver -kill :$DISPLAY_NUMBER
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

NOVNC_WEB=/usr/share/novnc
if [[ ! -d "$NOVNC_WEB" ]]; then echo "[ERROR] noVNC web assets not found: $NOVNC_WEB" >&2; exit 1; fi
WEBSOCKIFY_BIN="$(command -v websockify)"
cat > /etc/systemd/system/lxqt-novnc.service <<UNIT
[Unit]
Description=noVNC over loopback for LXQt
Requires=lxqt-vnc.service
After=lxqt-vnc.service

[Service]
Type=simple
ExecStart=$WEBSOCKIFY_BIN --web=$NOVNC_WEB 127.0.0.1:6080 127.0.0.1:5901
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

# Public HTTPS: websockify serves TLS and requires a separate HTTP password.
# Certificates for public IP addresses require a recent Certbot release.
printf '\n[HTTPS] Configuring public IP TLS certificate...\n'
PUBLIC_IP="$(curl -4fsS --max-time 15 https://api.ipify.org)"
if ! python3 - "$PUBLIC_IP" <<'PY_IP'
import ipaddress, sys
try:
    assert ipaddress.ip_address(sys.argv[1]).is_global
except (ValueError, AssertionError):
    sys.exit(1)
PY_IP
then
  echo '[ERROR] Could not detect a globally routable public IPv4 address.' >&2
  exit 1
fi
if [[ ! -x /opt/lxqt-certbot/bin/certbot ]]; then
  python3 -m venv /opt/lxqt-certbot
fi
/opt/lxqt-certbot/bin/python -m pip install --disable-pip-version-check 'certbot>=5.4,<7'
CERT_DIR="/etc/letsencrypt/live/$PUBLIC_IP"
# A rerun uses the existing valid certificate and avoids needless reissuance.
if [[ ! -s "$CERT_DIR/fullchain.pem" || ! -s "$CERT_DIR/privkey.pem" ]] || \
   ! openssl x509 -checkend 86400 -noout -in "$CERT_DIR/fullchain.pem" >/dev/null 2>&1; then
  /opt/lxqt-certbot/bin/certbot certonly --standalone --preferred-challenges http \
    --preferred-profile shortlived --ip-address "$PUBLIC_IP" \
    --non-interactive --agree-tos --register-unsafely-without-email \
    --keep-until-expiring
fi
test -s "$CERT_DIR/fullchain.pem"
test -s "$CERT_DIR/privkey.pem"

printf '\n[AUTH] Installing password-protected HTTPS access...\n'
HTTPS_PASSWORD_B64='__HTTPS_PASSWORD_B64__'
if [[ -z "$HTTPS_PASSWORD_B64" || "$HTTPS_PASSWORD_B64" == *'_'* ]]; then
  echo '[ERROR] HTTPS password missing from Windows installer.' >&2
  exit 1
fi
AUTH_DIR=/etc/lxqt-novnc
PLUGIN_DIR=/opt/lxqt-novnc-auth
install -d -m 700 "$AUTH_DIR"
install -d -m 755 "$PLUGIN_DIR"
# Store only a salted PBKDF2 password hash, never a plaintext password.
# Password enters Python via stdin rather than a process argument.
export HTTPS_PASSWORD_B64
python3 - "$AUTH_DIR/password.json" <<'PY_HASH'
import base64, hashlib, json, os, pathlib, secrets, sys
password = base64.b64decode(os.environ['HTTPS_PASSWORD_B64'], validate=True)
if not 12 <= len(password) <= 128 or not all(33 <= b <= 126 for b in password):
    raise SystemExit('[ERROR] Invalid HTTPS password')
salt = secrets.token_bytes(32)
iterations = 350000
key = hashlib.pbkdf2_hmac('sha256', password, salt, iterations)
path = pathlib.Path(sys.argv[1])
with path.open('w') as f:
    json.dump({'user': 'desktop', 'salt': salt.hex(), 'hash': key.hex(), 'iterations': iterations}, f)
os.chmod(path, 0o600)
PY_HASH
unset HTTPS_PASSWORD_B64

# A tiny authentication plugin reads the hashed password file.
# Unlike BasicHTTPAuth --auth-source user:password, no secret appears in ps/systemctl.
cat > "$PLUGIN_DIR/secure_auth.py" <<'PY_AUTH'
import hashlib
import hmac
import json
from websockify.auth_plugins import BasicHTTPAuth

class HashedBasicAuth(BasicHTTPAuth):
    def validate_creds(self, username, password):
        try:
            with open(self.src, encoding='utf-8') as f:
                data = json.load(f)
            if not hmac.compare_digest(username, data['user']):
                return False
            actual = hashlib.pbkdf2_hmac(
                'sha256', password.encode('latin-1'), bytes.fromhex(data['salt']),
                int(data['iterations']))
            return hmac.compare_digest(actual, bytes.fromhex(data['hash']))
        except (OSError, ValueError, KeyError, UnicodeError, TypeError):
            return False
PY_AUTH
chmod 644 "$PLUGIN_DIR/secure_auth.py"

# Replaces the original loopback-only noVNC service with public TLS.
cat > /etc/systemd/system/lxqt-novnc.service <<UNIT
[Unit]
Description=noVNC public HTTPS with password authentication
Requires=lxqt-vnc.service
After=lxqt-vnc.service

[Service]
Type=simple
Environment=PYTHONPATH=$PLUGIN_DIR
ExecStart=$WEBSOCKIFY_BIN --web=$NOVNC_WEB --web-auth --auth-plugin secure_auth.HashedBasicAuth --auth-source $AUTH_DIR/password.json --cert=$CERT_DIR/fullchain.pem --key=$CERT_DIR/privkey.pem --ssl-only --file-only 0.0.0.0:6080 127.0.0.1:5901
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

# Short-lived IP certificates are checked for renewal twice a day.
cat > /etc/systemd/system/lxqt-cert-renew.service <<'UNIT'
[Unit]
Description=Renew noVNC public IP TLS certificate
[Service]
Type=oneshot
ExecStart=/opt/lxqt-certbot/bin/certbot renew --quiet --deploy-hook "systemctl try-restart lxqt-novnc.service"
UNIT
cat > /etc/systemd/system/lxqt-cert-renew.timer <<'UNIT'
[Unit]
Description=Check noVNC TLS certificate renewal twice daily
[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=1800
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now lxqt-cert-renew.timer

printf '\n[5/6] Starting services...\n'
systemctl daemon-reload
systemctl enable lxqt-vnc.service lxqt-novnc.service
systemctl reset-failed lxqt-vnc.service
systemctl restart lxqt-vnc.service
systemctl restart lxqt-novnc.service
sleep 3

printf '\n[6/6] Verifying...\n'
systemctl --no-pager --full status lxqt-vnc.service lxqt-novnc.service | head -65 || true
if ! systemctl is-active --quiet lxqt-vnc.service || ! systemctl is-active --quiet lxqt-novnc.service; then
  echo '[ERROR] Service failed. Diagnostics:' >&2
  journalctl -u lxqt-vnc.service -u lxqt-novnc.service -n 70 --no-pager >&2
  exit 1
fi
# Unauthenticated HTTPS MUST be rejected with HTTP 401.
# websockify may close the TLS socket without a clean close_notify after 401,
# which makes curl return code 56 even though the response was correct.
HTTP_CODE="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
  --resolve "$PUBLIC_IP:6080:127.0.0.1" \
  "https://$PUBLIC_IP:6080/vnc.html" 2>/dev/null || true)"
if [[ "$HTTP_CODE" != 401 ]]; then
  echo "[ERROR] noVNC HTTPS expected HTTP 401 without credentials; got $HTTP_CODE" >&2
  exit 1
fi
echo '[OK] Public HTTPS and password gate are working.'
if ss -H -lnt | awk '$4 ~ /:(5901|6080)$/ && $4 !~ /^(127\.0\.0\.1|\[::1\]):/ {print; found=1} END {exit !found}'; then
  echo '[INFO] HTTPS is publicly bound on port 6080 (expected).' >&2
fi

echo
echo '=== INSTALLATION COMPLETE ==='
echo "Public URL: https://$PUBLIC_IP:6080/vnc.html"
echo 'HTTPS login: desktop; password: the one you entered at the start.'
echo 'Required inbound ports: TCP 80 for certificate issuance/renewal, TCP 6080 for desktop.'
echo 'VNC password: updated successfully (not displayed).'
echo 'Services: lxqt-vnc.service, lxqt-novnc.service, lxqt-cert-renew.timer'

