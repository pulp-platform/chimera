// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

// Collects all existing verification IP (VIP) in one module for use in testbenches of
// Cheshire-based SoCs and Chips. IOs are of inout direction where applicable.

module vip_chimera_soc
  import cheshire_pkg::*;
  import chimera_pkg::HypNumPhys;
  import chimera_pkg::HypNumChips;
#(
  // DUT (must be set)
  parameter cheshire_cfg_t DutCfg = '0,

  parameter type         axi_ext_mst_req_t      = logic,
  parameter type         axi_ext_mst_rsp_t      = logic,
  // Timing
  parameter time         ClkPeriodClu           = 2ns,
  parameter time         ClkPeriodSys           = 5ns,
  parameter time         ClkPeriodJtag          = 20ns,
  parameter time         ClkPeriodRtc           = 30518ns,
  parameter int unsigned RstCycles              = 5,
  parameter real         TAppl                  = 0.1,
  parameter real         TTest                  = 0.9,
  // UART
  parameter int unsigned UartBaudRate           = 115200,
  parameter int unsigned UartParityEna          = 0,
  parameter int unsigned UartBurstBytes         = 256,
  parameter int unsigned UartWaitCycles         = 60,
  // Serial Link
  parameter int unsigned SlinkMaxWaitAx         = 100,
  parameter int unsigned SlinkMaxWaitR          = 5,
  parameter int unsigned SlinkMaxWaitResp       = 20,
  parameter int unsigned SlinkBurstBytes        = 1024,
  parameter int unsigned SlinkMaxTxns           = 32,
  parameter int unsigned SlinkMaxTxnsPerId      = 16,
  parameter bit          SlinkAxiDebug          = 0,
  // HyperRAM (hardcoded to HypNumPhys = 2)
  parameter int unsigned HypUserPreload         = 0,
  parameter string       Hyp0UserPreloadMemFile = "",
  // Derived Parameters;  *do not override*
  parameter int unsigned AxiStrbWidth           = DutCfg.AxiDataWidth / 8,
  parameter int unsigned AxiStrbBits            = $clog2(DutCfg.AxiDataWidth / 8)
) (
  output logic                                   soc_clk,
  output logic                                   clu_clk,
  output logic                                   rst_n,
  output logic                                   test_mode,
  output logic [           1:0]                  boot_mode,
  output logic                                   rtc,
  // JTAG interface
  output logic                                   jtag_tck,
  output logic                                   jtag_trst_n,
  output logic                                   jtag_tms,
  output logic                                   jtag_tdi,
  input  logic                                   jtag_tdo,
  // UART interface
  input  logic                                   uart_tx,
  output logic                                   uart_rx,
  // I2C interface
  inout  wire                                    i2c_sda,
  inout  wire                                    i2c_scl,
  // SPI host interface
  inout  wire                                    spih_sck,
  inout  wire  [ SpihNumCs-1:0]                  spih_csb,
  inout  wire  [           3:0]                  spih_sd,
  // Hyperbus interface
         wire  [HypNumPhys-1:0][HypNumChips-1:0] pad_hyper_csn,
         wire  [HypNumPhys-1:0]                  pad_hyper_ck,
         wire  [HypNumPhys-1:0]                  pad_hyper_ckn,
         wire  [HypNumPhys-1:0]                  pad_hyper_rwds,
         wire  [HypNumPhys-1:0]                  pad_hyper_resetn,
         wire  [HypNumPhys-1:0][            7:0] pad_hyper_dq
);

  `include "cheshire/typedef.svh"
  `include "axi/assign.svh"

  `CHESHIRE_TYPEDEF_ALL(, DutCfg)

  ///////////
  //  DPI  //
  ///////////

  import "DPI-C" function byte read_elf(input string filename);
  import "DPI-C" function byte get_entry(output longint entry);
  import "DPI-C" function byte get_section(
    output longint address,
    output longint len
  );
  import "DPI-C" context function byte read_section(
    input longint address,
    inout byte    buffer [],
    input longint len
  );


  // CLU Clock Gen

  clk_rst_gen #(
    .ClkPeriod   (ClkPeriodClu),
    .RstClkCycles(RstCycles)
  ) i_clk_rst_clu (
    .clk_o (clu_clk),
    .rst_no()
  );

  ///////////////////////////////
  //  SoC Clock, Reset, Modes  //
  ///////////////////////////////

  clk_rst_gen #(
    .ClkPeriod   (ClkPeriodSys),
    .RstClkCycles(RstCycles)
  ) i_clk_rst_sys (
    .clk_o (soc_clk),
    .rst_no()
  );

  clk_rst_gen #(
    .ClkPeriod   (ClkPeriodRtc),
    .RstClkCycles(RstCycles)
  ) i_clk_rst_rtc (
    .clk_o (rtc),
    .rst_no()
  );

  initial begin
    rst_n = 0;
    #(RstCycles * ClkPeriodSys);
    rst_n = 1;
    #(RstCycles * ClkPeriodSys);
    rst_n = 0;
    // Keep negative pulse active enough to avoid hyperbus timing violations (x50 empirical)
    #(RstCycles * ClkPeriodSys * 25);
    rst_n = 1;
  end

  initial begin
    test_mode = '0;
    boot_mode = '0;
  end

  task wait_for_reset;
    @(posedge rst_n);
    @(posedge soc_clk);
  endtask

  task set_test_mode(input logic mode);
    test_mode = mode;
  endtask

  task set_boot_mode(input logic [1:0] mode);
    boot_mode = mode;
  endtask

  ////////////
  //  JTAG  //
  ////////////

  localparam dm::sbcs_t JtagInitSbcs = '{
      sbautoincrement: 1'b1,
      sbreadondata: 1'b1,
      sbaccess: $clog2(riscv::XLEN / 8),
      default: '0
  };

  // Generate clock
  clk_rst_gen #(
    .ClkPeriod   (ClkPeriodJtag),
    .RstClkCycles(RstCycles)
  ) i_clk_jtag (
    .clk_o (jtag_tck),
    .rst_no()
  );

  // Define test bus and driver
  JTAG_DV jtag (jtag_tck);

  typedef jtag_test::riscv_dbg#(
    .IrLength(5),
    .TA      (ClkPeriodJtag * TAppl),
    .TT      (ClkPeriodJtag * TTest)
  ) riscv_dbg_t;

  riscv_dbg_t::jtag_driver_t jtag_dv = new(jtag);
  riscv_dbg_t                jtag_dbg = new(jtag_dv);

  // Connect DUT to test bus
  assign jtag_trst_n = jtag.trst_n;
  assign jtag_tms    = jtag.tms;
  assign jtag_tdi    = jtag.tdi;
  assign jtag.tdo    = jtag_tdo;

  initial begin
    @(negedge rst_n);
    jtag_dbg.reset_master();
  end

  task automatic jtag_write(input dm::dm_csr_e addr, input word_bt data, input bit wait_cmd = 0,
                            input bit wait_sba = 0);
    jtag_dbg.write_dmi(addr, data);
    if (wait_cmd) begin
      dm::abstractcs_t acs;
      do begin
        jtag_dbg.read_dmi_exp_backoff(dm::AbstractCS, acs);
        if (acs.cmderr) $fatal(1, "[JTAG] Abstract command error!");
      end while (acs.busy);
    end
    if (wait_sba) begin
      dm::sbcs_t sbcs;
      do begin
        jtag_dbg.read_dmi_exp_backoff(dm::SBCS, sbcs);
        if (sbcs.sberror | sbcs.sbbusyerror) $fatal(1, "[JTAG] System bus error!");
      end while (sbcs.sbbusy);
    end
  endtask

  task automatic jtag_poll_bit0(input doub_bt addr, output word_bt data,
                                input int unsigned idle_cycles);
    automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
    jtag_write(dm::SBCS, sbcs, 0, 1);
    jtag_write(dm::SBAddress1, addr[63:32]);
    do begin
      jtag_write(dm::SBAddress0, addr[31:0]);
      jtag_dbg.wait_idle(idle_cycles);
      jtag_dbg.read_dmi_exp_backoff(dm::SBData0, data);
    end while (~data[0]);
  endtask

  // Initialize the debug module
  task automatic jtag_init;
    jtag_idcode_t   idcode;
    dm::dmcontrol_t dmcontrol = '{dmactive: 1, default: '0};
    // Check ID code
    repeat (10000) @(posedge jtag_tck);
    jtag_dbg.get_idcode(idcode);
    if (idcode != DutCfg.DbgIdCode)
      $fatal(1, "[JTAG] Unexpected ID code: expected 0x%h, got 0x%h!", DutCfg.DbgIdCode, idcode);
    // Activate, wait for debug module
    jtag_write(dm::DMControl, dmcontrol);
    do jtag_dbg.read_dmi_exp_backoff(dm::DMControl, dmcontrol); while (~dmcontrol.dmactive);
    // Activate, wait for system bus
    jtag_write(dm::SBCS, JtagInitSbcs, 0, 1);
    $display("[JTAG] Initialization success");
  endtask

  task automatic jtag_read_reg32(input doub_bt addr, output word_bt data,
                                 input int unsigned idle_cycles = 20);
    automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
    jtag_write(dm::SBCS, sbcs, 0, 1);
    jtag_write(dm::SBAddress1, addr[63:32]);
    jtag_write(dm::SBAddress0, addr[31:0]);
    jtag_dbg.wait_idle(idle_cycles);
    jtag_dbg.read_dmi_exp_backoff(dm::SBData0, data);
    $display("[JTAG] Read 0x%h from 0x%h", data, addr);
  endtask

  task automatic jtag_write_reg32(input doub_bt addr, input word_bt data, input bit check_write,
                                  input int unsigned check_write_wait_cycles = 20);
    automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbaccess: 2, default: '0};
    $display("[JTAG] Writing 0x%h to 0x%h", data, addr);
    jtag_write(dm::SBCS, sbcs, 0, 1);
    jtag_write(dm::SBAddress1, addr[63:32]);
    jtag_write(dm::SBAddress0, addr[31:0]);
    jtag_write(dm::SBData0, data);
    jtag_dbg.wait_idle(check_write_wait_cycles);
    if (check_write) begin
      word_bt rdata;
      jtag_read_reg32(addr, rdata);
      if (rdata != data) $fatal(1, "[JTAG] - Read back incorrect data 0x%h!", rdata);
      else $display("[JTAG] - Read back correct data");
    end
  endtask

  // Load a binary
  task automatic jtag_elf_preload(input string binary, output doub_bt entry);
    longint sec_addr, sec_len;
    $display("[JTAG] Preloading ELF binary: %s", binary);
    if (read_elf(binary)) $fatal(1, "[JTAG] Failed to load ELF!");
    while (get_section(
        sec_addr, sec_len
    )) begin
      byte bf[] = new[sec_len];
      $display("[JTAG] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[JTAG] Failed to read ELF section!");
      jtag_write(dm::SBCS, JtagInitSbcs, 1, 1);
      // Write address as 64-bit double
      jtag_write(dm::SBAddress1, sec_addr[63:32]);
      jtag_write(dm::SBAddress0, sec_addr[31:0]);
      for (longint i = 0; i <= sec_len; i += riscv::XLEN / 8) begin
        bit checkpoint = (i != 0 && i % 512 == 0);
        if (checkpoint)
          $display(
              "[JTAG] - %0d/%0d bytes (%0d%%)",
              i,
              sec_len,
              i * 100 / (sec_len > 1 ? sec_len - 1 : 1)
          );
        jtag_write(dm::SBData1, {bf[i+7], bf[i+6], bf[i+5], bf[i+4]}, 0, 1);
        jtag_write(dm::SBData0, {bf[i+3], bf[i+2], bf[i+1], bf[i]}, 1, 1);
      end
    end
    void'(get_entry(entry));
    $display("[JTAG] Preload complete");
  endtask

  // Halt the core and preload a binary
  task automatic jtag_elf_halt_load(input string binary, output doub_bt entry);
    dm::dmstatus_t status;
    // Halt hart 0
    jtag_write(dm::DMControl, dm::dmcontrol_t'{haltreq: 1, dmactive: 1, default: '0});
    do jtag_dbg.read_dmi_exp_backoff(dm::DMStatus, status); while (~status.allhalted);
    $display("[JTAG] Halted hart 0");
    // Preload binary
    jtag_elf_preload(binary, entry);
  endtask

  // Halt the core
  task automatic jtag_halt_hart();
    dm::dmstatus_t status;
    // Halt hart 0
    jtag_write(dm::DMControl, dm::dmcontrol_t'{haltreq: 1, dmactive: 1, default: '0});
    do jtag_dbg.read_dmi_exp_backoff(dm::DMStatus, status); while (~status.allhalted);
    repeat (2) @(posedge jtag_tck);
    $display("[JTAG] Halted hart 0");
  endtask

  // Unhalt the core
  task automatic jtag_resume_hart();
    doub_bt entry;
    repeat (2) @(posedge jtag_tck);
    void'(get_entry(entry));
    // Repoint execution
    jtag_write(dm::Data1, entry[63:32]);
    jtag_write(dm::Data0, entry[31:0]);
    if (riscv::XLEN == 64) begin
      jtag_write(dm::Command, 32'h0033_07b1, 0, 1);
    end else begin
      jtag_write(dm::Command, 32'h0023_07b1, 0, 1);
    end
    // Resume hart 0
    jtag_write(dm::DMControl, dm::dmcontrol_t'{resumereq: 1, dmactive: 1, default: '0});
    $display("[JTAG] Resumed hart 0 from 0x%h", entry);
  endtask

  // Run a binary
  task automatic jtag_elf_run(input string binary);
    doub_bt entry;
    jtag_elf_halt_load(binary, entry);
    // Repoint execution
    jtag_write(dm::Data1, entry[63:32]);
    jtag_write(dm::Data0, entry[31:0]);
    if (riscv::XLEN == 64) begin
      jtag_write(dm::Command, 32'h0033_07b1, 0, 1);
    end else begin
      jtag_write(dm::Command, 32'h0023_07b1, 0, 1);
    end
    // Resume hart 0
    jtag_write(dm::DMControl, dm::dmcontrol_t'{resumereq: 1, dmactive: 1, default: '0});
    $display("[JTAG] Resumed hart 0 from 0x%h", entry);
  endtask

  // Wait for termination signal and get return code
  task automatic jtag_wait_for_eoc(output word_bt exit_code);
    jtag_poll_bit0(AmRegs + cheshire_reg_pkg::CHESHIRE_SCRATCH_2_OFFSET, exit_code, 4000);
    exit_code >>= 1;
    if (exit_code) $error("[JTAG] FAILED: return code %0d", exit_code);
    else $display("[JTAG] SUCCESS");
  endtask

  ////////////
  //  UART  //
  ////////////

  localparam time UartBaudPeriod = 1000ns * 1000 * 1000 / UartBaudRate;

  localparam byte_bt UartDebugCmdRead = 'h11;
  localparam byte_bt UartDebugCmdWrite = 'h12;
  localparam byte_bt UartDebugCmdExec = 'h13;
  localparam byte_bt UartDebugAck = 'h06;
  localparam byte_bt UartDebugEot = 'h04;
  localparam byte_bt UartDebugEoc = 'h14;

  byte_bt uart_boot_byte;
  logic   uart_boot_ena;
  logic   uart_boot_eoc;
  logic   uart_reading_byte;

  initial begin
    uart_rx           = 1;
    uart_boot_eoc     = 0;
    uart_boot_ena     = 0;
    uart_reading_byte = 0;
  end

  task automatic uart_read_byte(output byte_bt bite);
    // Start bit
    @(negedge uart_tx);
    uart_reading_byte = 1;
    #(UartBaudPeriod / 2);
    // 8-bit byte
    for (int i = 0; i < 8; i++) begin
      #UartBaudPeriod bite[i] = uart_tx;
    end
    // Parity bit
    if (UartParityEna) begin
      bit parity;
      #UartBaudPeriod parity = uart_tx;
      if (parity ^ (^bite)) $error("[UART] - Parity error detected!");
    end
    // Stop bit
    #UartBaudPeriod;
    uart_reading_byte = 0;
  endtask

  task automatic uart_write_byte(input byte_bt bite);
    // Start bit
    uart_rx = 1'b0;
    // 8-bit byte
    for (int i = 0; i < 8; i++) #UartBaudPeriod uart_rx = bite[i];
    // Parity bit
    if (UartParityEna) #UartBaudPeriod uart_rx = (^bite);
    // Stop bit
    #UartBaudPeriod uart_rx = 1'b1;
    #UartBaudPeriod;
  endtask

  task automatic uart_boot_scoop(output byte_bt bite);
    // Assert our intention to scoop the next received byte
    uart_boot_ena = 1;
    // Wait until read task notifies us a scooped byte is available
    @(negedge uart_boot_ena);
    // Grab scooped byte
    bite = uart_boot_byte;
  endtask

  task automatic uart_boot_scoop_expect(input string name, input byte_bt exp);
    byte_bt bite;
    uart_boot_scoop(bite);
    if (bite != exp)
      $fatal(1, "[UART] Expected %s (%0x) after read command, received %0x", name, exp, bite);
  endtask

  // Continually read characters and print lines
  // TODO: we should be able to support CR properly, but buffers are hard to deal with...
  initial begin
    static byte_bt uart_read_buf[$];
    byte_bt        bite;
    wait_for_reset();
    forever begin
      uart_read_byte(bite);
      if (uart_boot_ena) begin
        uart_boot_byte = bite;
        uart_boot_ena  = 0;
      end else if (bite == "\n") begin
        $display("[UART] %s", {>>8{uart_read_buf}});
        uart_read_buf.delete();
      end else if (bite == UartDebugEoc) begin
        uart_boot_eoc = 1;
      end else begin
        uart_read_buf.push_back(bite);
        $display("Read Byte: %s", bite);
      end
    end
  end

  // A length of zero indcates a write (write lengths are inferred from their queue)
  task automatic uart_debug_rw(doub_bt addr, doub_bt len_or_w, ref byte_bt data[$]);
    byte_bt bite;
    doub_bt len = len_or_w ? len_or_w : data.size();
    // Send command, address, and length
    uart_write_byte(len_or_w ? UartDebugCmdRead : UartDebugCmdWrite);
    for (int i = 0; i < 8; ++i) uart_write_byte(addr[8*i+:8]);
    for (int i = 0; i < 8; ++i) uart_write_byte(len[8*i+:8]);
    // Receive and check ACK
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Send or receive requested data
    for (int i = 0; i < len; ++i) begin
      if (len_or_w) begin
        uart_boot_scoop(bite);
        data.push_back(bite);
      end else begin
        uart_write_byte(data[i]);
      end
    end
    // Receive and check EOT
    uart_boot_scoop_expect("EOT", UartDebugEot);
  endtask

  // Load a binary
  task automatic uart_debug_elf_preload(input string binary, output doub_bt entry);
    longint sec_addr, sec_len;
    $display("[UART] Preloading ELF binary: %s", binary);
    if (read_elf(binary)) $fatal(1, "[UART] Failed to load ELF!");
    while (get_section(
        sec_addr, sec_len
    )) begin
      byte bf[] = new[sec_len];
      $display("[UART] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[UART] Failed to read ELF section!");
      // Write section in blocks
      for (longint i = 0; i <= sec_len; i += UartBurstBytes) begin
        byte_bt bytes[$];
        if (i != 0)
          $display(
              "[UART] - %0d/%0d bytes (%0d%%)",
              i,
              sec_len,
              i * 100 / (sec_len > 1 ? sec_len - 1 : 1)
          );
        for (int b = 0; b < UartBurstBytes; b++) begin
          if (i + b >= sec_len) break;
          bytes.push_back(bf[i+b]);
        end
        uart_debug_rw(sec_addr + i, 0, bytes);
      end
    end
    void'(get_entry(entry));
    $display("[UART] Preload complete");
  endtask

  task automatic uart_debug_elf_run_and_wait(input string binary, output word_bt exit_code);
    byte_bt bite;
    doub_bt entry;
    // Wait some time for boot ROM to settle (No way to query this using only UART)
    $display("[UART] Waiting for debug loop to start");
    #(UartWaitCycles * UartBaudPeriod);
    // We send an ACK challenge to the debug server and wait for an ACK response
    $display("[UART] Sending ACK chellenge");
    uart_write_byte(UartDebugAck);
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Preload
    uart_debug_elf_preload(binary, entry);
    $display("[UART] Sending EXEC command for address %0x", entry);
    // Send exec command and receive ACK
    uart_write_byte(UartDebugCmdExec);
    for (int i = 0; i < 8; ++i) uart_write_byte(entry[8*i+:8]);
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Wait for EOC and read return code
    wait (uart_boot_eoc == 1);
    $display("[UART] Received EOC signal");
    uart_boot_eoc = 0;
    for (int i = 0; i < 4; ++i) uart_boot_scoop(exit_code[8*i+:8]);
    // Report exit code
    if (exit_code) $error("[UART] FAILED: return code %0d", exit_code);
    else $display("[UART] SUCCESS");
  endtask

  ///////////
  //  I2C  //
  ///////////

  // Write-protect only chip 0
  bit [3:0] i2c_wp = 4'b0001;

  // We connect 2 chips available at different addresses;
  // however, the boot ROM will always boot from chip 0.
  for (genvar i = 0; i < 2; i++) begin : gen_i2c_eeproms
    M24FC1025 i_i2c_eeprom (
      .RESET(rst_n),
      .A0   (i[0]),
      .A1   (1'b0),
      .A2   (1'b1),
      .WP   (i2c_wp[i]),
      .SDA  (i2c_sda),
      .SCL  (i2c_scl)
    );
  end

  // Preload function called by testbench
  task automatic i2c_eeprom_preload(string image);
    // We overlay the entire memory with an alternating pattern
    for (int k = 0; k < $size(gen_i2c_eeproms[0].i_i2c_eeprom.MemoryBlock); ++k)
      gen_i2c_eeproms[0].i_i2c_eeprom.MemoryBlock[k] = 'h9a;
    // We load an image into chip 0 only if it exists
    if (image != "") $readmemh(image, gen_i2c_eeproms[0].i_i2c_eeprom.MemoryBlock);
  endtask

  ////////////////
  //  SPI Host  //
  ////////////////

  // We connect one chip at CS1, where we can boot from this flash.
  s25fs512s #(
    .UserPreload(0)
  ) i_spi_norflash (
    .SI      (spih_sd[0]),
    .SO      (spih_sd[1]),
    .WPNeg   (spih_sd[2]),
    .RESETNeg(spih_sd[3]),
    .SCK     (spih_sck),
    .CSNeg   (spih_csb[1])
  );

  // Preload function called by testbench
  task automatic spih_norflash_preload(string image);
    // We overlay the entire memory with an alternating pattern
    for (int k = 0; k < $size(i_spi_norflash.Mem); ++k) i_spi_norflash.Mem[k] = 'h9a;
    // We load an image into chip 0 only if it exists
    if (image != "") $readmemh(image, i_spi_norflash.Mem);
  endtask

  //////////////
  // Hyperbus //
  //////////////

  localparam string HypUserPreloadMemFiles[HypNumPhys] = '{Hyp0UserPreloadMemFile};

  for (genvar i = 0; i < HypNumPhys; i++) begin : hyperrams
    for (genvar j = 0; j < HypNumChips; j++) begin : chips
      s27ks0641 #(
        .UserPreload  (HypUserPreload),
        .mem_file_name(HypUserPreloadMemFiles[i]),
        .TimingModel  ("S27KS0641DPBHI020")
      ) dut (
        .DQ7     (pad_hyper_dq[i][7]),
        .DQ6     (pad_hyper_dq[i][6]),
        .DQ5     (pad_hyper_dq[i][5]),
        .DQ4     (pad_hyper_dq[i][4]),
        .DQ3     (pad_hyper_dq[i][3]),
        .DQ2     (pad_hyper_dq[i][2]),
        .DQ1     (pad_hyper_dq[i][1]),
        .DQ0     (pad_hyper_dq[i][0]),
        .RWDS    (pad_hyper_rwds[i]),
        .CSNeg   (pad_hyper_csn[i][j]),
        .CK      (pad_hyper_ck[i]),
        .CKNeg   (pad_hyper_ckn[i]),
        .RESETNeg(pad_hyper_resetn[i])
      );
    end
  end

  for (genvar p = 0; p < HypNumPhys; p++) begin : sdf_annotation
    for (genvar l = 0; l < HypNumChips; l++) begin : sdf_annotation
      initial begin
`ifndef PATH_TO_HYP_SDF
        automatic string sdf_file_path = "../models/s27ks0641/s27ks0641.sdf";
