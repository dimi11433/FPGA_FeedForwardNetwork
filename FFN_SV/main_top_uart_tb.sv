`timescale 1ns/1ps

`include "ffn_ref_rtl.sv"

module main_top_uart_tb;
    localparam int N = 2;
    localparam int CLKS_PER_BIT = 86;
    localparam int RX_FRAME_BYTES = (2*N*N + 3*N) * 2;

    logic clk;
    logic rst_n;
    logic rx_bit;
    logic tx_bit;

    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1];
    logic [15:0] b2 [0:N-1];
    logic [15:0] x  [0:N-1];
    logic [15:0] y_ref [0:N-1];

    byte rx_byte_captured;
    byte exp_bytes [0:(N*2)-1];
    byte exp_rx_bytes [0:RX_FRAME_BYTES-1];
    int  err_count;
    int  rx_check_idx;
    int  rx_err_count;
    int  idx;

    main_top #(.N(N)) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .rx_bit (rx_bit),
        .tx_bit (tx_bit)
    );

    // Reference for expected final output vector bytes.
    ffn_ref_rtl #(.N(N)) ref_rtl (
        .w2    (w2),
        .w1    (w1),
        .b1    (b1),
        .b2    (b2),
        .x     (x),
        .y_ref (y_ref)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic uart_send_byte(input byte b);
        // start bit
        rx_bit <= 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);

        // data bits LSB-first
        for (int i = 0; i < 8; i++) begin
            rx_bit <= b[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end

        // stop bit
        rx_bit <= 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
    endtask

    task automatic uart_send_bf16(input logic [15:0] v);
        // Wrapper expects low byte first, then high byte.
        uart_send_byte(v[7:0]);
        uart_send_byte(v[15:8]);
    endtask

    task automatic uart_recv_byte(output byte b);
        // Wait for start bit.
        wait (tx_bit == 1'b0);

        // Move to middle of first data bit.
        repeat (CLKS_PER_BIT + (CLKS_PER_BIT/2)) @(posedge clk);

        for (int i = 0; i < 8; i++) begin
            b[i] = tx_bit;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end

        // Consume remainder of stop bit (we're already at mid-stop-bit after last
        // data sample + CLKS_PER_BIT, so only half a bit period is needed to avoid
        // accumulating a 43-cycle drift per byte that shifts subsequent sampling).
        repeat (CLKS_PER_BIT/2) @(posedge clk);
    endtask

    initial begin
        $dumpfile("main_top_uart_tb.vcd");
        $dumpvars(0, main_top_uart_tb);

        err_count = 0;
        rx_err_count = 0;
        rx_check_idx = 0;
        rx_bit    = 1'b1; // UART idle
        rst_n     = 1'b0;

        // Directed values
        w1[0][0] = 16'h3F80; w1[0][1] = 16'h0000;
        w1[1][0] = 16'h0000; w1[1][1] = 16'h3F80;

        w2[0][0] = 16'h3F80; w2[0][1] = 16'h0000;
        w2[1][0] = 16'h0000; w2[1][1] = 16'h3F80;

        b1[0] = 16'h0000; b1[1] = 16'h0000;
        b2[0] = 16'h0000; b2[1] = 16'h0000;

        x[0] = 16'h3F80;  x[1] = 16'h0000;

        // Let combinational ref settle (initial-block ordering / delta cycles).
        #1;
        // Build expected RX byte stream from reference inputs (wrapper expects low then high).
        idx = 0;
        for (int r = 0; r < N; r++)
            for (int c = 0; c < N; c++) begin
                exp_rx_bytes[idx] = w1[r][c][7:0]; idx++;
                exp_rx_bytes[idx] = w1[r][c][15:8]; idx++;
            end
        for (int r = 0; r < N; r++)
            for (int c = 0; c < N; c++) begin
                exp_rx_bytes[idx] = w2[r][c][7:0]; idx++;
                exp_rx_bytes[idx] = w2[r][c][15:8]; idx++;
            end
        for (int i = 0; i < N; i++) begin
            exp_rx_bytes[idx] = x[i][7:0]; idx++;
            exp_rx_bytes[idx] = x[i][15:8]; idx++;
        end
        for (int i = 0; i < N; i++) begin
            exp_rx_bytes[idx] = b1[i][7:0]; idx++;
            exp_rx_bytes[idx] = b1[i][15:8]; idx++;
        end
        for (int i = 0; i < N; i++) begin
            exp_rx_bytes[idx] = b2[i][7:0]; idx++;
            exp_rx_bytes[idx] = b2[i][15:8]; idx++;
        end

        // Build expected TX byte stream from reference output.
        #1;
        exp_bytes[0] = y_ref[0][7:0];
        exp_bytes[1] = y_ref[0][15:8];
        exp_bytes[2] = y_ref[1][7:0];
        exp_bytes[3] = y_ref[1][15:8];

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // Check that uart_rx decodes bytes correctly as it feeds uart_wrapper.
        fork
            begin : rx_check
                while (rx_check_idx < RX_FRAME_BYTES) begin
                    @(posedge clk);
                    if (rst_n && dut.uart_rx_module.o_Rx_DV) begin
                        rx_byte_captured = dut.uart_rx_module.o_Rx_byte;
                        if (rx_byte_captured !== exp_rx_bytes[rx_check_idx]) begin
                            rx_err_count++;
                            $display("RX BYTE MISMATCH idx=%0d exp=0x%02h got=0x%02h",
                                     rx_check_idx, exp_rx_bytes[rx_check_idx], rx_byte_captured);
                        end
                        rx_check_idx++;
                    end
                end
            end
        join_none

        // Send full frame in wrapper order: W1 -> W2 -> X -> b1 -> b2
        for (int r = 0; r < N; r++)
            for (int c = 0; c < N; c++)
                uart_send_bf16(w1[r][c]);

        for (int r = 0; r < N; r++)
            for (int c = 0; c < N; c++)
                uart_send_bf16(w2[r][c]);

        for (int i = 0; i < N; i++)
            uart_send_bf16(x[i]);

        for (int i = 0; i < N; i++)
            uart_send_bf16(b1[i]);

        for (int i = 0; i < N; i++)
            uart_send_bf16(b2[i]);

        // Receive N*2 result bytes from DUT TX and compare.
        for (int i = 0; i < (N*2); i++) begin
            uart_recv_byte(rx_byte_captured);
            if (rx_byte_captured !== exp_bytes[i]) begin
                err_count++;
                $display("BYTE MISMATCH idx=%0d exp=0x%02h got=0x%02h", i, exp_bytes[i], rx_byte_captured);
            end
        end

        // Also report RX correctness.
        if (rx_err_count == 0 && err_count == 0) begin
            $display("PASS: UART RX decoded correctly and UART TX matched expected bytes.");
        end else if (rx_err_count != 0) begin
            $display("FAIL: UART RX decoded mismatches=%0d (TX mismatches=%0d)", rx_err_count, err_count);
        end else begin
            $display("FAIL: UART TX mismatches=%0d (RX mismatches=%0d)", err_count, rx_err_count);
        end

        $finish;
    end

endmodule
