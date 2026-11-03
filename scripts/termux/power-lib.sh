#!/data/data/com.termux/files/usr/bin/bash
# Helpers compartidos: batería, MQTT, notificaciones (charge-limiter + thermal-guard).
# Source desde ~/bin/power-lib.sh — no ejecutar directamente.
# Requiere: pkg install termux-api jq mosquitto  +  app Termux:API (F-Droid, misma firma que Termux)

export PATH="${HOME}/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:${PATH}"

POWER_CONF="${POWER_CONF:-${HOME}/.config/gt2-power/power.conf}"
# Variables ya presentes en el entorno ganan al fichero (p. ej. THERMAL_HIGH_C=30 thermal-guard once)
power_load_conf() {
  local line key
  [[ -f "$1" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*((POWER|CHARGE|THERMAL|PLUG)_[A-Z0-9_]+)= ]] || continue
    key="${BASH_REMATCH[1]}"
    [[ -n "${!key+x}" ]] && continue
    eval "$line"   # fichero propio del usuario (mismo nivel de confianza que «source»)
  done <"$1"
}
power_load_conf "$POWER_CONF"

POWER_CACHE_DIR="${POWER_CACHE_DIR:-${HOME}/.cache/gt2-power}"
POWER_LOG_FILE="${POWER_LOG_FILE:-${HOME}/storage/shared/power-guard.log}"
POWER_BATTERY_CACHE="${POWER_CACHE_DIR}/battery.json"
POWER_BATTERY_MAX_AGE="${POWER_BATTERY_MAX_AGE:-20}"     # s: reutiliza lectura reciente (evita 2 llamadas API)
POWER_API_TIMEOUT="${POWER_API_TIMEOUT:-20}"             # s: termux-battery-status cuelga si falta la app
# MQTT (Mosquitto local del repo: listener 1883 127.0.0.1, anónimo)
POWER_MQTT_HOST="${POWER_MQTT_HOST:-127.0.0.1}"
POWER_MQTT_PORT="${POWER_MQTT_PORT:-1883}"
POWER_MQTT_PREFIX="${POWER_MQTT_PREFIX:-gt2/power}"
POWER_MQTT_USER="${POWER_MQTT_USER:-}"
POWER_MQTT_PASS="${POWER_MQTT_PASS:-}"
# Enchufe controlado DIRECTAMENTE por charge-limiter vía MQTT (sin Node-RED):
#   nodered    = solo publica charger/want; el flujo Node-RED conmuta el enchufe (defecto, comportamiento v1)
#   openbeken  = OpenBeken (OpenBK7231T_App / OpenLN882H): <PLUG_TOPIC>/<PLUG_CHANNEL>/set 1|0
#   tasmota    = Tasmota: cmnd/<PLUG_TOPIC>/POWER ON|OFF · estado stat/<PLUG_TOPIC>/POWER
#   shelly-gen2 = Shelly Plus/Pro (MQTT): <PLUG_TOPIC>/command/switch:0 on|off · estado <PLUG_TOPIC>/status/switch:0
PLUG_BACKEND="${PLUG_BACKEND:-nodered}"
PLUG_TOPIC="${PLUG_TOPIC:-lspa9}"           # OpenBeken: «Client Topic» (Config → MQTT), p. ej. lspa9
PLUG_CHANNEL="${PLUG_CHANNEL:-1}"           # OpenBeken: canal del relé (pin «Rel;N»): CB2S/BK7231N = 1 · LN882H = 0
PLUG_OBK_CMD="${PLUG_OBK_CMD:-channel}"     # channel = <topic>/<canal>/set 1|0 · power = cmnd/<topic>/POWER ON|OFF
PLUG_REPLY_WAIT="${PLUG_REPLY_WAIT:-4}"     # s esperando respuesta de estado del enchufe
PLUG_POWER_WAIT="${PLUG_POWER_WAIT:-12}"    # s esperando una lectura de potencia (W)

# Notificaciones: termux-notification + hook opcional (p. ej. ntfy). El hook recibe: <título> <mensaje> <prioridad>
POWER_NOTIFY="${POWER_NOTIFY:-1}"
POWER_NOTIFY_HOOK="${POWER_NOTIFY_HOOK:-${HOME}/.config/gt2-power/notify-hook}"
POWER_NOTIFY_COOLDOWN="${POWER_NOTIFY_COOLDOWN:-1800}"  # s entre avisos repetidos de la misma clave

mkdir -p "$POWER_CACHE_DIR" 2>/dev/null || true

