#!/bin/bash
# Log temperatures every 10 s to results/thermal.log, and pause the benchmark
# containers while the GPU is at 83 C or more or the CPU at 90 C or more, until
# both are back under 75 C. Stop it with: pkill -f thermal-guard.sh
cd "$(dirname "$0")/.."
GPU_MAX=83 CPU_MAX=90 RESUME=75
docker rm -f qr-gpustats >/dev/null 2>&1
docker/run.sh qr-llama:cuda12.8 -d --name qr-gpustats -- python3 /work/bench/gpu-stats.py /work/results/.gpu-now >/dev/null
paused=0
while true; do
  read gt gp gu gf < results/.gpu-now 2>/dev/null
  ct=$(( $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1) / 1000 ))
  line="$(date +%T) gpu ${gt}C ${gp}W ${gu}% fan ${gf}% | cpu ${ct}C"
  if [ $paused = 0 ] && { [ "${gt:-0}" -ge $GPU_MAX ] || [ $ct -ge $CPU_MAX ]; }; then
    ids=$(docker ps -q --filter name=qwen- --filter name=qr-server; docker ps -q --filter ancestor=qr-llama:cuda12.8 | grep -v $(docker ps -q -f name=qr-gpustats))
    docker pause $ids >/dev/null 2>&1; paused=1; line="$line | PAUSED"
  elif [ $paused = 1 ] && [ "${gt:-0}" -lt $RESUME ] && [ $ct -lt $RESUME ]; then
    docker unpause $(docker ps -q --filter status=paused) >/dev/null 2>&1; paused=0; line="$line | RESUMED"
  fi
  echo "$line" >> results/thermal.log
  sleep 10
done
