# chimera-sdk Integration

Goal: add **chimera-sdk** as a git submodule and retire the hand-written `sw/` layer
(`sw/lib/offload.c`, `sw/include/*`, `sw/link/*`, and the 8 tests), so chimera-top (and later the
downstream closed project) share one SW SDK. Tracked in `../TODO.md`.

## What chimera-sdk is

A newer, **CMake-first** bare-metal SW platform for Chimera-architecture SoCs (LLVM 18.1.4-pulp +
picolibc, *not* GCC/newlib). Its headline feature is a **multi-binary compilation flow**: one ELF
per execution domain (host + each device), so RV64 host and RV32 Snitch code no longer share a
common-denominator ISA.

Key pieces:

- `cmake/Chimera.cmake` — the API: `add_device_binary()` (compile a Snitch ELF, emit
  absolute-address symbol stubs + a placement `.ldh`) and `add_host_binary()` (compile the host
  ELF, link the device symbol stubs, chain placement, optionally merge into one unified ELF).
- `targets/<platform>/` — per-SoC config: `config.cmake` (ISA/ABI), linker templates, crt0,
  register maps, and the `chimera_shared_data_t` `.common` layout. **`chimera-open` already
  matches chimera-top** (host `rv64imafdc/lp64d`, cluster `rv32imafd_xdma/ilp32d`, memisl at
  `0x4800_0000`).
- `host/` — HAL (`device_api`, `interrupt_api`), drivers (cluster offload, uart_apb, clint32,
  hyperbus), runtime (alloc/clint/fll/uart/log), OpenTitan peripherals.
- `devices/snitch_cluster/` — cluster runtime + the `snitch-sdk` (SNRT) submodule.
- `tests/` — per-test dirs (`src_host/` + `src_cluster/` + `CMakeLists.txt`); the canonical
  example is `tests/snitchCluster/simpleOffload`.
- Build flavors via `HARDWARE_BACKEND` = `RTL` | `GVSoC` | `ASIC`; run via `ctest`
  (`TEST_MODE=simulation`, RTL) or `scripts/run_tests.sh` (GVSoC/ASIC).

## How the offload model maps

| chimera-top today | chimera-sdk |
|-------------------|-------------|
| Host + "device" functions in one memisl ELF, offloaded by function pointer | Separate host + device ELFs, chained by placement `.ldh`, sharing a `.common` section |
| `sw/lib/offload.c` HAL | `host/drivers/cluster/offload_snitchCluster.c` |
| `sw/include/soc_addr_map.h`, `regs/soc_ctrl.h` | `targets/chimera-open/shared/inc/*` |
| `sw/link/memisl.ld`, `common.ldh` | `targets/chimera-open/{host,devices}/link.ld.in`, `shared/common.ldh` |
| GCC/newlib, rv64gc | LLVM/picolibc, per-domain ISA/ABI |

## Integration steps

1. **Add submodule**: `git submodule add <chimera-sdk url> sw/sdk` (or top-level `chimera-sdk/`).
   The SDK has **nested** submodules (`snitch-sdk`, `opentitan_peripherals`) → always
   `git submodule update --init --recursive`.
2. **Toolchain**: provide `TOOLCHAIN_DIR` (LLVM) + `PICOLIBC_DIR`. Easiest via the SDK container
   image (below); alternatively `make llvm` / `make picolibc-multilib` in the SDK.
3. **Ensure `uv` is available** — SDK post-build steps (section-overlap check, unified-ELF merge
   via `lief`) shell out to `uv run python`.
4. **Adopt/extend the `chimera-open` target** for chimera-top (verify address map, register
   headers, ISA/ABI, `chimera_shared_data_t` match the RTL). Add a new `targets/<name>/` only if
   chimera-top diverges from `chimera-open`.
5. **Migrate the 8 tests** into SDK test dirs (host `src_host/` + device `src_cluster/`), plus a
   **new iDMA test** (current coverage gap):
   testReturnZero, testCluster, testClusterOffload, testClusterGating, testCfgBootAddr,
   testHyperbusAddr, testMemBypass, testPeripheralsGating.
6. **Wire simulation**: pass chimera-top's compiled RTL model as the SDK's `SOC_MODEL_BINARY`
   with `TEST_MODE=simulation`, so `ctest` (and the planned pytest layer) can launch it.
7. **Retire** the old `sw/lib`, `sw/include`, `sw/link`, `sw/tests`, and the `chim-sw` make rules
   once parity is reached.

## Containerized build (Docker / Singularity)

The SDK builds inside a toolchain container (LLVM + compiler-rt multilib + picolibc). Standard
Docker flow:

```bash
docker run -it --rm -v $(pwd):/app/chimera <image> zsh
cmake -D TARGET_PLATFORM=chimera-open \
      -D TOOLCHAIN_DIR=/app/install/llvm-18.1.4-pulp \
      -D PICOLIBC_DIR=/app/install/picolibc \
      -D HARDWARE_BACKEND=RTL -D CHIMERA_UNIFIED_ELF=ON -B build
cmake --build build -j
```

On IIS workstations (no Docker) use **Singularity/Apptainer**:
`singularity pull docker://<image>` then `singularity shell -e -s /bin/zsh <sif>` (`-e` isolates
the host env so container tool paths win).

> ⚠ **Image name is inconsistent in the SDK** — README uses `chimera:latest`, usage.rst uses
> `chimera:devel`, CLAUDE.md uses `deeploy:devel`. Standardize on one before documenting the
> chimera-top build.

## Open questions to resolve during integration

- Submodule location/name (`sw/sdk` vs top-level `chimera-sdk`).
- Whether chimera-top keeps the Bender/Make HW flow while the SDK owns *only* SW (recommended:
  yes — HW stays Bender, SW moves to the SDK's CMake).
- How the SDK's per-domain ELFs are preloaded by the existing `tb_chimera_soc.sv` fast-debug path
  (which currently expects a single memisl ELF).