power_log() {
  local tag="$1"
  shift
  local line
  line="$(date -Iseconds 2>/dev/null || date) [$tag] $*"
  echo "$line" >&2
  mkdir -p "$(dirname "$POWER_LOG_FILE")" 2>/dev/null || true
  echo "$line" >>"$POWER_LOG_FILE" 2>/dev/null || true
}

power_now() { date +%s; }

power_require_jq() {
  command -v jq >/dev/null 2>&1 || { echo "Error: falta jq (pkg install jq)" >&2; return 1; }
}

# JSON normalizado: {"percentage":N,"temperature":T,"plugged":"…","status":"…","health":"…","current":N,"ts":epoch,"source":"…"}
power_battery_read_raw() {
  local raw=""
  if command -v termux-battery-status >/dev/null 2>&1; then
    raw="$(timeout "$POWER_API_TIMEOUT" termux-battery-status 2>/dev/null || true)"
    if [[ -n "$raw" ]] && jq -e '.percentage != null' >/dev/null 2>&1 <<<"$raw"; then
      jq -c --argjson ts "$(power_now)" \
        '{percentage, temperature, plugged, status, health, current, ts: $ts, source: "termux-api"}' <<<"$raw"
      return 0
    fi
  fi
  # Fallback sysfs (lectura sin root suele estar permitida; no garantizado en ColorOS)
  local ps=/sys/class/power_supply/battery cap temp st usb ac plugged="UNPLUGGED"
  [[ -r "$ps/capacity" && -r "$ps/temp" ]] || return 1
  cap="$(cat "$ps/capacity" 2>/dev/null)"
  temp="$(cat "$ps/temp" 2>/dev/null)"
  st="$(tr '[:lower:]' '[:upper:]' <"$ps/status" 2>/dev/null | tr ' ' '_')"
  usb="$(cat /sys/class/power_supply/usb/online 2>/dev/null || echo 0)"
  ac="$(cat /sys/class/power_supply/ac/online 2>/dev/null || echo 0)"
  [[ "$usb" == "1" ]] && plugged="PLUGGED_USB"
  [[ "$ac" == "1" ]] && plugged="PLUGGED_AC"
  [[ "$cap" =~ ^[0-9]+$ && "$temp" =~ ^-?[0-9]+$ ]] || return 1
  jq -nc --argjson p "$cap" --argjson t "$temp" --arg pl "$plugged" --arg st "${st:-UNKNOWN}" \
    --argjson ts "$(power_now)" \
    '{percentage: $p, temperature: ($t / 10), plugged: $pl, status: $st, health: null, current: null, ts: $ts, source: "sysfs"}'
}

# Lee batería (con caché corta compartida). Deja JSON en POWER_BATTERY y lo escribe en caché.
power_battery_read() {
  power_require_jq || return 1
  local now age=999999
  now="$(power_now)"
  if [[ -f "$POWER_BATTERY_CACHE" ]]; then
    age=$(( now - $(jq -r '.ts // 0' "$POWER_BATTERY_CACHE" 2>/dev/null || echo 0) ))
  fi
  if [[ "${1:-}" != "--fresh" && "$age" -ge 0 && "$age" -le "$POWER_BATTERY_MAX_AGE" ]]; then
    POWER_BATTERY="$(cat "$POWER_BATTERY_CACHE")"
    return 0
  fi
  POWER_BATTERY="$(power_battery_read_raw)" || { POWER_BATTERY=""; return 1; }
  [[ -n "$POWER_BATTERY" ]] || return 1
  printf '%s\n' "$POWER_BATTERY" >"${POWER_BATTERY_CACHE}.tmp.$$" && mv -f "${POWER_BATTERY_CACHE}.tmp.$$" "$POWER_BATTERY_CACHE"
}

power_bat_field() {
  jq -r ".$1 // empty" <<<"$POWER_BATTERY"
}

# Compara decimales: power_ge 40.5 40 → 0 si a >= b
power_ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 >= b + 0) }'; }
power_le() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 <= b + 0) }'; }

power_mqtt_args() {
  local -n _m="$1"
  _m=(-h "$POWER_MQTT_HOST" -p "$POWER_MQTT_PORT")
  [[ -n "$POWER_MQTT_USER" ]] && _m+=(-u "$POWER_MQTT_USER")
  [[ -n "$POWER_MQTT_PASS" ]] && _m+=(-P "$POWER_MQTT_PASS")
  return 0
}

