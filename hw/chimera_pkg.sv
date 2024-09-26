// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

package chimera_pkg;

  import cheshire_pkg::*;

  `include "apb/typedef.svh"

  // ACCEL CFG
  localparam int ExtClusters = 5;

  typedef struct packed {
    logic [iomsb(ExtClusters):0]   hasWideMasterPort;
    byte_bt [iomsb(ExtClusters):0] NrCores;
  } cluster_config_t;

  localparam cluster_config_t ChimeraClusterCfg = '{
      hasWideMasterPort: {1'b1, 1'b1, 1'b1, 1'b1, 1'b1},
      NrCores: {8'h9, 8'h9, 8'h9, 8'h9, 8'h9}
  };

  function automatic int _sumVector(byte_bt [iomsb(ExtClusters):0] vector, int vectorLen);
    int sum = 0;
    for (int i = 0; i < vectorLen; i++) begin
      sum += vector[i];
    end
    return sum;
  endfunction


  localparam int ExtCores = _sumVector(ChimeraClusterCfg.NrCores, ExtClusters);

  // SoC Config
  localparam bit SnitchBootROM = 1;
  localparam bit TopLevelCfgRegs = 1;
  localparam bit ExtCfgRegs = 1;

  // SCHEREMO: Shared Snitch bootrom, one clock gate per cluster, External regs (PADs, FLLs etc...)
  localparam int ExtRegNum = SnitchBootROM + TopLevelCfgRegs + ExtCfgRegs;
  localparam int ClusterDataWidth = 64;

  localparam int SnitchBootROMIdx = 0;
  localparam doub_bt SnitchBootROMRegionStart = 64'h3000_0000;
  localparam doub_bt SnitchBootROMRegionEnd = 64'h3000_1000;

  localparam int TopLevelCfgRegsIdx = 1;
  localparam doub_bt TopLevelCfgRegsRegionStart = 64'h3000_1000;
  localparam doub_bt TopLevelCfgRegsRegionEnd = 64'h3000_2000;

  // External configuration registers: PADs, FLLs, PMU Controller
  localparam int ExtCfgRegsIdx = 2;
  localparam doub_bt ExtCfgRegsRegionStart = 64'h3000_2000;
  localparam doub_bt ExtCfgRegsRegionEnd = 64'h3000_5000;


  localparam aw_bt ClusterNarrowAxiMstIdWidth = 1;

  // Isolate Clusters from SoC
  localparam int unsigned IsolateClusters = 0;

  function automatic cheshire_cfg_t gen_chimera_cfg();
    localparam int AddrWidth = DefaultCfg.AddrWidth;

    cheshire_cfg_t cfg = DefaultCfg;

    // Global CFG

    // Set all Chimera addresses as uncached
    cfg.Cva6ExtCieLength = 'h0;

    cfg.Vga = 0;
    cfg.SerialLink = 0;
    cfg.MemoryIsland = 1;
    // SCHEREMO: Fully remove LLC
    cfg.LlcNotBypass = 0;
    cfg.LlcOutConnect = 0;

    // AXI CFG
    cfg.AxiMstIdWidth = 2;
    cfg.MemIslAxiMstIdWidth = 1;
    cfg.AxiDataWidth = 32;
    cfg.AddrWidth = 32;
    cfg.LlcOutRegionEnd = 'hFFFF_FFFF;

    cfg.MemIslWidePorts = $countones(ChimeraClusterCfg.hasWideMasterPort);
    cfg.MemIslNarrowToWideFactor = 4;

    cfg.AxiExtNumWideMst = $countones(ChimeraClusterCfg.hasWideMasterPort);
    // SCHEREMO: Two ports for each cluster: one to convert stray wides, one for the original narrow
    cfg.AxiExtNumMst = ExtClusters + $countones(ChimeraClusterCfg.hasWideMasterPort);
    cfg.AxiExtNumSlv = ExtClusters;
    cfg.AxiExtNumRules = ExtClusters;
    cfg.AxiExtRegionIdx = {8'h4, 8'h3, 8'h2, 8'h1, 8'h0};
    cfg.AxiExtRegionStart = {
      64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000, 64'h4000_0000
    };
    cfg.AxiExtRegionEnd = {
      64'h40A0_0000, 64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000
    };

    // REG CFG
    cfg.RegExtNumSlv = ExtRegNum;
    cfg.RegExtNumRules = ExtRegNum;
    cfg.RegExtRegionIdx = {8'h3, 8'h2, 8'h1, 8'h0};  // SnitchBootROM
    cfg.RegExtRegionStart = {
      ExtCfgRegsRegionStart, TopLevelCfgRegsRegionStart, SnitchBootROMRegionStart
    };
    cfg.RegExtRegionEnd = {ExtCfgRegsRegionEnd, TopLevelCfgRegsRegionEnd, SnitchBootROMRegionEnd};

    // ACCEL HART/IRQ CFG
    cfg.NumExtIrqHarts = ExtCores;
    cfg.NumExtDbgHarts = ExtCores;
    cfg.NumExtOutIntrTgts = ExtCores;

    return cfg;
  endfunction : gen_chimera_cfg

  localparam int NumCfgs = 1;

  localparam cheshire_cfg_t [NumCfgs-1:0] ChimeraCfg = {gen_chimera_cfg()};

  // To move into cheshire TYPEDEF
  localparam int unsigned RegDataWidth = 32;
  localparam type addr_t = logic [ChimeraCfg[0].AddrWidth-1:0];
  localparam type data_t = logic [RegDataWidth-1:0];
  localparam type strb_t = logic [RegDataWidth/8-1:0];

  `APB_TYPEDEF_ALL(apb, addr_t, data_t, strb_t)

endpackage
