// chip_top.sv
// Connects: top.sv (Q8.8) + dmi_reg.sv + dtmcs_reg.sv + dmi_jtag.sv
// Fixes applied:
//   1. dmi_req_o and dmi_resp_i use proper dm:: structs
//   2. dtmcs_status routed through dmi_reg at address 0x20
//   3. Clean signal naming throughout
import dm::*;

module chip_top #(parameter N = 2) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        testmode_i,

    // JTAG pins (connect to Basys 3 JTAG header)
    input  logic        tck_i,
    input  logic        tms_i,
    input  logic        trst_ni,
    input  logic        td_i,
    output logic        td_o,
    output logic        tdo_oe_o
);

    // Hardcoded test inputs: all 1.0 in Q8.8 format (16'h0100 = 1.0)
    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1][0:N-1];
    logic [15:0] b2 [0:N-1][0:N-1];
    logic [15:0] x  [0:N-1][0:N-1];
    logic [15:0] y  [0:N-1][0:N-1];

    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : gen_i
            for (gj = 0; gj < N; gj++) begin : gen_j
                assign w1[gi][gj] = 16'h0100;
                assign w2[gi][gj] = 16'h0100;
                assign b1[gi][gj] = 16'h0100;
                assign b2[gi][gj] = 16'h0100;
                assign x [gi][gj] = 16'h0100;
            end
        end
    endgenerate

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
    // ILA probes: capture what address/data/op the JTAG master is requesting
    (* MARK_DEBUG = "TRUE" *) logic [6:0]  dmi_addr;
    (* MARK_DEBUG = "TRUE" *) logic [31:0] dmi_wdata;
    (* MARK_DEBUG = "TRUE" *) logic [1:0]  dmi_op;

    assign dmi_addr  = dmi_req.addr;
    assign dmi_wdata = dmi_req.data;
    assign dmi_op    = dmi_req.op;

    // Pack dmi_reg outputs -> dmi_resp_struct for dmi_jtag
    // ILA probes: capture what data the debug module is sending back
    (* MARK_DEBUG = "TRUE" *) logic [31:0] dmi_rdata;
    (* MARK_DEBUG = "TRUE" *) logic [1:0]  dmi_resp;

    assign dmi_resp_struct.data = dmi_rdata;
    assign dmi_resp_struct.resp = dmi_resp;

    // Handshake signals
    // ILA probes: capture when transactions start and complete
    (* MARK_DEBUG = "TRUE" *) logic        dmi_req_valid;
    (* MARK_DEBUG = "TRUE" *) logic        dmi_req_ready;
    (* MARK_DEBUG = "TRUE" *) logic        dmi_resp_valid;
    (* MARK_DEBUG = "TRUE" *) logic        dmi_resp_ready;
                               logic        dmi_rst_n;

    // -------------------------
    // FIX 2: dtmcs_status wire
    // routed into dmi_reg
    // -------------------------
    logic [31:0] dtmcs_status;

    // -------------------------
    // Instantiate Q8.8 top
    // -------------------------
    (* DONT_TOUCH = "TRUE" *) top #(N) u_top (
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
    (* DONT_TOUCH = "TRUE" *) dtmcs_reg #(N) u_dtmcs_reg (
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
    (* DONT_TOUCH = "TRUE" *) dmi_reg #(N) u_dmi_reg (
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
    // VIO internal signals
    // VIO drives JTAG inputs so
    // you can manually clock the
    // TAP from Vivado Hardware Manager
    // without a physical JTAG probe
    // -------------------------
    logic vio_tck;
    logic vio_tms;
    logic vio_trst_n;
    logic vio_tdi;
    logic vio_tdo;
    logic vio_tdo_oe;

    // -------------------------
    // Instantiate VIO
    // PROBE_OUT → drives JTAG inputs
    // PROBE_IN  ← monitors JTAG outputs
    // -------------------------
    vio_0 u_vio (
        .clk        (clk),
        .probe_in0  (vio_tdo),      // monitor tdo
        .probe_in1  (vio_tdo_oe),   // monitor tdo_oe
        .probe_out0 (vio_tck),      // drive tck
        .probe_out1 (vio_tms),      // drive tms
        .probe_out2 (vio_trst_n),   // drive trst_n
        .probe_out3 (vio_tdi)       // drive tdi
    );

    // -------------------------
    // Instantiate dmi_jtag
    // FIX 1: use struct ports
    // JTAG inputs come from VIO
    // so Hardware Manager controls
    // the TAP directly
    // -------------------------
    (* DONT_TOUCH = "TRUE" *) dmi_jtag u_dmi_jtag (
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
        .tck_i            (vio_tck),    // from VIO
        .tms_i            (vio_tms),    // from VIO
        .trst_ni          (vio_trst_n), // from VIO
        .td_i             (vio_tdi),    // from VIO
        .td_o             (vio_tdo),    // to VIO
        .tdo_oe_o         (vio_tdo_oe) // to VIO
    );

    // -------------------------
    // Drive top-level output ports from VIO/dmi_jtag signals.
    // Without these assignments td_o and tdo_oe_o are undriven,
    // causing opt_design to trace back and remove the entire logic cone.
    // -------------------------
    assign td_o     = vio_tdo;
    assign tdo_oe_o = vio_tdo_oe;

endmodule