#! /bin/bash -e

# Use this script to download, build, start, stop and remove qwen-4090-bench: llama-swap in
# front of four inference engines for Qwen3.8-27B, all in one container, qwen-4090-bench.
#
# The container is defined in docker-compose.yml. This script only adds what compose
# cannot express: the submodules, the host uid/gid, compiling the engines inside the
# container, and downloading the models.

SERVICE=qwen-4090-bench

# The engines, in ../engines, that the container builds and runs.
ENGINES=(llama.cpp llama-cpp-turboquant open-jet ninfer-4090 azllm llama-swap)

function display_usage() {
    echo -e "\nUsage: ./dock.sh <command>\n
    Commands:
    download  Clone the engines (Git submodules)
    build     Build the image, then compile every engine in the container
    models    Download the models into ../models, or into \$MODELS_DIR
    start     Start the container: llama-swap on http://127.0.0.1:8085/v1
    logs      Follow the output of llama-swap and of the model servers
    status    Show the state of the container and the model that is loaded
    shell     Open an interactive terminal into the container
    stop      Stop the container
    clean     Stop the container and remove it and its image\n"
}

function check_engines() {
    local engine
    for engine in "${ENGINES[@]}"; do
        if [ -z "$(ls -A "../engines/$engine" 2>/dev/null)" ]; then
            echo "Engine '$engine' is missing: run ./docker/dock.sh download first." >&2
            exit 1
        fi
    done
}

# Compose resolves the paths in docker-compose.yml against the directory that holds it,
# so every command has to run from there.
cd "$(dirname "$0")"

if [ "$#" -lt 1 ]; then
    echo "Missing required arguments."
    display_usage
    exit 1
fi

# Build args for the Dockerfile: a container user matching the host user.
USER_UID=$(id -u)
USER_GID=$(id -g)
export USER_UID USER_GID

case "$1" in
    download)
        git -C .. submodule update --init --recursive
        ;;
    build)
        check_engines
        docker compose build $SERVICE
        # Compile in a throw-away container of the image: the engines are in the mounted
        # repository, so what is built stays on the host.
        docker compose run --rm --no-deps $SERVICE scripts/build.sh "${@:2}"
        ;;
    models)
        mkdir -p "${MODELS_DIR:-../models}"
        docker compose run --rm --no-deps $SERVICE scripts/download-models.sh
        ;;
    start)
        check_engines
        # What scripts/start.sh refuses to start without, checked before the container
        # starts at all.
        if [ ! -x ../build/llama-swap/llama-swap ]; then
            echo "llama-swap is not built: run ./docker/dock.sh build first." >&2
            exit 1
        fi
        if [ -z "$(ls -A "${MODELS_DIR:-../models}" 2>/dev/null)" ]; then
            echo "No models in ${MODELS_DIR:-../models}: run ./docker/dock.sh models first." >&2
            exit 1
        fi
        # By its name: compose would also count the containers of dock.sh build and shell.
        if [ "$(docker inspect -f '{{.State.Running}}' $SERVICE 2>/dev/null)" = true ]; then
            echo "The container is already running: ./docker/dock.sh stop first to restart it." >&2
            exit 1
        fi
        # Show the container's output until llama-swap says it is listening. The first
        # start runs without the restart policy, so a container that fails exits once and
        # its output ends there, with the reason; the policy is back however this ends, so
        # that llama-swap starts with the computer.
        since=$(date +%s)
        docker compose up --no-start
        docker update --restart no $SERVICE >/dev/null
        trap 'docker update --restart unless-stopped $SERVICE >/dev/null' EXIT
        docker compose start $SERVICE
        echo -e "\nWaiting for llama-swap; Ctrl-C stops waiting, the container keeps running.\n"
        # docker logs, not docker compose logs: compose ignores the kill after the loop.
        ready=""
        while IFS= read -r line; do
            echo "$line"
            [[ $line == *"llama-swap listening on"* ]] && { ready=1; break; }
        done < <(docker logs --follow --since "$since" $SERVICE 2>&1)
        kill $! 2>/dev/null || true
        if [ -z "$ready" ]; then
            echo -e "\nThe container did not start, see its output above: it is stopped." >&2
            exit 1
        fi
        echo -e "\nllama-swap is on http://127.0.0.1:${PORT:-8085}/v1"
        echo "Configure opencode with ./opencode-config.sh"
        echo "Follow the output with ./docker/dock.sh logs"
        ;;
    logs)
        docker compose logs --follow $SERVICE
        ;;
    status)
        docker compose ps --all
        curl -s "http://127.0.0.1:${PORT:-8085}/running" && echo || true
        ;;
    shell)
        if [ -n "$(docker compose ps --quiet --status running $SERVICE)" ]; then
            docker compose exec $SERVICE bash
        else
            docker compose run --rm --no-deps $SERVICE bash
        fi
        ;;
    stop)
        docker compose stop $SERVICE
        ;;
    clean)
        docker compose down --rmi all --remove-orphans
        ;;
    *)
        echo "Unknown parameter: $1"
        display_usage
        exit 1
        ;;
esac
