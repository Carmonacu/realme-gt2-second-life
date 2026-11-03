#!/system/bin/sh
# On-device benchmark runner (adb shell, no root)
export LD_LIBRARY_PATH=/data/local/tmp/llama
cd /data/local/tmp/llama || exit 1
LOG=/data/local/tmp/bench.log
: > "$LOG"

battery_temp() {
  dumpsys battery | grep temperature | head -1 | tr -dc '0-9'
}

mem_avail_kb() {
  grep MemAvailable /proc/meminfo | tr -dc '0-9'
}

run_bench() {
  model="$1"
  t="$2"
  extra="$3"
  echo "=== $(date -Iseconds) model=$(basename "$model") threads=$t $extra ===" >> "$LOG"
  if [ "$(mem_avail_kb)" -lt 600000 ]; then
    echo "ABORT low memory" >> "$LOG"
    return 1
  fi
  t0=$(battery_temp)
  echo "temp_before=$t0" >> "$LOG"
  if [ -n "$extra" ]; then
    taskset "$extra" ./llama-bench -m "$model" -r 3 -ngl 0 -p 512 -n 128 -t "$t" -o md >> "$LOG" 2>&1
  else
    ./llama-bench -m "$model" -r 3 -ngl 0 -p 512 -n 128 -t "$t" -o md >> "$LOG" 2>&1
  fi
  t1=$(battery_temp)
  echo "temp_after=$t1 delta=$((t1 - t0))" >> "$LOG"
}

MODELS="
/data/local/tmp/models/qwen2.5-0.5b-instruct-q4_k_m.gguf
/data/local/tmp/models/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf
/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf
/data/local/tmp/models/qwen2.5-3b-instruct-q4_k_m.gguf
/data/local/tmp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf
"

for m in $MODELS; do
  [ -f "$m" ] || continue
  echo "## MODEL $(basename "$m")" >> "$LOG"
  for t in 2 3 4 8; do
    run_bench "$m" "$t" ""
  done
  # Skip t=6 on 3B+ — observed tg128 hang >44min on SmolLM3 (see docs/benchmarks/rmx3311-llm.md)
  # big cores only (CPU4-7): mask 0xF0
  run_bench "$m" 4 "f0"
  echo "cooldown 75s" >> "$LOG"
  sleep 75
done

# Peak RSS sanity (best quality 3B @ t=4)
CLI_MODEL=/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf
echo "=== llama-cli peak RSS test ===" >> "$LOG"
./llama-cli -m "$CLI_MODEL" -c 4096 -t 4 -ngl 0 -n 32 -p "Hola" --no-display-prompt 2>>"$LOG" &
PID=$!
sleep 2
if [ -f "/proc/$PID/status" ]; then
  grep -E 'VmHWM|VmRSS' "/proc/$PID/status" >> "$LOG"
fi
wait "$PID" 2>/dev/null

# Sustained thermal: SmolLM3 tg ~5 min target
echo "=== sustained tg thermal SmolLM3 ===" >> "$LOG"
t0=$(battery_temp)
./llama-bench -m "$CLI_MODEL" -r 1 -ngl 0 -p 512 -n 2048 -t 4 -o md >> "$LOG" 2>&1
t1=$(battery_temp)
echo "sustained temp $t0 -> $t1" >> "$LOG"
echo "DONE $(date -Iseconds)" >> "$LOG"
