// Top-level JTAG wrapper: wires TAP controller to debug registers
module jtag_top #(
    parameter int N        = 2,
    parameter int IR_WIDTH = 4
)(
    // JTAG pad interface
    input  logic tck,
    input  logic tms,
    input  logic trst_n,
    input  logic tdi,
    output logic tdo,
    output logic tdo_en,

    // Design clock domain
    input  logic clk,
    input  logic rst_n,

    // Observation signals from main_top
    input  logic       ready,
    input  logic       done,
    input  logic       ffn_start,
    input  logic       rx_dv,
    input  logic       tx_dv,
    input  logic       tx_busy,
    input  logic [2:0] wrapper_state,

    input  var logic [15:0] w1_flat   [0:N*N-1],
    input  var logic [15:0] w2_flat   [0:N*N-1],
    input  var logic [15:0] x         [0:N-1],
    input  var logic [15:0] b1        [0:N-1],
    input  var logic [15:0] b2        [0:N-1],
    input  var logic [15:0] mac_out   [0:N-1],
    input  var logic [15:0] gelu_out  [0:N-1],
    input  var logic [15:0] mac_out_2 [0:N-1],
    input  var logic [15:0] y         [0:N-1],

    // Control outputs (TCK → design, synchronise externally)
    output logic jtag_force_start,
    output logic jtag_force_rst
);

    // TAP ↔ debug-regs interconnect
    logic shift_dr, capture_dr, update_dr;
    logic shift_ir, capture_ir, update_ir;
    logic [IR_WIDTH-1:0] ir;
    logic tap_reset_i;
    logic tdo_dr;
    logic tdo_tap;
    logic tdo_en_tap;

    jtag_tap #(
        .IR_WIDTH     (IR_WIDTH),
        .IR_RESET_VAL ({IR_WIDTH{1'b1}})
    ) u_tap (
        .tck        (tck),
        .tms        (tms),
        .trst_n     (trst_n),
        .tdi        (tdi),
        .tdo        (tdo_tap),
        .tdo_en     (tdo_en_tap),
        .shift_dr   (shift_dr),
        .capture_dr (capture_dr),
        .update_dr  (update_dr),
        .shift_ir   (shift_ir),
        .capture_ir (capture_ir),
        .update_ir  (update_ir),
        .ir_out     (ir),
        .tap_reset  (tap_reset_i)
    );

    jtag_debug_regs #(
        .N        (N),
        .IR_WIDTH (IR_WIDTH)
    ) u_regs (
        .tck             (tck),
        .trst_n          (trst_n),
        .tdi             (tdi),
        .tdo_dr          (tdo_dr),
        .shift_dr        (shift_dr),
        .capture_dr      (capture_dr),
        .update_dr       (update_dr),
        .ir              (ir),
        .clk             (clk),
        .rst_n           (rst_n),
        .ready           (ready),
        .done            (done),
        .ffn_start       (ffn_start),
        .rx_dv           (rx_dv),
        .tx_dv           (tx_dv),
        .tx_busy         (tx_busy),
        .wrapper_state   (wrapper_state),
        .w1_flat         (w1_flat),
        .w2_flat         (w2_flat),
        .x               (x),
        .b1              (b1),
        .b2              (b2),
        .mac_out         (mac_out),
        .gelu_out        (gelu_out),
        .mac_out_2       (mac_out_2),
        .y               (y),
        .jtag_force_start(jtag_force_start),
        .jtag_force_rst  (jtag_force_rst)
    );

    // Final TDO: during Shift-DR use debug register output, otherwise TAP handles it
    always_ff @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo    <= 1'b0;
            tdo_en <= 1'b0;
        end else begin
            tdo_en <= tdo_en_tap;
            tdo    <= shift_dr ? tdo_dr : tdo_tap;
        end
    end

endmodule
