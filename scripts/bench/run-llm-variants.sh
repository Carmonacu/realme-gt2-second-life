#!/data/data/com.termux/files/usr/bin/bash
# Benchmark en el teléfono (Termux, sin root): baseline vs KV q8_0 vs especulativa.
#   Parte A (llama-bench): Qwen2.5-3B pp512/tg128 a profundidad 0 y 2048 — f16 vs fa on vs KV q8_0
#   Parte B (llama-server /completion, greedy): base · kv-q8 · spec (borrador 0.5B) · spec+kv-q8
# Logs: un fichero por variante + summary.md en ~/storage/shared/Download/llm-bench-runs/<ts>-llm-variants/
# PC: adb pull /sdcard/Download/llm-bench-runs/. docs/benchmarks/runs/
# Uso: bash run-llm-variants.sh [--threads 4] [--ctx 4096] [--n-predict 128] [--reps 3]
#        [--skip-bench] [--skip-server] [--stop-llm] [--cooldown 60]
set -euo pipefail
export PATH="${HOME}/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:${PATH}"

THREADS=4
CTX=4096
NPRED=128
REPS=3
COOLDOWN=60
PORT=8079
SKIP_BENCH=0
SKIP_SERVER=0
STOP_LLM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="$2"; shift 2 ;;
    --ctx) CTX="$2"; shift 2 ;;
    --n-predict) NPRED="$2"; shift 2 ;;
    --reps) REPS="$2"; shift 2 ;;
    --cooldown) COOLDOWN="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --skip-bench) SKIP_BENCH=1; shift ;;
    --skip-server) SKIP_SERVER=1; shift ;;
    --stop-llm) STOP_LLM=1; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done

COMMON="$HOME/bin/llm-common.sh"
[[ -f "$COMMON" ]] || COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../termux" 2>/dev/null && pwd)/llm-common.sh"
# shellcheck source=../termux/llm-common.sh
source "$COMMON"
llm_resolve_server || exit 1
LLAMA_BENCH="$(dirname "$LLAMA_SERVER")/llama-bench"
command -v jq >/dev/null 2>&1 || { echo "Error: falta jq (pkg install jq)" >&2; exit 1; }

TARGET="$(llm_model_path qwen3b)"
DRAFT="$(llm_model_path qwen05)"
llm_check_model "$TARGET" || exit 1
llm_check_model "$DRAFT" || exit 1

if pgrep -f '/llama-server' >/dev/null 2>&1; then
  if [[ "$STOP_LLM" == "1" ]]; then
    pkill -CONT -f '/llama-server' 2>/dev/null || true
    pkill -f '/llama-server' 2>/dev/null || true
    sleep 3
  else
    echo "Error: llama-server activo (contaminaría la medida). Usa: mode idle  o  --stop-llm" >&2
    exit 1
  fi
fi

TS="$(date +%Y%m%d-%H%M%S)"
OUT="${BENCH_OUT:-${HOME}/storage/shared/Download/llm-bench-runs}/${TS}-llm-variants"
mkdir -p "$OUT"
SUMMARY="$OUT/summary.md"

battery_temp() {
  local t=""
  if command -v termux-battery-status >/dev/null 2>&1; then
    t="$(timeout 20 termux-battery-status 2>/dev/null | jq -r '.temperature // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$t" && -r /sys/class/power_supply/battery/temp ]]; then
    t="$(awk '{ printf "%.1f", $1 / 10 }' /sys/class/power_supply/battery/temp 2>/dev/null || true)"
  fi
  echo "${t:-NA}"
}
mem_avail_kb() { awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo; }

cooldown() {
  echo "cooldown ${COOLDOWN}s (temp $(battery_temp) °C)"
  sleep "$COOLDOWN"
}

termux-wake-lock 2>/dev/null || true
trap 'termux-wake-unlock 2>/dev/null || true' EXIT

{
  echo "# LLM variants — $(date -Iseconds)"
  echo ""
  echo "- Dispositivo: RMX3311 · $("$LLAMA_SERVER" --version 2>&1 | grep -m1 version || echo '?')"
  echo "- Objetivo: $(basename "$TARGET") · borrador: $(basename "$DRAFT") · -t ${THREADS} · ctx ${CTX}"
  echo "- MemAvailable inicio: $(mem_avail_kb) kB · batería $(battery_temp) °C"
  echo ""
} >"$SUMMARY"

# ---------- Parte A: llama-bench ----------
if [[ "$SKIP_BENCH" == "0" ]]; then
  echo "## A. llama-bench (pp512 / tg128, -r ${REPS}, depth 0 y 2048)" >>"$SUMMARY"
  echo "" >>"$SUMMARY"
  for variant in base fa-on kv-q8; do
    case "$variant" in
      base)  extra=() ;;
      fa-on) extra=(-fa 1) ;;
      kv-q8) extra=(-fa 1 -ctk q8_0 -ctv q8_0) ;;
    esac
    LOG="$OUT/bench-${variant}.log"
    echo "==> llama-bench $variant"
    {
      echo "START $(date -Iseconds)"
      echo "model=$TARGET threads=$THREADS variant=$variant args=${extra[*]:-}"
      echo "temp_before=$(battery_temp)"
      grep MemAvailable /proc/meminfo
      set +e
      timeout 1800 "$LLAMA_BENCH" -m "$TARGET" -r "$REPS" -ngl 0 -p 512 -n 128 -d 0,2048 -t "$THREADS" \
        "${extra[@]}" -o md
      ec=$?
      set -e
      echo "temp_after=$(battery_temp)"
      echo "bench_exit=$ec"
      echo "BENCH_DONE $(date -Iseconds)"
    } >"$LOG" 2>&1
    {
      echo "### $variant (\`${extra[*]:-defecto}\`)"
      echo ""
      grep -E '^\|' "$LOG" || echo "(sin tabla — ver $(basename "$LOG"))"
      echo ""
    } >>"$SUMMARY"
    cooldown
  done
