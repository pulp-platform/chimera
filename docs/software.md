# Software

The `sw/` tree is deliberately thin: it reuses Cheshire's entire SW build machinery and adds only
the Chimera-specific offload library, SoC address map, SoC-control register defines, memory-island
linker scripts, and the tests.

## Layout

```
sw/
├── sw.mk                     # Chimera SW build fragment
├── include/
│   ├── offload.h             # cluster offload / gating / reset API
│   ├── soc_addr_map.h        # SoC memory map + per-cluster core counts
│   └── regs/soc_ctrl.h       # generated SoC-control register offsets
├── lib/offload.c             # the only Chimera lib source → libchimera.a
├── link/
│   ├── common.ldh            # shared MEMORY regions + peripheral base symbols
│   └── memisl.ld             # places binaries in the memory island (0x4800_0000)
└── tests/*.c                 # 8 host test programs
```

## Build flow

- Toolchain selected by `CHS_XLEN` (default 64) → `riscv64-unknown-elf-*`. `sw/sw.mk` overrides
  the arch to `-march=rv64gc_zifencei -mabi=lp64d`.
- `sw/lib/*.c` → `libchimera.a`, appended to Cheshire's `CHS_SW_LIBS`.
- Each `tests/*.c` compiles to `test.o`, then links with `sw/link/memisl.ld` + libs into
  `test.memisl.elf` (+ `.dump`). Only the `memisl` link variant is built by default.
- The Snitch cluster **bootrom** (`hw/bootrom/snitch/`) is the one true device binary: compiled
  **rv32im** (`-march=rv32im_zicsr -mabi=ilp32`), objcopy'd to binary, converted to
  `snitch_bootrom.sv`.

## The offload model (how "device" code runs)

There is **no separate device ELF and no objcopy-into-array embedding**. "Device" code is just
ordinary functions in the *same host ELF*, which lives in the memory island (`0x4800_0000`) —
addressable by both CVA6 and the Snitch clusters. Offload works via shared-memory function
pointers + interrupts:

1. Host writes the target function pointer into `SNITCH_BOOT_ADDR`.
2. Host raises a CLINT software interrupt (MSIP) on the target cluster's hart
   (`hartId = 1 + Σ preceding cores`; hart 0 is CVA6).
3. The cluster's rv32 bootrom (`run_from_reg`) reads `SNITCH_BOOT_ADDR` and `jalr`s into it.
4. Host busy-polls `SNITCH_CLUSTER_n_RETURN` for the result (set by `cluster_return(ret)` which
   writes `ret|1`).

The HAL is entirely in `sw/lib/offload.c` (+ `include/offload.h`):
`setupInterruptHandler`, `offloadToCluster`, `waitForCluster`, `waitClusterBusy`,
`setClusterClockGating`/`setAllClusterClockGating`, `setClusterReset`/`setAllClusterReset`.
The cluster side is `hw/bootrom/snitch/snitch_startup.c` (`cluster_startup`, `cluster_return`,
`set_busy`/`clean_busy`).

> Note: `offload.h` declares the gating/reset setters with `uint8_t*` but `offload.c` defines
> them `volatile uint8_t*` — a signature mismatch to clean up.
> Note: host offloaded functions are rv64gc but the bootrom is rv32 — an existing quirk to be
> aware of during the SDK migration.

## Test inventory (`sw/tests/`)

All 8 are host (CVA6) programs; return 0 = pass. These are the tests to migrate into chimera-sdk.

| Test | Exercises |
|------|-----------|
| `testReturnZero.c` | Smoke: ungate clusters, return 0 (host-only) |
| `testCluster.c` | Narrow-AXI accessibility of each cluster's TCDM; reset/gating |
| `testClusterOffload.c` | Canonical offload round-trip over all 5 clusters (CLINT MSIP, return regs) |
| `testClusterGating.c` | Per-cluster clock gating (waveform-inspected, not self-checking) |
| `testCfgBootAddr.c` | `SNITCH_CONFIGURABLE_BOOT_ADDR` reset value + R/W; triggers cluster boot |
| `testHyperbusAddr.c` | HyperBus cfg + HyperRAM R/W at `0x8000_0000` (needs HyperRAM VIP) |
| `testMemBypass.c` | Memory island via wide vs narrow path; `WIDE_MEM_CLUSTER_n_BYPASS`; offload |
| `testPeripheralsGating.c` | Cheshire peripheral clock-gating driven from Chimera |

**Coverage gap:** there is **no iDMA test** despite `idma` being a dependency — add one.

## Linker layout

- `common.ldh` defines `MEMORY` regions: `bootrom 0x0200_0000`, `spm 0x1000_0000`,
  **`memisl 0x4800_0000` (128 KiB in the script)**, `dram 0x8000_0000`, plus peripheral base
  symbols. `__stack_start` tops the memory island.
- `memisl.ld` places `.text/.misc/.bss/.bulk` all in `memisl` — so host test binaries execute
  out of the memory island, which is what makes offloaded functions reachable by the clusters.
- The only device linker script is the bootrom's `hw/bootrom/snitch/snitch_bootrom.ld`
  (ORIGIN `0x3000_0000`, `__chim_regs = 0x3000_1000`).

## Relationship to Cheshire SW

Chimera inherits Cheshire's toolchain/flag machinery, `libcheshire.a` (printf, drivers,
OpenTitan DIFs, CRT0), the bootrom flow, and the linker-script structure. Chimera adds only the
offload HAL, SoC map, generated SoC-control regs, the `memisl` linker target, and the 8 tests.
Base-host coverage (helloworld, peripherals, DMA) is left to Cheshire's own `sw/tests/`.
