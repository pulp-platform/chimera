// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include "soc_addr_map.h"
#include "offload.h"
#include <stdint.h>

#define NUMCLUSTERS 5

int main() {

    setAllClusterReset(NUMCLUSTERS, 0);
    setAllClusterClockGating(NUMCLUSTERS, 0);

    setClusterClockGating(0, 1);
    setClusterClockGating(3, 1);
    setClusterClockGating(4, 1);

    while (1) {
    }

    return 0;
}
