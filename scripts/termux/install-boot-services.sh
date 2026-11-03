#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot + termux-services (runit) — SSH al arrancar el teléfono.
# Ejecutar en Termux (tras ssh-setup.sh y bootstrap si usas LLM):
#   bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
# Opt-in LLM en boot (RAM ~3+ GiB): añade --enable-llama-smol
# Opt-in energía: --enable-charge-limiter (enchufe vía MQTT/Node-RED) · --enable-thermal-guard
set -euo pipefail

SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
if [[ ! -f "${SETUP_DIR}/boot/start-services" && -f "${SETUP_DIR}/termux/boot/start-services" ]]; then
  SETUP_DIR="${SETUP_DIR}/termux"
fi
BOOT_SRC="${SETUP_DIR}/boot/start-services"
BOOT_DST="${HOME}/.termux/boot/start-services"
SVC_LLAMA_SRC="${SETUP_DIR}/services/llama-smol/run"
SVC_LLAMA_DST="${PREFIX}/var/service/llama-smol"
ENABLE_LLAMA=0
ENABLE_CHARGE=0
ENABLE_THERMAL=0

usage() {
  cat <<'EOF'
Uso: install-boot-services.sh [--enable-llama-smol] [--enable-charge-limiter] [--enable-thermal-guard]

Instala termux-services, habilita sshd (runit) y copia el script Termux:Boot.

Requisitos manuales (no automatizables desde Termux):
  1. F-Droid: Termux:Boot (misma firma que Termux F-Droid)
  2. Abrir Termux:Boot una vez desde el launcher
  3. ColorOS: sin optimización de batería para Termux y Termux:Boot

Por defecto NO arranca llama-server al boot (--enable-llama-smol para opt-in).
  En modo router (LLM_SERVER_MODE, ~/.llm.conf) solo ocupa RAM al recibir peticiones.

Energía (opt-in; requieren app Termux:API de F-Droid + pkg termux-api jq):
  --enable-charge-limiter  Publica batería en Mosquitto y pide ON/OFF al enchufe (Node-RED).
                           Mantiene mosquitto + node-red activos también en «mode idle».
  --enable-thermal-guard   Reduce hilos / congela / para el LLM si la batería pasa de ~40 °C.
  Config: ~/.config/gt2-power/power.conf (se crea desde power.conf.example)

Reversible: bash ~/storage/shared/Download/llm-setup/uninstall-boot-services.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-llama-smol) ENABLE_LLAMA=1; shift ;;
    --enable-charge-limiter) ENABLE_CHARGE=1; shift ;;
    --enable-thermal-guard) ENABLE_THERMAL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$BOOT_SRC" ]]; then
  echo "Error: no existe $BOOT_SRC" >&2
  echo "Desde el PC: adb push scripts/termux → /sdcard/Download/llm-setup/" >&2
  echo "  o: .\\scripts\\windows\\push-termux-boot.ps1" >&2
  exit 1
fi

echo "==> Paquetes (termux-services + openssh)..."
pkg install -y termux-services openssh
if [[ "$ENABLE_CHARGE" == "1" || "$ENABLE_THERMAL" == "1" ]]; then
  echo "==> Paquetes energía (termux-api jq mosquitto)..."
  pkg install -y termux-api jq mosquitto
fi

export SVDIR="${PREFIX}/var/service"
if [[ ! -d "$SVDIR" ]]; then
  echo "Error: SVDIR=$SVDIR no existe tras instalar termux-services." >&2
  exit 1
fi

# runsvdir only starts after start-services.sh (Termux:Boot or manual . profile)
if [[ -f "${PREFIX}/etc/profile.d/start-services.sh" ]]; then
  # shellcheck source=/dev/null
  . "${PREFIX}/etc/profile.d/start-services.sh"
  sleep 1
fi

echo "==> Habilitar sshd (runit, autostart con start-services.sh)..."
enable_sshd() {
  rm -f "$SVDIR/sshd/down" 2>/dev/null || true
  if [[ -x "${PREFIX}/bin/sv-enable" ]]; then
    sv-enable sshd 2>/dev/null || sv up sshd 2>/dev/null || true
  else
    sv up sshd 2>/dev/null || true
  fi
  if ! pgrep -x sshd >/dev/null 2>&1; then
    sshd 2>/dev/null || true
  fi
}
enable_sshd

echo "==> Script Termux:Boot → $BOOT_DST"
mkdir -p "${HOME}/.termux/boot"
cp -f "$BOOT_SRC" "$BOOT_DST"
chmod +x "$BOOT_DST"

MODE_BOOT="${SETUP_DIR}/boot/00-mode-apply.sh"
[[ -f "${SETUP_DIR}/termux/boot/00-mode-apply.sh" ]] && MODE_BOOT="${SETUP_DIR}/termux/boot/00-mode-apply.sh"
if [[ -f "$MODE_BOOT" ]]; then
  echo "==> Referencia boot/00-mode-apply.sh (opcional; por defecto integrado en start-services)"
fi

