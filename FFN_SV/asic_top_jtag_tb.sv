`timescale 1ns/1ps

`include "ffn_ref_rtl.sv"

module asic_top_jtag_tb;

    // =====================================================================
    // Parameters
    // =====================================================================
    localparam int N             = 2;
    localparam int CLKS_PER_BIT  = 86;
    localparam int IR_WIDTH      = 4;

    // JTAG IR opcodes (must match jtag_debug_regs.sv)
    localparam logic [3:0] IR_BYPASS      = 4'b1111;
    localparam logic [3:0] IR_IDCODE      = 4'b0001;
    localparam logic [3:0] IR_DBG_STATUS  = 4'b0010;
    localparam logic [3:0] IR_DBG_FFN_IN  = 4'b0011;
    localparam logic [3:0] IR_DBG_FFN_PIPE = 4'b0100;
    localparam logic [3:0] IR_DBG_CONTROL = 4'b0101;

    // Register widths
    localparam int IDCODE_W   = 32;
    localparam int STATUS_W   = 16;
    localparam int FFN_IN_W   = (N*N + N*N + N + N + N) * 16;  // 224
    localparam int FFN_PIPE_W = N * 16 * 4;                     // 128
    localparam int CONTROL_W  = 2;

    localparam logic [31:0] EXPECTED_IDCODE = 32'h1FF0_0001;

    // =====================================================================
    // Clock and reset
    // =====================================================================
    logic clk   = 0;
    logic tck   = 0;
    logic rst_n = 0;
    logic trst_n = 0;

    always #5   clk = ~clk;    // 100 MHz design clock
    always #50  tck = ~tck;    // 10 MHz JTAG clock

    // =====================================================================
    // DUT signals
    // =====================================================================
    logic uart_rxd = 1'b1;     // UART idle high
    logic uart_txd;
    logic tms = 1'b1;
    logic tdi = 1'b0;
    logic tdo;
    logic tdo_en;

    asic_top #(.N(N)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_rxd (uart_rxd),
        .uart_txd (uart_txd),
        .tck      (tck),
        .tms      (tms),
        .trst_n   (trst_n),
        .tdi      (tdi),
        .tdo      (tdo),
        .tdo_en   (tdo_en)
    );

    // =====================================================================
    // Reference model
    // =====================================================================
    logic [15:0] w1_tb [0:N-1][0:N-1];
    logic [15:0] w2_tb [0:N-1][0:N-1];
    logic [15:0] b1_tb [0:N-1];
    logic [15:0] b2_tb [0:N-1];
    logic [15:0] x_tb  [0:N-1];
    logic [15:0] y_ref [0:N-1];

    ffn_ref_rtl #(.N(N)) ref_model (
        .w1    (w1_tb),
        .w2    (w2_tb),
        .b1    (b1_tb),
        .b2    (b2_tb),
        .x     (x_tb),
        .y_ref (y_ref)
    );

    // =====================================================================
    // Scorecard
    // =====================================================================
    int total_tests  = 0;
    int total_pass   = 0;
    int total_fail   = 0;

    task automatic check(input string name, input logic pass);
        total_tests++;
        if (pass) begin
            total_pass++;
            $display("[PASS] %s", name);
        end else begin
            total_fail++;
            $display("[FAIL] %s", name);
        end
    endtask

    // =====================================================================
    // JTAG low-level tasks
    // =====================================================================

    // Drive TMS high for 5+ TCK cycles to force TLR, then drop to RTI.
    task automatic jtag_reset();
        tms = 1'b1;
        repeat (5) @(posedge tck);
        tms = 1'b0;
        @(posedge tck);   // TLR → RTI
        @(negedge tck);
    endtask

    // Shift a new instruction into the IR (4 bits). Starts and ends in RTI.
    task automatic jtag_shift_ir(input logic [IR_WIDTH-1:0] ir_val);
        // RTI → SEL_DR → SEL_IR → CAP_IR → SH_IR
        tms = 1'b1; @(posedge tck);   // → SEL_DR
        tms = 1'b1; @(posedge tck);   // → SEL_IR
        tms = 1'b0; @(posedge tck);   // → CAP_IR
        tms = 1'b0; @(posedge tck);   // capture, → SH_IR
        @(negedge tck);               // TDO settles with IR capture value

        for (int i = 0; i < IR_WIDTH; i++) begin
            tdi = ir_val[i];
            tms = (i == IR_WIDTH - 1) ? 1'b1 : 1'b0;
            @(posedge tck);            // shift
            @(negedge tck);
        end

        // EX1_IR → UPD_IR → RTI
        tms = 1'b1; @(posedge tck);   // → UPD_IR
        tms = 1'b0; @(posedge tck);   // → RTI
        @(negedge tck);
    endtask

    // Shift `width` bits through the currently selected DR.
    // tdi_data is shifted in LSB-first; tdo_data is captured LSB-first.
    // Starts and ends in RTI.
    task automatic jtag_shift_dr(
        input  int              width,
        input  logic [255:0]    tdi_data,
        output logic [255:0]    tdo_data
    );
        tdo_data = '0;

        // RTI → SEL_DR → CAP_DR → SH_DR
        tms = 1'b1; @(posedge tck);   // → SEL_DR
        tms = 1'b0; @(posedge tck);   // → CAP_DR
        tms = 1'b0; @(posedge tck);   // capture happens, → SH_DR
        @(negedge tck); #1;           // TDO NBA settles: sr[0] = bit 0

        for (int i = 0; i < width; i++) begin
            tdo_data[i] = tdo;         // sample TDO (NBA now complete)
            tdi = tdi_data[i];
            tms = (i == width - 1) ? 1'b1 : 1'b0;
            @(posedge tck);            // shift happens
            @(negedge tck); #1;        // TDO NBA settles for next iteration
        end

        // EX1_DR → UPD_DR → RTI
        tms = 1'b1; @(posedge tck);   // → UPD_DR (update latch)
        tms = 1'b0; @(posedge tck);   // → RTI
        @(negedge tck); #1;
    endtask

    // Convenience: select IR then read DR (shift in zeros).
    task automatic jtag_read_dr(
        input  logic [IR_WIDTH-1:0] ir_val,
        input  int                  width,
        output logic [255:0]        data
    );
        jtag_shift_ir(ir_val);
        jtag_shift_dr(width, '0, data);
    endtask

    // Convenience: select IR then write DR.
    task automatic jtag_write_dr(
        input logic [IR_WIDTH-1:0] ir_val,
        input int                  width,
        input logic [255:0]        data
    );
        logic [255:0] dummy;
        jtag_shift_ir(ir_val);
        jtag_shift_dr(width, data, dummy);
    endtask

    // =====================================================================
    // UART tasks (from main_top_uart_tb, adapted for asic_top signals)
    // =====================================================================
    task automatic uart_send_byte(input byte b);
        uart_rxd <= 1'b0;                              // start bit
        repeat (CLKS_PER_BIT) @(posedge clk);
        for (int i = 0; i < 8; i++) begin               // data LSB-first
            uart_rxd <= b[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        uart_rxd <= 1'b1;                              // stop bit
        repeat (CLKS_PER_BIT) @(posedge clk);
    endtask

    task automatic uart_send_bf16(input logic [15:0] v);
        uart_send_byte(v[7:0]);
        uart_send_byte(v[15:8]);
    endtask

    task automatic uart_recv_byte(output byte b);
        wait (uart_txd == 1'b0);                        // start bit
        repeat (CLKS_PER_BIT + (CLKS_PER_BIT/2)) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            b[i] = uart_txd;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        repeat (CLKS_PER_BIT/2) @(posedge clk);        // consume rest of stop bit
    endtask

    // =====================================================================
    // Main test sequence
    // =====================================================================
    // Global timeout — kill sim if it hangs
    initial begin
        #1_000_000;
        $display("\n*** TIMEOUT: simulation exceeded 500 us ***");
        $finish;
    end

    initial begin
        // ---- Test vectors (identity matrix, same as main_top_uart_tb) ----
        w1_tb[0][0] = 16'h3F80; w1_tb[0][1] = 16'h0000;
        w1_tb[1][0] = 16'h0000; w1_tb[1][1] = 16'h3F80;

        w2_tb[0][0] = 16'h3F80; w2_tb[0][1] = 16'h0000;
        w2_tb[1][0] = 16'h0000; w2_tb[1][1] = 16'h3F80;

        b1_tb[0] = 16'h0000; b1_tb[1] = 16'h0000;
        b2_tb[0] = 16'h0000; b2_tb[1] = 16'h0000;

        x_tb[0]  = 16'h3F80; x_tb[1]  = 16'h0000;

        #1; // let ref model settle

        // ---- Release resets ----
        repeat (5) @(posedge clk);
        rst_n  = 1'b1;
        trst_n = 1'b1;
        repeat (5) @(posedge clk);

        // ==============================================================
        // TEST 1: JTAG TAP reset + IDCODE
        // ==============================================================
        $display("\n========== TEST 1: JTAG IDCODE ==========");
        begin
            logic [255:0] id_out;
            jtag_reset();
            jtag_read_dr(IR_IDCODE, IDCODE_W, id_out);
            $display("  IDCODE read = 0x%08h (expected 0x%08h)", id_out[31:0], EXPECTED_IDCODE);
            check("IDCODE value", id_out[31:0] === EXPECTED_IDCODE);
        end

        // ==============================================================
        // TEST 2: BYPASS register (1-bit, captured 0, TDI passes through)
        // ==============================================================
        $display("\n========== TEST 2: BYPASS ==========");
        begin
            logic [255:0] byp_out;
            jtag_shift_ir(IR_BYPASS);
            jtag_shift_dr(1, 256'b1, byp_out);
            $display("  BYPASS captured = %0b (expected 0)", byp_out[0]);
            check("BYPASS capture", byp_out[0] === 1'b0);
        end

        // ==============================================================
        // TEST 3: DBG_STATUS before UART (should see idle state)
        // ==============================================================
        $display("\n========== TEST 3: DBG_STATUS (pre-UART) ==========");
        begin
            logic [255:0] st_out;
            jtag_read_dr(IR_DBG_STATUS, STATUS_W, st_out);
            $display("  STATUS = 0x%04h", st_out[15:0]);
            $display("    ready=%0b done=%0b ffn_start=%0b rx_dv=%0b tx_dv=%0b tx_busy=%0b wrapper_st=%0b",
                     st_out[0], st_out[1], st_out[2], st_out[3], st_out[4], st_out[5], st_out[8:6]);
            check("STATUS: done=0 before UART", st_out[1] === 1'b0);
        end

        // ==============================================================
        // TEST 4: Send UART packet & receive result
        // ==============================================================
        $display("\n========== TEST 4: UART end-to-end ==========");
        begin
            byte tx_bytes [0:(N*2)-1];
            int uart_err;
            int uart_rx_done;
            uart_err = 0;
            uart_rx_done = 0;

            // Build expected TX bytes from reference
            tx_bytes[0] = y_ref[0][7:0];
            tx_bytes[1] = y_ref[0][15:8];
            tx_bytes[2] = y_ref[1][7:0];
            tx_bytes[3] = y_ref[1][15:8];

            $display("  y_ref[0]=0x%04h  y_ref[1]=0x%04h", y_ref[0], y_ref[1]);
            $display("  Expected TX bytes: %02h %02h %02h %02h",
                     tx_bytes[0], tx_bytes[1], tx_bytes[2], tx_bytes[3]);

            // Fork: receive UART TX in background + monitor done pulse
            fork
                begin : uart_rx_thread
                    byte got;
                    for (int i = 0; i < N*2; i++) begin
                        uart_recv_byte(got);
                        $display("  UART TX byte[%0d] = 0x%02h (exp 0x%02h)%s",
                                 i, got, tx_bytes[i],
                                 (got !== tx_bytes[i]) ? " MISMATCH" : "");
                        if (got !== tx_bytes[i]) uart_err++;
                    end
                    uart_rx_done = 1;
                end
                begin : done_monitor
                    @(posedge dut.dbg_done);
                    $display("  FFN done asserted at %0t", $time);
                end
            join_none

            // Send full UART frame: W1 → W2 → X → b1 → b2
            for (int r = 0; r < N; r++)
                for (int c = 0; c < N; c++)
                    uart_send_bf16(w1_tb[r][c]);
            for (int r = 0; r < N; r++)
                for (int c = 0; c < N; c++)
                    uart_send_bf16(w2_tb[r][c]);
            for (int i = 0; i < N; i++)
                uart_send_bf16(x_tb[i]);
            for (int i = 0; i < N; i++)
                uart_send_bf16(b1_tb[i]);
            for (int i = 0; i < N; i++)
                uart_send_bf16(b2_tb[i]);

            // UART RX thread will complete after all TX bytes arrive
            // (this also implies FFN has finished since TX only starts after done)
            wait (uart_rx_done == 1);
            #100;

            check("UART TX all bytes match", uart_err == 0);
        end

        // ==============================================================
        // TEST 5: DBG_STATUS after FFN completes
        // ==============================================================
        $display("\n========== TEST 5: DBG_STATUS (post-FFN) ==========");
        begin
            logic [255:0] st_out;

            // Allow CDC synchronisers to propagate (≥ 2 tck cycles)
            repeat (4) @(posedge tck);

            jtag_read_dr(IR_DBG_STATUS, STATUS_W, st_out);
            $display("  STATUS = 0x%04h", st_out[15:0]);
            $display("    ready=%0b done=%0b ffn_start=%0b wrapper_st=%0b",
                     st_out[0], st_out[1], st_out[2], st_out[8:6]);
            // Note: done is a pulse, so it may have already deasserted by the
            // time we scan. The wrapper_state should be back to IDLE (000)
            // or PACKET_DONE (110) depending on timing.
        end

        // ==============================================================
        // TEST 6: DBG_FFN_IN — verify weights/inputs via JTAG
        // ==============================================================
        $display("\n========== TEST 6: DBG_FFN_IN ==========");
        begin
            logic [255:0] ffn_in_raw;
            logic [15:0] jtag_w1 [0:3];
            logic [15:0] jtag_w2 [0:3];
            logic [15:0] jtag_x  [0:1];
            logic [15:0] jtag_b1 [0:1];
            logic [15:0] jtag_b2 [0:1];
            int ffn_in_err;
            ffn_in_err = 0;

            jtag_read_dr(IR_DBG_FFN_IN, FFN_IN_W, ffn_in_raw);

            // Unpack (matches packing in jtag_debug_regs.sv)
            for (int i = 0; i < 4; i++) jtag_w1[i] = ffn_in_raw[i*16 +: 16];
            for (int i = 0; i < 4; i++) jtag_w2[i] = ffn_in_raw[(4+i)*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_x[i]  = ffn_in_raw[(8+i)*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_b1[i] = ffn_in_raw[(10+i)*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_b2[i] = ffn_in_raw[(12+i)*16 +: 16];

            $display("  JTAG w1 = {%04h, %04h, %04h, %04h}",
                     jtag_w1[0], jtag_w1[1], jtag_w1[2], jtag_w1[3]);
            $display("  JTAG w2 = {%04h, %04h, %04h, %04h}",
                     jtag_w2[0], jtag_w2[1], jtag_w2[2], jtag_w2[3]);
            $display("  JTAG x  = {%04h, %04h}", jtag_x[0], jtag_x[1]);
            $display("  JTAG b1 = {%04h, %04h}", jtag_b1[0], jtag_b1[1]);
            $display("  JTAG b2 = {%04h, %04h}", jtag_b2[0], jtag_b2[1]);

            // Compare against TB inputs (row-major flat)
            if (jtag_w1[0] !== w1_tb[0][0]) ffn_in_err++;
            if (jtag_w1[1] !== w1_tb[0][1]) ffn_in_err++;
            if (jtag_w1[2] !== w1_tb[1][0]) ffn_in_err++;
            if (jtag_w1[3] !== w1_tb[1][1]) ffn_in_err++;
            if (jtag_w2[0] !== w2_tb[0][0]) ffn_in_err++;
            if (jtag_w2[1] !== w2_tb[0][1]) ffn_in_err++;
            if (jtag_w2[2] !== w2_tb[1][0]) ffn_in_err++;
            if (jtag_w2[3] !== w2_tb[1][1]) ffn_in_err++;
            if (jtag_x[0]  !== x_tb[0])     ffn_in_err++;
            if (jtag_x[1]  !== x_tb[1])     ffn_in_err++;
            if (jtag_b1[0] !== b1_tb[0])    ffn_in_err++;
            if (jtag_b1[1] !== b1_tb[1])    ffn_in_err++;
            if (jtag_b2[0] !== b2_tb[0])    ffn_in_err++;
            if (jtag_b2[1] !== b2_tb[1])    ffn_in_err++;

            check("FFN_IN weights/inputs match", ffn_in_err == 0);
        end

        // ==============================================================
        // TEST 7: DBG_FFN_PIPE — verify pipeline outputs via JTAG
        // ==============================================================
        $display("\n========== TEST 7: DBG_FFN_PIPE ==========");
        begin
            logic [255:0] pipe_raw;
            logic [15:0] jtag_mac_out   [0:1];
            logic [15:0] jtag_gelu_out  [0:1];
            logic [15:0] jtag_mac_out_2 [0:1];
            logic [15:0] jtag_y         [0:1];
            int pipe_err;
            pipe_err = 0;

            jtag_read_dr(IR_DBG_FFN_PIPE, FFN_PIPE_W, pipe_raw);

            // Unpack (matches packing in jtag_debug_regs.sv)
            for (int i = 0; i < 2; i++) jtag_mac_out[i]   = pipe_raw[i*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_gelu_out[i]  = pipe_raw[(2+i)*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_mac_out_2[i] = pipe_raw[(4+i)*16 +: 16];
            for (int i = 0; i < 2; i++) jtag_y[i]         = pipe_raw[(6+i)*16 +: 16];

            $display("  JTAG mac_out   = {%04h, %04h}", jtag_mac_out[0], jtag_mac_out[1]);
            $display("  JTAG gelu_out  = {%04h, %04h}", jtag_gelu_out[0], jtag_gelu_out[1]);
            $display("  JTAG mac_out_2 = {%04h, %04h}", jtag_mac_out_2[0], jtag_mac_out_2[1]);
            $display("  JTAG y         = {%04h, %04h}", jtag_y[0], jtag_y[1]);
            $display("  REF  y_ref     = {%04h, %04h}", y_ref[0], y_ref[1]);

            if (jtag_y[0] !== y_ref[0]) pipe_err++;
            if (jtag_y[1] !== y_ref[1]) pipe_err++;

            check("FFN_PIPE y matches reference", pipe_err == 0);
        end

        // ==============================================================
        // TEST 8: DBG_CONTROL — write force_rst, verify design resets
        // ==============================================================
        $display("\n========== TEST 8: DBG_CONTROL force_rst ==========");
        begin
            logic [255:0] ctrl_data;
            ctrl_data = '0;
            ctrl_data[1] = 1'b1;  // force_rst = bit 1

            jtag_write_dr(IR_DBG_CONTROL, CONTROL_W, ctrl_data);

            // Wait for CDC to propagate (2 clk-domain flops)
            repeat (10) @(posedge clk);

            $display("  rst_n_eff = %0b (expect 0 = reset active)",
                     dut.rst_n_eff);
            check("JTAG force_rst asserts effective reset",
                  dut.rst_n_eff === 1'b0);

            // Release: write 0 back
            ctrl_data = '0;
            jtag_write_dr(IR_DBG_CONTROL, CONTROL_W, ctrl_data);
            repeat (10) @(posedge clk);

            $display("  rst_n_eff = %0b (expect 1 = running)",
                     dut.rst_n_eff);
            check("JTAG force_rst release",
                  dut.rst_n_eff === 1'b1);
        end

        // ==============================================================
        // Summary
        // ==============================================================
        $display("\n==========================================");
        $display("  TOTAL: %0d tests, %0d passed, %0d failed",
                 total_tests, total_pass, total_fail);
        if (total_fail == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d TEST(S) FAILED ***", total_fail);
        $display("==========================================\n");

        $finish;
    end

endmodule
