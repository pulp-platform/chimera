// Copyright 2024 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Xiaoling Yi <xiaoling.yi@esat.kuleuven.be>

#include "soc_addr_map.h"
#include "kultest/snax-kul-cluster-xdma-test.h"


// #define XDMA_DEBUG
// #ifdef XDMA_DEBUG
// #define XDMA_DEBUG_PRINT(...) printf(__VA_ARGS__)
// #else
// #define XDMA_DEBUG_PRINT(...)
// #endif

int xdma_memcpy_nd(unsigned char* src, unsigned char* dst, unsigned int* spatial_stride_src,
                       unsigned int* spatial_stride_dst, unsigned int temp_dim_src,
                       unsigned int* temp_stride_src, unsigned int* temp_bound_src,
                       unsigned int temp_dim_dst, unsigned int* temp_stride_dst,
                       unsigned int* temp_bound_dst, unsigned int enabled_chan_src,
                       unsigned int enabled_chan_dst, unsigned int enabled_byte_dst) {
    csrw_ss(XDMA_SRC_ADDR_PTR_LSB, (unsigned int)(uint64_t)src);
    csrw_ss(XDMA_SRC_ADDR_PTR_MSB, (unsigned int)((uint64_t)src >> 32));

    csrw_ss(XDMA_DST_ADDR_PTR_LSB, (unsigned int)(uint64_t)dst);
    csrw_ss(XDMA_DST_ADDR_PTR_MSB, (unsigned int)((uint64_t)dst >> 32));
    // Rule check
    // The enabled spatial bound for input should be equal to the enabled
    // Src frame count and dst frame count should be equal
    // unsigned int src_size = 1;
    // if (temp_dim_src > 0) {
    //     for (unsigned int i = 0; i < temp_dim_src; i++) {
    //         src_size *= temp_bound_src[i];
    //     }
    // }
    // unsigned int dst_size = 1;
    // if (temp_dim_dst > 0) {
    //     for (unsigned int i = 0; i < temp_dim_dst; i++) {
    //         dst_size *= temp_bound_dst[i];
    //     }
    // }
    // if (src_size != dst_size) {
    //     // XDMA_DEBUG_PRINT("src loop and dst loop is not equal\n");
    //     // return -3;
    // }
    // Spatial Stride 0 to XDMA_SRC_SPATIAL_DIM at src
    for (unsigned int i = 0; i < XDMA_SRC_SPATIAL_DIM; i++) {
        csrw_ss(XDMA_SRC_SPATIAL_STRIDE_PTR + i, spatial_stride_src[i]);
    }
    // Spatial Stride 0 to XDMA_DST_SPATIAL_DIM at dst
    for (unsigned int i = 0; i < XDMA_DST_SPATIAL_DIM; i++) {
        csrw_ss(XDMA_DST_SPATIAL_STRIDE_PTR + i, spatial_stride_dst[i]);
    }
    // Temporal Dimension 0 to n at src
    for (unsigned int i = 0; i < temp_dim_src; i++) {
        if (i >= XDMA_SRC_TEMP_DIM) {
            // XDMA_DEBUG_PRINT("Source dimension is too high for xdma\n");
            return -4;
        }
        csrw_ss(XDMA_SRC_TEMP_BOUND_PTR + i, temp_bound_src[i]);
        csrw_ss(XDMA_SRC_TEMP_STRIDE_PTR + i, temp_stride_src[i]);
    }
    // Dimension n to MAX at src
    for (unsigned int i = temp_dim_src; i < XDMA_SRC_TEMP_DIM; i++) {
        csrw_ss(XDMA_SRC_TEMP_BOUND_PTR + i, 1);
        csrw_ss(XDMA_SRC_TEMP_STRIDE_PTR + i, 0);
    }
    // Temporal Dimension 0 to n at dst
    for (unsigned int i = 0; i < temp_dim_dst; i++) {
        if (i >= XDMA_DST_TEMP_DIM) {
            // XDMA_DEBUG_PRINT("Destination dimension is too high for xdma\n");
            return -4;
        }
        csrw_ss(XDMA_DST_TEMP_BOUND_PTR + i, temp_bound_dst[i]);
        csrw_ss(XDMA_DST_TEMP_STRIDE_PTR + i, temp_stride_dst[i]);
    }
    // Dimension n to MAX at dst
    for (unsigned int i = temp_dim_dst; i < XDMA_DST_TEMP_DIM; i++) {
        csrw_ss(XDMA_DST_TEMP_BOUND_PTR + i, 1);
        csrw_ss(XDMA_DST_TEMP_STRIDE_PTR + i, 0);
    }
    // Enabled channel at src
    csrw_ss(XDMA_SRC_ENABLED_CHAN_PTR, enabled_chan_src);
    // Enabled channel at dst
    csrw_ss(XDMA_DST_ENABLED_CHAN_PTR, enabled_chan_dst);
    // Enabled byte at dst
    csrw_ss(XDMA_DST_ENABLED_BYTE_PTR, enabled_byte_dst);
    return 0;
}