# power_mqtt_pub <subtopic> <payload> [retain=1]
power_mqtt_pub() {
  local topic="${POWER_MQTT_PREFIX}/$1" payload="$2" retain="${3:-1}" args=()
  command -v mosquitto_pub >/dev/null 2>&1 || return 2
  power_mqtt_args args
  [[ "$retain" == "1" ]] && args+=(-r)
  timeout 10 mosquitto_pub "${args[@]}" -q 1 -t "$topic" -m "$payload" 2>/dev/null
}

# power_mqtt_get <subtopic> → último mensaje retenido (vacío si no hay / sin broker)
power_mqtt_get() {
  local topic="${POWER_MQTT_PREFIX}/$1" args=()
  command -v mosquitto_sub >/dev/null 2>&1 || return 2
  power_mqtt_args args
  timeout 6 mosquitto_sub "${args[@]}" -t "$topic" -C 1 -W 3 2>/dev/null || true
}

# power_notify <clave> <título> <mensaje> [prioridad: default|high] [--force]
power_notify() {
  local key="$1" title="$2" msg="$3" prio="${4:-default}" force="${5:-}"
  local stamp="${POWER_CACHE_DIR}/notify-${key}.last" now last=0
  now="$(power_now)"
  [[ -f "$stamp" ]] && last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [[ "$force" != "--force" && $(( now - last )) -lt "$POWER_NOTIFY_COOLDOWN" ]]; then
    return 0
  fi
  echo "$now" >"$stamp" 2>/dev/null || true
  power_log notify "$title — $msg"
  [[ "$POWER_NOTIFY" == "1" ]] || return 0
  if command -v termux-notification >/dev/null 2>&1; then
    timeout "$POWER_API_TIMEOUT" termux-notification --id "gt2-power-${key}" --title "$title" \
      --content "$msg" --priority "$prio" 2>/dev/null || true
  fi
  if [[ -x "$POWER_NOTIFY_HOOK" ]]; then
    timeout 30 "$POWER_NOTIFY_HOOK" "$title" "$msg" "$prio" >/dev/null 2>&1 || true
  fi
}

power_notify_reset() {
  rm -f "${POWER_CACHE_DIR}/notify-$1.last" 2>/dev/null || true
}

power_portal_refresh() {
  [[ "${POWER_PORTAL_REFRESH:-1}" == "1" ]] || return 0
  local ps="${HOME}/bin/portal-status.sh"
  if [[ -x "$ps" ]]; then
    bash "$ps" >/dev/null 2>&1 || true
  fi
}

# Escritura atómica: power_write_file <ruta> <contenido>
power_write_file() {
  printf '%s\n' "$2" >"$1.tmp.$$" 2>/dev/null && mv -f "$1.tmp.$$" "$1"
}

# --- Enchufe directo por MQTT (PLUG_BACKEND ≠ nodered) ---

# power_mqtt_raw_pub <topic> <payload> [retain=0] — payload vacío = mensaje nulo (-n)
power_mqtt_raw_pub() {
  local topic="$1" payload="$2" retain="${3:-0}" args=()
  command -v mosquitto_pub >/dev/null 2>&1 || return 2
  power_mqtt_args args
  [[ "$retain" == "1" ]] && args+=(-r)
  if [[ -z "$payload" ]]; then
    timeout 10 mosquitto_pub "${args[@]}" -q 1 -t "$topic" -n 2>/dev/null
  else
    timeout 10 mosquitto_pub "${args[@]}" -q 1 -t "$topic" -m "$payload" 2>/dev/null
  fi
}

# power_mqtt_request <sub_topic> <wait_s> <filtro_regex> [<pub_topic> <payload>]
# Se suscribe, (opcional) publica la petición y devuelve el primer payload que casa con el filtro.
# Ignora payloads vacíos (p. ej. nuestra propia petición «get» vacía de OpenBeken).
power_mqtt_request() {
  local sub="$1" wait="$2" re="$3" pub="${4:-}" pay="${5:-}" args=() tmp pid line=""
  command -v mosquitto_sub >/dev/null 2>&1 || return 2
  power_mqtt_args args
  tmp="$(mktemp "${POWER_CACHE_DIR}/mqreq.XXXXXX")" || return 1
  timeout "$((wait + 2))" mosquitto_sub "${args[@]}" -t "$sub" -W "$wait" >"$tmp" 2>/dev/null &
  pid=$!
  if [[ -n "$pub" ]]; then
    sleep 0.5
    power_mqtt_raw_pub "$pub" "$pay" 0 || true
  fi
  local _
  for _ in $(seq 1 "$((wait * 4))"); do
    line="$(grep -m1 -E "$re" "$tmp" 2>/dev/null || true)"
    [[ -n "$line" ]] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  [[ -n "$line" ]] || line="$(grep -m1 -E "$re" "$tmp" 2>/dev/null || true)"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$tmp"
  [[ -n "$line" ]] || return 1
  printf '%s\n' "$line"
}

