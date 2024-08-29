#pragma once

#include <stddef.h>

// --------------------------------------------------------------------------------
// --------------------------- Core IDX functions ----------------------------------
// --------------------------------------------------------------------------------

#define SNRT_CLUSTER_DM_CORE_NUM 1

inline uint32_t __attribute__((const)) snrt_cluster_base_addrl() {
    uint32_t base_address_l;
    asm("csrr %0, 0xbc1" : "=r"(base_address_l));
    return base_address_l;
}

inline uint32_t __attribute__((const)) snrt_cluster_core_idx() {
    // return snrt_global_core_idx() % snrt_cluster_core_num();
    uint32_t cluster_core_id;
    asm("csrr %0, 0xbc3" : "=r"(cluster_core_id));
    return cluster_core_id & 0xffff;
}

inline uint32_t __attribute__((const)) snrt_cluster_core_num() {
    // return SNRT_CLUSTER_CORE_NUM;
    uint32_t cluster_core_id;
    asm("csrr %0, 0xbc3" : "=r"(cluster_core_id));
    return cluster_core_id >> 16;
}

inline uint32_t __attribute__((const)) snrt_cluster_dm_core_num() {
    return SNRT_CLUSTER_DM_CORE_NUM;
}

inline uint32_t __attribute__((const)) snrt_cluster_compute_core_num() {
    return snrt_cluster_core_num() - snrt_cluster_dm_core_num();
}

inline int __attribute__((const)) snrt_is_compute_core() {
    return snrt_cluster_core_idx() < snrt_cluster_compute_core_num();
}

inline int __attribute__((const)) snrt_is_dm_core() {
    return !snrt_is_compute_core();
}


// --------------------------------------------------------------------------------
// --------------------------- DMA functions --------------------------------------
// --------------------------------------------------------------------------------

/// A DMA transfer identifier.
typedef uint32_t snrt_dma_txid_t;

/// Initiate an asynchronous 1D DMA transfer with wide 64-bit pointers.
inline snrt_dma_txid_t snrt_dma_start_1d_wideptr(uint64_t dst, uint64_t src,
                                                 size_t size) {
    // Current DMA does not allow transfers with size == 0 (blocks)
    // TODO(colluca) remove this check once new DMA is integrated
    if (size > 0) {
        register uint32_t reg_dst_low asm("a0") = dst >> 0;    // 10
        register uint32_t reg_dst_high asm("a1") = dst >> 32;  // 11
        register uint32_t reg_src_low asm("a2") = src >> 0;    // 12
        register uint32_t reg_src_high asm("a3") = src >> 32;  // 13
        register uint32_t reg_size asm("a4") = size;           // 14

        // dmsrc a2, a3
        asm volatile(
            ".word (0b0000000 << 25) | \
                (     (13) << 20) | \
                (     (12) << 15) | \
                (    0b000 << 12) | \
                (0b0101011 <<  0)   \n" ::"r"(reg_src_high),
            "r"(reg_src_low));

        // dmdst a0, a1
        asm volatile(
            ".word (0b0000001 << 25) | \
                (     (11) << 20) | \
                (     (10) << 15) | \
                (    0b000 << 12) | \
                (0b0101011 <<  0)   \n" ::"r"(reg_dst_high),
            "r"(reg_dst_low));

        // dmcpyi a0, a4, 0b00
        register uint32_t reg_txid asm("a0");  // 10
        asm volatile(
            ".word (0b0000010 << 25) | \
                (  0b00000 << 20) | \
                (     (14) << 15) | \
                (    0b000 << 12) | \
                (     (10) <<  7) | \
                (0b0101011 <<  0)   \n"
            : "=r"(reg_txid)
            : "r"(reg_size));

        return reg_txid;
    } else {
        return -1;
    }
}

/// Initiate an asynchronous 1D DMA transfer.
inline snrt_dma_txid_t snrt_dma_start_1d(void *dst, const void *src,
                                         size_t size) {
    return snrt_dma_start_1d_wideptr((size_t)dst, (size_t)src, size);
}

/// Block until all operation on the DMA ceases.
inline void snrt_dma_wait_all() {
    // dmstati t0, 2  # 2=status.busy
    asm volatile(
        "1: \n"
        ".word (0b0000100 << 25) | \
               (  0b00010 << 20) | \
               (    0b000 << 12) | \
               (      (5) <<  7) | \
               (0b0101011 <<  0)   \n"
        "bne t0, zero, 1b \n" ::
            : "t0");
}

//================================================================================
// --------------------------- Barrier functions --------------------------------
//================================================================================

/// Synchronize cores in a cluster with a hardware barrier
inline void snrt_cluster_hw_barrier() {
    asm volatile("csrr x0, 0x7C2" ::: "memory");
}

// --------------------------------------------------------------------------------
// --------------------------- CSR Write&Read functions --------------------------
// --------------------------------------------------------------------------------

#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define write_csr(reg, val) ({ \
  asm volatile ("csrw " #reg ", %0" :: "rK"(val)); })

