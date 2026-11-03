#!/data/data/com.termux/files/usr/bin/sh
# Referencia: aplicar modo tras boot (alternativa a fin de start-services).
# Por defecto el repo integra esto en boot/start-services.
# Copia manual solo si quieres script separado en ~/.termux/boot/
sleep 20
export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"
if [[ -x "${HOME}/bin/mode" ]]; then
  bash "${HOME}/bin/mode" apply "${TERMUX_DEFAULT_MODE:-idle}" || true
fi
