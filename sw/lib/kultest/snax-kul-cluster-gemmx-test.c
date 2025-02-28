// Copyright 2024 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Xiaoling Yi <xiaoling.yi@esat.kuleuven.be>

#include "soc_addr_map.h"
#include "kultest/snax-kul-cluster-gemmx-test.h"


int32_t gen_size_config(uint8_t Batch, uint8_t M, uint8_t K, uint8_t N) {
    return ((int32_t)Batch << 24) | ((int32_t)M << 16) | ((int32_t)K << 8) |
           (int32_t)N;
}

int32_t gen_subtraction_config(int8_t subtraction_a, int8_t subtraction_b) {
    return ((uint8_t)subtraction_b << 8) | (uint8_t)subtraction_a;
}

int32_t gen_csr0_config(uint8_t input_zp_i, uint8_t output_zp_i,
                        uint8_t max_int_i, uint8_t min_int_i) {
    // encode the configuration into a single 32-bit integer
    return ((int32_t)min_int_i << 24) | ((int32_t)max_int_i << 16) |
           ((int32_t)output_zp_i << 8) | (int32_t)input_zp_i;
}

int32_t gen_csr1_config(bool double_round_i) {
    // encode the configuration into a single 32-bit integer
    return (uint32_t)double_round_i;
}

