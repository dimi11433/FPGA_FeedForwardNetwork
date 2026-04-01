// ASIC top-level: FFN design + JTAG debug interface
// Pad-level ports for tapeout
module asic_top #(
    parameter int N = 2
)(
    // Functional pads
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rxd,
    output logic uart_txd,

    // JTAG pads (active during test/debug)
    input  logic tck,
    input  logic tms,
    input  logic trst_n,
    input  logic tdi,
    output logic tdo,
    output logic tdo_en
);

    // ---- Debug observation bus from main_top ----
    logic       dbg_ready, dbg_done, dbg_ffn_start;
    logic       dbg_rx_dv, dbg_tx_dv, dbg_tx_busy;
    logic [2:0] dbg_wrapper_state;
    logic [15:0] dbg_w1_flat  [0:N*N-1];
    logic [15:0] dbg_w2_flat  [0:N*N-1];
    logic [15:0] dbg_x        [0:N-1];
    logic [15:0] dbg_b1       [0:N-1];
    logic [15:0] dbg_b2       [0:N-1];
    logic [15:0] dbg_mac_out  [0:N-1];
    logic [15:0] dbg_gelu_out [0:N-1];
    logic [15:0] dbg_mac_out_2[0:N-1];
    logic [15:0] dbg_y        [0:N-1];

    // JTAG control outputs (synchronise from TCK → clk domain)
    logic jtag_force_start_tck, jtag_force_rst_tck;
    logic jtag_force_start_s1, jtag_force_start_sync;
    logic jtag_force_rst_s1,   jtag_force_rst_sync;

    // Two-flop synchroniser: TCK → clk
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            jtag_force_start_s1   <= 1'b0;
            jtag_force_start_sync <= 1'b0;
            jtag_force_rst_s1     <= 1'b0;
            jtag_force_rst_sync   <= 1'b0;
        end else begin
            jtag_force_start_s1   <= jtag_force_start_tck;
            jtag_force_start_sync <= jtag_force_start_s1;
            jtag_force_rst_s1     <= jtag_force_rst_tck;
            jtag_force_rst_sync   <= jtag_force_rst_s1;
        end
    end

    // Effective reset: either pad reset or JTAG-forced reset
    logic rst_n_eff;
    assign rst_n_eff = rst_n & ~jtag_force_rst_sync;

    // ---- FFN design core ----
    main_top #(.N(N)) u_ffn (
        .clk              (clk),
        .rst_n            (rst_n_eff),
        .rx_bit           (uart_rxd),
        .tx_bit           (uart_txd),
        .dbg_ready        (dbg_ready),
        .dbg_done         (dbg_done),
        .dbg_ffn_start    (dbg_ffn_start),
        .dbg_rx_dv        (dbg_rx_dv),
        .dbg_tx_dv        (dbg_tx_dv),
        .dbg_tx_busy      (dbg_tx_busy),
        .dbg_wrapper_state(dbg_wrapper_state),
        .dbg_w1_flat      (dbg_w1_flat),
        .dbg_w2_flat      (dbg_w2_flat),
        .dbg_x            (dbg_x),
        .dbg_b1           (dbg_b1),
        .dbg_b2           (dbg_b2),
        .dbg_mac_out      (dbg_mac_out),
        .dbg_gelu_out     (dbg_gelu_out),
        .dbg_mac_out_2    (dbg_mac_out_2),
        .dbg_y            (dbg_y)
    );

    // ---- JTAG debug interface ----
    jtag_top #(.N(N), .IR_WIDTH(4)) u_jtag (
        .tck              (tck),
        .tms              (tms),
        .trst_n           (trst_n),
        .tdi              (tdi),
        .tdo              (tdo),
        .tdo_en           (tdo_en),
        .clk              (clk),
        .rst_n            (rst_n_eff),
        .ready            (dbg_ready),
        .done             (dbg_done),
        .ffn_start        (dbg_ffn_start),
        .rx_dv            (dbg_rx_dv),
        .tx_dv            (dbg_tx_dv),
        .tx_busy          (dbg_tx_busy),
        .wrapper_state    (dbg_wrapper_state),
        .w1_flat          (dbg_w1_flat),
        .w2_flat          (dbg_w2_flat),
        .x                (dbg_x),
        .b1               (dbg_b1),
        .b2               (dbg_b2),
        .mac_out          (dbg_mac_out),
        .gelu_out         (dbg_gelu_out),
        .mac_out_2        (dbg_mac_out_2),
        .y                (dbg_y),
        .jtag_force_start (jtag_force_start_tck),
        .jtag_force_rst   (jtag_force_rst_tck)
    );

endmodule
