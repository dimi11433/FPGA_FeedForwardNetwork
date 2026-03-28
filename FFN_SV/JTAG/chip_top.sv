// chip_top.sv
// Connects: top.sv (Q8.8) + dmi_reg.sv + dtmcs_reg.sv + dmi_jtag.sv
// Fixes applied:
//   1. dmi_req_o and dmi_resp_i use proper dm:: structs
//   2. dtmcs_status routed through dmi_reg at address 0x20
//   3. Clean signal naming throughout

module chip_top #(parameter N = 2) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        testmode_i,

    // JTAG pins (connect to Nexys A7 JTAG header)
    input  logic        tck_i,
    input  logic        tms_i,
    input  logic        trst_ni,
    input  logic        td_i,
    output logic        td_o,
    output logic        tdo_oe_o,

    // Q8.8 datapath ports
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
    // FIX 1: Proper DMI struct wires
    // instead of raw concatenations
    // -------------------------
    dm::dmi_req_t  dmi_req;
    dm::dmi_resp_t dmi_resp_struct;

    // Unpack dmi_req struct -> individual signals for dmi_reg
    logic [6:0]  dmi_addr;
    logic [31:0] dmi_wdata;
    logic [1:0]  dmi_op;

    assign dmi_addr  = dmi_req.addr;
    assign dmi_wdata = dmi_req.data;
    assign dmi_op    = dmi_req.op;

    // Pack dmi_reg outputs -> dmi_resp_struct for dmi_jtag
    logic [31:0] dmi_rdata;
    logic [1:0]  dmi_resp;

    assign dmi_resp_struct.data = dmi_rdata;
    assign dmi_resp_struct.resp = dmi_resp;

    // Handshake signals
    logic        dmi_req_valid;
    logic        dmi_req_ready;
    logic        dmi_resp_valid;
    logic        dmi_resp_ready;
    logic        dmi_rst_n;

    // -------------------------
    // FIX 2: dtmcs_status wire
    // routed into dmi_reg
    // -------------------------
    logic [31:0] dtmcs_status;

    // -------------------------
    // Instantiate Q8.8 top
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
    // FIX 2: dtmcs_status now
    // passed in as input port
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
        .dtmcs_status  (dtmcs_status)   // FIX 2: was unconnected before
    );

    // -------------------------
    // Instantiate dmi_jtag
    // FIX 1: use struct ports
    // -------------------------
    dmi_jtag u_dmi_jtag (
        .clk_i            (clk),
        .rst_ni           (rst_n),
        .testmode_i       (testmode_i),
        .dmi_rst_no       (dmi_rst_n),
        .dmi_req_o        (dmi_req),           // FIX 1: struct wire
        .dmi_req_valid_o  (dmi_req_valid),
        .dmi_req_ready_i  (dmi_req_ready),
        .dmi_resp_i       (dmi_resp_struct),   // FIX 1: struct wire
        .dmi_resp_ready_o (dmi_resp_ready),
        .dmi_resp_valid_i (dmi_resp_valid),
        .tck_i            (tck_i),
        .tms_i            (tms_i),
        .trst_ni          (trst_ni),
        .td_i             (td_i),
        .td_o             (td_o),
        .tdo_oe_o         (tdo_oe_o)
    );

endmodule