// Set STREAMER configuration CSR
void set_gemmx_streamer_csr(
    int Aslstride0, int Aslstride1, int Atlbound0, int Atlstride0,
    int Atlbound1, int Atlstride1, int Atlbound2, int Atlstride2, int Atlbound3,
    int Atlstride3, int Atlbound4, int Atlstride4, int Atlbound5,
    int Atlstride5, int set_addr_remap_index_A,

    int Bslstride0, int Bslstride1, int Btlbound0, int Btlstride0,
    int Btlbound1, int Btlstride1, int Btlbound2, int Btlstride2,
    int set_addr_remap_index_B,

    int D8slstride0, int D8slstride1, int D8tlbound0, int D8tlstride0,
    int D8tlbound1, int D8tlstride1, int D8tlbound2, int D8tlstride2,
    int set_addr_remap_index_D8,

    int Cslstride0, int Cslstride1, int Ctlbound0, int Ctlstride0,
    int Ctlbound1, int Ctlstride1, int Ctlbound2, int Ctlstride2,
    int set_addr_remap_index_C,

    int D32slstride0, int D32slstride1, int D32tlbound0, int D32tlstride0,
    int D32tlbound1, int D32tlstride1, int D32tlbound2, int D32tlstride2,
    int set_addr_remap_index_D32,

    int delta_local_a, int delta_local_b, int delta_local_d8, int delta_local_c,
    int delta_local_d32, int bypassSIMD, int32_t transpose_A,
    int32_t transpose_B, int32_t channel_en_C, int32_t broadcast_C) {
    // base ptr for A
    write_csr(BASE_PTR_READER_0_LOW, (uint32_t)(delta_local_a + snrt_cluster_base_addrl()));

    // spatial strides for A
    write_csr(S_STRIDE_READER_0_0, Aslstride1);

    // loop bounds, from innermost to outermost, for data mover A
    write_csr(T_BOUND_READER_0_0, Atlbound0);
    write_csr(T_BOUND_READER_0_1, Atlbound1);
    write_csr(T_BOUND_READER_0_2, Atlbound2);
    write_csr(T_BOUND_READER_0_3, Atlbound3);
    write_csr(T_BOUND_READER_0_4, Atlbound4);
    write_csr(T_BOUND_READER_0_5, Atlbound5);

    // temporal strides for A
    write_csr(T_STRIDE_READER_0_0, Atlstride0);
    write_csr(T_STRIDE_READER_0_1, Atlstride1);
    write_csr(T_STRIDE_READER_0_2, Atlstride2);
    write_csr(T_STRIDE_READER_0_3, Atlstride3);
    write_csr(T_STRIDE_READER_0_4, Atlstride4);
    write_csr(T_STRIDE_READER_0_5, Atlstride5);

    // set the address remap index for A
    write_csr(ADDR_REMAP_INDEX_READER_0, set_addr_remap_index_A);

    // base ptr for B
    write_csr(BASE_PTR_READER_1_LOW, (uint32_t)(delta_local_b + snrt_cluster_base_addrl()));

    // spatial strides for B
    write_csr(S_STRIDE_READER_1_0, Bslstride1);

    // loop bounds, from innermost to outermost, for data mover B
    write_csr(T_BOUND_READER_1_0, Btlbound0);
    write_csr(T_BOUND_READER_1_1, Btlbound1);
    write_csr(T_BOUND_READER_1_2, Btlbound2);

    // temporal strides for B
    write_csr(T_STRIDE_READER_1_0, Btlstride0);
    write_csr(T_STRIDE_READER_1_1, Btlstride1);
    write_csr(T_STRIDE_READER_1_2, Btlstride2);

    // set the address remap index for B
    write_csr(ADDR_REMAP_INDEX_READER_1, set_addr_remap_index_B);

    // base ptr for D8
    write_csr(BASE_PTR_WRITER_0_LOW, (uint32_t)(delta_local_d8 + snrt_cluster_base_addrl()));

    // spatial strides for D8
    write_csr(S_STRIDE_WRITER_0_0, D8slstride1);

    // for D8, from N to M
    if (bypassSIMD == 0) {
        write_csr(T_BOUND_WRITER_0_0, D8tlbound0);
        write_csr(T_BOUND_WRITER_0_1, D8tlbound1);
        write_csr(T_BOUND_WRITER_0_2, D8tlbound2);
    } else {
        write_csr(T_BOUND_WRITER_0_0, 0);
        write_csr(T_BOUND_WRITER_0_1, 0);
        write_csr(T_BOUND_WRITER_0_2, 0);
    }

    // temporal strides for D8
    write_csr(T_STRIDE_WRITER_0_0, D8tlstride0);
    write_csr(T_STRIDE_WRITER_0_1, D8tlstride1);
    write_csr(T_STRIDE_WRITER_0_2, D8tlstride2);

    // set the address remap index for D8
    write_csr(ADDR_REMAP_INDEX_WRITER_0, set_addr_remap_index_D8);

    // base ptr for C
    write_csr(BASE_PTR_READER_WRITER_0_LOW,
            (uint32_t)(delta_local_c + snrt_cluster_base_addrl()));

    // spatial strides for C
    write_csr(S_STRIDE_READER_WRITER_0_0, Cslstride0);
    write_csr(S_STRIDE_READER_WRITER_0_1, Cslstride1);

    // loop bounds, from innermost to outermost, for data mover C
    write_csr(T_BOUND_READER_WRITER_0_0, Ctlbound0);
    write_csr(T_BOUND_READER_WRITER_0_1, Ctlbound1);
    write_csr(T_BOUND_READER_WRITER_0_2, Ctlbound2);

    // temporal strides for C
    write_csr(T_STRIDE_READER_WRITER_0_0, Ctlstride0);
    write_csr(T_STRIDE_READER_WRITER_0_1, Ctlstride1);
    write_csr(T_STRIDE_READER_WRITER_0_2, Ctlstride2);

    // set the address remap index for C
    write_csr(ADDR_REMAP_INDEX_READER_WRITER_0, set_addr_remap_index_C);

#ifdef ENABLED_CHANNEL_READER_WRITER_0
    write_csr(ENABLED_CHANNEL_READER_WRITER_0, channel_en_C);
#endif

#ifdef C_BROADCAST_EXTENSION_ENABLE
    write_csr(C_BROADCAST_CSR_READER_WRITER_0, broadcast_C == 1 ? 0 : 1);
#endif

    // base ptr for D32
    write_csr(BASE_PTR_READER_WRITER_1_LOW,
            (uint32_t)(delta_local_d32 + snrt_cluster_base_addrl()));

    // spatial strides for D32
    write_csr(S_STRIDE_READER_WRITER_1_0, D32slstride0);
    write_csr(S_STRIDE_READER_WRITER_1_1, D32slstride1);

    // for D32, from N to M
    if (bypassSIMD == 0) {
        write_csr(T_BOUND_READER_WRITER_1_0, 0);
        write_csr(T_BOUND_READER_WRITER_1_1, 0);
        write_csr(T_BOUND_READER_WRITER_1_2, 0);
    } else {
        write_csr(T_BOUND_READER_WRITER_1_0, D32tlbound0);
        write_csr(T_BOUND_READER_WRITER_1_1, D32tlbound1);
        write_csr(T_BOUND_READER_WRITER_1_2, D32tlbound2);
    }

    // temporal strides for D32
    write_csr(T_STRIDE_READER_WRITER_1_0, D32tlstride0);
    write_csr(T_STRIDE_READER_WRITER_1_1, D32tlstride1);
    write_csr(T_STRIDE_READER_WRITER_1_2, D32tlstride2);

    // set the address remap index for D32
    write_csr(ADDR_REMAP_INDEX_READER_WRITER_1, set_addr_remap_index_D32);

    // set the transpose
#ifdef TRANSPOSE_EXTENSION_ENABLE
    write_csr(TRANSPOSE_CSR_READER_0, transpose_A == 0 ? 1 : 0);
    write_csr(TRANSPOSE_CSR_READER_1, transpose_B == 0 ? 1 : 0);
#endif
}

