# Memory Map & Registers (SystemRDL)

Chimera's SoC memory map and control registers are described **once** in SystemRDL under
`cfg/rdl/`, and all downstream artifacts are generated with [`peakrdl`](https://peakrdl.readthedocs.io)
(`make chim-rdl`). This replaces the previous hand-maintained duplication across
`hw/chimera_pkg.sv` localparams, `sw/include/soc_addr_map.h`, and the lowRISC-reggen
register block (`hw/regs/chimera_regs.hjson`).

## Sources (`cfg/rdl/`)

- `chimera_soc_regs.rdl` — the top-level SoC-control register block (Snitch boot/interrupt
  addresses; per-cluster reset, clock-gate, return, busy, wide-memory bypass). Layout matches
  the legacy offsets `0x0–0x6c`.
- `chimera_addrmap.rdl` — the **global address map**: the SoC-control block plus every region
  (bootrom, external cfg regs, HyperBus cfg, the `NrClusters` cluster windows, the memory
  island, and off-chip HyperRAM).

## Generation (`make chim-rdl`)

| Target | Output | Tool |
|--------|--------|------|
| `chim-rdl-markdown` | `docs/addressmap.md` (generated, gitignored) | `peakrdl markdown` |
| `chim-rdl-c-header` | `.generated/chimera_soc_regs.h` | `peakrdl c-header` |
| `chim-rdl-raw-header` | `.generated/chimera_addrmap.{svh,h}` (region base addrs/sizes) | `peakrdl raw-header` |
| `rdl` | all of the above | |

All generated output lands in `.generated/` (gitignored); nothing generated is committed.

## Migration status & plan

Done:
- SoC-control registers + the global address map authored in SystemRDL and validated
  (`peakrdl` emits correct offsets/resets and a region table matching the RTL).

Next (incremental, to avoid breaking the RTL/SW at once):
1. Point `sw/include/soc_addr_map.h` (and the SDK targets' `soc_addr_map.h`) at the generated
   `chimera_addrmap.svh`/`.h` region bases, instead of hand-editing them.
2. Replace the lowRISC-reggen register block (`chimera_reg_pkg.sv` / `chimera_reg_top.sv`,
   `reg_iface`) with `peakrdl regblock`, and retire `hw/regs/chimera_regs.hjson` + `utils/reggen`.
3. Derive `hw/chimera_pkg.sv`'s address-map localparams from the RDL (or assert-check them
   against the generated header in CI) so the three maps can never drift again.
4. Fold in the peripheral register blocks (cheshire, hyperbus, clint) as RDL includes so the
   whole SoC map is one document (cf. Gwaihir's `cfg/rdl/`).