fi

# ---------- Parte B: llama-server ----------
PROMPTS=(
  "Escribe una función en Python que devuelva los n primeros números primos, con docstring."
  "Explica en cinco frases qué es la decodificación especulativa en modelos de lenguaje."
  "Lista los días de la semana y los meses del año en inglés, separados por comas."
)

server_variant() {
  local variant="$1"
  shift
  local LOG="$OUT/server-${variant}.log" SLOG="$OUT/server-${variant}.stderr.log"
  echo "==> llama-server $variant"
  "$LLAMA_SERVER" -m "$TARGET" -ngl 0 -c "$CTX" -t "$THREADS" --host 127.0.0.1 --port "$PORT" \
    --metrics --no-webui "$@" >"$SLOG" 2>&1 &
  local pid=$! i ok=0 peak=0 hwm
  for i in $(seq 1 180); do
    if curl -sf -m 2 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then ok=1; break; fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  {
    echo "START $(date -Iseconds)"
    echo "variant=$variant args=$*"
    echo "temp_before=$(battery_temp)"
    grep MemAvailable /proc/meminfo
    echo "load_s=$i ready=$ok"
  } >"$LOG"
  if [[ "$ok" != "1" ]]; then
    echo "ERROR: servidor no arrancó (ver $(basename "$SLOG"))" >>"$LOG"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    echo "| $variant | ERROR | — | — | — | — |" >>"$SUMMARY"
    return 0
  fi
  local p body tg_sum=0 pp_sum=0 dn=0 da=0 n=0
  for p in "${PROMPTS[@]}"; do
    body="$(jq -nc --arg p "$p" --argjson n "$NPRED" \
      '{prompt:$p, n_predict:$n, temperature:0, top_k:1, seed:42, cache_prompt:false}')"
    local res tg pp d a
    res="$(curl -sf -m 600 -H 'Content-Type: application/json' -d "$body" "http://127.0.0.1:${PORT}/completion" || echo '{}')"
    tg="$(jq -r '.timings.predicted_per_second // 0' <<<"$res")"
    pp="$(jq -r '.timings.prompt_per_second // 0' <<<"$res")"
    d="$(jq -r '.timings.draft_n // 0' <<<"$res")"
    a="$(jq -r '.timings.draft_n_accepted // 0' <<<"$res")"
    echo "prompt=$((n + 1)) tg_tok_s=$tg pp_tok_s=$pp predicted_n=$(jq -r '.timings.predicted_n // 0' <<<"$res") draft_n=$d draft_accepted=$a" >>"$LOG"
    hwm="$(awk '/^VmHWM:/ { print $2 }' "/proc/$pid/status" 2>/dev/null || echo 0)"
    [[ "${hwm:-0}" -gt "$peak" ]] && peak="$hwm"
    tg_sum="$(awk -v a="$tg_sum" -v b="$tg" 'BEGIN { print a + b }')"
    pp_sum="$(awk -v a="$pp_sum" -v b="$pp" 'BEGIN { print a + b }')"
    dn=$((dn + d)); da=$((da + a)); n=$((n + 1))
  done
  {
    echo "--- /metrics ---"
    curl -sf -m 5 "http://127.0.0.1:${PORT}/metrics" | grep -E '^llamacpp:' || true
    echo "peak_VmHWM_kB=$peak"
    echo "temp_after=$(battery_temp)"
    echo "BENCH_DONE $(date -Iseconds)"
  } >>"$LOG"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  local acc="—"
  [[ "$dn" -gt 0 ]] && acc="$(awk -v a="$da" -v d="$dn" 'BEGIN { printf "%.0f %%", 100 * a / d }')"
  awk -v v="$variant" -v tg="$tg_sum" -v pp="$pp_sum" -v n="$n" -v acc="$acc" -v pk="$peak" \
    'BEGIN { printf "| %s | %.2f | %.2f | %s | %.2f | %s |\n", v, tg / n, pp / n, acc, pk / 1048576, n }' >>"$SUMMARY"
}

if [[ "$SKIP_SERVER" == "0" ]]; then
  {
    echo "## B. llama-server /completion (greedy, n_predict ${NPRED}, ${#PROMPTS[@]} prompts)"
    echo ""
    echo "| Variante | tg tok/s (media) | pp tok/s (media) | aceptación borrador | pico VmHWM GiB | prompts |"
    echo "|----------|------------------|------------------|---------------------|----------------|---------|"
  } >>"$SUMMARY"
  SPEC=(--model-draft "$DRAFT" --spec-type draft-simple --spec-draft-n-max "${LLM_SPEC_DRAFT_N_MAX}" \
        --spec-draft-n-min "${LLM_SPEC_DRAFT_N_MIN}" --spec-draft-p-min "${LLM_SPEC_DRAFT_P_MIN}")
  KVQ8=(--cache-type-k q8_0 --cache-type-v q8_0 --flash-attn on)
  server_variant base;          cooldown
  server_variant kv-q8 "${KVQ8[@]}"; cooldown
  server_variant spec "${SPEC[@]}"; cooldown
  server_variant spec-kv-q8 "${SPEC[@]}" "${KVQ8[@]}" --cache-type-k-draft q8_0 --cache-type-v-draft q8_0
  echo "" >>"$SUMMARY"
fi

echo "- Fin: $(date -Iseconds) · batería $(battery_temp) °C" >>"$SUMMARY"
echo ""
cat "$SUMMARY"
echo ""
echo "Logs: $OUT"
echo "PC:   adb pull /sdcard/Download/llm-bench-runs/. docs/benchmarks/runs/"