int xdma_memcpy_1d(unsigned char* src, unsigned char* dst, unsigned int size) {
    if (size % XDMA_WIDTH != 0) {
        // XDMA_DEBUG_PRINT("Size is not multiple of XDMA_WIDTH\n");
        return -1;
    }
    unsigned int spatial_stride[1] = {XDMA_WIDTH / XDMA_SPATIAL_CHAN};
    unsigned int temporal_stride[1] = {XDMA_WIDTH};
    unsigned int temporal_bound[1] = {size / XDMA_WIDTH};
    unsigned int bound[2] = {XDMA_SPATIAL_CHAN, size / XDMA_WIDTH};
    return xdma_memcpy_nd(src, dst, spatial_stride, spatial_stride, 2,
                          temporal_stride, temporal_bound, 2, temporal_stride,
                          temporal_bound, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
}

// xdma extension interface
int xdma_enable_src_ext(unsigned char ext, unsigned int* csr_value) {
    if (ext >= XDMA_SRC_EXT_NUM) {
        return -1;
    }
    unsigned char custom_csr_list[XDMA_SRC_EXT_NUM] = XDMA_SRC_EXT_CUSTOM_CSR_NUM;
    unsigned int csr_offset = XDMA_SRC_EXT_CSR_PTR;
    for (unsigned char i = 0; i < ext; i++) {
        csr_offset += custom_csr_list[i];
    }

    // Not bypass the xdma extension -> set the corresponding CSR bit to 0
    csrw_ss(XDMA_SRC_BYPASS_PTR, csrr_ss(XDMA_SRC_BYPASS_PTR) & ~(1 << ext));

    for (unsigned char i = 0; i < custom_csr_list[ext]; i++) {
        csrw_ss(csr_offset + i, csr_value[i]);
    }
    return 0;
}
int xdma_enable_dst_ext(unsigned char ext, unsigned int* csr_value) {
    if (ext >= XDMA_DST_EXT_NUM) {
        return -1;
    }
    unsigned char custom_csr_list[XDMA_DST_EXT_NUM] = XDMA_DST_EXT_CUSTOM_CSR_NUM;
    unsigned int csr_offset = XDMA_DST_EXT_CSR_PTR;
    for (unsigned char i = 0; i < ext; i++) {
        csr_offset += custom_csr_list[i];
    }

    // Not bypass the xdma extension -> set the corresponding CSR bit to 0
    csrw_ss(XDMA_DST_BYPASS_PTR, csrr_ss(XDMA_DST_BYPASS_PTR) & ~(1 << ext));
    for (unsigned char i = 0; i < custom_csr_list[ext]; i++) {
        csrw_ss(csr_offset + i, csr_value[i]);
    }
    return 0;
}

int xdma_disable_src_ext(unsigned char ext) {
    if (ext >= XDMA_SRC_EXT_NUM) {
        return 0;
    }
    // Bypass the xdma extension -> set the corresponding CSR bit to 1
    csrw_ss(XDMA_SRC_BYPASS_PTR, csrr_ss(XDMA_SRC_BYPASS_PTR) | (1 << ext));
    return 0;
}

int xdma_disable_dst_ext(unsigned char ext) {
    if (ext >= XDMA_DST_EXT_NUM) {
        return 0;
    }
    // Bypass the xdma extension -> set the corresponding CSR bit to 1
    csrw_ss(XDMA_DST_BYPASS_PTR, csrr_ss(XDMA_DST_BYPASS_PTR) | (1 << ext));
    return 0;
}

// Start xdma
unsigned int xdma_start() {
    int ret = csrr_ss(XDMA_COMMIT_TASK_PTR);
    csrw_ss(XDMA_START_PTR, 1);
    while (csrr_ss(XDMA_COMMIT_TASK_PTR) == ret) {
        // Wait for xdma to start
    }
    return csrr_ss(XDMA_COMMIT_TASK_PTR);
}

// Check if xdma is finished
bool xdma_is_finished(unsigned int task_id) {
    return csrr_ss(XDMA_FINISH_TASK_PTR) >= task_id;
}

void xdma_wait(unsigned int task_id) {
    while (!xdma_is_finished(task_id)) {
        // Wait for xdma to finish
    }
}

// This is the test function for the SNAX XDMA doing a maxpool operation
extern unsigned int __global_pointer$;

int kul_cluster_xdma_test() {
    // wake up the dma core, not work...
    // if (snrt_cluster_core_idx() == 0) {
    // volatile uint32_t *interruptTarget = ((uint32_t *)CLINT_CTRL_BASE) + 6 + 1;
    // *interruptTarget = 1;
    // }

    // !!! set the stack pointer and global pointer !!!
    // set it to the end of the KUL cluster TCDM (size = 128KB) address - 4
    unsigned int stack_start = snrt_cluster_base_addrl() + 128 * 1024 - 4;
    asm("mv sp, %0" ::"r"((unsigned int)stack_start));
    unsigned int gp_value = (unsigned int)(&__global_pointer$);
    asm("mv gp, %0" ::"r"(gp_value));


    // Set err value for checking
    int err = 0;
    // Obtain the start address of the TCDM memory
    unsigned int dma_load_input_start;
    unsigned int dma_load_input_end;
    unsigned int tcdm_baseaddress = snrt_cluster_base_addrl();
    // Put the input at the starting of tcdm
    unsigned char *tcdm_in = (unsigned char *)tcdm_baseaddress;
    // Put the output at the middle of tcdm
    unsigned char *tcdm_out = (unsigned char *)(tcdm_baseaddress + delta_local_out);

    if (snrt_is_dm_core()) {
        // --------------------------------//
        // -------------source cfg---------//
        // --------------------------------//
        // source base ptr
        write_csr(960, (unsigned int)tcdm_in);
        write_csr(961, 0);

        // spatial strides
        write_csr(962, 8);
        
        // temporal bounds
        write_csr(963, 1);
        write_csr(964, 1);
        write_csr(965, 1);
        write_csr(966, 1);
        write_csr(967, 1);
        write_csr(968, 1);

        // temporal strides
        write_csr(969, 64);
        write_csr(970, 64);
        write_csr(971, 64);
        write_csr(972, 64);
        write_csr(973, 64);
        write_csr(974, 64);

        // XDMA_SRC_ENABLED_CHAN_PTR
        write_csr(975, 0xFFFFFFFF);

        // --------------------------------//
        // -------------dest cfg---------//
        // --------------------------------//
        // dest base ptr
        write_csr(976, (unsigned int)tcdm_out);
        write_csr(977, 0);

        // spatial strides
        write_csr(978, 8);

        // temporal bounds
        write_csr(979, 1);
        write_csr(980, 1);
        write_csr(981, 1);
        write_csr(982, 1);
        write_csr(983, 1);
        write_csr(984, 1);

        // temporal strides
        write_csr(985, 64);
        write_csr(986, 64);
        write_csr(987, 64);
        write_csr(988, 64);
        write_csr(989, 64);
        write_csr(990, 64);

        // XDMA_DST_ENABLED_CHAN_PTR
        write_csr(991, 0xFFFFFFFF);

        // XDMA_DST_ENABLED_BYTE_PTR
        write_csr(992, 0xFFFFFFFF);

        // XDMA_DST_BYPASS_PTR
        write_csr(993, 0b101);

        // XDMA_DST_EXT_CSR_PTR 
        // the second extension is enabled and cfg is 1
        // jump 994
        write_csr(995, 0b1);

        // start
        // XDMA_START_PTR 
        write_csr(996, 1);

        // XDMA_COMMIT_TASK_PTR 
        int task_id = read_csr(997);
        // XDMA_FINISH_TASK_PTR 
        while (read_csr(998) < task_id) {
        }

        // // The xdma core is the last compute core in the cluster
        // unsigned int sstride_src[1] = {0};
        // unsigned int sstride_dst[1] = {0};
        // unsigned int tstride_src[5] = {0};
        // unsigned int tbound_src[5] = {0};
        // unsigned int tstride_dst[3] = {0};
        // unsigned int tbound_dst[3] = {0};

        // // Load the CFG from data.h
        // sstride_src[0] = spatialStride1_in;
        // sstride_dst[0] = spatialStride1_out;
        // tstride_src[0] = tempStride0_in;
        // tstride_src[1] = tempStride1_in;
        // tstride_src[2] = tempStride2_in;
        // tstride_src[3] = tempStride3_in;
        // tstride_src[4] = tempStride4_in;
        // tbound_src[0] = tempLoop0_in;
        // tbound_src[1] = tempLoop1_in;
        // tbound_src[2] = tempLoop2_in;
        // tbound_src[3] = tempLoop3_in;
        // tbound_src[4] = tempLoop4_in;
        // tstride_dst[0] = tempStride0_out;
        // tstride_dst[1] = tempStride1_out;
        // tstride_dst[2] = tempStride2_out;
        // tbound_dst[0] = tempLoop0_out;
        // tbound_dst[1] = tempLoop1_out;
        // tbound_dst[2] = tempLoop2_out;

        // // First we need to transfer the input data from L3->TCDM
        // snrt_dma_start_1d(tcdm_in, DataIn, input_data_len * sizeof(int8_t));
        // snrt_dma_wait_all();

        // // --------------------- Configure the Ext --------------------- //

        // if (xdma_disable_dst_ext(0) != 0) {
        //     err++;
        // } else {
        // }

        // unsigned int ext_param_maxpool_size[1] = {reduceLen};
        // if (xdma_enable_dst_ext(1, ext_param_maxpool_size) != 0) {
        //     err++;
        // } else {
        // }

        // if (xdma_disable_dst_ext(2) != 0) {
        //     err++;
        // } else {
        // }

        // // --------------------- Configure the AGU --------------------- //
        // xdma_memcpy_nd(tcdm_in, tcdm_out, sstride_src, sstride_dst, 5,
        //                tstride_src, tbound_src, 3, tstride_dst, tbound_dst,
        //                0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
        // int task_id = xdma_start();
        // xdma_wait(task_id);

        // --------------------- Checking the Results --------------------- //
        for (int i = 0; i < output_data_len; i++) {
            if ((int8_t)tcdm_out[i] != C_golden[i]) {
                err++;
            }
        }
    }

    return err;
}