echo "==> mode + LLM router + energía → ~/bin"
mkdir -p "${HOME}/bin"
for mf in mode mode-lib.sh llm llm-common.sh run-router.sh run-qwen3b-spec.sh portal-status.sh \
  power-lib.sh charge-limiter thermal-guard; do
  msrc="${SETUP_DIR}/${mf}"
  [[ -f "${SETUP_DIR}/termux/${mf}" ]] && msrc="${SETUP_DIR}/termux/${mf}"
  if [[ -f "$msrc" ]]; then
    cp -f "$msrc" "${HOME}/bin/${mf}"
    chmod +x "${HOME}/bin/${mf}" 2>/dev/null || true
  fi
done

# Plantillas de config (no se sobrescriben)
cfg_src() { if [[ -f "${SETUP_DIR}/termux/$1" ]]; then echo "${SETUP_DIR}/termux/$1"; else echo "${SETUP_DIR}/$1"; fi; }
POWER_CONF_DST="${HOME}/.config/gt2-power/power.conf"
if [[ ! -f "$POWER_CONF_DST" && -f "$(cfg_src power.conf.example)" ]]; then
  mkdir -p "$(dirname "$POWER_CONF_DST")"
  cp "$(cfg_src power.conf.example)" "$POWER_CONF_DST"
  echo "    creado $POWER_CONF_DST (umbrales 80 %/45 %, 40 °C)"
fi
[[ -f "$(cfg_src llm.conf.example)" ]] && cp -f "$(cfg_src llm.conf.example)" "${HOME}/.llm.conf.example"

# install_power_svc <nombre> <habilitar 0|1>
install_power_svc() {
  local name="$1" enable="$2" src="${SETUP_DIR}/services/$1/run" dst="${SVDIR}/$1"
  [[ -f "$src" ]] || src="${SETUP_DIR}/termux/services/$1/run"
  [[ -f "$src" ]] || { echo "    omitido $name (no hay services/$name/run)"; return 0; }
  mkdir -p "$dst"
  cp -f "$src" "$dst/run"
  chmod +x "$dst/run"
  if [[ "$enable" == "1" ]]; then
    sv-enable "$name" 2>/dev/null || { rm -f "$dst/down"; sv up "$name" 2>/dev/null || true; }
    echo "    $name habilitado (sv status $name)"
  else
    sv-disable "$name" 2>/dev/null || touch "$dst/down"
    echo "    $name deshabilitado (opt-in: --enable-$name)"
  fi
}

echo "==> Energía: charge-limiter / thermal-guard (runit)"
install_power_svc charge-limiter "$ENABLE_CHARGE"
install_power_svc thermal-guard "$ENABLE_THERMAL"
if [[ "$ENABLE_CHARGE" == "1" ]]; then
  for dep in mosquitto node-red; do
    if [[ -d "${SVDIR}/${dep}" ]]; then
      rm -f "${SVDIR}/${dep}/down"
      sv up "$dep" 2>/dev/null || true
    else
      echo "    AVISO: falta servicio $dep — ejecuta install-optional-services.sh y repite." >&2
    fi
  done
  echo "    Node-RED: importa node-red/charge-limiter-flow.json (http://127.0.0.1:1880 → Import) y ajusta PLUG_TYPE."
fi
if [[ "$ENABLE_CHARGE" == "1" || "$ENABLE_THERMAL" == "1" ]]; then
  if ! timeout 20 termux-battery-status >/dev/null 2>&1; then
    echo "    AVISO: termux-battery-status no responde — instala/abre la app Termux:API (F-Droid)." >&2
  fi
fi

if [[ -f "$SVC_LLAMA_SRC" ]]; then
  echo "==> Definición runit llama-smol (opt-in)..."
  mkdir -p "$SVC_LLAMA_DST"
  cp -f "$SVC_LLAMA_SRC" "$SVC_LLAMA_DST/run"
  chmod +x "$SVC_LLAMA_DST/run"
  if [[ "$ENABLE_LLAMA" == "1" ]]; then
    echo "    AVISO: modo single: SmolLM3 al boot consume ~3 GiB RAM (router: solo al usarlo)."
    sv-enable llama-smol 2>/dev/null || { rm -f "$SVC_LLAMA_DST/down"; sv up llama-smol; }
  else
    sv-disable llama-smol 2>/dev/null || touch "$SVC_LLAMA_DST/down"
    echo "    llama-smol deshabilitado (sv-enable llama-smol para activar)."
  fi
fi

echo ""
echo "==> Comprobación local (sin reiniciar el teléfono)..."
if command -v sv >/dev/null 2>&1; then
  sv status sshd 2>/dev/null || true
fi
pgrep -x sshd >/dev/null && echo "sshd: proceso activo" || echo "sshd: no visible (normal hasta boot o start-services)"

echo ""
echo "Listo."
echo "  Termux:Boot: instala/abre la app F-Droid y reinicia el teléfono para probar."
echo "  Tras reboot: adb forward tcp:8022 tcp:8022 && ssh … 'pgrep -x sshd && sv status sshd'"
echo "  Modo boot: TERMUX_DEFAULT_MODE=idle (LLM manual: mode llm). Ver docs/service-modes-design.md"
echo "  Opcional: bash ~/storage/shared/Download/llm-setup/install-optional-services.sh"
echo "  Portal:   bash ~/storage/shared/Download/llm-setup/install-portal.sh"
echo "  Guía: docs/termux-boot-services.md (repo PC)"
