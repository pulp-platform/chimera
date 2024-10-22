// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Thomas Benz <tbenz@iis.ee.ethz.ch>

/// This package contains parameters used in the simulation environment
package tb_chimera_pkg;

  import chimera_pkg::*;
  import cheshire_pkg::*;

  // A dedicated RT config
  function automatic chimera_cfg_t gen_cheshire_rt_cfg();
    cheshire_cfg_t ChsCfg = DefaultCfg;
    chimera_cfg_t  ret;
    ret.ChsCfg.AxiRt = 1;
    return ret;
  endfunction

  // An embedded 32 bit config
  function automatic chimera_cfg_t gen_cheshire_emb_cfg();
    cheshire_cfg_t ChsCfg = DefaultCfg;
    chimera_cfg_t  ret;
    ret.ChsCfg.Vga          = 0;
    ret.ChsCfg.SerialLink   = 0;
    ret.ChsCfg.AxiUserWidth = 64;
    return ret;
  endfunction : gen_cheshire_emb_cfg

  // Number of Cheshire configurations
  localparam int unsigned NumCheshireConfigs = 32'd3;

  // Assemble a configuration array indexed by a numeric parameter
  localparam chimera_cfg_t [NumCheshireConfigs-1:0] TbCheshireConfigs = {
    gen_cheshire_emb_cfg(),  // 2: Embedded configuration
    gen_cheshire_rt_cfg(),  // 1: RT-enabled configuration
    DefaultCfg  // 0: Default configuration
  };

  // HyperBus
  localparam int HypNumPhys = 2;
  localparam int HypNumChips = 2;

endpackage
