#!/data/data/com.termux/files/usr/bin/bash
# Configura OpenSSH en Termux (ejecutar UNA vez). Requiere authorized_keys en llm-setup/.
set -euo pipefail

AUTH_SRC="${HOME}/storage/shared/Download/llm-setup/authorized_keys"
SSHD_CONFIG="${PREFIX}/etc/ssh/sshd_config"
BASHRC="${HOME}/.bashrc"

echo "==> Instalando openssh y openssl (API remota)..."
pkg install -y openssh openssl

echo "==> Instalando clave pública..."
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
if [[ ! -f "$AUTH_SRC" ]]; then
  echo "Error: no existe $AUTH_SRC" >&2
  echo "Desde el PC: adb push authorized_keys → /sdcard/Download/llm-setup/" >&2
  exit 1
fi
cp -f "$AUTH_SRC" "${HOME}/.ssh/authorized_keys"
chmod 600 "${HOME}/.ssh/authorized_keys"

echo "==> Configurando sshd (puerto 8022, sin contraseña)..."
touch "$SSHD_CONFIG"
if grep -q '^Port ' "$SSHD_CONFIG" 2>/dev/null; then
  sed -i 's/^Port .*/Port 8022/' "$SSHD_CONFIG"
else
  echo 'Port 8022' >> "$SSHD_CONFIG"
fi
if grep -q '^PasswordAuthentication ' "$SSHD_CONFIG" 2>/dev/null; then
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG"
else
  echo 'PasswordAuthentication no' >> "$SSHD_CONFIG"
fi

echo "==> Arrancando sshd..."
if command -v sshd >/dev/null 2>&1; then
  pkill -x sshd 2>/dev/null || true
  sshd
fi

echo "==> Auto-arranque en ~/.bashrc (idempotente)..."
ensure_line() {
  local marker="$1"
  local line="$2"
  if ! grep -Fq "$marker" "$BASHRC" 2>/dev/null; then
    {
      echo ""
      echo "# $marker"
      echo "$line"
    } >> "$BASHRC"
  fi
}
ensure_line "llm-setup: termux-wake-lock" "termux-wake-lock 2>/dev/null || true"
ensure_line "llm-setup: sshd" "command -v sshd >/dev/null && sshd 2>/dev/null || true"

echo ""
echo "Listo. Usuario SSH: $(whoami)"
echo "Desde el PC (USB): adb forward tcp:8022 tcp:8022"
echo "  ssh -i %USERPROFILE%\\.ssh\\realme_gt2_termux -p 8022 -o StrictHostKeyChecking=accept-new $(whoami)@127.0.0.1"
