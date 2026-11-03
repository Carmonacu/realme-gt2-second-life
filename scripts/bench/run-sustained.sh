#!/system/bin/sh
# 5-minute repeated llama-bench tg128; args: LOG MODEL THREADS DURATION_SEC
LOG="$1"
MODEL="$2"
T="$3"
DUR="${4:-300}"
export LD_LIBRARY_PATH=/data/local/tmp/llama
cd /data/local/tmp/llama || exit 1

{
  echo "START $(date -Iseconds)"
  echo "model=$MODEL threads=$T duration=${DUR}s"
  tb=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_before=$tb"
  END=$(($(date +%s) + DUR))
  RUN=0
  while [ "$(date +%s)" -lt "$END" ]; do
    RUN=$((RUN + 1))
    NOW=$(date +%s)
    ELAPSED=$((NOW - (END - DUR)))
    temp=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
    echo "=== run=$RUN elapsed=${ELAPSED}s temp=$temp ==="
    ./llama-bench -m "$MODEL" -r 1 -ngl 0 -p 512 -n 128 -t "$T" -o md
  done
  ta=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_after=$ta"
  echo "total_runs=$RUN"
  echo "BENCH_DONE $(date -Iseconds)"
} >"$LOG" 2>&1
