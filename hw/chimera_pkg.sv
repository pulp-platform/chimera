// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

package chimera_pkg;

// TODO: Include APB TYPEDEF
`include "apb/typedef.svh"

   import cheshire_pkg::*;

   // ACCEL CFG
   localparam int ExtClusters = 5;

   typedef struct packed {
      logic [iomsb(ExtClusters):0] hasWideMasterPort;
      byte_bt [iomsb(ExtClusters):0] NrCores;
   } ClusterConfig;

   localparam ClusterConfig ChimeraClusterCfg = {
                                                 hasWideMasterPort: {1'b1, 1'b1, 1'b1, 1'b1, 1'b1},
                                                 NrCores: {8'h9, 8'h9, 8'h9, 8'h9, 8'h9}
                                                 };

   function automatic int _sumVector(byte_bt [iomsb(ExtClusters):0] vector, int vectorLen);
      int sum = 0;
      for(int i=0; i<vectorLen; i++) begin
         sum += vector[i];
      end
      return sum;
   endfunction


   localparam int ExtCores = _sumVector(ChimeraClusterCfg.NrCores, ExtClusters);

   // SoC Config
   localparam int SnitchBootROM = 1;

   // SCHEREMO: Shared Snitch bootrom, one clock gate per cluster, Fll cfg regs, Pad cfg regs
   localparam int ExtRegNum = SnitchBootROM + 1 + 1 + 1;

   localparam int SnitchBootROMIdx = 0;
   localparam     doub_bt SnitchBootROMRegionStart = 64'h3000_0000;
   localparam     doub_bt SnitchBootROMRegionEnd = 64'h3000_1000;

   localparam int TopLevelIdx = 1;
   localparam     doub_bt TopLevelRegionStart = 64'h3000_1000;
   localparam     doub_bt TopLevelRegionEnd = 64'h3000_2000;

   // PADs external configuration registers
   localparam int PadIdx = 2;
   localparam doub_bt PadRegionStart = 64'h3000_8000;
   localparam doub_bt PadRegionEnd = 64'h3000_9000;

   // FLL external configuration registers
   localparam int FllIdx = 3;
   localparam doub_bt FllRegionStart = 64'h3000_9000;
   localparam doub_bt FllRegionEnd = 64'h3000_a000;

   function automatic cheshire_cfg_t gen_chimera_cfg();
      localparam AddrWidth = DefaultCfg.AddrWidth;

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
      // SCHEREMO: Assume 2 Master per cluster -> 5 clusters, 1 host core, 1 DMA, 1 DBG Unit
      cfg.AxiMstIdWidth = 4;

      cfg.MemIslWidePorts = $countones(ChimeraClusterCfg.hasWideMasterPort);
      cfg.AxiExtNumWideMst = $countones(ChimeraClusterCfg.hasWideMasterPort);
      // SCHEREMO: Two ports for each cluster: one to convert stray wides, one for the original narrow
      cfg.AxiExtNumMst = ExtClusters + $countones(ChimeraClusterCfg.hasWideMasterPort);
      cfg.AxiExtNumSlv = ExtClusters;
      cfg.AxiExtNumRules = ExtClusters;
      cfg.AxiExtRegionIdx = {8'h4, 8'h3, 8'h2, 8'h1, 8'h0};
      cfg.AxiExtRegionStart = {64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000, 64'h4000_0000};
      cfg.AxiExtRegionEnd = {64'h40A0_0000, 64'h4080_0000, 64'h4060_0000, 64'h4040_0000, 64'h4020_0000};

      // REG CFG
      cfg.RegExtNumSlv = ExtRegNum;
      cfg.RegExtNumRules = ExtRegNum;
      cfg.RegExtRegionIdx = {8'h3, 8'h2, 8'h1, 8'h0}; // SnitchBootROM
      cfg.RegExtRegionStart = {PadRegionStart, FllRegionStart, TopLevelRegionStart, SnitchBootROMRegionStart};
      cfg.RegExtRegionEnd = {PadRegionEnd, FllRegionEnd, TopLevelRegionEnd, SnitchBootROMRegionEnd};

      // ACCEL HART/IRQ CFG
      cfg.NumExtIrqHarts = ExtCores;
      cfg.NumExtDbgHarts = ExtCores;
      cfg.NumExtOutIntrTgts = ExtCores;

      return cfg;
   endfunction // gen_chimera_cfg

   localparam int numCfgs = 1;

   localparam cheshire_cfg_t [numCfgs-1:0] ChimeraCfg =
    {gen_chimera_cfg()
     };

   // To move into cheshire TYPEDEF
   localparam int unsigned RegDataWidth = 32;
   localparam type addr_t = logic[DefaultCfg.AddrWidth-1:0];
   // localparam type data_t = logic[DefaultCfg.AxiDataWidth];
    localparam type data_t = logic[RegDataWidth-1:0];
   localparam type strb_t = logic[RegDataWidth/8-1:0];

   `APB_TYPEDEF_ALL(apb,addr_t, data_t, strb_t)

endpackage
