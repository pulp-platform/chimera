# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<<<<<<< Updated upstream
## [1.0.0] - 2025-08-08
||||||| Stash base
## [0.2.0] - 2026-04-17

### Added

- `hw`: Add configurable CDC cut removal between SoC and clusters. Clock gating pushed into cluster domain.
- `hw`: Add `apb_dump_msg` module for APB-based fast printf support in simulation.
- `hw`: Add simulation waveform scripts (`waves.tcl`, `run.tcl`).
- `ci`: Add GitLab CI configuration for open repository with bender dependency stage.
- `sw`: Add `pyproject.toml`, replace `requirements.txt` with proper Python packaging.

### Changed

- `hw`: Increase memory island size from 64 KiB to 128 KiB; align linker script accordingly.
- `hw`: Fix Snitch cache configuration.
- `hw`: Bump Snitch Cluster; refactor integration and testbench.

## [0.1.0] - 2025-08-08
=======
## [0.2.0] - 2026-04-17

### Added

- `hw`: Add configurable CDC cut removal between SoC and clusters. Clock gating pushed into cluster domain.
- `hw`: Add `apb_dump_msg` module for APB-based fast printf support in simulation.
- `ci`: Add GitLab CI configuration for open repository with bender dependency stage.
- `sw`: Add `pyproject.toml`, replace `requirements.txt` with proper Python packaging.

### Changed

- `hw`: Increase memory island size from 64 KiB to 128 KiB; align linker script accordingly.
- `hw`: Fix Snitch cache configuration.
- `hw`: Bump Snitch Cluster; refactor integration and testbench.

## [0.1.0] - 2025-08-08
>>>>>>> Stashed changes

### Added

- Initial early public release