// Set GEMM configuration CSR
void set_gemmx_csr(int tempLoop0, int tempLoop1, int tempLoop2,
                   int subtractions, uint32_t csr0, uint32_t csr1,
                   int shared_bitpacked_shift0, int shared_bitpacked_shift1,
                   int shared_multiplier0, int shared_multiplier1,
                   int shared_multiplier2, int shared_multiplier3,
                   int shared_multiplier4, int shared_multiplier5,
                   int shared_multiplier6, int shared_multiplier7,
                   uint32_t temporal_loop_bound, uint32_t bypassSIMD) {
    // set loop bounds, from innermost to outermost, aka from K to N to M
    write_csr(T_BOUND_K, tempLoop0);
    write_csr(T_BOUND_N, tempLoop1);
    write_csr(T_BOUND_M, tempLoop2);

    // set subtraction a and b
    write_csr(SUBTRACTIONS, subtractions);

    // set the constants for the SIMD unit
    write_csr(SIMD_CSR0, csr0);
    write_csr(SIMD_CSR1, csr1);

    // set the shared bitpacked shift
    write_csr(SIMD_SHARED_BITPACKED_SHIFT0, shared_bitpacked_shift0);
    write_csr(SIMD_SHARED_BITPACKED_SHIFT1, shared_bitpacked_shift1);

    // set the shared multipliers
    write_csr(SIMD_SHARED_MULTIPLIER0, shared_multiplier0);
    write_csr(SIMD_SHARED_MULTIPLIER1, shared_multiplier1);
    write_csr(SIMD_SHARED_MULTIPLIER2, shared_multiplier2);
    write_csr(SIMD_SHARED_MULTIPLIER3, shared_multiplier3);
    write_csr(SIMD_SHARED_MULTIPLIER4, shared_multiplier4);
    write_csr(SIMD_SHARED_MULTIPLIER5, shared_multiplier5);
    write_csr(SIMD_SHARED_MULTIPLIER6, shared_multiplier6);
    write_csr(SIMD_SHARED_MULTIPLIER7, shared_multiplier7);

    // set the temporal loop bound
    write_csr(TEMPORAL_LOOP_BOUND, temporal_loop_bound);

    write_csr(BYPASS_SIMD, bypassSIMD);
}

// Stall until Streamer and GEMM accelerator finish
void wait_gemmx_and_streamer() {
    write_csr(STREAMER_START_CSR, 0);
    write_csr(STREAMER_START_CSR, 0);
    while (read_csr(GEMMX_BUSY)) {
    }
    while (read_csr(STREAMER_BUSY_CSR)) {
    }
    write_csr(GEMMX_START, 0);
}

// Read performance counter of the Streamer, a read-only CSR
uint32_t read_gemmx_streamer_perf_counter() {
    uint32_t perf_counter = read_csr(STREAMER_PERFORMANCE_COUNTER_CSR);
    return perf_counter;
}

// Read performance counter of GEMM, a read-only CSR
uint32_t read_gemmx_perf_counter() {
    uint32_t perf_counter = read_csr(GEMMX_PERFORMANCE_COUNTER);
    return perf_counter;
}

