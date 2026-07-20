# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Add a standard set of Chimera cluster signals for a given cluster_id.
#
# Usage:
#   add_chimera_cluster_waves 3
#
proc add_chimera_cluster_waves {cluster_id num_cores} {
  # Base paths
  set clu_base "/tb_chimera_soc/fix/dut/i_cluster_domain/gen_clusters\[${cluster_id}\]/gen_cluster_type/i_chimera_cluster/i_test_cluster"
  set grp "Cluster ${cluster_id}"

  # Cluster-level signals
  add wave -noupdate -group $grp ${clu_base}/cluster_base_addr_i
  add wave -noupdate -group $grp ${clu_base}/clk_i
  add wave -noupdate -group $grp ${clu_base}/rst_ni

  # Barrier (if present)
  add wave -noupdate -group $grp ${clu_base}/i_snitch_barrier/barrier_i
  add wave -noupdate -group $grp ${clu_base}/i_snitch_barrier/arrival_q
  add wave -noupdate -group $grp ${clu_base}/i_snitch_barrier/barrier_o

  # iCache/Hive signals (note: hive is commonly not per-core; keep under a subgroup)
  # Adjust gen_hive index if needed.
  add wave -noupdate -group $grp -group {iCache} ${clu_base}/gen_hive\[0\]/i_snitch_hive/*

  # Per-core signals.
  for {set core 0} {$core < $num_cores} {incr core} {
    set core_base "${clu_base}/gen_core\[${core}\]/i_snitch_cc"
    set core_grp "Core ${core}"

    add wave -noupdate -group $grp -group $core_grp ${core_base}/hart_id_i
    add wave -noupdate -group $grp -group $core_grp ${core_base}/i_snitch/pc_q
    add wave -noupdate -group $grp -group $core_grp ${core_base}/i_snitch/wfi_q
  }
}


onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/soc_clk_i}
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/clu_clk_i}
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/rtc_i}
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/rst_ni}
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/uart_tx_o}
add wave -noupdate -expand -group {Global} {/tb_chimera_soc/fix/dut/uart_rx_i}

add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/gen_cva6_cores[0]/i_core_cva6/hart_id_i}
add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/gen_cva6_cores[0]/i_core_cva6/pc_commit}
add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/intr_routed}
add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/intr}
add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/msip}
add wave -noupdate -expand -group {CVA6} {/tb_chimera_soc/fix/dut/i_cheshire/mtip}

add wave -noupdate -expand -group {Cluster Register} {tb_chimera_soc/fix/dut/i_reg_top/reg2hw}

# Add waves for Cluster 0
add_chimera_cluster_waves 0 9
# Add waves for Cluster 1
add_chimera_cluster_waves 1 9
# Add waves for Cluster 2
add_chimera_cluster_waves 2 9
# Add waves for Cluster 3
add_chimera_cluster_waves 3 9
# Add waves for Cluster 4
add_chimera_cluster_waves 4 9

# Finalize
update