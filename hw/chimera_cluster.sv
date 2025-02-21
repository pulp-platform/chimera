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
  parameter int unsigned ClusterId         = 0,
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
  `include "axi/assign.svh"

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
    `ifndef TARGET_PULP_CLUSTER
    .clu_clk_i(clu_clk_i),
    `endif
    .rst_ni,

    // NARROW PORTS
    // SoC to cluster (from SoC master port)
    .narrow_in_req_i  (clu_axi_narrow_slv_req),
    .narrow_in_resp_o (clu_axi_narrow_slv_rsp),
    // SoC to cluster (to cluster slave port)
    .clu_narrow_in_req_o  (clu_axi_adapter_slv_req),
    .clu_narrow_in_resp_i (clu_axi_adapter_slv_resp),

    // cluster to SoC (to SoC slave port)
    .narrow_out_req_o (clu_axi_narrow_mst_req),
    .narrow_out_resp_i(clu_axi_narrow_mst_rsp),
    // cluster to SoC (from cluster master port)
    .clu_narrow_out_req_i (clu_axi_adapter_mst_req),
    .clu_narrow_out_resp_o(clu_axi_adapter_mst_resp),

    // WIDE PORTS
    // cluster to SoC (to SoC slave port)
    .wide_out_req_o     (wide_out_req_o),
    .wide_out_resp_i    (wide_out_resp_i),
    // cluster to SoC (from cluster master port)
    .clu_wide_out_req_i (clu_axi_wide_mst_req),
    .clu_wide_out_resp_o(clu_axi_wide_mst_resp),

    .wide_mem_bypass_mode_i(widemem_bypass_i)
  );

  ////////////////////
  // Snitch cluster //
  ////////////////////

  `ifdef TARGET_SNITCH_CLUSTER

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

  snitch_cluster #(
    .PhysicalAddrWidth(Cfg.ChsCfg.AddrWidth),
    .NarrowDataWidth  (ClusterDataWidth),            // SCHEREMO: Convolve needs this...
    .WideDataWidth    (WideDataWidth),
    .NarrowIdWidthIn  (ClusterNarrowAxiMstIdWidth),
    .WideIdWidthIn    (WideMasterIdWidth),
    .NarrowUserWidth  (Cfg.ChsCfg.AxiUserWidth),
    .WideUserWidth    (Cfg.ChsCfg.AxiUserWidth),

    .BootAddr(SnitchBootROMRegionStart),

    .NrHives          (1),
    .NrCores          (NrCores),
    .TCDMDepth        (1024),
    .ZeroMemorySize   (64),
    .ClusterPeriphSize(64),
    .NrBanks          (16),

    .DMANumAxInFlight(3),
    .DMAReqFifoDepth (3),

    .ICacheLineWidth('{256}),
    .ICacheLineCount('{16}),
    .ICacheSets     ('{2}),

    .VMSupport(0),
    .Xdma     ({1'b1, {(NrCores - 1) {1'b0}}}),

    .NumIntOutstandingLoads(NumIntOutstandingLoads),
    .NumIntOutstandingMem  (NumIntOutstandingMem),
    .RegisterOffloadReq    (1),
    .RegisterOffloadRsp    (1),
    .RegisterCoreReq       (1),
    .RegisterCoreRsp       (1),

    .narrow_in_req_t (axi_cluster_in_narrow_req_t),
    .narrow_in_resp_t(axi_cluster_in_narrow_resp_t),
    .wide_in_req_t   (axi_cluster_in_wide_req_t),
    .wide_in_resp_t  (axi_cluster_in_wide_resp_t),

    .narrow_out_req_t (axi_cluster_out_narrow_req_t),
    .narrow_out_resp_t(axi_cluster_out_narrow_resp_t),
    .wide_out_req_t   (axi_cluster_out_wide_req_t),
    .wide_out_resp_t  (axi_cluster_out_wide_resp_t),

    .sram_cfg_t (sram_cfg_t),
    .sram_cfgs_t(sram_cfgs_t),

    .RegisterExtWide  ('0),
    .RegisterExtNarrow('0)
  ) i_test_cluster (

    .clk_i          (clu_clk_i),
    .clk_d2_bypass_i('0),
    .rst_ni,

    .debug_req_i(debug_req_i),
    .meip_i     (meip_i),
    .mtip_i     (mtip_i),
    .msip_i     (msip_i),

    .hart_base_id_i     (hart_base_id_i),
    .cluster_base_addr_i(cluster_base_addr_i),
    .sram_cfgs_i        ('0),

    .narrow_in_req_i  (clu_axi_adapter_slv_req),
    .narrow_in_resp_o (clu_axi_adapter_slv_resp),
    .narrow_out_req_o (clu_axi_adapter_mst_req),
    .narrow_out_resp_i(clu_axi_adapter_mst_resp),
    .wide_in_req_i    ('0),
    .wide_in_resp_o   (),
    .wide_out_req_o   (clu_axi_wide_mst_req),
    .wide_out_resp_i  (clu_axi_wide_mst_resp)
  );

  //////////////////
  // PULP cluster //
  //////////////////

  `elsif TARGET_PULP_CLUSTER

  // SoC to Cluster CDC source slice (narrow slave)
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth   ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataInWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdInWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth   )
  ) soc_to_cluster_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth   ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataInWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdInWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth   ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth )
  ) async_soc_to_cluster_axi_bus();

  axi_cdc_src_intf   #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth   ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataInWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdInWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth   ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth )
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
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth    ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth    )
  ) cluster_to_soc_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth    ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth    ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth  )
  ) async_cluster_to_soc_axi_bus();

  axi_cdc_dst_intf   #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth    ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth    ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth  )
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
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth        ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWideWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWideWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth        )
  ) dma_axi_bus();
  AXI_BUS_ASYNC_GRAY #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth        ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWideWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWideWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth        ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth      )
  ) async_dma_axi_bus();

  axi_cdc_dst_intf  #(
    .AXI_ADDR_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiAddrWidth        ),
    .AXI_DATA_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiDataOutWideWidth ),
    .AXI_ID_WIDTH   ( Cfg.PulpCluCfgs[ClusterId].AxiIdOutWideWidth   ),
    .AXI_USER_WIDTH ( Cfg.PulpCluCfgs[ClusterId].AxiUserWidth        ),
    .LOG_DEPTH      ( Cfg.PulpCluCfgs[ClusterId].AxiCdcLogDepth      )
  ) dma_dst_cdc_fifo_i (
      .dst_clk_i  ( soc_clk_i         ),
      .dst_rst_ni ( rst_ni            ),
      .src        ( async_dma_axi_bus ),
      .dst        ( dma_axi_bus       )
  );

  `AXI_ASSIGN_TO_REQ(clu_axi_wide_mst_req, dma_axi_bus)
  `AXI_ASSIGN_FROM_RESP(dma_axi_bus, clu_axi_wide_mst_resp)

  pulp_cluster #(
    .Cfg ( Cfg.PulpCluCfgs[ClusterId] )
  ) cluster_i (
    .clk_i                       ( clu_clk_i                                         ),
    .rst_ni                      ( rst_ni                                            ),
    .pwr_on_rst_ni               ( rst_ni                                            ),
    .ref_clk_i                   ( clu_clk_i                                         ),
    .axi_isolate_i               ( '0                                                ),
    .axi_isolated_o              ( /* Unconnected */                                 ),
    .axi_isolated_wide_o         ( /* Unconnected */                                 ),
    .pmu_mem_pwdn_i              ( 1'b0                                              ),
    .base_addr_i                 ( Cfg.PulpCluCfgs[ClusterId].ClusterBaseAddr[31:28] ),
    .dma_pe_evt_ack_i            ( '1                                                ),
    .dma_pe_evt_valid_o          ( /* Unconnected */                                 ),
    .dma_pe_irq_ack_i            ( 1'b1                                              ),
    .dma_pe_irq_valid_o          ( /* Unconnected */                                 ),
    .dbg_irq_valid_i             ( '0                                                ),
    .mbox_irq_i                  ( '0                                                ),
    .pf_evt_ack_i                ( 1'b1                                              ),
    .pf_evt_valid_o              ( /* Unconnected */                                 ),
    .async_cluster_events_wptr_i ( '0                                                ),
    .async_cluster_events_rptr_o ( /* Unconnected */                                 ),
    .async_cluster_events_data_i ( '0                                                ),
    .en_sa_boot_i                ( 1'b0                                              ),
    .test_mode_i                 ( 1'b0                                              ),
    .fetch_en_i                  ( 1'b0                                              ),
    .eoc_o                       ( /* Unconnected */                                 ),
    .busy_o                      ( /* Unconnected */                                 ),
    .cluster_id_i                ( ClusterId[5:0]                                    ),
    .async_data_master_aw_wptr_o ( async_cluster_to_soc_axi_bus.aw_wptr              ),
    .async_data_master_aw_rptr_i ( async_cluster_to_soc_axi_bus.aw_rptr              ),
    .async_data_master_aw_data_o ( async_cluster_to_soc_axi_bus.aw_data              ),
    .async_data_master_ar_wptr_o ( async_cluster_to_soc_axi_bus.ar_wptr              ),
    .async_data_master_ar_rptr_i ( async_cluster_to_soc_axi_bus.ar_rptr              ),
    .async_data_master_ar_data_o ( async_cluster_to_soc_axi_bus.ar_data              ),
    .async_data_master_w_data_o  ( async_cluster_to_soc_axi_bus.w_data               ),
    .async_data_master_w_wptr_o  ( async_cluster_to_soc_axi_bus.w_wptr               ),
    .async_data_master_w_rptr_i  ( async_cluster_to_soc_axi_bus.w_rptr               ),
    .async_data_master_r_wptr_i  ( async_cluster_to_soc_axi_bus.r_wptr               ),
    .async_data_master_r_rptr_o  ( async_cluster_to_soc_axi_bus.r_rptr               ),
    .async_data_master_r_data_i  ( async_cluster_to_soc_axi_bus.r_data               ),
    .async_data_master_b_wptr_i  ( async_cluster_to_soc_axi_bus.b_wptr               ),
    .async_data_master_b_rptr_o  ( async_cluster_to_soc_axi_bus.b_rptr               ),
    .async_data_master_b_data_i  ( async_cluster_to_soc_axi_bus.b_data               ),
    .async_wide_master_aw_wptr_o ( async_dma_axi_bus.aw_wptr                         ),
    .async_wide_master_aw_rptr_i ( async_dma_axi_bus.aw_rptr                         ),
    .async_wide_master_aw_data_o ( async_dma_axi_bus.aw_data                         ),
    .async_wide_master_ar_wptr_o ( async_dma_axi_bus.ar_wptr                         ),
    .async_wide_master_ar_rptr_i ( async_dma_axi_bus.ar_rptr                         ),
    .async_wide_master_ar_data_o ( async_dma_axi_bus.ar_data                         ),
    .async_wide_master_w_data_o  ( async_dma_axi_bus.w_data                          ),
    .async_wide_master_w_wptr_o  ( async_dma_axi_bus.w_wptr                          ),
    .async_wide_master_w_rptr_i  ( async_dma_axi_bus.w_rptr                          ),
    .async_wide_master_r_wptr_i  ( async_dma_axi_bus.r_wptr                          ),
    .async_wide_master_r_rptr_o  ( async_dma_axi_bus.r_rptr                          ),
    .async_wide_master_r_data_i  ( async_dma_axi_bus.r_data                          ),
    .async_wide_master_b_wptr_i  ( async_dma_axi_bus.b_wptr                          ),
    .async_wide_master_b_rptr_o  ( async_dma_axi_bus.b_rptr                          ),
    .async_wide_master_b_data_i  ( async_dma_axi_bus.b_data                          ),
    .async_data_slave_aw_wptr_i  ( async_soc_to_cluster_axi_bus.aw_wptr              ),
    .async_data_slave_aw_rptr_o  ( async_soc_to_cluster_axi_bus.aw_rptr              ),
    .async_data_slave_aw_data_i  ( async_soc_to_cluster_axi_bus.aw_data              ),
    .async_data_slave_ar_wptr_i  ( async_soc_to_cluster_axi_bus.ar_wptr              ),
    .async_data_slave_ar_rptr_o  ( async_soc_to_cluster_axi_bus.ar_rptr              ),
    .async_data_slave_ar_data_i  ( async_soc_to_cluster_axi_bus.ar_data              ),
    .async_data_slave_w_data_i   ( async_soc_to_cluster_axi_bus.w_data               ),
    .async_data_slave_w_wptr_i   ( async_soc_to_cluster_axi_bus.w_wptr               ),
    .async_data_slave_w_rptr_o   ( async_soc_to_cluster_axi_bus.w_rptr               ),
    .async_data_slave_r_wptr_o   ( async_soc_to_cluster_axi_bus.r_wptr               ),
    .async_data_slave_r_rptr_i   ( async_soc_to_cluster_axi_bus.r_rptr               ),
    .async_data_slave_r_data_o   ( async_soc_to_cluster_axi_bus.r_data               ),
    .async_data_slave_b_wptr_o   ( async_soc_to_cluster_axi_bus.b_wptr               ),
    .async_data_slave_b_rptr_i   ( async_soc_to_cluster_axi_bus.b_rptr               ),
    .async_data_slave_b_data_o   ( async_soc_to_cluster_axi_bus.b_data               )
  );

  /* Error */
  `else
  $error("No cluster selected");
  `endif

endmodule
