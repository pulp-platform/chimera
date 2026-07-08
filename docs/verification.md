# Verification

This document describes the **current** simulation/test flow and the **planned** verification
framework. The framework work is tracked in `../TODO.md`.

## Current flow

Simulator: **QuestaSim/vsim only** (`iis-env.sh` pins questa-2022.3; compilation is Bender-driven
via `bender script vsim`).

Testbench (`target/sim/src/`):

- `tb_chimera_soc.sv` — top TB. Reads plusargs `BOOTMODE`, `PRELMODE`, `BINARY`, `IMAGE`.
  Preload modes: JTAG (0), UART (2), **FAST DEBUG (3, default)** which force-writes ELF sections
  directly into memory-island SRAM by hierarchical path, then polls end-of-computation.
- `fixture_chimera_soc.sv` — DUT + clocks (`ClkPeriodClu=2ns`, `ClkPeriodSys=5ns`) + VIP.
- `vip_chimera_soc.sv` — JTAG riscv-dbg driver + tasks (`jtag_init/elf_run/halt/resume/
  wait_for_eoc`, EOC from `CHESHIRE_SCRATCH_2`), UART model/printer, I²C EEPROM, SPI flash, and
  HyperRAM models with `$sdf_annotate`.
- `tb_chimera_pkg.sv` — a sim-side config array (separate from `chimera_pkg::ChimeraCfg`).

How a test runs today:

```sh
make chim-sw
make chim-run-batch BINARY=sw/tests/testClusterOffload.memisl.elf VSIM_FLAGS="-l t.transcript"
./scripts/vsim_ret_error.sh t.transcript      # greps "Errors: N", nonzero if N>0
```

CI (`.gitlab-ci.yml`) runs `init-deps → vsim-build → vsim-test`, where `vsim-test` is a fixed
`parallel:matrix` over `{testCluster, testClusterOffload, testMemBypass, testPeripheralsGating,
testHyperbusAddr, testCfgBootAddr}`, each invoked as above.

### Limitations

- Pass/fail is *grep the transcript* — no structured result, no per-assertion reporting.
- The test list lives only in CI YAML → **cannot be reproduced locally** with one command.
- No golden-model / data-output verification.
- Single simulator; no GVSoC path.

## Planned framework

Design goals: (1) the **exact same test runs locally and in CI**; (2) structured, browsable
reporting; (3) a declarative test registry; (4) built on top of the `chimera-sdk` CMake/ctest
build (see `sdk-integration.md`).

**Chosen tooling: `pytest` as the single top-level runner.** CI (`.gitlab-ci.yml` / GitHub
Actions) does nothing but call `pytest`; so does the developer. Rationale:

- `@pytest.mark.parametrize` expresses the test matrix `(binary, backend, prelmode, expected)` in
  Python — this replaces the CI-only YAML matrix and is the *locally runnable* equivalent of
  Gwaihir's `parallel:matrix` registry.
- fixtures model "build ELFs once (session), launch a sim per test, tear down cleanly".
- `--junitxml` + `pytest-html` give CI-consumable and browsable reports from one run.
- markers (`-m hyperbus`, `-m offload`, `-m "not slow"`) select subsets.
- `pytest-xdist` parallelizes locally, matching CI throughput.

**Layering:** keep `ctest` (already partially wired in chimera-sdk via `add_test` when
`TEST_MODE=simulation`) as the thin CMake-native registration; pytest is the orchestration +
reporting layer on top (it can shell out to `ctest -R <name>` or invoke the sim directly).

**Result contract (adopt from Gwaihir):** the testbench prints a canonical `] SUCCESS` / a
`return code N`, and a single shared checker interprets it (success string / expected nonzero
exit / optional UART match / fail on any `Fatal:`/`Error:`). For data-heavy kernels, dump memory
and run a Python `verify.py` subclassing one shared `Verifier` (`get_expected`/`get_actual`).

> Runner performance is intentionally not a selection criterion — wall-clock is dominated by the
> RTL/GVSoC simulation, so a faster (e.g. Rust) runner would not move the needle and would leave
> the toolchain (Python/uv/CMake) fragmented.

### Sketch

```
tests/
├── conftest.py          # fixtures: build session, sim launcher, transcript parser
├── registry.py          # TEST_MATRIX = [(elf, backend, prelmode, expected), ...]
└── test_soc.py          # @parametrize over registry -> launch sim -> assert on result
```

```yaml
# .gitlab-ci.yml (and mirrored GitHub workflow) — the entire test stage:
test:
  script:
    - pytest --junitxml=report.xml
  artifacts:
    reports: { junit: report.xml }
```

## Migration path

1. Land `chimera-sdk` integration (SW builds via CMake, ELFs land in `build/bin/`).
2. Migrate the 8 tests (+ a new iDMA test) into SDK test dirs.
3. Add the pytest harness + registry; wire the shared result contract into the TB.
4. Replace the CI `vsim-test` matrix and `scripts/vsim_ret_error.sh` with a single `pytest` call.
5. (Optional) add a second simulator and/or a GVSoC backend behind the same `backend` param.