`else
        automatic string sdf_file_path = `PATH_TO_HYP_SDF;
`endif
        $sdf_annotate(sdf_file_path, hyperrams[p].chips[l].dut);
        $display("Mem (%d,%d)", p, l);
      end
    end
  end

endmodule

// Map pad IO to tristate wires to adapt from SoC IO (not needed for chip instances).

module vip_cheshire_soc_tristate
  import cheshire_pkg::*;
#(
  parameter int unsigned HypNumPhys  = 1,
  parameter int unsigned HypNumChips = 2
) (
  // I2C pad IO
  output logic                                   i2c_sda_i,
  input  logic                                   i2c_sda_o,
  input  logic                                   i2c_sda_en,
  output logic                                   i2c_scl_i,
  input  logic                                   i2c_scl_o,
  input  logic                                   i2c_scl_en,
  // SPI host pad IO
  input  logic                                   spih_sck_o,
  input  logic                                   spih_sck_en,
  input  logic [ SpihNumCs-1:0]                  spih_csb_o,
  input  logic [ SpihNumCs-1:0]                  spih_csb_en,
  output logic [           3:0]                  spih_sd_i,
  input  logic [           3:0]                  spih_sd_o,
  input  logic [           3:0]                  spih_sd_en,
  // I2C wires
  inout  wire                                    i2c_sda,
  inout  wire                                    i2c_scl,
  // SPI host wires
  inout  wire                                    spih_sck,
  inout  wire  [ SpihNumCs-1:0]                  spih_csb,
  inout  wire  [           3:0]                  spih_sd,
  // Hyperbus pad IO
  input  logic [HypNumPhys-1:0][HypNumChips-1:0] hyper_cs_no,
  output logic [HypNumPhys-1:0]                  hyper_ck_i,
  input  logic [HypNumPhys-1:0]                  hyper_ck_o,
  output logic [HypNumPhys-1:0]                  hyper_ck_ni,
  input  logic [HypNumPhys-1:0]                  hyper_ck_no,
  input  logic [HypNumPhys-1:0]                  hyper_rwds_o,
  output logic [HypNumPhys-1:0]                  hyper_rwds_i,
  input  logic [HypNumPhys-1:0]                  hyper_rwds_oe_o,
  output logic [HypNumPhys-1:0][            7:0] hyper_dq_i,
  input  logic [HypNumPhys-1:0][            7:0] hyper_dq_o,
  input  logic [HypNumPhys-1:0]                  hyper_dq_oe_o,
  input  logic [HypNumPhys-1:0]                  hyper_reset_no,
  // Hyperbus wires
         wire  [HypNumPhys-1:0][HypNumChips-1:0] pad_hyper_csn,
         wire  [HypNumPhys-1:0]                  pad_hyper_ck,
         wire  [HypNumPhys-1:0]                  pad_hyper_ckn,
         wire  [HypNumPhys-1:0]                  pad_hyper_rwds,
         wire  [HypNumPhys-1:0]                  pad_hyper_resetn,
         wire  [HypNumPhys-1:0][            7:0] pad_hyper_dq
);

  // I2C
  bufif1 (i2c_sda_i, i2c_sda, ~i2c_sda_en);
  bufif1 (i2c_sda, i2c_sda_o, i2c_sda_en);
  bufif1 (i2c_scl_i, i2c_scl, ~i2c_scl_en);
  bufif1 (i2c_scl, i2c_scl_o, i2c_scl_en);
  pullup (i2c_sda);
  pullup (i2c_scl);

  // SPI
  bufif1 (spih_sck, spih_sck_o, spih_sck_en);
  pullup (spih_sck);

  for (genvar i = 0; i < 4; ++i) begin : gen_spih_sd_io
    bufif1 (spih_sd_i[i], spih_sd[i], ~spih_sd_en[i]);
    bufif1 (spih_sd[i], spih_sd_o[i], spih_sd_en[i]);
    pullup (spih_sd[i]);
  end

  for (genvar i = 0; i < SpihNumCs; ++i) begin : gen_spih_cs_io
    bufif1 (spih_csb[i], spih_csb_o[i], spih_csb_en[i]);
    pullup (spih_csb[i]);
  end

  for (genvar i = 0; i < HypNumPhys; i++) begin : gen_hyper_phy
    for (genvar j = 0; j < HypNumChips; j++) begin : gen_hyper_cs
      pad_functional_pd padinst_hyper_csno (
        .OEN(1'b0),
        .I  (hyper_cs_no[i][j]),
        .O  (),
        .PEN(),
        .PAD(pad_hyper_csn[i][j])
      );
    end
    pad_functional_pd padinst_hyper_ck (
      .OEN(1'b0),
      .I  (hyper_ck_o[i]),
      .O  (),
      .PEN(),
      .PAD(pad_hyper_ck[i])
    );
    pad_functional_pd padinst_hyper_ckno (
      .OEN(1'b0),
      .I  (hyper_ck_no[i]),
      .O  (),
      .PEN(),
      .PAD(pad_hyper_ckn[i])
    );
    pad_functional_pd padinst_hyper_rwds0 (
      .OEN(~hyper_rwds_oe_o[i]),
      .I  (hyper_rwds_o[i]),
      .O  (hyper_rwds_i[i]),
      .PEN(),
      .PAD(pad_hyper_rwds[i])
    );
    pad_functional_pd padinst_hyper_resetn (
      .OEN(1'b0),
      .I  (hyper_reset_no[i]),
      .O  (),
      .PEN(),
      .PAD(pad_hyper_resetn[i])
    );
    for (genvar j = 0; j < 8; j++) begin : gen_hyper_dq
      pad_functional_pd padinst_hyper_dqio0 (
        .OEN(~hyper_dq_oe_o[i]),
        .I  (hyper_dq_o[i][j]),
        .O  (hyper_dq_i[i][j]),
        .PEN(),
        .PAD(pad_hyper_dq[i][j])
      );
    end
  end : gen_hyper_phy

endmodule
