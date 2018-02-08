// Copyright (c) 2018 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Bug fixes and contributions will eventually be released under the
// SolderPad open hardware license in the context of the PULP platform
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
// University of Bologna.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

/// A synthesis test bench which instantiates various adapter variants.
module synth_bench (
  input logic clk_i,
  input logic rst_ni
);

  localparam int AXI_ADDR_WIDTH[6] = {32, 64, 1, 2, 42, 129};
  localparam int AXI_ID_USER_WIDTH[3] = {0, 1, 8};
  localparam int NUM_SLAVE_MASTER[3] = {1, 2, 4};

  // AXI_DATA_WIDTH = {8, 16, 32, 64, 128, 256, 512, 1024}
  for (genvar i = 0; i < 8; i++) begin
    localparam DW = (2**i) * 8;
    synth_slice #(.AW(32), .DW(DW), .IW(8), .UW(8)) s(.*);
  end

  // AXI_ADDR_WIDTH
  for (genvar i = 0; i < 6; i++) begin
    localparam int AW = AXI_ADDR_WIDTH[i];
    synth_slice #(.AW(AW), .DW(32), .IW(8), .UW(8)) s(.*);
  end

  // AXI_ID_WIDTH and AXI_USER_WIDTH
  for (genvar i = 0; i < 3; i++) begin
    localparam int IUW = AXI_ID_USER_WIDTH[i];
    synth_slice #(.AW(32), .DW(32), .IW(IUW), .UW(IUW)) s(.*);
  end

  // Crossbar
  for (genvar i = 0; i < 3; i++) begin : xbar_master
    localparam int NM = NUM_SLAVE_MASTER[i];
    for (genvar j = 0; j < 3; j++) begin : xbar_slave
      localparam int NS = NUM_SLAVE_MASTER[j];
      axi_lite_xbar_slice #(.NUM_MASTER(NM), .NUM_SLAVE(NS)) i_xbar (.*);
    end
  end

endmodule


module synth_slice #(
  parameter int AW = -1,
  parameter int DW = -1,
  parameter int IW = -1,
  parameter int UW = -1
)(
  input logic clk_i,
  input logic rst_ni
);

  AXI_BUS #(
    .AXI_ADDR_WIDTH(AW),
    .AXI_DATA_WIDTH(DW),
    .AXI_ID_WIDTH(IW),
    .AXI_USER_WIDTH(UW)
  ) a_full(), b_full();

  AXI_LITE #(
    .AXI_ADDR_WIDTH(AW),
    .AXI_DATA_WIDTH(DW)
  ) a_lite(), b_lite();

  axi_to_axi_lite a (.slave(a_full.Slave), .master(a_lite.Master), .*);
  axi_lite_to_axi b (.slave(b_lite.Slave), .master(b_full.Master), .*);

endmodule


module axi_lite_xbar_slice #(
  parameter int NUM_MASTER = -1,
  parameter int NUM_SLAVE = -1
)(
  input logic clk_i,
  input logic rst_ni
);

  AXI_LITE #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32)
  ) xbar_master [NUM_MASTER-1:0]();

  AXI_LITE #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32)
  ) xbar_slave [NUM_SLAVE-1:0]();

  AXI_ROUTING_RULES #(
    .AXI_ADDR_WIDTH(32),
    .NUM_SLAVE(NUM_SLAVE),
    .NUM_RULES(1)
  ) xbar_routing();

  for (genvar i = 0; i < NUM_SLAVE; i++) begin
    assign xbar_routing.rules[i] = {{ 32'hfffff000, 32'h00010000 * i }};
  end

  axi_lite_xbar #(
    .NUM_MASTER(NUM_MASTER),
    .NUM_SLAVE(NUM_SLAVE)
  ) xbar (
    .clk_i  ( clk_i              ),
    .rst_ni ( rst_ni             ),
    .master ( xbar_master.in     ),
    .slave  ( xbar_slave.out     ),
    .rules  ( xbar_routing.xbar  )
  );

endmodule