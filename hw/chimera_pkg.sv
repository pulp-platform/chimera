// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

package chimera_pkg;

  import cheshire_pkg::*;

  `include "apb/typedef.svh"

  // Bit vector types for parameters.
  //We limit range to keep parameters sane.
  typedef bit [7:0] byte_bt;
  typedef bit [63:0] doub_bt;
  typedef bit [15:0] shrt_bt;

  typedef enum logic [0:0] {SNITCH} cluster_type_e;

  // --------------------------
  // | Cluster domain config  |
  // --------------------------

  localparam int ExtClusters = 5;

  typedef struct packed {
    logic [iomsb(ExtClusters):0]          hasWideMasterPort;
    byte_bt [iomsb(ExtClusters):0]        NrCores;
    cluster_type_e [iomsb(ExtClusters):0] ClusterType;
  } cluster_config_t;

  // For each instantiated cluster you need to specify three parameters:
  //  - If the cluster has direct wide access to the memory island
  //  - How many cores are include in the cluster
  //  - What type of cluster must be instantiated. Make sure the type exists

  localparam cluster_config_t ChimeraClusterCfg = '{
      hasWideMasterPort: {1'b1, 1'b1, 1'b1, 1'b1, 1'b1},
      NrCores: {8'h9, 8'h9, 8'h9, 8'h9, 8'h9},
      ClusterType: {SNITCH, SNITCH, SNITCH, SNITCH, SNITCH}
  };

  function automatic int _sumVector(byte_bt [iomsb(ExtClusters):0] vector, int vectorLen);
    int sum = 0;
    for (int i = 0; i < vectorLen; i++) begin
      sum += vector[i];
    end
    return sum;
  endfunction : _sumVector

  localparam int ExtCores = _sumVector(ChimeraClusterCfg.NrCores, ExtClusters);

  // --------------------------
  // |       Soc config       |
  // --------------------------

  // Configuration struct for Chimer: it includes the Cheshire Cfg
  typedef struct packed {
    cheshire_cfg_t ChsCfg;
    doub_bt        MemIslRegionStart;
    doub_bt        MemIslRegionEnd;
    aw_bt          MemIslAxiMstIdWidth;
    byte_bt        MemIslNarrowToWideFactor;
    byte_bt        MemIslNarrowPorts;
    byte_bt        MemIslWidePorts;
    byte_bt        MemIslNumWideBanks;
    shrt_bt        MemIslWordsPerBank;
    int unsigned   IsolateClusters;
  } chimera_cfg_t;

  // SoC Config
  localparam bit SnitchBootROM = 1;
  localparam bit TopLevelCfgRegs = 1;
  localparam bit ExtCfgRegs = 1;
  localparam bit HyperCfgRegs = 1;

  // -------------------------------
  // | External Register Interface |
  // -------------------------------

  // SCHEREMO: Shared Snitch bootrom, one clock gate per cluster, External regs (PADs, FLLs etc...)
  localparam int ExtRegNum = SnitchBootROM + TopLevelCfgRegs + ExtCfgRegs + HyperCfgRegs;
  localparam int ClusterDataWidth = 64;

  localparam byte_bt SnitchBootROMIdx = 8'h0;
  localparam doub_bt SnitchBootROMRegionStart = 64'h3000_0000;
  localparam doub_bt SnitchBootROMRegionEnd = 64'h3000_1000;

  localparam byte_bt TopLevelCfgRegsIdx = 8'h1;
  localparam doub_bt TopLevelCfgRegsRegionStart = 64'h3000_1000;
  localparam doub_bt TopLevelCfgRegsRegionEnd = 64'h3000_2000;

  // External configuration registers: PADs, FLLs, PMU Controller
  localparam byte_bt ExtCfgRegsIdx = 8'h2;
  localparam doub_bt ExtCfgRegsRegionStart = 64'h3000_2000;
  localparam doub_bt ExtCfgRegsRegionEnd = 64'h3000_5000;

  // Hyperbus configuration registers: HyperBus
  localparam byte_bt HyperCfgRegsIdx = 8'h3;
  localparam doub_bt HyperCfgRegsRegionStart = 64'h3000_5000;
  localparam doub_bt HyperCfgRegsRegionEnd = 64'h3000_6000;

  // --------------------------
  // |   External AXI ports   |
  // --------------------------

  // Cluster domain
  localparam byte_bt [iomsb(ExtClusters):0] ClusterIdx = {8'h4, 8'h3, 8'h2, 8'h1, 8'h0};
  localparam doub_bt [iomsb(
ExtClusters
):0] ClusterRegionStart = {
    64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000, 64'h4000_0000
  };
  localparam doub_bt [iomsb(
ExtClusters
):0] ClusterRegionEnd = {
    64'h40A0_0000, 64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000
  };

  localparam aw_bt ClusterNarrowAxiMstIdWidth = 1;

  // Memory Island
  localparam byte_bt MemIslandIdx = ClusterIdx[ExtClusters-1] + 1;
  localparam doub_bt MemIslRegionStart = 64'h4800_0000;
  localparam doub_bt MemIslRegionEnd = 64'h4804_0000;

  localparam aw_bt MemIslAxiMstIdWidth = 1;
  localparam byte_bt MemIslNarrowToWideFactor = 4;
  localparam byte_bt MemIslNarrowPorts = 1;
  localparam byte_bt MemIslWidePorts = $countones(ChimeraClusterCfg.hasWideMasterPort);
  localparam byte_bt MemIslNumWideBanks = 2;
  localparam shrt_bt MemIslWordsPerBank = 1024;

  // Hyperbus
  localparam byte_bt HyperbusIdx = MemIslandIdx + 1;
  localparam doub_bt HyperbusRegionStart = 64'h5000_0000;
  //TODO(smazzola): Correct size of HyperRAM?
  localparam doub_bt HyperbusRegionEnd = HyperbusRegionStart + 64'h1000_0000;

  localparam int unsigned HypNumPhys = 1;
  localparam int unsigned HypNumChips = 2;

  localparam int unsigned LogDepth = 3;
  localparam int unsigned SyncStages = 3;

  // -------------------
  // |   Generate Cfg   |
  // --------------------

  function automatic chimera_cfg_t gen_chimera_cfg();
    localparam int AddrWidth = DefaultCfg.AddrWidth;
    localparam int MemoryIsland = 1;
    localparam int Hyperbus = 1;

    chimera_cfg_t  chimera_cfg;
    cheshire_cfg_t cfg = DefaultCfg;

    // Global CFG

    // Set all Chimera addresses as uncached
    cfg.Cva6ExtCieLength = 'h0;
    cfg.Cva6ExtCieOnTop = 1;

    cfg.Vga = 0;
    cfg.SerialLink = 0;
    // SCHEREMO: Fully remove LLC
    cfg.LlcNotBypass = 0;
    cfg.LlcOutConnect = 0;

    // AXI CFG
    cfg.AxiMstIdWidth = 2;
    cfg.AxiDataWidth = 32;
    cfg.AddrWidth = 32;
    cfg.LlcOutRegionEnd = 'hFFFF_FFFF;

    cfg.AxiExtNumWideMst = $countones(ChimeraClusterCfg.hasWideMasterPort);

    // SCHEREMO: Two ports for each cluster: one to convert stray wides, one for the original narrow
    cfg.AxiExtNumMst = ExtClusters + $countones(ChimeraClusterCfg.hasWideMasterPort);
    cfg.AxiExtNumSlv = ExtClusters + MemoryIsland + Hyperbus;
    cfg.AxiExtNumRules = ExtClusters + MemoryIsland + Hyperbus;

    cfg.AxiExtRegionIdx = {HyperbusIdx, MemIslandIdx, ClusterIdx};
    cfg.AxiExtRegionStart = {HyperbusRegionStart, MemIslRegionStart, ClusterRegionStart};
    cfg.AxiExtRegionEnd = {HyperbusRegionEnd, MemIslRegionEnd, ClusterRegionEnd};

    // REG CFG
    cfg.RegExtNumSlv = ExtRegNum;
    cfg.RegExtNumRules = ExtRegNum;
    cfg.RegExtRegionIdx = {HyperCfgRegsIdx, ExtCfgRegsIdx, TopLevelCfgRegsIdx, SnitchBootROMIdx};
    cfg.RegExtRegionStart = {
      HyperCfgRegsRegionStart,
      ExtCfgRegsRegionStart,
      TopLevelCfgRegsRegionStart,
      SnitchBootROMRegionStart
    };
    cfg.RegExtRegionEnd = {
      HyperCfgRegsRegionEnd, ExtCfgRegsRegionEnd, TopLevelCfgRegsRegionEnd, SnitchBootROMRegionEnd
    };

    // ACCEL HART/IRQ CFG
    cfg.NumExtIrqHarts = ExtCores;
    cfg.NumExtDbgHarts = ExtCores;
    cfg.NumExtOutIntrTgts = ExtCores;

    chimera_cfg = '{
        ChsCfg                    : cfg,
        MemIslRegionStart         : MemIslRegionStart,
        MemIslRegionEnd           : MemIslRegionEnd,
        MemIslAxiMstIdWidth       : MemIslAxiMstIdWidth,
        MemIslNarrowToWideFactor  : MemIslNarrowToWideFactor,
        MemIslNarrowPorts         : MemIslNarrowPorts,
        MemIslWidePorts           : MemIslWidePorts,
        MemIslNumWideBanks        : MemIslNumWideBanks,
        MemIslWordsPerBank        : MemIslWordsPerBank,
        default: '0
    };

    return chimera_cfg;
  endfunction : gen_chimera_cfg

  function automatic chimera_cfg_t gen_chimera_cfg_isolate();
    chimera_cfg_t chimera_cfg;
    chimera_cfg                 = gen_chimera_cfg();
    // Override the isolation params
    chimera_cfg.IsolateClusters = 1;

    return chimera_cfg;
  endfunction : gen_chimera_cfg_isolate

  localparam int unsigned NumCfgs = 2;

  localparam chimera_cfg_t [NumCfgs-1:0] ChimeraCfg = {
    gen_chimera_cfg_isolate(),  // 1: Configuration with Isolation for Power Managemenet
    gen_chimera_cfg()  // 0: Default configuration
  };


  localparam int unsigned RegDataWidth = 32;
  localparam type addr_t = logic [ChimeraCfg[0].ChsCfg.AddrWidth-1:0];
  localparam type data_t = logic [RegDataWidth-1:0];
  localparam type strb_t = logic [RegDataWidth/8-1:0];

  `APB_TYPEDEF_ALL(apb, addr_t, data_t, strb_t)

endpackage
