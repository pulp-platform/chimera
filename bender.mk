# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

# Bender defines

COMMON_DEFS ?=
# PULP Cluster defines
COMMON_DEFS += -D FEATURE_ICACHE_STAT
COMMON_DEFS += -D PRIVATE_ICACHE
COMMON_DEFS += -D HIERARCHY_ICACHE_32BIT
# COMMON_DEFS += -D ICAHE_USE_FF
COMMON_DEFS += -D CLUSTER_ALIAS
COMMON_DEFS += -D USE_PULP_PARAMETERS

# Bender targets

COMMON_TARGS ?=
# PULP Cluster targets
COMMON_TARGS += -t pulp_cluster
COMMON_TARGS += -t cluster_standalone
# Other targets
COMMON_TARGS += -t rtl
COMMON_TARGS += -t cv32a6_convolve -t cva6 
#COMMON_TARGS += -t snitch_cluster

# Bender sim arguments

SIM_DEFS  ?=
SIM_TARGS ?= -t test -t sim
