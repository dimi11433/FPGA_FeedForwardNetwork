// Nexys A7 top: 100 MHz → 10 MHz, UART (USB bridge)
module fpga_top #(
    parameter int N = 2
) (
    input  logic clk_100mhz,
    input  logic cpu_resetn,   // active-low pushbutton on Nexys A7
    input  logic uart_rxd,     // FT2232HQ → FPGA  (pin C4)
    output logic uart_txd,     // FPGA → FT2232HQ  (pin D4)
    output logic led_busy      // LD0: lights while TX frame is in progress
);

    logic clk_10mhz;
    logic clk_locked;

    // Xilinx Clocking Wizard IP: 100 MHz → 10 MHz
    clk_wiz_0 clk_gen (
        .clk_in1  (clk_100mhz),
        .reset   (~cpu_resetn),
        .clk_out1 (clk_10mhz),
        .locked   (clk_locked)
    );

    // Async-assert / sync-deassert: cpu_resetn → 10 MHz domain, then gate with PLL lock
    logic cpu_rst_s1, cpu_rst_n_sync;
    logic rst_n_sync;

    always_ff @(posedge clk_10mhz or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            cpu_rst_s1     <= 1'b0;
            cpu_rst_n_sync <= 1'b0;
        end else begin
            cpu_rst_s1     <= 1'b1;
            cpu_rst_n_sync <= cpu_rst_s1;
        end
    end

    assign rst_n_sync = cpu_rst_n_sync & clk_locked;

    // Debug observation (from main_top; no off-chip tap — UART-only bring-up)
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

    // ---- FFN design core ----
    main_top #(.N(N)) u_main (
        .clk              (clk_10mhz),
        .rst_n            (rst_n_sync),
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

    assign led_busy = dbg_tx_busy;

endmodule
