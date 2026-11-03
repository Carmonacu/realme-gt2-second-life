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
    [[ "$line" =~ ^[[:space:]]*((POWER|CHARGE|THERMAL)_[A-Z0-9_]+)= ]] || continue
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
