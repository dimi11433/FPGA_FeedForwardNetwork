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
        .reset   (cpu_resetn),
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

    main_top #(.N(2)) u_main (
        .clk    (clk_10mhz),
        .rst_n  (rst_n_sync),
        .rx_bit (uart_rxd),
        .tx_bit (uart_txd)
    );

    assign led_busy = u_main.tx_busy;

endmodule
