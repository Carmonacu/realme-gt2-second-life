#!/data/data/com.termux/files/usr/bin/bash
# OnePlus 15 (mando) — Oh My Zsh + plugins + ~/.zshrc + ~/.ssh/config (Host gt2)
# Run once in Termux on the REMOTE phone (not on Realme):
#   bash install-oneplus-zsh.sh
# Prereqs: pkg install zsh git openssh; Oh My Zsh already installed; Tailscale + pubkey on Realme.

set -euo pipefail

GT2_TAILSCALE_IP="${GT2_TAILSCALE_IP:-}"
GT2_SSH_USER="${GT2_SSH_USER:-u0_aNNN}"
GT2_SSH_PORT="${GT2_SSH_PORT:-8022}"
GT2_IDENTITY="${GT2_IDENTITY:-$HOME/.ssh/id_ed25519_gt2}"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Error: instala Oh My Zsh primero." >&2
  exit 1
fi

if [[ -z "$GT2_TAILSCALE_IP" ]]; then
  echo "Error: export GT2_TAILSCALE_IP (Tailscale IPv4 del Realme: tailscale ip -4 en el GT2)." >&2
  exit 1
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

clone_plugin() {
  local repo="$1" dir="$2"
  if [[ -d "$dir" ]]; then
    echo "  ok: $(basename "$dir")"
  else
    echo "  clone: $(basename "$dir")"
    git clone --depth 1 "$repo" "$dir"
  fi
}

echo "==> Plugins custom (OMZ no los trae)"
clone_plugin https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_plugin https://github.com/zsh-users/zsh-history-substring-search.git \
  "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

echo "==> ~/.zshrc"
cp -a "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat >"$HOME/.zshrc" <<'ZSHRC'
# Termux (OnePlus mando) — Oh My Zsh + GT2 remote

export ZSH="$HOME/.oh-my-zsh"

# Agnoster needs a Nerd Font / powerline font in Termux (Settings → font).
# If glyphs break: ZSH_THEME="robbyrussell"
ZSH_THEME="agnoster"

# Faster git prompt on slow storage
DISABLE_UNTRACKED_FILES_DIRTY="true"

# zsh-syntax-highlighting MUST be last in this list
plugins=(
  git
  ssh
  command-not-found
  history-substring-search
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# --- Locale (Termux: pkg install locales; optional es_ES) ---
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-nano}"

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS INC_APPEND_HISTORY SHARE_HISTORY

# history-substring-search (after OMZ)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Hide user@host prefix in agnoster (cleaner on phone)
prompt_context() {}

# --- Termux helpers ---
alias tx-update='pkg update && pkg upgrade -y'
alias tx-reload='exec zsh'

# --- Realme GT2 (requires ~/.ssh/config Host gt2) ---
gt2-status()   { ssh gt2 '~/bin/mode status'; }
gt2-media()    { ssh gt2 '~/bin/mode media && ~/bin/media-stack start'; }
gt2-media-off(){ ssh gt2 '~/bin/media-stack stop'; }
gt2-llm()      { ssh gt2 '~/bin/mode llm'; }
gt2-idle()     { ssh gt2 '~/bin/mode idle'; }
gt2-gaming()   { ssh gt2 '~/bin/mode gaming'; }
gt2-portal() {
  local url="http://GT2_TAILSCALE_IP_PLACEHOLDER:8081/"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$url"
  else
    echo "Portal: $url"
  fi
}
ZSHRC

# Inject Tailscale IP into gt2-portal (sed safe on Termux)
sed -i "s/GT2_TAILSCALE_IP_PLACEHOLDER/${GT2_TAILSCALE_IP}/g" "$HOME/.zshrc"

echo "==> ~/.ssh/config (Host gt2)"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [[ -f "$HOME/.ssh/config" ]] && grep -q '^Host gt2' "$HOME/.ssh/config" 2>/dev/null; then
  echo "  ya existe Host gt2 — no sobrescribo"
else
  {
    echo "# Realme GT2 Termux (auto install-oneplus-zsh.sh)"
    echo "Host gt2"
    echo "  HostName ${GT2_TAILSCALE_IP}"
    echo "  Port ${GT2_SSH_PORT}"
    echo "  User ${GT2_SSH_USER}"
    echo "  IdentityFile ${GT2_IDENTITY}"
    echo "  IdentitiesOnly yes"
    echo "  ServerAliveInterval 30"
    echo "  ServerAliveCountMax 4"
    echo "  StrictHostKeyChecking accept-new"
  } >>"$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  echo "  añadido Host gt2"
fi

echo ""
echo "Listo. Ejecuta: exec zsh"
echo "Prueba:        ssh gt2 echo ok && gt2-status"
echo ""
echo "Fuente agnoster: pkg install termux-style  (o elige fuente Nerd en ajustes Termux)"