uint32_t check_gemmx_result_D8(int8_t* output, int8_t* output_golden,
                               int32_t Batch, int32_t M, int32_t N,
                               bool banked_data_layout) {
    uint32_t err = 0;
    uint32_t size = 0;
    size = Batch * M * N * meshRow * meshCol;

    if (banked_data_layout) {
        for (int i = 0; i < size / 64; i += 1) {
            for (int j = 0; j < 64; j++) {
                if (*(output + i * 256 + j) != output_golden[i * 64 + j]) {
                    err++;
                }
            }
        }
    } else {
        for (int i = 0; i < size; i++) {
            if (output[i] != output_golden[i]) {
                err++;
            }
        }
    }

    return err;
}

uint32_t check_gemmx_result_D32(int32_t* output, int32_t* output_golden,
                                int32_t Batch, int32_t M, int32_t N,
                                bool banked_data_layout) {
    uint32_t err = 0;
    uint32_t size = 0;
    size = Batch * M * N * meshRow * meshCol;

    if (banked_data_layout) {
        for (int i = 0; i < size / 16; i += 1) {
            for (int j = 0; j < 16; j++) {
                if (*(output + i * (256 / 4) + j) !=
                    output_golden[i * 16 + j]) {
                    err++;
                }
            }
        }
    } else {
        for (int i = 0; i < size; i++) {
            if (output[i] != output_golden[i]) {
                err++;
            }
        }
    }

    return err;
}

// This is the test function for the SNAX GEMM for Conv2d
// We use several nested loops to iterate over the input data and weights,
// achieving implicit im2col
extern uint32_t __global_pointer$;

