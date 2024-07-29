# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

COMMON_TARGS ?=
COMMON_TARGS += -t snitch_cluster -t cv32a6_convolve -t cva6 -t rtl

SIM_TARGS = -t test -t sim
