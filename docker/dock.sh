#! /bin/bash -e

# Use this script to download, build, start, stop and remove opencode-4090: llama-swap in
# front of four inference engines for Qwen3.8-27B, all in one container, opencode-4090.
#
# The container is defined in docker-compose.yml. This script only adds what compose
# cannot express: the submodules, the host uid/gid, compiling the engines inside the
# container, and downloading the models.

SERVICE=opencode-4090

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
        docker compose up --detach
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
