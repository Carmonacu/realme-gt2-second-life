#!/system/bin/sh
# Part 2: finish 3B models (skip t=6 — hung >44min on SmolLM3 tg128)
export LD_LIBRARY_PATH=/data/local/tmp/llama
cd /data/local/tmp/llama || exit 1
LOG=/data/local/tmp/bench.log

append_bench() {
  model="$1"
  t="$2"
  mask="$3"
  echo "=== $(date -Iseconds) model=$(basename "$model") threads=$t mask=$mask ===" >> "$LOG"
  t0=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_before=$t0" >> "$LOG"
  if [ -n "$mask" ]; then
    taskset "$mask" ./llama-bench -m "$model" -r 3 -ngl 0 -p 512 -n 128 -t "$t" -o md >> "$LOG" 2>&1
  else
    ./llama-bench -m "$model" -r 3 -ngl 0 -p 512 -n 128 -t "$t" -o md >> "$LOG" 2>&1
  fi
  t1=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
  echo "temp_after=$t1 delta=$((t1 - t0))" >> "$LOG"
  sleep 60
}

SMOL=/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf
QWEN=/data/local/tmp/models/qwen2.5-3b-instruct-q4_k_m.gguf
PHI=/data/local/tmp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf

echo "## PART2 resume" >> "$LOG"
append_bench "$SMOL" 8 ""
append_bench "$SMOL" 4 f0
for t in 2 3 4 8; do append_bench "$QWEN" "$t" ""; done
append_bench "$QWEN" 4 f0
for t in 2 3 4 8; do append_bench "$PHI" "$t" ""; done
append_bench "$PHI" 4 f0

echo "=== llama-cli peak RSS SmolLM3 c4096 t4 ===" >> "$LOG"
./llama-cli -m "$SMOL" -c 4096 -t 4 -ngl 0 -n 48 -p "Resume en espanol que es un pentest." --no-display-prompt 2>>"$LOG" &
PID=$!
sleep 3
grep -E 'VmHWM|VmRSS' "/proc/$PID/status" >> "$LOG" 2>/dev/null
wait "$PID" 2>/dev/null

echo "=== sustained tg SmolLM3 n=1024 t=4 (~4-5 min) ===" >> "$LOG"
t0=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
./llama-bench -m "$SMOL" -r 1 -ngl 0 -p 512 -n 1024 -t 4 -o md >> "$LOG" 2>&1
t1=$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9')
echo "sustained temp $t0 -> $t1" >> "$LOG"
echo "DONE $(date -Iseconds)" >> "$LOG"
