# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""pytest front-end for the Chimera SoC test suite.

The chimera-sdk build (``TEST_MODE=simulation``) registers one ctest case per
enabled test, each of which runs the unified ELF in the chimera-top RTL
testbench via ``scripts/sim_runner.sh`` (the SoC model binary). This front-end
discovers those ctest cases and runs each as a pytest case, so the *same*
command runs locally and in CI, with JUnit/HTML reporting on top.

Discovery is done with ``ctest --show-only=json-v1`` so pytest and ctest never
drift out of sync.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

CHIM_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BUILD_DIR = CHIM_ROOT / "sw" / "deps" / "chimera-sdk" / "build"

# Per-test sim-timeout overrides (seconds). Tests not listed use --sim-timeout.
# Some cluster tests are legitimately slow in RTL simulation (a single global
# timeout can't fit both a ~30s host test and a multi-minute cluster test).
SIM_TIMEOUT_OVERRIDES = {
    "test_host_uartSimple": 1800,
    "test_snitchCluster_snrt": 3600,  # host-forwarded syscall printf: slowest test in RTL
    "test_snitchCluster_matmul": 1800,  # compute kernel
    "test_snitchCluster_offloadAll": 1800,  # offloading all clusters
}


def pytest_addoption(parser):
    parser.addoption(
        "--build-dir",
        action="store",
        default=str(DEFAULT_BUILD_DIR),
        help="chimera-sdk CMake build directory configured with TEST_MODE=simulation",
    )
    parser.addoption(
        "--sim-verbose",
        action="store_true",
        default=False,
        help="Stream ctest/vsim output live instead of capturing it (use with -s).",
    )
    parser.addoption(
        "--sim-timeout",
        action="store",
        type=int,
        default=300,
        help="Default per-test sim timeout (s); per-test overrides in SIM_TIMEOUT_OVERRIDES.",
    )


@pytest.fixture
def sim_timeout(request):
    """Resolved per-test sim timeout in seconds (override map, else --sim-timeout)."""
    name = request.getfixturevalue("soc_test")
    return SIM_TIMEOUT_OVERRIDES.get(name, request.config.getoption("--sim-timeout"))


def _discover_ctest_tests(build_dir: str):
    """Return the list of ctest test names registered in build_dir (or [])."""
    if shutil.which("ctest") is None or not Path(build_dir).is_dir():
        return []
    try:
        out = subprocess.run(
            ["ctest", "--test-dir", build_dir, "--show-only=json-v1"],
            capture_output=True, text=True, check=True,
        )
        data = json.loads(out.stdout)
        return [t["name"] for t in data.get("tests", [])]
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return []


def _test_markers(name):
    """host/cluster marks so `pytest -m host` / `pytest -m cluster` select subsets."""
    if "snitchCluster" in name:
        return [pytest.mark.cluster]
    if "host" in name:
        return [pytest.mark.host]
    return []


def pytest_generate_tests(metafunc):
    """Parametrize `soc_test` over the ctest cases discovered in the build dir."""
    if "soc_test" not in metafunc.fixturenames:
        return
    build_dir = metafunc.config.getoption("--build-dir")
    tests = _discover_ctest_tests(build_dir)
    if not tests:
        pytest.skip(
            f"No ctest cases in {build_dir}. Build the SDK with TEST_MODE=simulation "
            f"first (make chim-sdk-test-configure)."
        )
    params = [pytest.param(t, marks=_test_markers(t)) for t in tests]
    metafunc.parametrize("soc_test", params, ids=tests)
