// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

module chimera_cluster
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter chimera_cfg_t Cfg = '0,

  parameter int unsigned NrCores           = 9,
  parameter type         narrow_in_req_t   = logic,
  parameter type         narrow_in_resp_t  = logic,
  parameter type         narrow_out_req_t  = logic,
  parameter type         narrow_out_resp_t = logic,
  parameter type         wide_out_req_t    = logic,
  parameter type         wide_out_resp_t   = logic
) (
  input  logic                                        soc_clk_i,
  input  logic                                        clu_clk_i,
  input  logic                                        rst_ni,
  input  logic                                        widemem_bypass_i,
  //-----------------------------
  // Interrupt ports
  //-----------------------------
  input  logic             [             NrCores-1:0] debug_req_i,
  input  logic             [             NrCores-1:0] meip_i,
  input  logic             [             NrCores-1:0] mtip_i,
  input  logic             [             NrCores-1:0] msip_i,
  //-----------------------------
  // Cluster base addressing
  //-----------------------------
  input  logic             [                     9:0] hart_base_id_i,
  input  logic             [Cfg.ChsCfg.AddrWidth-1:0] cluster_base_addr_i,
  input  logic             [                    31:0] boot_addr_i,
  //-----------------------------
  // Narrow AXI ports
  //-----------------------------
  input  narrow_in_req_t                              narrow_in_req_i,
  output narrow_in_resp_t                             narrow_in_resp_o,
  output narrow_out_req_t  [                     1:0] narrow_out_req_o,
  input  narrow_out_resp_t [                     1:0] narrow_out_resp_i,
  //-----------------------------
  //Wide AXI ports
  //-----------------------------
  output wide_out_req_t                               wide_out_req_o,
  input  wide_out_resp_t                              wide_out_resp_i
);

  `include "axi/typedef.svh"

  localparam int WideDataWidth = $bits(wide_out_req_o.w.data);

  localparam int WideMasterIdWidth = $bits(wide_out_req_o.aw.id);
  localparam int WideSlaveIdWidth = WideMasterIdWidth + $clog2(Cfg.ChsCfg.AxiExtNumWideMst) - 1;

  localparam int NarrowSlaveIdWidth = $bits(narrow_in_req_i.aw.id);
  localparam int NarrowMasterIdWidth = $bits(narrow_out_req_o[0].aw.id);

  typedef logic [Cfg.ChsCfg.AddrWidth-1:0] axi_addr_t;
  typedef logic [Cfg.ChsCfg.AxiUserWidth-1:0] axi_user_t;

  typedef logic [Cfg.ChsCfg.AxiDataWidth-1:0] axi_soc_data_narrow_t;
  typedef logic [Cfg.ChsCfg.AxiDataWidth/8-1:0] axi_soc_strb_narrow_t;

  typedef logic [ClusterDataWidth-1:0] axi_cluster_data_narrow_t;
  typedef logic [ClusterDataWidth/8-1:0] axi_cluster_strb_narrow_t;

  typedef logic [WideDataWidth-1:0] axi_cluster_data_wide_t;
  typedef logic [WideDataWidth/8-1:0] axi_cluster_strb_wide_t;

  typedef logic [ClusterNarrowAxiMstIdWidth-1:0] axi_cluster_mst_id_width_narrow_t;
  typedef logic [ClusterNarrowAxiMstIdWidth-1+2:0] axi_cluster_slv_id_width_narrow_t;

  typedef logic [NarrowMasterIdWidth-1:0] axi_soc_mst_id_width_narrow_t;
  typedef logic [NarrowSlaveIdWidth-1:0] axi_soc_slv_id_width_narrow_t;

  typedef logic [WideMasterIdWidth-1:0] axi_mst_id_width_wide_t;
  typedef logic [WideMasterIdWidth-1+2:0] axi_slv_id_width_wide_t;

  `AXI_TYPEDEF_ALL(axi_cluster_out_wide, axi_addr_t, axi_slv_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_wide, axi_addr_t, axi_mst_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_soc_out_narrow, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_soc_in_narrow, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow, axi_addr_t, axi_cluster_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow, axi_addr_t, axi_cluster_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow_socIW, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow_socIW, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  // Cluster-side in- and out- narrow ports used in chimera adapter
  axi_cluster_in_narrow_req_t               clu_axi_adapter_slv_req;
  axi_cluster_in_narrow_resp_t              clu_axi_adapter_slv_resp;
  axi_cluster_out_narrow_req_t              clu_axi_adapter_mst_req;
  axi_cluster_out_narrow_resp_t             clu_axi_adapter_mst_resp;

  // Cluster-side in- and out- narrow ports used in narrow adapter
  axi_cluster_in_narrow_socIW_req_t         clu_axi_narrow_slv_req;
  axi_cluster_in_narrow_socIW_resp_t        clu_axi_narrow_slv_rsp;
  axi_cluster_out_narrow_socIW_req_t  [1:0] clu_axi_narrow_mst_req;
  axi_cluster_out_narrow_socIW_resp_t [1:0] clu_axi_narrow_mst_rsp;

  // Cluster-side out wide ports
  axi_cluster_out_wide_req_t                clu_axi_wide_mst_req;
  axi_cluster_out_wide_resp_t               clu_axi_wide_mst_resp;


  if (ClusterDataWidth != Cfg.ChsCfg.AxiDataWidth) begin : gen_narrow_adapter

    narrow_adapter #(
      .narrow_in_req_t  (axi_soc_out_narrow_req_t),
      .narrow_in_resp_t (axi_soc_out_narrow_resp_t),
      .narrow_out_req_t (axi_soc_in_narrow_req_t),
      .narrow_out_resp_t(axi_soc_in_narrow_resp_t),

      .clu_narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
      .clu_narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
      .clu_narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
      .clu_narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

      .MstPorts(2),
      .SlvPorts(1)

    ) i_cluster_narrow_adapter (
      .soc_clk_i(soc_clk_i),
      .rst_ni,

      // SoC side narrow.
      .narrow_in_req_i  (narrow_in_req_i),
      .narrow_in_resp_o (narrow_in_resp_o),
      .narrow_out_req_o (narrow_out_req_o),
      .narrow_out_resp_i(narrow_out_resp_i),

      // Cluster side narrow
      .clu_narrow_in_req_o  (clu_axi_narrow_slv_req),
      .clu_narrow_in_resp_i (clu_axi_narrow_slv_rsp),
      .clu_narrow_out_req_i (clu_axi_narrow_mst_req),
      .clu_narrow_out_resp_o(clu_axi_narrow_mst_rsp)

    );

  end else begin : gen_skip_narrow_adapter  // if (ClusterDataWidth != Cfg.AxiDataWidth)

    assign clu_axi_narrow_slv_req = narrow_in_req_i;
    assign narrow_in_resp_o       = clu_axi_narrow_slv_rsp;
    assign narrow_out_req_o       = clu_axi_narrow_mst_req;
    assign clu_axi_narrow_mst_rsp = narrow_out_resp_i;

  end

  ////////////////////////////////////////////////////////////////////////
  // Complement chimera_cluster_adapter with CDC slice for PULP cluster //
  ////////////////////////////////////////////////////////////////////////
  `include "axi/assign.svh"
  `include "axi/typedef.svh"
  //TODO(smazzola): move all of this in a customized cluster adapter for PULP Cluster

  // SoC to Cluster CDC source slice (narrow slave)
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth )
  ) soc_to_cluster_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
  ) async_soc_to_cluster_axi_bus();

  axi_cdc_src_intf   #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
  ) soc_to_cluster_src_cdc_fifo_i  (
      .src_clk_i  ( soc_clk_i                    ),
      .src_rst_ni ( rst_ni                       ),
      .src        ( soc_to_cluster_axi_bus       ),
      .dst        ( async_soc_to_cluster_axi_bus )
  );

  `AXI_ASSIGN_FROM_REQ(soc_to_cluster_axi_bus, clu_axi_adapter_slv_req)
  `AXI_ASSIGN_TO_RESP(clu_axi_adapter_slv_resp, soc_to_cluster_axi_bus)

  // Cluster to SoC CDC destination slice (narrow master)
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth )
  ) cluster_to_soc_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
  ) async_cluster_to_soc_axi_bus();

  axi_cdc_dst_intf   #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( ClusterDataWidth ),
    .AXI_ID_WIDTH   ( ClusterNarrowAxiMstIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
    ) cluster_to_soc_dst_cdc_fifo_i (
      .dst_clk_i  ( soc_clk_i                    ),
      .dst_rst_ni ( rst_ni                       ),
      .src        ( async_cluster_to_soc_axi_bus ),
      .dst        ( cluster_to_soc_axi_bus       )
  );

  `AXI_ASSIGN_TO_REQ(clu_axi_adapter_mst_req, cluster_to_soc_axi_bus)
  `AXI_ASSIGN_FROM_RESP(cluster_to_soc_axi_bus, clu_axi_adapter_mst_resp)

  // DMA CDC destination slice (wide master)
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( WideDataWidth ),
    .AXI_ID_WIDTH   ( WideMasterIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth )
  ) dma_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( WideDataWidth ),
    .AXI_ID_WIDTH   ( WideMasterIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
  ) async_dma_axi_bus();

  axi_cdc_dst_intf  #(
    .AXI_ADDR_WIDTH ( Cfg.ChsCfg.AddrWidth ),
    .AXI_DATA_WIDTH ( WideDataWidth ),
    .AXI_ID_WIDTH   ( WideMasterIdWidth ),
    .AXI_USER_WIDTH ( Cfg.ChsCfg.AxiUserWidth ),
    .LOG_DEPTH      ( 3 )
  ) dma_dst_cdc_fifo_i (
      .dst_clk_i  ( soc_clk_i         ),
      .dst_rst_ni ( rst_ni            ),
      .src        ( async_dma_axi_bus ),
      .dst        ( dma_axi_bus         )
  );

  `AXI_ASSIGN_TO_REQ(clu_axi_wide_mst_req, dma_axi_bus)
  `AXI_ASSIGN_FROM_RESP(dma_axi_bus, clu_axi_wide_mst_resp)

  ////////////////////////////////////////////////////////////////////////

  chimera_cluster_adapter #(
    .WidePassThroughRegionStart(Cfg.MemIslRegionStart),
    .WidePassThroughRegionEnd  (Cfg.MemIslRegionEnd),

    .narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
    .narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
    .narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
    .narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

    .clu_narrow_in_req_t  (axi_cluster_in_narrow_req_t),
    .clu_narrow_in_resp_t (axi_cluster_in_narrow_resp_t),
    .clu_narrow_out_req_t (axi_cluster_out_narrow_req_t),
    .clu_narrow_out_resp_t(axi_cluster_out_narrow_resp_t),

    .wide_out_req_t (wide_out_req_t),
    .wide_out_resp_t(wide_out_resp_t),

    .clu_wide_out_req_t (axi_cluster_out_wide_req_t),
    .clu_wide_out_resp_t(axi_cluster_out_wide_resp_t)

  ) i_cluster_axi_adapter (
    .soc_clk_i(soc_clk_i),
    // .clu_clk_i(clu_clk_i),
    .rst_ni,

    .narrow_in_req_i  (clu_axi_narrow_slv_req),
    .narrow_in_resp_o (clu_axi_narrow_slv_rsp),
    .narrow_out_req_o (clu_axi_narrow_mst_req),
    .narrow_out_resp_i(clu_axi_narrow_mst_rsp),

    .clu_narrow_in_req_o  (clu_axi_adapter_slv_req), // Cluster side narrow slave
    .clu_narrow_in_resp_i (clu_axi_adapter_slv_resp),
    .clu_narrow_out_req_i (clu_axi_adapter_mst_req), // Cluster side narrow master
    .clu_narrow_out_resp_o(clu_axi_adapter_mst_resp),

    .wide_out_req_o     (wide_out_req_o),
    .wide_out_resp_i    (wide_out_resp_i),
    .clu_wide_out_req_i (clu_axi_wide_mst_req), // Cluster side wide master
    .clu_wide_out_resp_o(clu_axi_wide_mst_resp),

    .wide_mem_bypass_mode_i(widemem_bypass_i)
  );

  typedef struct packed {
    logic [2:0] ema;
    logic [1:0] emaw;
    logic [0:0] emas;
  } sram_cfg_t;

  typedef struct packed {
    sram_cfg_t icache_tag;
    sram_cfg_t icache_data;
    sram_cfg_t tcdm;
  } sram_cfgs_t;

  localparam int unsigned NumIntOutstandingLoads[NrCores] = '{NrCores{32'h1}};
  localparam int unsigned NumIntOutstandingMem[NrCores] = '{NrCores{32'h4}};

  pulp_cluster  #(
    .NB_CORES                     ( 8                ),              // snitch_cluster had 9 because 1 was DMA
    .HWPE_WIDTH_FAC                ( 9                        ),     // ???
    .NB_DMA_PORTS                 ( 2                 ),             // ???
    .N_HWPE                       ( 1                        ),      // ???
    .TCDM_SIZE                    ( 128*1024                 ),      // ???
    .NB_TCDM_BANKS                ( 16                       ),      // ???
    .SET_ASSOCIATIVE              ( 4                        ),      // ???
    .CACHE_LINE                   ( 1                        ),      // ???
    .CACHE_SIZE                   ( 4096                     ),      // ???
    .ICACHE_DATA_WIDTH            ( 128                      ),      // ???
    .L0_BUFFER_FEATURE            ( "DISABLED"               ),      // ???
    .MULTICAST_FEATURE            ( "DISABLED"               ),      // ???
    .SHARED_ICACHE                ( "ENABLED"                ),      // ???
    .DIRECT_MAPPED_FEATURE        ( "DISABLED"               ),      // ???
    .L2_SIZE                      ( 32'h10000                ),      // ???
    .ROM_BOOT_ADDR                ( 32'h1A000000             ),      // ??? substitute with correct ones
    .BOOT_ADDR                    ( 32'h1c008080             ),      // ??? substitute with correct ones
    .INSTR_RDATA_WIDTH            ( 32                       ),      // ???
    .CLUST_FPU                    ( 1               ),
    .CLUST_FP_DIVSQRT             ( 1        ),
    .CLUST_SHARED_FP              ( 2         ),
    .CLUST_SHARED_FP_DIVSQRT      ( 2 ),
    .AXI_ADDR_WIDTH               ( Cfg.ChsCfg.AddrWidth),
    .AXI_DATA_S2C_WIDTH           ( ClusterDataWidth                    ),
    .AXI_DATA_C2S_WIDTH           ( ClusterDataWidth                    ),
    .AXI_DMA_DATA_C2S_WIDTH       ( WideDataWidth                 ),
    .AXI_USER_WIDTH               ( Cfg.ChsCfg.AxiUserWidth),
    .AXI_ID_IN_WIDTH              ( ClusterNarrowAxiMstIdWidth                  ),
    .AXI_ID_OUT_WIDTH             ( ClusterNarrowAxiMstIdWidth                    ),
    .AXI_DMA_ID_OUT_WIDTH         ( WideMasterIdWidth                    ),
    .LOG_DEPTH                    ( 3                        ),
    .DATA_WIDTH                   ( 32                       ),   // ???
    .ADDR_WIDTH                   ( 32                       ),
    .LOG_CLUSTER                  ( 3                        ),
    .PE_ROUTING_LSB               ( 10                       ),
    .EVNT_WIDTH                   ( 8                        ),
    .IDMA                         ( 1'b1                     ),
    .DMA_USE_HWPE_PORT            ( 1'b1                     )
  ) cluster_i (
      .clk_i                       ( clu_clk_i                                ),
      .rst_ni                      ( rst_ni                               ),
      .ref_clk_i                   ( clu_clk_i                                ),

      .pmu_mem_pwdn_i              ( 1'b0                                 ),

      .base_addr_i                 ( '0                                   ),

      .dma_pe_evt_ack_i            ( '1                                   ),
      .dma_pe_evt_valid_o          (                                      ),

      .dma_pe_irq_ack_i            ( 1'b1                                 ),
      .dma_pe_irq_valid_o          (                                      ),

      .dbg_irq_valid_i             ( '0                                   ),

      .pf_evt_ack_i                ( 1'b1                                 ),
      .pf_evt_valid_o              (                                      ),

      .async_cluster_events_wptr_i ( '0                                   ),
      .async_cluster_events_rptr_o (                                      ),
      .async_cluster_events_data_i ( '0                                   ),

      .en_sa_boot_i                ( s_cluster_en_sa_boot                 ), // ??? fix or disconnect
      .test_mode_i                 ( 1'b0                                 ), // ??? fix or disconnect
      .fetch_en_i                  ( s_cluster_fetch_en                   ), // ??? fix or disconnect
      .eoc_o                       ( s_cluster_eoc                        ), // ??? fix or disconnect
      .busy_o                      ( s_cluster_busy                       ), // ??? fix or disconnect
      .cluster_id_i                ( 6'b000000                            ), // ??? fix or disconnect

      .async_data_master_aw_wptr_o ( async_cluster_to_soc_axi_bus.aw_wptr ),
      .async_data_master_aw_rptr_i ( async_cluster_to_soc_axi_bus.aw_rptr ),
      .async_data_master_aw_data_o ( async_cluster_to_soc_axi_bus.aw_data ),
      .async_data_master_ar_wptr_o ( async_cluster_to_soc_axi_bus.ar_wptr ),
      .async_data_master_ar_rptr_i ( async_cluster_to_soc_axi_bus.ar_rptr ),
      .async_data_master_ar_data_o ( async_cluster_to_soc_axi_bus.ar_data ),
      .async_data_master_w_data_o  ( async_cluster_to_soc_axi_bus.w_data  ),
      .async_data_master_w_wptr_o  ( async_cluster_to_soc_axi_bus.w_wptr  ),
      .async_data_master_w_rptr_i  ( async_cluster_to_soc_axi_bus.w_rptr  ),
      .async_data_master_r_wptr_i  ( async_cluster_to_soc_axi_bus.r_wptr  ),
      .async_data_master_r_rptr_o  ( async_cluster_to_soc_axi_bus.r_rptr  ),
      .async_data_master_r_data_i  ( async_cluster_to_soc_axi_bus.r_data  ),
      .async_data_master_b_wptr_i  ( async_cluster_to_soc_axi_bus.b_wptr  ),
      .async_data_master_b_rptr_o  ( async_cluster_to_soc_axi_bus.b_rptr  ),
      .async_data_master_b_data_i  ( async_cluster_to_soc_axi_bus.b_data  ),

      .async_dma_master_aw_wptr_o ( async_dma_axi_bus.aw_wptr ),
      .async_dma_master_aw_rptr_i ( async_dma_axi_bus.aw_rptr ),
      .async_dma_master_aw_data_o ( async_dma_axi_bus.aw_data ),
      .async_dma_master_ar_wptr_o ( async_dma_axi_bus.ar_wptr ),
      .async_dma_master_ar_rptr_i ( async_dma_axi_bus.ar_rptr ),
      .async_dma_master_ar_data_o ( async_dma_axi_bus.ar_data ),
      .async_dma_master_w_data_o  ( async_dma_axi_bus.w_data  ),
      .async_dma_master_w_wptr_o  ( async_dma_axi_bus.w_wptr  ),
      .async_dma_master_w_rptr_i  ( async_dma_axi_bus.w_rptr  ),
      .async_dma_master_r_wptr_i  ( async_dma_axi_bus.r_wptr  ),
      .async_dma_master_r_rptr_o  ( async_dma_axi_bus.r_rptr  ),
      .async_dma_master_r_data_i  ( async_dma_axi_bus.r_data  ),
      .async_dma_master_b_wptr_i  ( async_dma_axi_bus.b_wptr  ),
      .async_dma_master_b_rptr_o  ( async_dma_axi_bus.b_rptr  ),
      .async_dma_master_b_data_i  ( async_dma_axi_bus.b_data  ),

      .async_data_slave_aw_wptr_i  ( async_soc_to_cluster_axi_bus.aw_wptr ),
      .async_data_slave_aw_rptr_o  ( async_soc_to_cluster_axi_bus.aw_rptr ),
      .async_data_slave_aw_data_i  ( async_soc_to_cluster_axi_bus.aw_data ),
      .async_data_slave_ar_wptr_i  ( async_soc_to_cluster_axi_bus.ar_wptr ),
      .async_data_slave_ar_rptr_o  ( async_soc_to_cluster_axi_bus.ar_rptr ),
      .async_data_slave_ar_data_i  ( async_soc_to_cluster_axi_bus.ar_data ),
      .async_data_slave_w_data_i   ( async_soc_to_cluster_axi_bus.w_data  ),
      .async_data_slave_w_wptr_i   ( async_soc_to_cluster_axi_bus.w_wptr  ),
      .async_data_slave_w_rptr_o   ( async_soc_to_cluster_axi_bus.w_rptr  ),
      .async_data_slave_r_wptr_o   ( async_soc_to_cluster_axi_bus.r_wptr  ),
      .async_data_slave_r_rptr_i   ( async_soc_to_cluster_axi_bus.r_rptr  ),
      .async_data_slave_r_data_o   ( async_soc_to_cluster_axi_bus.r_data  ),
      .async_data_slave_b_wptr_o   ( async_soc_to_cluster_axi_bus.b_wptr  ),
      .async_data_slave_b_rptr_i   ( async_soc_to_cluster_axi_bus.b_rptr  ),
      .async_data_slave_b_data_o   ( async_soc_to_cluster_axi_bus.b_data  )
   );
endmodule
