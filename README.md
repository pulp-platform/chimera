<h1 align="center">Chimera: A Flexible Multi-Accelerator Framework for Heterogeneous SoC Integration</h1>

<a href="https://pulp-platform.org">
<img src="docs/img/pulp_logo_icon.svg" alt="Logo" width="100" align="right">
</a>

Chimera is an open-source, highly configurable microcontroller System-on-Chip (SoC) template designed for multi-cluster, heterogeneous computing systems. Its primary objective is to provide a modular platform for seamlessly integrating and managing hardware accelerators, offering developers and researchers an intuitive and extensible foundation.\
Chimera is developed as part of the [PULP (Parallel Ultra-Low Power) Platform](https://pulp-platform.org/), a joint effort between ETH Zurich and the University of Bologna.

<div align="center">

[![CI status](https://github.com/pulp-platform/chimera/actions/workflows/gitlab-ci.yml/badge.svg?branch=main)](https://github.com/pulp-platform/chimera/actions/workflows/gitlab-ci.yml?query=branch%3Main)
[![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/pulp-platform/chimera?color=blue&label=current&sort=semver)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-red)](LICENSE-APACHE)
[![License](https://img.shields.io/badge/license-SHL--0.51-red)](LICENSE-SHL)

[Getting started](#-getting-started)
[Build RTL](#️-build-rtl)
[Platform Simulation](#platform-simulation)
[Formatting](#-formatting)
</div>

## 📜 License
Unless specified otherwise in the respective file headers, all code in this repository is released under permissive licenses.
- Hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see [LICENSE-SHL](LICENSE-SHL)) or compatible licenses.
- Register file code (e.g. [hw/regs/*.sv](hw/regs/)) is generated using a fork of lowRISC's [regtool](https://github.com/lowRISC/opentitan/blob/master/util/regtool.py) and is licensed under Apache 2.0 (see [LICENSE-APACHE](LICENSE-APACHE)).
- All software sources are licensed under Apache 2.0.

## 👥 Contributing

If you would like to contribute to this project, please check our [contribution guidelines](CONTRIBUTING.md).

## 🚀 Getting started
### Environment setup for IIS-members
For IIS members, set up the environment by sourcing the `iis-env.sh` script:
```sh
source iis-env.sh
```

### Environment for non IIS-members
Non-IIS users need to follow a few more steps to set up the environment properly.

#### Bender
Chimera uses [Bender](https://github.com/pulp-platform/bender) to manage hardware dependencies and automatically generate compilation scripts.

#### Python environment
Python 3.11 or later is required. Create and activate a virtual environment:
```sh
make python-venv
source .venv/bin/activate
```
You can override the Python version using the `BASE_PYTHON` environment variable.
Dependencies are listed in `requirements.txt` and handled via the `python-venv` target.

#### Toolchain
Chimera requires a working RISC-V GCC toolchain for building the Cheshire 32-bit host code. Follow the _Installation (Newlib)_ instructions from [pulp-platform/riscv-gni-toolchain](https://github.com/pulp-platform/riscv-gnu-toolchain).\
After installation, export the toolchain path:
```shell
export RISCV_GCC_BINROOT=/path/to/gcc/bin
export $PATH=$PATH:$RISCV_GCC_BINROOT
```
To verify that the toolchain is in your path:
```shell
which riscv32-unknown-elf-gcc
```

### 🛠️ Build RTL
If you have all needed dependencies and you want to build the full Chimera SoC, both RTL and SW, run:
``` sh
make chim-all
```
Or for more selective builds:
```sh
make chw-hw-init
make snitch-hw-init
make chim-sw
make chim-bootrom-init
```
⚠️ You must build the software (`chim-sw`) before building the boot ROM (`chim-bootrom-init`).

### Compile Software Tests
To compile the software for Cheshire:
```sh
make chim-sw
```

### Platform simulation
To run simulations, ensure you have Questa installed and accessible via vsim (`which vsim`).\
To compile the hardware run `make chim-sim`.\
To run a simulation, use the `chim-run` target. You must specify the path to the compiled Cheshire binary using the `BINARY` variable:
```sh
make chim-run-batch BINARY=path/to/sw/tests.elf
```
To run the simulation in batch mode, use the `chim-run-batch` target.

### Additional Help
To list all available make targets and their descriptions:
```sh
make help
```

## 🧼 Formatting

### Verilog Formatting
To format all hardware source files:

```sh
verible-verilog-format --flagfile .verilog_format --inplace --verbose hw/*.sv target/sim/src/*.sv
```

### CXX Formatting
To format all files in the `sw/` directory, run
```sh
python scripts/run_clang_format.py -ir sw/
```

Our CI uses llvm-12 for clang-format. On IIS machines, run:
```sh
python scripts/run_clang_format.py -ir sw/ --clang-format-executable=/usr/pack/riscv-1.0-kgf/pulp-llvm-0.12.0/bin/clang-format

python scripts/run_clang_format.py -ir hw/ --clang-format-executable=/usr/pack/riscv-1.0-kgf/pulp-llvm-0.12.0/bin/clang-format
```
If you're not using the IIS setup, specify a valid `clang-format-12` binary instead.
.

