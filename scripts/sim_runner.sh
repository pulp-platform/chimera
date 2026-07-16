#!/usr/bin/env bash
# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# One-test RTL simulation primitive. Used as the chimera-sdk `SOC_MODEL_BINARY`
# so `ctest` (and the pytest front-end wrapping it) can run each unified ELF in
# the chimera-top Questa testbench via the existing `chim-run-batch` flow.
#
# Invoked the way chimera-sdk's add_test() calls the sim model:
#   sim_runner.sh +BINARY=<unified.elf> [+PRELMODE=<n>]
#
# Exit 0 = pass (testbench printed SUCCESS, no Fatal, "Errors: 0").
# NOTE: no `set -u` — sourcing iis-env.sh references unset vars and would abort.
set -o pipefail

CHIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BINARY=""
PRELMODE=3
for arg in "$@"; do
    case "$arg" in
        +BINARY=*)  BINARY="${arg#+BINARY=}" ;;
        +PRELMODE=*) PRELMODE="${arg#+PRELMODE=}" ;;
    esac
done

if [ -z "$BINARY" ]; then
    echo "sim_runner.sh: missing +BINARY=<elf>" >&2
    exit 2
fi
if [ ! -f "$BINARY" ]; then
    echo "sim_runner.sh: binary not found: $BINARY" >&2
    exit 2
fi

name="$(basename "$BINARY" .elf)"

# Per-test run directory. The RTL tracers write trace_hart_*/dma_trace_*/transcript
# to the cwd, so give each test its own dir → isolated, parallel-safe traces.
rundir="$CHIM_ROOT/target/sim/vsim/runs/${name}"
mkdir -p "$rundir/target/sim"
# The HyperRAM SDF is referenced by a compile-time-baked relative path
# (./target/sim/models/...); expose just that subtree so it resolves from rundir.
ln -sfn "$CHIM_ROOT/target/sim/models" "$rundir/target/sim/models"
transcript="$rundir/transcript"

# Bring in the IIS sim environment (VSIM/questa) if not already set.
if ! command -v vsim >/dev/null 2>&1 || [ -z "${VSIM:-}" ]; then
    # shellcheck disable=SC1091
    source "$CHIM_ROOT/iis-env.sh" >/dev/null 2>&1 || true
fi

# Wall-clock watchdog: the testbench has no internal cycle-limit, so a run that
# never reaches end-of-computation would hang forever. Kill it after SIM_TIMEOUT
# seconds (SIGTERM, then SIGKILL 10s later) and clean up any orphaned vsim.
SIM_TIMEOUT="${SIM_TIMEOUT:-600}"

# Reap this run's vsim (matched by its unique unified-ELF name on the command
# line). Killing `timeout`/`make` alone orphans vsim, so target it explicitly.
reap_vsim() { pkill -u "$(id -un)" -f "vsim.*${name}" 2>/dev/null || true; }

# On Ctrl+C / SIGTERM (e.g. interrupting `make chim-test`), kill the sim child
# and reap vsim so nothing is left running.
on_interrupt() {
    echo ">> [sim] interrupted: $name" >&2
    [ -n "${sim_pid:-}" ] && kill "$sim_pid" 2>/dev/null || true
    reap_vsim
    exit 130
}
trap on_interrupt INT TERM

echo ">> [sim] $name (PRELMODE=$PRELMODE, timeout=${SIM_TIMEOUT}s)"
# Run in the background + wait so the trap can fire promptly while the sim runs.
timeout -k 10 "$SIM_TIMEOUT" \
    make -C "$CHIM_ROOT" chim-run-batch \
        RUN_DIR="$rundir" \
        BINARY="$BINARY" PRELMODE="$PRELMODE" \
        VSIM_FLAGS="-c -l $transcript" >/dev/null 2>&1 &
sim_pid=$!
wait "$sim_pid"
rc=$?
trap - INT TERM

if [ "$rc" -eq 124 ]; then
    # timeout fired; make was killed but vsim may be orphaned — reap it.
    reap_vsim
    echo ">> [sim] TIMEOUT after ${SIM_TIMEOUT}s: $name" >&2
    exit 1
fi

# Pass iff the testbench signalled SUCCESS, hit no Fatal, and reported 0 errors.
if grep -q "] SUCCESS" "$transcript" 2>/dev/null \
    && ! grep -qE "Fatal:" "$transcript" \
    && grep -qE "Errors: 0(,|$)" "$transcript"; then
    echo ">> [sim] PASS: $name"
    exit 0
fi

echo ">> [sim] FAIL: $name (transcript: $transcript)" >&2
grep -iE "FAILED|Fatal:|Errors: [1-9]" "$transcript" 2>/dev/null | tail -5 >&2
exit 1
