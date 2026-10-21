#!/bin/bash
# Speed (short prompts, thinking, 29K prompt) and accuracy of launcher profiles.
# Usage: bench/profile-run.sh "<label>|<launcher and its args>|<no-think style: kwargs or top>" ...
cd "$(dirname "$0")/.."
B="docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench"
for cfg in "$@"; do
  IFS='|' read -r label launcher style <<< "$cfg"
  sleep 60  # cool-down: the machine reset once during back-to-back runs
  ./$launcher | tail -1
  U="--url http://127.0.0.1:8084 --model Qwen3.8-27B --no-think $style"
  $B/bench.py $U --label "$label" --reps 2 2>&1 | grep "^== [a-z]"
  $B/bench.py $U --label "$label" --think 2>&1 | grep "^== [a-z]" | sed 's/$/ (thinking)/'
  $B/bench.py $U --label "$label-long" --long 100000 2>&1 | grep "^== [a-z]" | sed 's/$/ (29K prompt)/'
  $B/evalacc.py $U --label "$label" 2>&1 | grep -E "GSM8K|HumanEval"
  python3 bench/vision-check.py 2>&1 | sed "s/^/$label vision: /"
done
