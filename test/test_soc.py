# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Run every chimera-sdk simulation test through ctest and report pass/fail.

Each `soc_test` is a ctest case name (see conftest.py). We invoke ctest for that
single case; ctest runs the SoC model (scripts/sim_runner.sh) on the test's
unified ELF, which drives the RTL testbench and returns 0 only if the testbench
printed SUCCESS with no errors.
"""

import os
import subprocess


def test_soc_simulation(soc_test, sim_timeout, request):
    build_dir = request.config.getoption("--build-dir")
    cmd = ["ctest", "--test-dir", build_dir, "-R", f"^{soc_test}$",
           "--output-on-failure", "-V"]

    # Per-test wall-clock timeout, enforced by sim_runner.sh via $SIM_TIMEOUT.
    env = os.environ.copy()
    env["SIM_TIMEOUT"] = str(sim_timeout)

    if request.config.getoption("--sim-verbose"):
        # Inherit stdout/stderr so ctest/vsim output streams live (needs `-s`).
        result = subprocess.run(cmd, env=env)
    else:
        result = subprocess.run(cmd, env=env, capture_output=True, text=True)
        # Surface the sim/transcript output in the pytest report (on failure).
        print(result.stdout)
        if result.stderr:
            print(result.stderr)

    assert result.returncode == 0, f"{soc_test} failed in RTL simulation"
