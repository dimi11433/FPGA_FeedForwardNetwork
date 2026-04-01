module main_top #(parameter int N = 2)(
    input logic clk,
    input logic rst_n,
    input logic rx_bit,
    output logic tx_bit,

    // Debug observation ports for JTAG
    output logic       dbg_ready,
    output logic       dbg_done,
    output logic       dbg_ffn_start,
    output logic       dbg_rx_dv,
    output logic       dbg_tx_dv,
    output logic       dbg_tx_busy,
    output logic [2:0] dbg_wrapper_state,
    output logic [15:0] dbg_w1_flat  [0:N*N-1],
    output logic [15:0] dbg_w2_flat  [0:N*N-1],
    output logic [15:0] dbg_x        [0:N-1],
    output logic [15:0] dbg_b1       [0:N-1],
    output logic [15:0] dbg_b2       [0:N-1],
    output logic [15:0] dbg_mac_out  [0:N-1],
    output logic [15:0] dbg_gelu_out [0:N-1],
    output logic [15:0] dbg_mac_out_2[0:N-1],
    output logic [15:0] dbg_y        [0:N-1]
);

    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1];
    logic [15:0] b2 [0:N-1];
    logic [15:0] x  [0:N-1];
    logic [15:0] y [0:N-1];
    logic [7:0] tx_byte;
    logic [7:0] rx_byte;
    logic rx_dv;
    logic tx_dv;
    logic tx_done;
    logic tx_busy;
    logic tx_active;
    logic ready;
    logic done;
    // UVM used start=1 every cycle so GELU + MAC pipeline could settle. A one-cycle
    // uart_wrapper.ready pulse is too short — stretch start so layer2 sees fresh gelu_out.
    localparam int unsigned FFN_START_HOLD = 16;
    logic [4:0] ffn_start_cnt;
    logic [4:0] ffn_start_cnt_prev;
    logic       ffn_start;
    // ffn_done is taken directly from top.done.

    always_ff @(posedge clk) begin
        if (!rst_n)
            ffn_start_cnt <= 5'd0;
        else if (ready)
            ffn_start_cnt <= 5'(FFN_START_HOLD);
        else if (ffn_start_cnt != 5'd0)
            ffn_start_cnt <= ffn_start_cnt - 5'd1;
    end

    assign ffn_start = (ffn_start_cnt != 5'd0);

    always_ff @(posedge clk) begin
        if (!rst_n)
            ffn_start_cnt_prev <= 5'd0;
        else
            ffn_start_cnt_prev <= ffn_start_cnt;
    end

    uart_rx #(.CLKS_PER_BIT(86)) uart_rx_module(
        .i_clock(clk),
        .i_Rx_serial(rx_bit),
        .o_Rx_DV(rx_dv),
        .o_Rx_byte(rx_byte)
    );
    //Firstly get the data fron receiver and send to wrapper

    logic [2:0] wrapper_state;

    uart_wrapper #(.N(N)) uart_rx_wrapper(
        .clk(clk),
        .rst_n(rst_n),
        .data_in(rx_byte),
        .rx(rx_dv),
        .W1(w1),
        .W2(w2),
        .b1(b1),
        .b2(b2),
        .X(x),
        .ready(ready),
        .dbg_state(wrapper_state)
    );

    //then we need to send data to the top level module

    logic [15:0] mac_out_dbg   [0:N-1];
    logic [15:0] gelu_out_dbg  [0:N-1];
    logic [15:0] mac_out_2_dbg [0:N-1];

    top #(.N(N)) ffn_design(
        .clk(clk),
        .rst_n(rst_n),
        .start(ffn_start),
        .w1(w1),
        .w2(w2),
        .b1(b1),
        .b2(b2),
        .x(x),
        .done(done),
        .y(y),
        .dbg_mac_out(mac_out_dbg),
        .dbg_gelu_out(gelu_out_dbg),
        .dbg_mac_out_2(mac_out_2_dbg)
    );

    //then we send data to the uart_wrapper_tx
    uart_tx_serializer #(.N(N))uart_tx_wrapper(
        .clk(clk),
        .rst_n(rst_n),
        .result(y),
        .ffn_done(done),
        .tx_byte(tx_byte),
        .tx_dv(tx_dv),
        .tx_done(tx_done),
        .tx_busy(tx_busy)
    );

    //then we send data to the uart_tx
    uart_tx #(.CLKS_PER_BIT(86))uart_tx_module(
        .i_Clock(clk),
        .i_Tx_DV(tx_dv),
        .i_Tx_Byte(tx_byte),
        .o_Tx_Active(tx_active),
        .o_Tx_Bit(tx_bit),
        .o_Tx_Done(tx_done)
    );

    // ---- Debug observation wiring (synthesisable — no hierarchical refs) ----
    assign dbg_ready         = ready;
    assign dbg_done          = done;
    assign dbg_ffn_start     = ffn_start;
    assign dbg_rx_dv         = rx_dv;
    assign dbg_tx_dv         = tx_dv;
    assign dbg_tx_busy       = tx_busy;
    assign dbg_wrapper_state = wrapper_state;
    assign dbg_x  = x;
    assign dbg_b1 = b1;
    assign dbg_b2 = b2;
    assign dbg_y  = y;
    assign dbg_mac_out   = mac_out_dbg;
    assign dbg_gelu_out  = gelu_out_dbg;
    assign dbg_mac_out_2 = mac_out_2_dbg;

    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : dbg_w_row
            for (gj = 0; gj < N; gj++) begin : dbg_w_col
                assign dbg_w1_flat[gi*N + gj] = w1[gi][gj];
                assign dbg_w2_flat[gi*N + gj] = w2[gi][gj];
            end
        end
    endgenerate

endmodule