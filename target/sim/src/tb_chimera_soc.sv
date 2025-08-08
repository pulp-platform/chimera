// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

module tb_chimera_soc
  import cheshire_pkg::*;
#(
  /// The selected simulation configuration from the `tb_chimera_pkg`.
  parameter int unsigned SelectedCfg = 32'd0
);

  fixture_chimera_soc #(.SelectedCfg(SelectedCfg)) fix ();

  string        preload_elf;
  string        boot_hex;
  logic  [ 1:0] boot_mode;
  logic  [ 1:0] preload_mode;
  bit    [31:0] exit_code;
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

  // Load a binary
  task automatic force_write(doub_bt addr, doub_bt data);
    static doub_bt write_addr;
    static doub_bt write_data;
    write_addr = addr;
    write_data = data;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_addr_i[1] = write_addr;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_req_i[1] = 1'b1;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_we_i[1] = 1'b1;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_wdata_i[1] = write_data;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_strb_i[1] = 4'hf;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_gnt_o[1] = 1'b0;
    force fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_rvalid_o[1] = 1'b0;
  endtask


  task automatic fast_elf_preload(input string binary);
    longint sec_addr, sec_len;
    $display("[FAST PRELOAD] Preloading ELF binary: %s", binary);
    if (read_elf(binary)) $fatal(1, "[JTAG] Failed to load ELF!");
    while (get_section(
        sec_addr, sec_len
    )) begin
      byte bf[] = new[sec_len];
      $display("[FAST PRELOAD] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len))
        $fatal(1, "[FAST PRELOAD] Failed to read ELF section!");
      @(posedge fix.vip.soc_clk);  // 
      for (longint i = 0; i <= sec_len; i += riscv::XLEN / 8) begin
        bit checkpoint = (i != 0 && i % 512 == 0);
        if (checkpoint)
          $display(
              "[FAST PRELOAD] - %0d/%0d bytes (%0d%%)",
              i,
              sec_len,
              i * 100 / (sec_len > 1 ? sec_len - 1 : 1)
          );
        @(posedge fix.vip.soc_clk);
        force_write((sec_addr + i), {bf[i+3], bf[i+2], bf[i+1], bf[i]});
      end
    end
    @(posedge fix.vip.soc_clk);
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_addr_i[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_req_i[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_we_i[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_wdata_i[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_strb_i[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_gnt_o[1];
    release fix.dut.i_memisland_domain.i_memory_island.i_memory_island.narrow_rvalid_o[1];
    // a few cycles safety margin after the end of transactions
    repeat (3) @(posedge fix.vip.soc_clk);
  endtask

  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("BOOTMODE=%d", boot_mode)) boot_mode = 0;
    if (!$value$plusargs("PRELMODE=%d", preload_mode)) preload_mode = 3;
    if (!$value$plusargs("BINARY=%s", preload_elf)) preload_elf = "";
    if (!$value$plusargs("IMAGE=%s", boot_hex)) boot_hex = "";

    // Set boot mode and preload boot image if there is one
    fix.vip.set_boot_mode(boot_mode);
    fix.vip.i2c_eeprom_preload(boot_hex);
    fix.vip.spih_norflash_preload(boot_hex);

    // Wait for reset
    fix.vip.wait_for_reset();

    // Preload in idle mode or wait for completion in autonomous boot
    if (boot_mode == 0) begin
      // Idle boot: preload with the specified mode
      case (preload_mode)
        0: begin  // JTAG
          fix.vip.jtag_init();
          fix.vip.jtag_elf_run(preload_elf);
          fix.vip.jtag_wait_for_eoc(exit_code);
        end
        2: begin  // UART
          fix.vip.uart_debug_elf_run_and_wait(preload_elf, exit_code);
        end
        3: begin  // FAST DEBUG
          // Initialize JTAG 
          fix.vip.jtag_init();
          // Halt the core
          fix.vip.jtag_halt_hart();
          // Preload the binary through FAST PRELOAD
          fast_elf_preload(preload_elf);
          // Unhalt the core
          fix.vip.jtag_resume_hart();
          // Wait for the end of computation
          fix.vip.jtag_wait_for_eoc(exit_code);
        end
        default: begin
          $fatal(1, "Unsupported preload mode %d (reserved)!", boot_mode);
        end
      endcase
    end else if (boot_mode == 1) begin
      $fatal(1, "Unsupported boot mode %d (SD Card)!", boot_mode);
    end else begin
      // Autonomous boot: Only poll return code
      fix.vip.jtag_init();
      fix.vip.jtag_wait_for_eoc(exit_code);
    end

    // Wait for the UART to finish reading the current byte
    wait (fix.vip.uart_reading_byte == 0);

    $finish;
  end

endmodule
