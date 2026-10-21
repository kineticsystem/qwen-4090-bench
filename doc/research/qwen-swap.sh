#!/bin/bash
# llama-swap in front of every Qwen3.8-27B server of this folder, on
# http://127.0.0.1:8085/v1: a request names the model (azllm, azllm-256k, ninfer-long,
# ninfer-precise, ninfer-fast, openjet, baseline) and llama-swap starts that server,
# stopping the one that was running. The configuration is llama-swap/config.yaml.
#
# Usage: ./qwen-swap.sh start | stop | logs | status
# LLAMA_SWAP selects the llama-swap binary (default ~/scripts/llama-swap).
cd "$(dirname "$0")"
BIN=${LLAMA_SWAP:-$HOME/scripts/llama-swap}
LISTEN=127.0.0.1:8085
PIDFILE=results/llama-swap.pid
LOG=results/llama-swap.log
running() { [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) 2>/dev/null; }
case "${1:-start}" in
  start)
    running && { echo "llama-swap already running on http://$LISTEN/v1"; exit 0; }
    nohup "$BIN" -config llama-swap/config.yaml -listen $LISTEN >> $LOG 2>&1 &
    echo $! > $PIDFILE
    for i in $(seq 1 20); do curl -sf http://$LISTEN/v1/models >/dev/null && break; sleep 0.5; done
    if running; then echo "llama-swap on http://$LISTEN/v1 (log: $LOG)"; else echo "llama-swap failed:"; tail -5 $LOG; exit 1; fi ;;
  stop)
    running && kill $(cat $PIDFILE)
    rm -f $PIDFILE
    # The servers it started, in case it did not stop them itself.
    docker stop -t 20 qwen-azllm qwen-ninfer qwen-openjet qwen-baseline >/dev/null 2>&1
    echo "llama-swap stopped" ;;
  logs) tail -f $LOG ;;
  status) running && { echo "llama-swap running"; curl -s http://$LISTEN/running; echo; } || echo "llama-swap not running" ;;
  *) echo "unknown command: $1"; exit 1 ;;
esac
