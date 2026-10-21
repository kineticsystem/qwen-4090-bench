# The qwen-4090-bench container: every engine, llama-swap and the server scripts, for one
# NVIDIA GeForce RTX 4090 (sm_89). Ubuntu 24.04 with user "developer".
#
# CUDA 13.0 matches the CUDA version of the 580 driver series exactly: newer CUDA
# images need the driver's minor-version compatibility, older ones cannot build NInfer.
# The engines themselves are not in the image: they are Git submodules of the repository,
# which is mounted at /home/developer/ws, and `dock.sh build` compiles them there, so
# what is built stays on the host and survives a rebuilt image.
FROM nvidia/cuda:13.0.2-devel-ubuntu24.04

LABEL name="qwen-4090-bench"

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo git curl ca-certificates build-essential cmake ninja-build pkg-config \
      python3 python3-pip python3-jinja2 iproute2 \
      libcurl4-openssl-dev libssl-dev \
      libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

# The CUDA image ships forward-compatibility libraries in /usr/local/cuda*/compat. Forward
# compatibility is supported only on datacenter GPUs: on a GeForce card every CUDA call
# fails with cudaErrorCompatNotSupportedOnDevice once the loader picks them up.
RUN rm -rf /usr/local/cuda*/compat

# llama-swap is written in Go, with a web UI built by Node.js.
ARG GO_VERSION=1.27.3
ARG NODE_VERSION=v24.22.1
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -xz -C /usr/local \
    && curl -fsSL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz \
       | tar -xJ -C /usr/local --strip-components=1
ENV PATH=/usr/local/go/bin:/usr/local/cuda/bin:$PATH

# Ubuntu 24.04 base images ship a default 'ubuntu' user at uid/gid 1000. Remove it so
# 'developer' can take the uid/gid of the host user, which keeps the mounted repository
# writable.
RUN if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g ${USER_GID} developer \
    && useradd --create-home --shell /bin/bash --uid ${USER_UID} --gid ${USER_GID} developer \
    && echo 'developer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/developer

USER developer
ENV GOPATH=/home/developer/go GOCACHE=/home/developer/.cache/go-build
WORKDIR /home/developer/ws
CMD ["scripts/start.sh"]