power_plug_direct() { [[ "$PLUG_BACKEND" != "nodered" && "$PLUG_BACKEND" != "" ]]; }

# power_plug_set ON|OFF
power_plug_set() {
  local want="$1" on=0
  [[ "$want" == "ON" ]] && on=1
  case "$PLUG_BACKEND" in
    openbeken)
      if [[ "$PLUG_OBK_CMD" == "power" ]]; then
        # Estilo Tasmota: OpenBeken aplica POWER al primer canal con relé (indexación 0 o 1)
        power_mqtt_raw_pub "cmnd/${PLUG_TOPIC}/POWER" "$want"
      else
        power_mqtt_raw_pub "${PLUG_TOPIC}/${PLUG_CHANNEL}/set" "$on"
      fi
      ;;
    tasmota) power_mqtt_raw_pub "cmnd/${PLUG_TOPIC}/POWER" "$want" ;;
    shelly-gen2) power_mqtt_raw_pub "${PLUG_TOPIC}/command/switch:0" "$([[ $on == 1 ]] && echo on || echo off)" ;;
    nodered|"") return 0 ;;
    *) echo "PLUG_BACKEND desconocido: $PLUG_BACKEND" >&2; return 1 ;;
  esac
}

# power_plug_get → ON|OFF (rc 1 si el enchufe no responde)
power_plug_get() {
  local v
  case "$PLUG_BACKEND" in
    openbeken)
      # Publicar vacío en <topic>/<canal>/get pide al dispositivo que publique el valor del canal
      v="$(power_mqtt_request "${PLUG_TOPIC}/${PLUG_CHANNEL}/get" "$PLUG_REPLY_WAIT" '^-?[0-9]+$' \
        "${PLUG_TOPIC}/${PLUG_CHANNEL}/get" "")" || return 1
      [[ "$v" == "0" ]] && echo OFF || echo ON
      ;;
    tasmota)
      # cmnd/<topic>/POWER sin payload = consulta → stat/<topic>/POWER ON|OFF
      v="$(power_mqtt_request "stat/${PLUG_TOPIC}/POWER" "$PLUG_REPLY_WAIT" '^(ON|OFF)$' \
        "cmnd/${PLUG_TOPIC}/POWER" "")" || return 1
      echo "$v"
      ;;
    shelly-gen2)
      v="$(power_mqtt_request "${PLUG_TOPIC}/status/switch:0" "$PLUG_REPLY_WAIT" '"output"' \
        "${PLUG_TOPIC}/command/switch:0" "status_update")" || return 1
      jq -r 'if .output then "ON" else "OFF" end' <<<"$v" 2>/dev/null || return 1
      ;;
    *) return 1 ;;
  esac
}

# power_plug_watts → potencia instantánea en W (rc 1 si no hay lectura)
power_plug_watts() {
  local v
  case "$PLUG_BACKEND" in
    openbeken)
      # BL0937/BL0942 publican <topic>/power/get al cambiar (umbral) y en el broadcast periódico.
      # Además se pide con un «get» vacío (documentado para variables como led_dimmer; para power
      # no está garantizado → si no responde se espera al siguiente envío, hasta PLUG_POWER_WAIT s).
      v="$(power_mqtt_request "${PLUG_TOPIC}/power/get" "$PLUG_POWER_WAIT" '^-?[0-9]+([.][0-9]+)?$' \
        "${PLUG_TOPIC}/power/get" "")" || return 1
      echo "$v"
      ;;
    tasmota)
      v="$(power_mqtt_request "stat/${PLUG_TOPIC}/STATUS8" "$PLUG_REPLY_WAIT" 'ENERGY' \
        "cmnd/${PLUG_TOPIC}/STATUS" "8")" || return 1
      jq -r '.StatusSNS.ENERGY.Power // empty' <<<"$v" 2>/dev/null
      ;;
    shelly-gen2)
      v="$(power_mqtt_request "${PLUG_TOPIC}/status/switch:0" "$PLUG_REPLY_WAIT" '"apower"' \
        "${PLUG_TOPIC}/command/switch:0" "status_update")" || return 1
      jq -r '.apower // empty' <<<"$v" 2>/dev/null
      ;;
    *) return 1 ;;
  esac
}
