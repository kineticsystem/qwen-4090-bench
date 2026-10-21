# Shared by the qwen-*.sh launchers: one server at a time, on port 8084 unless --port says
# otherwise (llama-swap gives each model a port of its own).
PORT=8084
ALL=(qwen-fast qwen-ninfer qwen-openjet qwen-baseline qwen-azllm)
SNAP=$HOME/.cache/huggingface/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502

# Stop every launcher's container: they all want the GPU and the port. Then wait until
# the port is free, TIME_WAIT included: NInfer cannot bind a port with connections still
# closing ("cannot bind 0.0.0.0:8084"), which takes up to a minute after a server stops.
stop_all() {
  docker rm -f "${ALL[@]}" >/dev/null 2>&1
  local i
  for i in $(seq 1 90); do
    ss -tan | grep -q ":$PORT " || break
    [ $i = 1 ] && echo "waiting for port $PORT to be released..."
    sleep 1
  done
  sleep 2
}

# Wait until the server answers, or show why not.
wait_ready() {
  local name=$1 i
  for i in $(seq 1 200); do
    curl -sf localhost:$PORT/health >/dev/null && { echo "$name ready on http://localhost:$PORT/v1"; return 0; }
    docker ps -q -f name=^$name\$ | grep -q . || break
    sleep 3
  done
  echo "$name did not start:"; docker logs --tail 5 $name 2>&1; return 1
}

# start | run | stop | logs, for the container $1; returns when the caller should start it.
# `run` keeps the server in the foreground, for llama-swap, which starts and stops it.
handle_command() {
  case "$2" in
    stop) docker rm -f $1 >/dev/null 2>&1; echo "$1 stopped"; exit 0 ;;
    logs) docker logs -f $1; exit 0 ;;
    start) FOREGROUND=0; return 0 ;;
    run) FOREGROUND=1; return 0 ;;
    *) echo "unknown command: $2"; exit 1 ;;
  esac
}

# Start the server's container $1 with the docker run arguments that follow: detached for
# `start`, then wait until it answers; in the foreground for `run`, removed when it exits.
docker_run() {
  local name=$1; shift
  [ "$FOREGROUND" = 1 ] && exec docker run --rm --init --name $name "$@"
  docker run -d --name $name "$@" >/dev/null && wait_ready $name
}
