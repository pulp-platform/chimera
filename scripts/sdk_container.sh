#!/usr/bin/env bash
# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Run a command inside the chimera-sdk toolchain container (LLVM 18.1.4-pulp +
# picolibc + Python deps). Supports both Singularity/Apptainer and Docker so the
# exact same SDK build works on IIS workstations (Singularity) and elsewhere
# (Docker), per chimera-sdk/docs/src_sphinx/usage/usage.rst.
#
# Usage:
#   scripts/sdk_container.sh <command...>
#   scripts/sdk_container.sh                 # no args -> interactive shell
#
# Environment overrides:
#   CONTAINER_RUNTIME   auto|singularity|docker   (default: auto)
#   CHIM_SDK_SIF        path to the .sif image    (default: <repo>/.cache/containers/chimera_latest.sif)
#                       Auto-pulled from CHIM_SDK_IMAGE if missing; kept gitignored.
#   CHIM_SDK_IMAGE      docker image ref          (default: ghcr.io/xeratec/chimera)
#                       TODO: switch to ghcr.io/pulp-platform/chimera:devel once
#                       https://github.com/pulp-platform/chimera-sdk/pull/43 is merged.
#   CHIM_SDK_WORKDIR    dir to cd into inside     (default: <repo>/sw/deps/chimera-sdk)
#   CHIM_SDK_CACHE_DIR  writable uv/ccache root   (default: <repo>/.cache)
#                       Kept on the bind-mounted scratch (large quota), NOT in $HOME
#                       (small quota on IIS) and NOT /scratch (read-only in-container).
#                       Point it at a shared scratch dir to reuse caches across repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-auto}"
CHIM_SDK_IMAGE="${CHIM_SDK_IMAGE:-ghcr.io/xeratec/chimera}"
CHIM_SDK_WORKDIR="${CHIM_SDK_WORKDIR:-$CHIM_ROOT/sw/deps/chimera-sdk}"
CHIM_SDK_CACHE_DIR="${CHIM_SDK_CACHE_DIR:-$CHIM_ROOT/.cache}"
# Managed, gitignored image location (auto-pulled on first use). Not a hardcoded
# external path — override CHIM_SDK_SIF to reuse an image elsewhere (e.g. a shared dir).
CHIM_SDK_SIF="${CHIM_SDK_SIF:-$CHIM_SDK_CACHE_DIR/containers/chimera_latest.sif}"

# Auto-select a runtime: prefer Singularity/Apptainer when available (the .sif is
# pulled on demand), else Docker.
if [ "$CONTAINER_RUNTIME" = "auto" ]; then
  if command -v singularity >/dev/null 2>&1 || command -v apptainer >/dev/null 2>&1; then
    CONTAINER_RUNTIME=singularity
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_RUNTIME=docker
  else
    echo "sdk_container.sh: no container runtime found (need singularity/apptainer or docker)." >&2
    exit 1
  fi
fi

# Fetch the image if it is not present yet.
ensure_image() {
  case "$CONTAINER_RUNTIME" in
    singularity|apptainer)
      local rt; rt="$(command -v singularity || command -v apptainer)"
      if [ ! -f "$CHIM_SDK_SIF" ]; then
        echo ">> image missing -> pulling docker://$CHIM_SDK_IMAGE into $CHIM_SDK_SIF" >&2
        mkdir -p "$(dirname "$CHIM_SDK_SIF")"
        # Keep the (large) layer cache on scratch too, not in $HOME.
        SINGULARITY_CACHEDIR="$CHIM_SDK_CACHE_DIR/singularity" \
        APPTAINER_CACHEDIR="$CHIM_SDK_CACHE_DIR/singularity" \
          "$rt" pull "$CHIM_SDK_SIF" "docker://$CHIM_SDK_IMAGE"
      fi
      ;;
    docker)
      if ! docker image inspect "$CHIM_SDK_IMAGE" >/dev/null 2>&1; then
        echo ">> image missing -> docker pull $CHIM_SDK_IMAGE" >&2
        docker pull "$CHIM_SDK_IMAGE"
      fi
      ;;
  esac
}
ensure_image

# The command to run inside the container (default: interactive shell).
if [ "$#" -eq 0 ]; then
  CMD="exec zsh"
else
  CMD="$*"
fi

# Cache/venv setup. Unlike ~/.zsh-container (which parks caches in $HOME to dodge the
# read-only in-container /scratch), we keep them on the bind-mounted, high-quota scratch
# via CHIM_SDK_CACHE_DIR — IIS $HOME quota is too small for uv/ccache. We also keep a
# container-specific uv venv (.venv-container) separate from the host's .venv. For
# Singularity, `bash -l` sources ~/.profile which may reset UV_CACHE_DIR, so these
# exports run *after* login setup.
mkdir -p "$CHIM_SDK_CACHE_DIR/uv" "$CHIM_SDK_CACHE_DIR/ccache"
ENV_SETUP="export UV_CACHE_DIR='$CHIM_SDK_CACHE_DIR/uv' CCACHE_DIR='$CHIM_SDK_CACHE_DIR/ccache' UV_PROJECT_ENVIRONMENT=.venv-container;"

# Bind the repo, and the cache dir too if it lives outside the repo.
BINDS=("$CHIM_ROOT")
case "$CHIM_SDK_CACHE_DIR" in "$CHIM_ROOT"/*) ;; *) BINDS+=("$CHIM_SDK_CACHE_DIR") ;; esac
BIND_ARG="$(IFS=,; echo "${BINDS[*]}")"

case "$CONTAINER_RUNTIME" in
  singularity|apptainer)
    RT="$(command -v singularity || command -v apptainer)"
    echo ">> [singularity] $CHIM_SDK_SIF :: $CMD" >&2
    exec "$RT" exec -e --bind "$BIND_ARG" "$CHIM_SDK_SIF" \
      bash -lc "$ENV_SETUP cd '$CHIM_SDK_WORKDIR' && $CMD"
    ;;
  docker)
    echo ">> [docker] $CHIM_SDK_IMAGE :: $CMD" >&2
    # Mount the repo (and external cache dir) at the same path so build artifacts and
    # their baked-in absolute paths are identical on host and in the container.
    DOCKER_MOUNTS=(-v "$CHIM_ROOT":"$CHIM_ROOT")
    case "$CHIM_SDK_CACHE_DIR" in "$CHIM_ROOT"/*) ;; *) DOCKER_MOUNTS+=(-v "$CHIM_SDK_CACHE_DIR":"$CHIM_SDK_CACHE_DIR") ;; esac
    exec docker run --rm -it \
      "${DOCKER_MOUNTS[@]}" -w "$CHIM_SDK_WORKDIR" \
      -e UV_CACHE_DIR="$CHIM_SDK_CACHE_DIR/uv" \
      -e CCACHE_DIR="$CHIM_SDK_CACHE_DIR/ccache" \
      -e UV_PROJECT_ENVIRONMENT=.venv-container \
      "$CHIM_SDK_IMAGE" bash -lc "cd '$CHIM_SDK_WORKDIR' && $CMD"
    ;;
  *)
    echo "sdk_container.sh: unknown CONTAINER_RUNTIME='$CONTAINER_RUNTIME'" >&2
    exit 1
    ;;
esac
