# Realme GT2 server — zsh mínimo (sin OMZ)
export PATH="$HOME/bin:$PREFIX/bin:$PATH"
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-nano}"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=3000
SAVEHIST=3000
setopt HIST_IGNORE_ALL_DUPS INC_APPEND_HISTORY SHARE_HISTORY

# Sesiones interactivas largas (igual que ~/.bashrc)
termux-wake-lock 2>/dev/null || true

# --- Completion (pkg zsh + zsh-completions) ---
setopt AUTO_MENU COMPLETE_IN_SHELL ALWAYS_TO_END
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:*:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:ssh:*' hosts $(grep -h '^Host ' "$HOME/.ssh/config" 2>/dev/null | awk '{print $2}' | grep -v '\*')

fpath=("$PREFIX/share/zsh/site-functions" "${fpath[@]}")
autoload -Uz compinit bashcompinit
setopt extendedglob
bashcompinit 2>/dev/null
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

_mode() {
  local -a cmds
  cmds=(status llm idle pentest media light-stack lab gaming apply help)
  _describe 'mode' cmds
}
compdef _mode mode 2>/dev/null

_media_stack() {
  local -a cmds
  cmds=(start stop status help)
  _describe 'media-stack' cmds
}
compdef _media_stack media-stack 2>/dev/null

PROMPT='%F{cyan}gt2%f %~ %# '
