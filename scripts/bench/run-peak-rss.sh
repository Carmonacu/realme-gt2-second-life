#!/system/bin/sh
# Peak VmHWM monitor for llama-cli; args: LOG MODEL THREADS NTOK PROMPT
LOG="$1"
MODEL="$2"
T="$3"
NTOK="${4:-64}"
PROMPT="${5:-Hola}"
export LD_LIBRARY_PATH=/data/local/tmp/llama
cd /data/local/tmp/llama || exit 1

{
  echo "START $(date -Iseconds)"
  echo "model=$MODEL threads=$T ctx=4096 n=$NTOK"
  tb=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_before=$tb"
  echo "=== mem before ==="
  grep -E 'MemAvailable|MemFree' /proc/meminfo
  ./llama-cli -m "$MODEL" -c 4096 -t "$T" -ngl 0 -n "$NTOK" -p "$PROMPT" --no-display-prompt 2>&1 &
  PID=$!
  echo "cli_pid=$PID"
  PEAK=0
  while kill -0 "$PID" 2>/dev/null; do
    if [ -f "/proc/$PID/status" ]; then
      hwm=$(grep '^VmHWM:' "/proc/$PID/status" | awk '{print $2}')
      rss=$(grep '^VmRSS:' "/proc/$PID/status" | awk '{print $2}')
      echo "sample VmHWM=${hwm}kB VmRSS=${rss}kB"
      if [ -n "$hwm" ] && [ "$hwm" -gt "$PEAK" ] 2>/dev/null; then
        PEAK=$hwm
      fi
    fi
    sleep 1
  done
  wait "$PID" 2>/dev/null
  ec=$?
  if [ -f "/proc/$PID/status" ]; then
    grep -E '^VmHWM:|^VmRSS:' "/proc/$PID/status"
  fi
  echo "peak_VmHWM_kB=$PEAK"
  echo "=== mem after ==="
  grep -E 'MemAvailable|MemFree' /proc/meminfo
  ta=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_after=$ta"
  echo "cli_exit=$ec"
  echo "BENCH_DONE $(date -Iseconds)"
} >"$LOG" 2>&1
