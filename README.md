# qwen-4090-bench

[![CI](https://github.com/kineticsystem/qwen-4090-bench/actions/workflows/ci.yml/badge.svg)](https://github.com/kineticsystem/qwen-4090-bench/actions/workflows/ci.yml)

<p align="center"><img src="doc/img/summary.svg" width="80%" alt="Decode speed and served context of the seven models on one RTX 4090: azllm is the fastest"></p>

This repository is a benchmark. We wanted to know how to run a large language model on our own computer, with one **NVIDIA GeForce RTX 4090** (24 GB), as fast as possible and without losing quality.

We used one model, **Qwen3.8-27B**, and compared four programs that run it, called *inference engines*:

- **llama.cpp**, the usual choice, as the reference: the baseline;
- **OpenJet**, **NInfer** and **azllm**, three engines written specially for this family of models.

At full precision the model does not fit in 24 GB, so each engine uses a compressed copy of it, a *quantized* model, with about 4 to 5 bits per weight instead of 16. llama.cpp and OpenJet read the same file; NInfer and azllm each read a format of their own, so their copies differ slightly.

For each engine we measured the speed, the accuracy, the largest context that fits on the card, with and without the model's vision, and how much precision is lost by compressing the memory of the context, the KV cache.

The best engine, azllm, is 2.5 times faster than llama.cpp, as precise, and has the most context: 228K tokens with vision, while leaving 2 GB of the card free for the display. The details are in the [research report](doc/research/REPORT.md) and the [paper](doc/research/Serving-Qwen3.8-27B-on-a-single-RTX-4090.pdf).

The repository also packages every configuration we measured, ready to use: one Docker container with the four engines and [llama-swap](https://github.com/mostlygeek/llama-swap), which starts the engine a request asks for. Any program that speaks the OpenAI API can use it. We used the coding agent [opencode](https://opencode.ai), and provide a script that configures it.

> [!IMPORTANT]
> This project is built and tuned for the RTX 4090 (24 GB, `sm_89`) only. The engines are compiled for that GPU, and the context sizes fill its memory, less the room the display needs: see [Room for the Display](#room-for-the-display).

## Table of Contents <!-- omit in toc -->

- [The Results](#the-results)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Use It](#use-it)
  - [opencode](#opencode)
- [The Commands](#the-commands)
- [Change a Model](#change-a-model)
- [Room for the Display](#room-for-the-display)
- [Troubleshooting](#troubleshooting)
- [Licenses](#licenses)

## The Results

Decode speed on six short prompts, with the recommended sampling and thinking off, and accuracy with greedy decoding. The first column is the name a client asks for:

| Model | Engine | Context | Vision | Speed | GSM8K | HumanEval |
|---|---|---:|:---:|---:|---:|---:|
| `baseline` | llama.cpp (TurboQuant fork) | 128K | yes | 89.6 tok/s | 97.2% | 96.3% |
| `openjet` | OpenJet | 64K | no | 135.9 tok/s | 95.6% | 96.3% |
| `ninfer-precise` | NInfer | 116K | yes | 137.4 tok/s | 97.6% | 95.1% |
| `ninfer-long` | NInfer | 172K | yes | 139.0 tok/s | 96.0% | 96.3% |
| `ninfer-fast` | NInfer | 76K | yes | 166.0 tok/s | 97.2% | 95.7% |
| **`azllm`** | azllm | 148K | yes | **228.6 tok/s** | 95.2% | 95.7% |
| **`azllm-228k`** | azllm | **228K** | yes | **228.8 tok/s** | 96.8% | 95.7% |

**azllm is the best of the engines we tested.** It is 2.5 times faster than the baseline, about 300 tok/s on code, and as precise: its weights predict code within 0.5% of the baseline's, and the accuracy differences are within the noise of the tests.

The context is the one each model is served with here, which keeps 2 GB of the GPU free for the display: see [Room for the Display](#room-for-the-display). The research measured the speeds and scores at larger contexts, which left each engine only its default free memory, e.g. 768 MiB for azllm; the speed hardly depends on the context size.

For long coding sessions, use **`azllm-228k`**: it has the most context, its 4-bit KV cache costs almost nothing in precision, and it is as fast on short prompts.

How the measurements were made, and how to reproduce them, is in the [research report](doc/research/REPORT.md).

## Prerequisites

- **An NVIDIA GeForce RTX 4090** and its driver, version 580 or newer.
- **Linux, Docker and the NVIDIA Container Toolkit.** Please refer to [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) and [Installing the NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
- **About 75 GB of disk**: 54 GB of models and 20 GB for the image and the builds.
- **32 GB of RAM** to compile OpenJet.

## Install

Clone the repository with the engines, which are Git submodules:

```
git clone --recursive https://github.com/kineticsystem/qwen-4090-bench.git
cd qwen-4090-bench
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

The command shows the output of the container until llama-swap says it is listening, a few seconds. A container that fails shows why and is stopped, instead of restarting forever.

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

The script reads the list of models, with their context sizes, from llama-swap, and writes the provider `qwen-4090-bench` into `~/.config/opencode/opencode.json`, after a backup next to it, `opencode.json.bak-<date>`; it keeps the last 5 backups, or the last `KEEP` with e.g. `KEEP=10 ./opencode-config.sh`. The other providers and settings stay as they are. In opencode, choose a model with `/models`; opencode shows the progress while an engine loads.

## The Commands

| Command | What it does |
|---|---|
| `./docker/dock.sh download` | Clone the engines, if the repository was cloned without `--recursive` |
| `./docker/dock.sh build` | Build the image and compile the engines |
| `./docker/dock.sh models` | Download the models |
| `./docker/dock.sh start` | Start llama-swap and show its output until it listens; it also starts with the computer from then on |
| `./docker/dock.sh status` | Show the container and the model that is loaded |
| `./docker/dock.sh logs` | Follow llama-swap and the engines |
| `./docker/dock.sh stop` | Stop the container |
| `./docker/dock.sh shell` | Open a terminal in the container |
| `./docker/dock.sh clean` | Remove the container and its image |

## Change a Model

The models are defined in [`scripts/llama-swap.yaml`](scripts/llama-swap.yaml). Each one runs a script of [`scripts/serve`](scripts/serve) with its options, e.g. a context size or a KV cache format; each script lists its options in its header. The scripts are mounted into the container, so a change needs no rebuild: restart the container with `./docker/dock.sh stop` and `./docker/dock.sh start`, then run `./opencode-config.sh` again so that opencode knows the new context sizes.

## Room for the Display

The RTX 4090 of our computer also drives the display. The desktop holds 0.7 to 1 GB of its memory: Xorg, gnome-shell, the browser and the other windows, more as windows open. `nvidia-smi` lists them as type `G`.

azllm and NInfer reserve the memory of the whole context when they start, so a long conversation does not run out of it later: NInfer used the same memory after start, after a short request and after a 20,000-token prompt. What grows while an engine runs is the desktop, and azllm's cache of CUDA graphs, about 12 MB each. So each model is served with a context, in steps of 4,096 tokens, that starts with the desktop running and leaves at least 2 GB of the GPU free. The last column is the free memory after one short request, or for azllm after loading, as its own check reports it:

| Model | Measured in the research | Served, 2 GB free | Free, measured |
|---|---:|---:|---:|
| `baseline` | 128,000 | 128,000 | 2,300 MiB |
| `openjet` | 131,072 | 65,536 | 2,245 MiB |
| `ninfer-precise` | 204,800 | 118,784 | 2,212 MiB |
| `ninfer-long` | 262,144 | 176,128 | 2,227 MiB |
| `ninfer-fast` | 192,512 | 77,824 | 2,171 MiB |
| `azllm` | 241,664 | 151,552 | 2.18 GB, azllm's report |
| `azllm-228k` | 262,144 | 233,472 | 2.15 GB or more, azllm's report |

azllm checks the room itself: [`scripts/serve/azllm.sh`](scripts/serve/azllm.sh) runs it with `-fitt 2048`, and with `-fitl off`, so it refuses a context that does not fit instead of starting with smaller buffers or a shorter context than we asked for. The other engines have no such setting: their contexts were measured with `nvidia-smi`, with at least 2,048 MiB free as the test, and the desktop moves the result by up to 400 MiB from one start to the next, so NInfer and OpenJet get one step below the last context that passed.

The room costs some models more than others. `ninfer-fast` keeps a second KV cache for its DFlash2 drafter, and near the `azllm` limit what does not fit is the prefill buffers, not the KV cache. With room for a display, `azllm-228k` is the model with the most context.

For more context, leave less room: pass `--ctx` to the scripts in [`scripts/llama-swap.yaml`](scripts/llama-swap.yaml), and lower `-fitt` in `azllm.sh`. The contexts measured in the research, which left each engine only its default free memory, are the most each engine can start with.

## Troubleshooting

**opencode shows no `qwen-4090-bench` models.** The container was not running when `./opencode-config.sh` ran: start it and run the script again.

**`./docker/dock.sh start` ends with `llama-swap is not built` or `No models in ../models`.** The engines are not compiled or the models are not downloaded: run `./docker/dock.sh build` or `./docker/dock.sh models` first.

**`./docker/dock.sh start` ends with `The container did not start`.** The lines above it are the output of the container and say why; the container is stopped.

**opencode seems to think forever, and `./docker/dock.sh logs` shows `does not fit as asked` and `starting azllm failed`.** azllm does not fit next to what the display holds. NInfer says `requested Engine runtime reservation requires … bytes, but only … bytes are available`, and OpenJet `out of memory`. While a model loads, llama-swap writes its progress in the reasoning field, so opencode shows it as thinking; when azllm gives up, opencode sends the request again and the load starts over. Close windows that use the GPU, or give azllm a smaller `--ctx`: see [Room for the Display](#room-for-the-display).

**OpenJet or the baseline does not start, and the log shows `model is corrupted or incomplete`.** The download of `models/unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf` stopped before the end, e.g. when the connection dropped; a complete file is 17.6 GB and has a `.ok` file next to it. Run `./docker/dock.sh models` again: it continues where it stopped and checks the SHA-256.

**A request ends with an error after about seven minutes.** The engine did not start: `./docker/dock.sh logs` shows why, usually a missing model file.

**The computer gets hot or restarts during long sessions.** The RTX 4090 draws up to 450 W under load. Keep the case well ventilated.

## Licenses

This repository is under the [MIT License](LICENSE). The engines are Git submodules with their own licenses: [llama.cpp](https://github.com/ggml-org/llama.cpp), [llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) and [llama-swap](https://github.com/mostlygeek/llama-swap) are MIT, [NInfer-4090](https://github.com/sergiuszm/ninfer-4090) and [azllm](https://github.com/xhinker/azllm) Apache 2.0, and [OpenJet](https://github.com/L-Forster/open-jet) AGPL 3.0. The models keep the licenses of their authors.
