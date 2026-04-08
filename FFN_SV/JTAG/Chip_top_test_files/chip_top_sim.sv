// chip_top_sim.sv
// Simulation-only version of chip_top.
// Differences from chip_top_vivado.sv:
//   - No vio_0 IP core (Xilinx-only, not simulatable in EDA Playground)
//   - JTAG pins exposed as top-level ports so tb_chip_top.sv can drive them
//   - No (* MARK_DEBUG *) attributes (synthesis-only, ignored in sim but kept clean)
//   - FFN inputs exposed as ports so testbench can provide its own values
//
// Use this file for:
//   - EDA Playground simulation
//   - Vivado behavioural simulation (xsim)
//   - Any simulator (Icarus, ModelSim, Riviera)
//
// Use chip_top_vivado.sv for:
//   - Vivado synthesis + implementation
//   - On-board testing with Hardware Manager + VIO

import dm::*;

module chip_top_sim #(parameter N = 2) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        testmode_i,

    // JTAG pins — driven by testbench
    input  logic        tck_i,
    input  logic        tms_i,
    input  logic        trst_ni,
    input  logic        td_i,
    output logic        td_o,
    output logic        tdo_oe_o,

    // FFN datapath inputs — driven by testbench
    input  logic [15:0] w1 [0:N-1][0:N-1],
    input  logic [15:0] w2 [0:N-1][0:N-1],
    input  logic [15:0] b1 [0:N-1][0:N-1],
    input  logic [15:0] b2 [0:N-1][0:N-1],
    input  logic [15:0] x  [0:N-1][0:N-1],
    output logic [15:0] y  [0:N-1][0:N-1]
);

    // -------------------------
    // Debug signals from top
    // -------------------------
    logic [15:0] dbg_mac_out   [0:N-1][0:N-1];
    logic [15:0] dbg_gelu_out  [0:N-1][0:N-1];
    logic [15:0] dbg_mac_out_2 [0:N-1][0:N-1];
    logic        dbg_ready1    [0:N-1][0:N-1];
    logic        dbg_ready2    [0:N-1][0:N-1];

    // -------------------------
    // DMI struct wires
    // -------------------------
    dm::dmi_req_t  dmi_req;
    dm::dmi_resp_t dmi_resp_struct;

    logic [6:0]  dmi_addr;
    logic [31:0] dmi_wdata;
    logic [1:0]  dmi_op;

    assign dmi_addr  = dmi_req.addr;
    assign dmi_wdata = dmi_req.data;
    assign dmi_op    = dmi_req.op;

    logic [31:0] dmi_rdata;
    logic [1:0]  dmi_resp;

    assign dmi_resp_struct.data = dmi_rdata;
    assign dmi_resp_struct.resp = dmi_resp;

    // Handshake signals
    logic dmi_req_valid;
    logic dmi_req_ready;
    logic dmi_resp_valid;
    logic dmi_resp_ready;
    logic dmi_rst_n;

    // -------------------------
    // dtmcs_status wire
    // -------------------------
    logic [31:0] dtmcs_status;

    // -------------------------
    // Instantiate FFN top
    // -------------------------
    top #(N) u_top (
        .clk           (clk),
        .rst_n         (rst_n),
        .w1            (w1),
        .w2            (w2),
        .b1            (b1),
        .b2            (b2),
        .x             (x),
        .y             (y),
        .dbg_mac_out   (dbg_mac_out),
        .dbg_gelu_out  (dbg_gelu_out),
        .dbg_mac_out_2 (dbg_mac_out_2),
        .dbg_ready1    (dbg_ready1),
        .dbg_ready2    (dbg_ready2)
    );

    // -------------------------
    // Instantiate dtmcs_reg
    // -------------------------
    dtmcs_reg #(N) u_dtmcs_reg (
        .clk          (clk),
        .rst_n        (rst_n),
        .ready1       (dbg_ready1),
        .ready2       (dbg_ready2),
        .y            (y),
        .dtmcs_status (dtmcs_status)
    );

    // -------------------------
    // Instantiate dmi_reg
    // -------------------------
    dmi_reg #(N) u_dmi_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .dmi_addr      (dmi_addr),
        .dmi_wdata     (dmi_wdata),
        .dmi_op        (dmi_op),
        .dmi_req_valid (dmi_req_valid),
        .dmi_req_ready (dmi_req_ready),
        .dmi_rdata     (dmi_rdata),
        .dmi_resp      (dmi_resp),
        .dmi_resp_valid(dmi_resp_valid),
        .dmi_resp_ready(dmi_resp_ready),
        .mac_out       (dbg_mac_out),
        .gelu_out      (dbg_gelu_out),
        .mac_out_2     (dbg_mac_out_2),
        .y             (y),
        .ready1        (dbg_ready1),
        .ready2        (dbg_ready2),
        .dtmcs_status  (dtmcs_status)
    );

    // -------------------------
    // Instantiate dmi_jtag
    // JTAG pins come from ports
    // (driven by testbench)
    // -------------------------
    dmi_jtag u_dmi_jtag (
        .clk_i            (clk),
        .rst_ni           (rst_n),
        .testmode_i       (testmode_i),
        .dmi_rst_no       (dmi_rst_n),
        .dmi_req_o        (dmi_req),
        .dmi_req_valid_o  (dmi_req_valid),
        .dmi_req_ready_i  (dmi_req_ready),
        .dmi_resp_i       (dmi_resp_struct),
        .dmi_resp_ready_o (dmi_resp_ready),
        .dmi_resp_valid_i (dmi_resp_valid),
        .tck_i            (tck_i),
        .tms_i            (tms_i),
        .trst_ni          (trst_ni),
        .td_i             (td_i),
        .td_o             (td_o),
        .tdo_oe_o         (tdo_oe_o)
    );

endmodule : chip_top_sim
