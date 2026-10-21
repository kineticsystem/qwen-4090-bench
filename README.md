# opencode-4090

[![CI](https://github.com/kineticsystem/opencode-4090/actions/workflows/ci.yml/badge.svg)](https://github.com/kineticsystem/opencode-4090/actions/workflows/ci.yml)

A study of how fast, and how precisely, a Qwen model runs on one **NVIDIA GeForce RTX 4090**. We took Qwen3.8-27B, in the quantized versions that each engine reads, and measured four inference engines against llama.cpp: decode speed, accuracy, the largest context that fits in 24 GB, with and without vision, and what a smaller KV cache costs in precision.

The best engine, azllm, is 2.5 times faster than llama.cpp, as precise, and fits the model's full 256K context with vision. The full results are in the [research report](doc/research/REPORT.md) and the [paper](doc/research/Serving-Qwen3.8-27B-on-a-single-RTX-4090.pdf).

The repository also packages every configuration we measured, ready to use: one Docker container with the four engines and [llama-swap](https://github.com/mostlygeek/llama-swap) in front of them, on one OpenAI-compatible endpoint. A client picks a model by name, and llama-swap starts the engine that serves it. Any OpenAI-compatible client works; we used the coding agent [opencode](https://opencode.ai), and provide a script that configures it.

> [!IMPORTANT]
> This project is built and tuned for the RTX 4090 (24 GB, `sm_89`) only. The engines are compiled for that GPU, and the context sizes fill its memory exactly.

## Table of Contents <!-- omit in toc -->

- [The Results](#the-results)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Use It](#use-it)
  - [opencode](#opencode)
- [The Commands](#the-commands)
- [Change a Model](#change-a-model)
- [Troubleshooting](#troubleshooting)
- [Licenses](#licenses)

## The Results

Decode speed on six short prompts, with the recommended sampling and thinking off, and accuracy with greedy decoding. The first column is the name a client asks for:

| Model | Engine | Context | Vision | Speed | GSM8K | HumanEval |
|---|---|---:|:---:|---:|---:|---:|
| `baseline` | llama.cpp (TurboQuant fork) | 128K | yes | 89.6 tok/s | 97.2% | 96.3% |
| `openjet` | OpenJet | 128K | no | 135.9 tok/s | 95.6% | 96.3% |
| `ninfer-precise` | NInfer | 200K | yes | 137.4 tok/s | 97.6% | 95.1% |
| `ninfer-long` | NInfer | 256K | yes | 139.0 tok/s | 96.0% | 96.3% |
| `ninfer-fast` | NInfer | 192K | yes | 166.0 tok/s | 97.2% | 95.7% |
| **`azllm`** | azllm | 242K | yes | **228.6 tok/s** | 95.2% | 95.7% |
| **`azllm-256k`** | azllm | **256K** | yes | **228.8 tok/s** | 96.8% | 95.7% |

**azllm is the best of the engines we tested.** It is 2.5 times faster than the baseline, about 300 tok/s on code, and as precise: its weights predict code within 0.5% of the baseline's, and the accuracy differences are within the noise of the tests.

How the measurements were made, and how to reproduce them, is in the [research report](doc/research/REPORT.md).

## Prerequisites

- **An NVIDIA GeForce RTX 4090** and its driver, version 580 or newer.
- **Linux, Docker and the NVIDIA Container Toolkit.** Please refer to [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) and [Installing the NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
- **About 75 GB of disk**: 54 GB of models and 20 GB for the image and the builds.
- **32 GB of RAM** to compile OpenJet.

## Install

Clone the repository with the engines, which are Git submodules:

```
git clone --recursive https://github.com/kineticsystem/opencode-4090.git
cd opencode-4090
```

Build the image and compile the engines, about 30 minutes:

```
./docker/dock.sh build
```

Download the models into `models/`, about 54 GB:

```
./docker/dock.sh models
```

To keep the models elsewhere, set `MODELS_DIR` to that folder for every `dock.sh` command, e.g. `MODELS_DIR=/data/models ./docker/dock.sh models`.

## Use It

Start the container; llama-swap listens on `http://127.0.0.1:8085/v1`:

```
./docker/dock.sh start
```

Any OpenAI-compatible client can use it: the model is the name in the first column of [the results](#the-results). For example:

```
curl http://127.0.0.1:8085/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model": "azllm", "messages": [{"role": "user", "content": "Hello"}]}'
```

The first request to a model waits for its engine to load, one to two minutes. Only one model fits on the GPU at a time: asking for another one stops the current engine. A model is unloaded after 30 idle minutes.

### opencode

Add the models to [opencode](https://opencode.ai), with azllm as the default:

```
./opencode-config.sh --default azllm
```

The script reads the list of models, with their context sizes, from llama-swap, and writes the provider `opencode-4090` into `~/.config/opencode/opencode.json`, after a backup. In opencode, choose a model with `/models`; opencode shows the progress while an engine loads.

## The Commands

| Command | What it does |
|---|---|
| `./docker/dock.sh download` | Clone the engines, if the repository was cloned without `--recursive` |
| `./docker/dock.sh build` | Build the image and compile the engines |
| `./docker/dock.sh models` | Download the models |
| `./docker/dock.sh start` | Start llama-swap; it also starts with the computer from then on |
| `./docker/dock.sh status` | Show the container and the model that is loaded |
| `./docker/dock.sh logs` | Follow llama-swap and the engines |
| `./docker/dock.sh stop` | Stop the container |
| `./docker/dock.sh shell` | Open a terminal in the container |
| `./docker/dock.sh clean` | Remove the container and its image |

## Change a Model

The models are defined in [`scripts/llama-swap.yaml`](scripts/llama-swap.yaml). Each one runs a script of [`scripts/serve`](scripts/serve) with its options, e.g. a context size or a KV cache format; each script lists its options in its header. The scripts are mounted into the container, so a change needs no rebuild: restart the container with `./docker/dock.sh stop` and `./docker/dock.sh start`, then run `./opencode-config.sh` again so that opencode knows the new context sizes.

## Troubleshooting

**opencode shows no `opencode-4090` models.** The container was not running when `./opencode-config.sh` ran: start it and run the script again.

**`./docker/dock.sh start` ends with `llama-swap is not built` or `no models in /models`** in the logs. Run `./docker/dock.sh build` or `./docker/dock.sh models` first.

**A request ends with an error after about seven minutes.** The engine did not start: `./docker/dock.sh logs` shows why, usually a missing model file.

**The computer gets hot or restarts during long sessions.** The RTX 4090 draws up to 450 W under load. Keep the case well ventilated.

## Licenses

This repository is under the [MIT License](LICENSE). The engines are Git submodules with their own licenses: [llama.cpp](https://github.com/ggml-org/llama.cpp), [llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) and [llama-swap](https://github.com/mostlygeek/llama-swap) are MIT, [NInfer-4090](https://github.com/sergiuszm/ninfer-4090) and [azllm](https://github.com/xhinker/azllm) Apache 2.0, and [OpenJet](https://github.com/L-Forster/open-jet) AGPL 3.0. The models keep the licenses of their authors.
