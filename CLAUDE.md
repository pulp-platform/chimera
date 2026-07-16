# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What Chimera is

Chimera is an open-source, configurable heterogeneous SoC template (PULP Platform, ETH Zurich /
University of Bologna). It integrates:

- a **Cheshire** host SoC (64-bit CVA6, CLINT/PLIC/CLIC, JTAG debug, UART/I²C/SPI/GPIO, AXI LLC),
- up to **5 Snitch clusters** (9 cores each) as compute accelerators,
- a shared multi-banked **memory island** (`0x4800_0000`),
- a **HyperBus** controller for off-chip HyperRAM (`0x8000_0000`).

This repo is the *integration layer*: almost all leaf IP comes from Bender git dependencies
(cheshire, snitch_cluster, idma, memory_island, hyperbus, axi, common_cells, …). The RTL here
wires those together and adds SoC-control registers, a Snitch bootrom, and the cluster/memory
adapters.

## Documentation map

Detailed docs live in `docs/`:

- `docs/architecture.md` — SoC block diagram, HW module map, full address map.
- `docs/build-system.md` — Bender + Make flow, every target, dependency versions.
- `docs/software.md` — SW build, the cluster-offload model, test inventory, linker layout.
- `docs/verification.md` — current sim/test flow **and** the planned pytest-based framework.
- `docs/sdk-integration.md` — plan to adopt `chimera-sdk` as the SW layer.

`TODO.md` (repo root) tracks the active cleanup / verification-framework initiative.

## Environment

IIS members: `source iis-env.sh` (pins bender-0.31.0, questa-2022.3, RISC-V GCC 32/64, Snitch
LLVM, python3.11; auto-creates `.venv`). Non-IIS: `make python-venv`, install Bender, and a
RISC-V GCC toolchain (`RISCV_GCC_BINROOT`). See `README.md`.

## Build (current Bender + Make flow)

```sh
bender checkout
make chim-all        # = HW (chs-hw-init sn-hw-all chim-bootrom-init) + SW (chim-sw) + sim (chim-sim)
```

Selective:
```sh
make chs-hw-init         # patch PLIC, gen iDMA, build libchimera.a, then Cheshire chs-hw-all
make sn-hw-all           # generate Snitch cluster RTL (uses cfg/default.json)
make chim-sw             # build libchimera.a + all sw/tests/*.c -> *.memisl.elf
make chim-bootrom-init   # Cheshire bootrom  (⚠ requires chim-sw first)
make snitch_bootrom      # regenerate hw/bootrom/snitch/snitch_bootrom.sv (rv32im)
make chim-sim            # fetch HyperRAM model + compile RTL in Questa
make chim-run-batch BINARY=sw/tests/<test>.memisl.elf   # run a test (batch)
make help                # list all targets
```

Key gotchas:
- **`chim-sw` must run before `chim-bootrom-init`** (bootrom embeds SW).
- Host builds at `CHS_XLEN=64` (`rv64gc_zifencei`/`lp64d`); the Snitch bootrom is **rv32im**.
- Register offsets come from generated `sw/include/regs/soc_ctrl.h`; regenerate with
  `make regenerate_soc_regs` after editing `hw/regs/chimera_regs.hjson`.
- Core counts are hardcoded in `chimera.mk` (`CLINTCORES/PLICCORES/PLIC_NUM_INTRS`) and must
  track `ExtClusters`/`NrCores` in `hw/chimera_pkg.sv`.

## Running / writing tests

Today a "test" is a host (CVA6) ELF linked into the memory island; it drives SoC-control
registers and offloads functions to clusters via a shared-memory function-pointer + CLINT MSIP
mechanism. Pass/fail = the program's return code. CI runs a fixed matrix via `chim-run-batch`
and greps the transcript with `scripts/vsim_ret_error.sh`. See `docs/software.md` (offload model,
test inventory) and `docs/verification.md` (the planned pytest framework that replaces the
grep-the-transcript approach).

## Formatting

```sh
verible-verilog-format --flagfile .verilog_format --inplace hw/*.sv target/sim/src/*.sv
python scripts/run_clang_format.py -ir sw/    # llvm-12; on IIS pass --clang-format-executable=<pulp-llvm>/bin/clang-format
```

## Conventions

- Every source file carries an SPDX header (SHL-0.51 for HW/scripts, Apache-2.0 for SW and
  generated register RTL).
- Do not commit build artifacts. Most are gitignored; note `build/` is currently a gap.
- `iis_compile.sh` is an empty placeholder (0 bytes) — safe to ignore/remove.
