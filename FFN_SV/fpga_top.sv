module fpga_top (
    input  logic clk_100mhz,
    input  logic cpu_resetn,   // active-low pushbutton on Nexys A7
    input  logic uart_rxd,     // FT2232HQ → FPGA  (pin C4)
    output logic uart_txd,     // FPGA → FT2232HQ  (pin D4)
    output logic led_busy      // optional: lights while TX frame is in progress
);

    logic clk_10mhz;
    logic clk_locked;

    // Xilinx Clocking Wizard IP: 100 MHz → 10 MHz
    // Generate this IP in Vivado with:
    //   Input  : 100 MHz  (clk_in1)
    //   Output : 10 MHz   (clk_out1)
    //   Reset  : active-low (resetn)
    clk_wiz_0 clk_gen (
        .clk_in1  (clk_100mhz),
        .reset   (~cpu_resetn),
        .clk_out1 (clk_10mhz),
        .locked   (clk_locked)
    );

    // Synchronous reset: hold design in reset until PLL locks
    logic rst_n_sync;
    logic [2:0] rst_pipe;

    always_ff @(posedge clk_10mhz) begin
        rst_pipe  <= {rst_pipe[1:0], clk_locked & cpu_resetn};
        rst_n_sync <= rst_pipe[2];
    end

    // Debug ports left unconnected on FPGA (optimised away by synthesis)
    logic       dbg_ready, dbg_done, dbg_ffn_start;
    logic       dbg_rx_dv, dbg_tx_dv, dbg_tx_busy;
    logic [2:0] dbg_wrapper_state;
    logic [15:0] dbg_w1_flat [0:3], dbg_w2_flat [0:3];
    logic [15:0] dbg_x [0:1], dbg_b1 [0:1], dbg_b2 [0:1];
    logic [15:0] dbg_mac_out [0:1], dbg_gelu_out [0:1];
    logic [15:0] dbg_mac_out_2 [0:1], dbg_y [0:1];

    main_top #(.N(2)) u_main (
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
