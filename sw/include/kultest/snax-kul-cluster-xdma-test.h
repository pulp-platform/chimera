// Copyright 2024 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Xiaoling Yi <xiaoling.yi@esat.kuleuven.be>

#pragma once

#include "snrt/snrt_TO.h"
#include "snrt/csr.h"

#include "xdma/data.h"

#include "xdma/snax-xdma-csr-addr.h"
#include "xdma/snax-xdma-lib.h"
// #include "xdma/streamer_csr_addr_map.h"


// This is the test function for the SNAX GEMM for Conv2d
// We use several nested loops to iterate over the input data and weights,
// achieving implicit im2col
int kul_cluster_xdma_test();
