// Nexys A7 top: 100 MHz → 10 MHz, UART + optional JTAG on Pmod JA
module fpga_top #(
    parameter int N = 2
) (
    input  logic clk_100mhz,
    input  logic cpu_resetn,   // active-low pushbutton on Nexys A7
    input  logic uart_rxd,     // FT2232HQ → FPGA  (pin C4)
    output logic uart_txd,     // FPGA → FT2232HQ  (pin D4)
    output logic led_busy,     // LD0: lights while TX frame is in progress

    // JTAG via Pmod JA
    input  logic jtag_tck,     // JA[1] pin C17
    input  logic jtag_tms,     // JA[2] pin D18
    input  logic jtag_tdi,     // JA[3] pin E18
    output logic jtag_tdo,     // JA[4] pin G17
    input  logic jtag_trst_n   // JA[7] pin D17
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

    // ---- Debug observation bus ----
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

    // JTAG control outputs (TCK → clk CDC)
    logic jtag_force_start_tck, jtag_force_rst_tck;
    logic jtag_force_start_s1, jtag_force_start_sync;
    logic jtag_force_rst_s1,   jtag_force_rst_sync;

    always_ff @(posedge clk_10mhz or negedge rst_n_sync) begin
        if (!rst_n_sync) begin
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

    logic rst_n_eff;
    assign rst_n_eff = rst_n_sync & ~jtag_force_rst_sync;

    // ---- FFN design core ----
    main_top #(.N(N)) u_main (
        .clk              (clk_10mhz),
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
    logic tdo_internal;
    logic tdo_en;

    jtag_top #(.N(N), .IR_WIDTH(4)) u_jtag (
        .tck              (jtag_tck),
        .tms              (jtag_tms),
        .trst_n           (jtag_trst_n),
        .tdi              (jtag_tdi),
        .tdo              (tdo_internal),
        .tdo_en           (tdo_en),
        .clk              (clk_10mhz),
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

    // TDO output: drive when enabled, tri-state otherwise
    assign jtag_tdo = tdo_en ? tdo_internal : 1'b0;

    assign led_busy = dbg_tx_busy;

endmodule
