#!/data/data/com.termux/files/usr/bin/bash
# Añade alias qprune → qbit-prune en ~/.bashrc (idempotente).
set -euo pipefail

BASHRC="${HOME}/.bashrc"
MARK='# nethunter media-stack aliases'

grep -qF "$MARK" "$BASHRC" 2>/dev/null && exit 0

cat >>"$BASHRC" <<EOF

$MARK
alias qprune='qbit-prune'
alias qprune-ns='qbit-prune --no-start'
EOF

echo "Alias añadidos: qprune, qprune-ns (source ~/.bashrc)"
