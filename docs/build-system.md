# Build System

Chimera builds with **Bender** (HW dependency + compile-script management) driving a layered
**Make** flow that wraps Cheshire's own build machinery. There is no CMake in the current flow.

## Entry points

- `Makefile` (root) — sets `CHIM_ROOT`, defines `BENDER = bender -d $(CHIM_ROOT)`, resolves
  dependency roots via `bender path <dep>` (only if `.bender/` exists), then `-include`s
  **`cheshire.mk` from the cheshire dependency** and **`chimera.mk`**. Also defines
  `python-venv`, `dvt_flist`, and the `help` target.
- `chimera.mk` — the SoC-level targets (below).
- `bender.mk` — Bender target flags:
  `COMMON_TARGS = -t snitch_cluster -t cv64a6_imafdchsclic_sv39_wb -t cva6 -t rtl`;
  `SIM_TARGS = $(COMMON_TARGS) -t test -t sim`.
- `sw/sw.mk`, `target/sim/sim.mk`, `utils/utils.mk` — sub-makefiles included from `chimera.mk`.
- `iis-env.sh` — IIS environment (bender-0.31.0, questa-2022.3, RISC-V GCC 32/64, Snitch LLVM,
  python3.11; auto-creates/sources `.venv`).
- `iis_compile.sh` — **empty (0 bytes)** placeholder.

## Relationship to Cheshire

Chimera does not reimplement the SW/bootrom/sim machinery — it **wraps** Cheshire's phonies and
reuses its variables (`CHS_SW_CC`, `CHS_SW_INCLUDES`, `CHS_SW_LIBS`, `CHS_SW_LDFLAGS`,
`CHS_SW_LD_DIR`, `gen_bootrom.py`, `elfloader.cpp`):

| Chimera target | wraps Cheshire |
|----------------|----------------|
| `chs-hw-init`  | `chs-hw-all` (after `update_plic`, `gen_idma_hw`, `libchimera.a`) |
| `chim-bootrom-init` | `chs-bootrom-all` |
| `chim-sim` | `chs-sim-all` |

Cheshire itself is pinned to `rev wiesep/chimera-main` and locally cloned to
`working_dir/cheshire` (via `Bender.local`), which is where `cheshire.mk` comes from.

## Targets

| Target | What it does |
|--------|--------------|
| `chim-all` | `CHIM_HW_ALL` (`chs-hw-init sn-hw-all chim-bootrom-init`) + `chim-sw` + `chim-sim` |
| `chs-hw-init` | `update_plic` (sed-patch `rv_plic.cfg.hjson` counts) + `gen_idma_hw` (`make -C idma idma_hw_all`) + build `libchimera.a`, then `chs-hw-all` |
| `sn-hw-all` | `sn-rtl` — generate Snitch cluster RTL from `SN_CFG` (`cfg/default.json`) |
| `chim-sw` | build `libchimera.a` (`sw/lib/*.c`) + every `sw/tests/*.c` → `*.memisl.elf` + `.dump` |
| `chim-bootrom-init` | build the Cheshire bootrom (**needs `chim-sw` first**) |
| `snitch_bootrom` | compile `hw/bootrom/snitch/*.{S,c}` (rv32im) → elf → bin → `snitch_bootrom.sv` via `gen_bootrom.py` |
| `regenerate_soc_regs` | run vendored `utils/reggen/regtool.py` on `hw/regs/chimera_regs.hjson` → `chimera_reg_{pkg,top}.sv`, `sw/include/regs/soc_ctrl.h`, `hw/regs/pcr.md` |
| `chim-sim` | `chim-hyperram-model` (fetch s27ks0641 VIP) + `chs-sim-all` + `chim-compile` (`bender script vsim` → `compile.tcl`, then `vsim -c`) |
| `chim-run` | GUI sim: `vsim -voptargs=+acc tb_chimera_soc` |
| `chim-run-batch` | batch sim: `vsim -c ... tb_chimera_soc -do "run -all; quit"` |
| `dvt_flist` | `bender script flist-plus` → `.dvt/default.build` for DVT Eclipse |

Simulation plusargs (`BINARY`, `SELCFG`, `BOOTMODE`, `PRELMODE`, `IMAGE`) are forwarded to vsim
by the `add_vsim_flag` macro in `sim.mk`.

## Key variables

- `CHS_XLEN ?= 64` — host is 64-bit.
- `CLINTCORES=46`, `PLICCORES=92`, `PLIC_NUM_INTRS=59` — **hand-computed** from 5 clusters × 9
  cores + host; must track `ExtClusters`/`NrCores` in `hw/chimera_pkg.sv`.
- `SN_CFG = $(SN_ROOT)/cfg/default.json` — Snitch cluster configuration.
- `CHS_SW_LD_DIR = $(CHIM_ROOT)/sw/link` — repoints linker scripts to Chimera's.

## Dependencies (Bender)

From `Bender.yml` / `Bender.lock` (see also `Bender.local` overrides):

| Dep | Pin |
|-----|-----|
| cheshire | `rev wiesep/chimera-main` (local clone `working_dir/cheshire`) |
| snitch_cluster | `5b2fccd…` |
| axi | `colluca/axi` `bd1abff…` |
| idma | `0.6.5` (override `28a36e5…`) |
| memory_island | `main` |
| hyperbus | `0.0.9` |
| common_cells | `1.39.0` (override `ca9d577…`) |
| register_interface | `0.4.7` |
| apb | `0.2.4` |
| tech_cells_generic | `0.2.12` |

`Bender.yml` also declares `workspace.package_links` (symlinks `deps/cheshire`,
`deps/snitch_cluster`, `deps/cva6`) and a `vendor_package` importing lowRISC **reggen** into
`utils/reggen/`.

## Current status

The repo is on branch `dev/64bit` — the switch to 64-bit CVA6 (and LLC/HyperBus rework) is in
progress. See `../TODO.md`.

## Cleanup opportunities

- `build/` is not gitignored (other artifacts are).
- Register generation uses **vendored reggen**; `peakrdl` (SystemRDL) is declared in
  `pyproject.toml` but unused — see the SystemRDL TODO.
- Python env is a plain `venv` + `pyproject.toml`; consider `uv` + committed lockfile (Gwaihir).
