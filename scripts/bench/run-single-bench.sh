#!/system/bin/sh
# One llama-bench run; log path is $1, model $2, threads $3
LOG="$1"
MODEL="$2"
T="$3"
export LD_LIBRARY_PATH=/data/local/tmp/llama
cd /data/local/tmp/llama || exit 1

{
  echo "START $(date -Iseconds)"
  echo "model=$MODEL threads=$T"
  tb=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_before=$tb"
  grep MemAvailable /proc/meminfo
  timeout 600 ./llama-bench -m "$MODEL" -r 3 -ngl 0 -p 512 -n 128 -t "$T" -o md
  ec=$?
  ta=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_after=$ta"
  echo "bench_exit=$ec"
  echo "BENCH_DONE $(date -Iseconds)"
} >"$LOG" 2>&1