int kul_cluster_gemmx_test() {
    // wake up the dma core, not work...
    // if (snrt_cluster_core_idx() == 0) {
    // volatile uint32_t *interruptTarget = ((uint32_t *)CLINT_CTRL_BASE) + 6 + 1;
    // *interruptTarget = 1;
    // }
    // !!! set the stack pointer and global pointer !!!
    // set it to the end of the KUL cluster TCDM (size = 128KB) address - 4
    uint32_t stack_start = snrt_cluster_base_addrl() + 128 * 1024 - 4;
    asm("mv sp, %0" ::"r"((uint32_t)stack_start));
    uint32_t gp_value = (uint32_t)(&__global_pointer$);
    asm("mv gp, %0" ::"r"(gp_value));

    // Set err value for checking
    int err = 0;

    // Prepare addresses pointers in TCDM for DMA
    int8_t *local_a_dma, *local_b_dma;
    int32_t *local_c_dma, *local_d32_dma;
    int8_t *local_d8_dma;

    // Allocate space in TCDM for DMA
    local_a_dma = (int8_t *)(snrt_cluster_base_addrl() + delta_physical_a);
    local_b_dma = (int8_t *)(snrt_cluster_base_addrl() + delta_physical_b);
    local_c_dma = (int32_t *)(snrt_cluster_base_addrl() + delta_physical_c);
    local_d32_dma = (int32_t *)(snrt_cluster_base_addrl() + delta_physical_d32);
    local_d8_dma = (int8_t *)(snrt_cluster_base_addrl() + delta_physical_d8);

    // Prepare addresses pointers in TCDM for streamer
    int8_t *local_a, *local_b;
    int32_t *local_c, *local_d32;
    int8_t *local_d8;

    // Allocate space in TCDM for streamer
    local_a = (int8_t *)(snrt_cluster_base_addrl() + delta_local_a);
    local_b = (int8_t *)(snrt_cluster_base_addrl() + delta_local_b);
    local_c = (int32_t *)(snrt_cluster_base_addrl() + delta_local_c);
    local_d32 = (int32_t *)(snrt_cluster_base_addrl() + delta_local_d32);
    local_d8 = (int8_t *)(snrt_cluster_base_addrl() + delta_local_d8);

    // Transfer data from L3 to L1
    // Using DMA only
    if (snrt_is_dm_core()) {
        if (interleaved_address == 1) {
            snrt_dma_start_1d(local_a, A,
                              Nbatch * (H + 2 * pad_h) * (W + 2 * pad_w) * Cin *
                                  sizeof(int8_t));
            snrt_dma_start_1d(local_b, B,
                              Cout * Kh * Kw * Cin * sizeof(int8_t));
        } else {
            snrt_dma_start_2d(
                local_a_dma, A, 64 * sizeof(int8_t), 256, 64,
                Nbatch * (H + 2 * pad_h) * (W + 2 * pad_w) * Cin / 64);
            snrt_dma_start_2d(local_b_dma, B, 64 * sizeof(int8_t), 256, 64,
                              Cout * Kh * Kw * Cin / 64);
        }
        snrt_dma_wait_all();
    }

    // Wait for DMA to finish
    snrt_cluster_hw_barrier();
    if (snrt_is_dm_core()) {
        if (interleaved_address == 1) {
            snrt_dma_start_1d(local_c, C,
                              M * N * meshRow * meshCol * sizeof(int32_t));
        } else {
            snrt_dma_start_2d(local_c_dma, C, 16 * sizeof(int32_t), 256,
                              16 * sizeof(int32_t),
                              M * N * meshRow * meshCol / 16);
        }
        snrt_dma_wait_all();
    }

    snrt_cluster_hw_barrier();

    if (snrt_cluster_core_idx() == 0) {
        // Set Streamer configuration CSR for conv2d
        set_gemmx_streamer_csr(
            Aslstride0, Aslstride1, Atlbound0, Atlstride0, Atlbound1,
            Atlstride1, Atlbound2, Atlstride2, Atlbound3, Atlstride3, Atlbound4,
            Atlstride4, Atlbound5, Atlstride5, set_addr_remap_index_A,

            Bslstride0, Bslstride1, Btlbound0, Btlstride0, Btlbound1,
            Btlstride1, Btlbound2, Btlstride2, set_addr_remap_index_B,

            D8slstride0, D8slstride1, D8tlbound0, D8tlstride0, D8tlbound1,
            D8tlstride1, D8tlbound2, D8tlstride2, set_addr_remap_index_D8,

            Cslstride0, Cslstride1, Ctlbound0, Ctlstride0, Ctlbound1,
            Ctlstride1, Ctlbound2, Ctlstride2, set_addr_remap_index_C,

            D32slstride0, D32slstride1, D32tlbound0, D32tlstride0, D32tlbound1,
            D32tlstride1, D32tlbound2, D32tlstride2, set_addr_remap_index_D32,

            delta_local_a, delta_local_b, delta_local_d8, delta_local_c,
            delta_local_d32, bypassSIMD, transposed_A, transposed_B,
            channel_en_C, broadcast_C);

        // Set GEMMX configuration CSR
        uint32_t subtraction_setting =
            gen_subtraction_config(subtraction_a, subtraction_b);

        uint32_t csr0 =
            gen_csr0_config(input_zp_i, output_zp_i, max_int_i, min_int_i);
        uint32_t csr1 = gen_csr1_config(double_round_i);

        set_gemmx_csr(
            K, N, M, subtraction_setting, csr0, csr1, shared_bitpacked_shift0,
            shared_bitpacked_shift1, shared_multiplier0, shared_multiplier1,
            shared_multiplier2, shared_multiplier3, shared_multiplier4,
            shared_multiplier5, shared_multiplier6, shared_multiplier7, M * N,
            bypassSIMD);

        // Set CSR to start Streamer for conv2d
        set_gemmx_streamer_start();

        // Set CSR to start GEMM
        set_gemmx_start();

        // Poll until Streamer and GEMM accelerator finish
        wait_gemmx_and_streamer();

        // check the result of the implicit im2col convolution
        if (interleaved_address == 1) {
            if (!bypassSIMD) {
                err += check_gemmx_result_D8(local_d8, D8, Batch, M, N, false);
            } else {
                err +=
                    check_gemmx_result_D32(local_d32, D32, Batch, M, N, false);
            }
        } else {
            if (!bypassSIMD) {
                err +=
                    check_gemmx_result_D8(local_d8_dma, D8, Batch, M, N, true);
            } else {
                err += check_gemmx_result_D32(local_d32_dma, D32, Batch, M, N,
                                              true);
            }
        }

    };

    return err;

}
