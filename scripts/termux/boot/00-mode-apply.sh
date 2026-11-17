#!/data/data/com.termux/files/usr/bin/bash
# Referencia: aplicar modo tras boot (alternativa a fin de start-services).
# Por defecto el repo integra esto en boot/start-services.
# Copia manual solo si quieres script separado en ~/.termux/boot/
sleep 20
export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"
if [[ -x "${HOME}/bin/mode" ]]; then
  target="${TERMUX_DEFAULT_MODE:-media}"
  if [[ -f "${HOME}/bin/mode-lib.sh" ]]; then
    # shellcheck source=/dev/null
    . "${HOME}/bin/mode-lib.sh"
    target="$(mode_boot_target)"
  fi
  bash "${HOME}/bin/mode" apply "$target" || true
fi