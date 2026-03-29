//JTAG Reset (hold trst_n low for 5 TCK cycles):
//  trst_n = 0 → wait 5 cycles → trst_n = 1

//Select DMIACCESS register (shift IR = 5'h11):
//  TMS sequence: 1,1,0,0 → then shift 5 bits of IR → 1,1,0

//Read address 0x0C (y[0][0]):
//  Shift DR = {7'h0C, 32'h0, 2'b01} = 41 bits
//  Then capture the 41-bit response


// Think of it like this:
//jtag_reset()          — plug in the debugger, clear state
//jtag_shift_ir(5'h11)  — tell it "I want to talk to DMI"
//jtag_shift_dr(41bit)  — send "read address 0x0C" request
//jtag_shift_dr(41bit)  — send noop, capture the result back

`timescale 1ns/1ps
import dm::*;

module tb_chip_top;

    localparam int N = 2;

    // ----------------------------------------
    // System signals
    // ----------------------------------------
    logic clk;
    logic rst_n;
    logic testmode_i;

    // ----------------------------------------
    // JTAG pins — we drive these as the "host"
    // ----------------------------------------
    logic tck;
    logic tms;
    logic trst_n;
    logic tdi;
    logic tdo;
    logic tdo_oe;

    // ----------------------------------------
    // FFN datapath inputs
    // ----------------------------------------
    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1][0:N-1];
    logic [15:0] b2 [0:N-1][0:N-1];
    logic [15:0] x  [0:N-1][0:N-1];
    logic [15:0] y  [0:N-1][0:N-1];

    // ----------------------------------------
    // Capture register — shift in TDO bits here
    // ----------------------------------------
    logic [40:0] captured_dr;


    // ----------------------------------------
    // Instantiate the design under test
    // ----------------------------------------
    chip_top #(.N(N)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .testmode_i(testmode_i),
        .tck_i     (tck),
        .tms_i     (tms),
        .trst_ni   (trst_n),
        .td_i      (tdi),
        .td_o      (tdo),
        .tdo_oe_o  (tdo_oe),
        .w1        (w1),
        .w2        (w2),
        .b1        (b1),
        .b2        (b2),
        .x         (x),
        .y         (y)
    );

    // ----------------------------------------
    // System clock — 10ns period (100MHz)
    // ----------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------
    // TCK clock — 40ns period (25MHz)
    // JTAG runs slower than system clock
    // ----------------------------------------
    initial tck = 0;
    always #20 tck = ~tck;

    // ----------------------------------------
    // TASK 1: jtag_reset
    // Pulls trst_n low for 5 TCK cycles then
    // releases it. This forces the TAP FSM back
    // to TestLogicReset no matter what state
    // it was in. Always run this first.
    // ----------------------------------------
    task jtag_reset();
        trst_n = 0;
        tms    = 1;
        tdi    = 0;
        repeat(5) @(posedge tck);
        #1;
        trst_n = 1;
        @(posedge tck);
    endtask

    // ----------------------------------------
    // TASK 2: jtag_tms_seq
    // Sends a sequence of TMS bits one per TCK.
    // input: tms_bits — the bits to send
    // input: len      — how many bits to send
    // This navigates the TAP state machine.
    // Example: tms_seq(5'b11100, 5) moves
    // through states to get to ShiftIR.
    // ----------------------------------------
    task jtag_tms_seq(input logic [7:0] tms_bits, input int len);
        for (int i = 0; i < len; i++) begin
            tms = tms_bits[i];   // send LSB first
            tdi = 0;
            @(posedge tck); #1;
        end
    endtask

    // ----------------------------------------
    // TASK 3: jtag_shift_ir
    // Shifts a 5-bit instruction into the IR.
    // Steps:
    //   1. Navigate to ShiftIR state via TMS
    //   2. Shift 5 bits in (LSB first) via TDI
    //   3. Exit ShiftIR back to RunTestIdle
    //
    // The IR tells the TAP which register to
    // talk to next — 5'h11 = DMIACCESS (DMI)
    // ----------------------------------------
    task jtag_shift_ir(input logic [4:0] ir_val);
        // Navigate: RunTestIdle → SelectDR →
        //           SelectIR → CaptureIR → ShiftIR
        // TMS sequence: 1, 1, 0, 0
        jtag_tms_seq(8'b00001011, 4);

        // Shift 5 IR bits in, LSB first
        // Keep TMS=0 to stay in ShiftIR
        // Set TMS=1 on the LAST bit to exit
        for (int i = 0; i < 5; i++) begin
            tdi = ir_val[i];
            tms = (i == 4) ? 1 : 0;  // exit on last bit
            @(posedge tck); #1;
        end

        // Navigate: Exit1IR → UpdateIR → RunTestIdle
        // TMS sequence: 1, 0
        jtag_tms_seq(8'b00000001, 2);
    endtask

    // ----------------------------------------
    // TASK 4: jtag_shift_dr
    // Shifts a 41-bit value into the DR and
    // captures 41 bits back from TDO.
    // The DR for DMI is always 41 bits:
    //   [40:34] = address (7 bits)
    //   [33:2]  = data    (32 bits)
    //   [1:0]   = op      (2 bits)
    //
    // While we shift IN our request,
    // the chip shifts OUT the previous result.
    // We capture that into captured_dr.
    // ----------------------------------------
    task jtag_shift_dr(input logic [40:0] dr_in);
        // Navigate: RunTestIdle → SelectDR →
        //           CaptureDR → ShiftDR
        // TMS sequence: 1, 0, 0
        jtag_tms_seq(8'b00000001, 1);
        jtag_tms_seq(8'b00000000, 2);

        // Shift 41 bits — LSB first
        // Capture TDO at the same time
        captured_dr = 41'h0;
        for (int i = 0; i < 41; i++) begin
            tdi = dr_in[i];
            tms = (i == 40) ? 1 : 0;  // exit on last bit
            @(posedge tck); #1;
            captured_dr[i] = tdo;      // sample TDO
        end

        // Navigate: Exit1DR → UpdateDR → RunTestIdle
        // TMS sequence: 1, 0
        jtag_tms_seq(8'b00000001, 2);
    endtask

    // ----------------------------------------
    // MAIN TEST
    // ----------------------------------------
    initial begin
        // ----------------------------------
        // 1. Set up waveform dump
        // Creates a .vcd file you can open
        // in GTKWave to see all the signals
        // ----------------------------------
        $dumpfile("tb_chip_top.vcd");
        $dumpvars(0, tb_chip_top);

        // ----------------------------------
        // 2. Initialize all signals to safe
        // default values before releasing reset
        // ----------------------------------
        rst_n      = 0;
        testmode_i = 0;
        trst_n     = 0;
        tms        = 1;
        tdi        = 0;

        // Zero out all FFN inputs
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                w1[i][j] = 16'h0000;
                w2[i][j] = 16'h0000;
                b1[i][j] = 16'h0000;
                b2[i][j] = 16'h0000;
                x[i][j]  = 16'h0000;
            end
        end

        // ----------------------------------
        // 3. Release system reset after
        // a few clock cycles
        // ----------------------------------
        repeat(5) @(posedge clk);
        rst_n = 1;

        // ----------------------------------
        // 4. Load FFN inputs
        // Same values as tb_top.sv so we
        // know what the expected output is:
        //   W1 = W2 = identity matrix
        //   x  = identity matrix
        //   b1 = b2 = zero
        // Expected: y ≈ GELU(1.0) for [0][0]
        //           y ≈ 0 elsewhere
        // ----------------------------------
        w1[0][0] = 16'h3F80; w1[0][1] = 16'h0000;
        w1[1][0] = 16'h0000; w1[1][1] = 16'h3F80;

        w2[0][0] = 16'h3F80; w2[0][1] = 16'h0000;
        w2[1][0] = 16'h0000; w2[1][1] = 16'h3F80;

        x[0][0]  = 16'h3F80; x[0][1]  = 16'h0000;
        x[1][0]  = 16'h0000; x[1][1]  = 16'h3F80;

        $display("=== FFN inputs loaded ===");

        // ----------------------------------
        // 5. Wait for the FFN pipeline to
        // finish — same 20 cycle latency
        // as tb_top.sv
        // ----------------------------------
        repeat(25) @(posedge clk);
        $display("=== FFN pipeline done — y[0][0] = %04h ===", dut.y[0][0]);

        // ----------------------------------
        // 6. JTAG reset — always do this
        // first to get the TAP into a known
        // state (TestLogicReset)
        // ----------------------------------
        jtag_reset();
        $display("=== JTAG reset done ===");

        // ----------------------------------
        // 7. Select the DMIACCESS register
        // IR = 5'h11 tells the TAP "I want
        // to talk to the DMI data register"
        // ----------------------------------
        jtag_shift_ir(5'h11);
        $display("=== IR shifted: DMIACCESS selected ===");

        // ----------------------------------
        // 8. First DR shift — send READ
        // request for address 0x0C (y[0][0])
        // Packet format: {addr, data, op}
        //   addr = 7'h0C
        //   data = 32'h0 (ignored on read)
        //   op   = 2'b01 (READ)
        // ----------------------------------
        jtag_shift_dr({7'h0C, 32'h0, 2'b01});
        $display("=== DR shift 1: read request sent for addr 0x0C ===");

        // ----------------------------------
        // 9. Wait a few system clocks for
        // dmi_reg to process the request
        // and latch the read data
        // ----------------------------------
        repeat(10) @(posedge clk);    // was 5 — give dmi_jtag FSM time to complete


        // ----------------------------------
        // 10. Second DR shift — send NOOP
        // This clocks out the result from
        // the previous read. The chip puts
        // the result in [33:2] of TDO.
        // op = 2'b00 means do nothing new.
        // ----------------------------------
        jtag_shift_dr({7'h00, 32'h0, 2'b00});
        $display("=== DR shift 2: response captured ===");

        // ----------------------------------
        // 11. Decode and display the result
        // captured_dr layout:
        //   [40:34] = address echo
        //   [33:2]  = read data (our value)
        //   [1:0]   = status (00 = success)
        // ----------------------------------
        $display("--- JTAG Read Result ---");
        $display("  Raw captured DR : 0x%011h", captured_dr);  // changed from $display("  Raw captured DR : %041b", captured_dr); to what it is now to show hex instead of binary
        $display("  Address echo    : 0x%02h", captured_dr[40:34]);
        $display("  Read data       : 0x%08h", captured_dr[33:2]);
        $display("  Status          : %02b (00=ok)", captured_dr[1:0]);
        $display("  y[0][0] via JTAG: %04h", captured_dr[17:2]);

        // ----------------------------------
        // 12. Pass/fail check
        // Compare JTAG read against direct
        // wire observation of y[0][0]
        // ----------------------------------
        if (captured_dr[17:2] == dut.y[0][0])
            $display("PASS — JTAG read matches y[0][0]");
        else
            $display("FAIL — JTAG=%04h, direct=%04h",
                     captured_dr[17:2], dut.y[0][0]);

        $display("=== tb_chip_top done ===");
        $finish;
    end

endmodule
