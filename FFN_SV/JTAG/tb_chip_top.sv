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
    // FFN datapath signals — driven by testbench
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
    chip_top_sim #(.N(N)) dut (
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
    // TCK = clk (single clock domain for sim)
    // dmi_jtag has no CDC so TCK must match clk
    // Hardware uses separate TCK from Pmod JA
    // ----------------------------------------
    assign tck = clk;

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
        tms    = 0;  // TMS=0 so TestLogicReset → RunTestIdle on the next posedge
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
        jtag_tms_seq(8'b00000011, 4);

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
        // TDO is registered on negedge from dr_q[0] BEFORE the posedge shift.
        // So correct order is: wait negedge → sample TDO → wait posedge (shift)
        captured_dr = 41'h0;
        for (int i = 0; i < 41; i++) begin
            tdi = dr_in[i];
            tms = (i == 40) ? 1 : 0;  // exit on last bit
            @(negedge tck); #1;        // TDO latches dr_q[0] = bit i (pre-shift)
            captured_dr[i] = tdo;      // sample TDO now valid
            @(posedge tck); #1;        // DUT samples TDI and shifts DR (bit i+1 → dr_q[0])
        end

        // Navigate: Exit1DR → UpdateDR → RunTestIdle
        // TMS sequence: 1, 0
        jtag_tms_seq(8'b00000001, 2);
    endtask

    // ----------------------------------------
    // TASK 5: jtag_dmi_read
    // Performs a complete DMI read transaction:
    //   1. DR shift 1 — sends READ request for
    //      the given 7-bit address. The op field
    //      is 2'b01 = READ.
    //   2. Waits 100 cycles for the dmi_jtag FSM
    //      to issue the request to dmi_reg, wait
    //      for the response, and latch data_q.
    //   3. DR shift 2 — sends a NOOP (op=2'b00).
    //      While shifting in the NOOP, the chip
    //      shifts out the captured response.
    //      captured_dr[33:2] = 32-bit read data.
    //      captured_dr[1:0]  = status (00 = ok).
    //
    // IR must already be set to DMIACCESS (5'h11)
    // before calling this task.
    // ----------------------------------------
    task jtag_dmi_read(input logic [6:0] addr, output logic [31:0] rdata);
        // DR shift 1: send READ request
        // Packet = {addr[6:0], 32'h0 (ignored), 2'b01 (READ)}
        jtag_shift_dr({addr, 32'h0, 2'b01});

        // Wait for dmi_jtag FSM:
        //   Idle → Read (asserts dmi_req_valid)
        //   Read → WaitReadValid (dmi_req_ready=1 so immediate)
        //   WaitReadValid → Idle (dmi_resp_valid fires, data_q latched)
        repeat(100) @(posedge clk);

        // DR shift 2: send NOOP to clock out the response
        // The TAP captures {address_q, data_q, DMINoError} into dr_q
        // on CaptureDR, then shifts it out LSB-first via TDO.
        jtag_shift_dr({7'h00, 32'h0, 2'b00});

        // captured_dr[33:2] is the 32-bit read data
        // captured_dr[1:0]  is the status (00 = success)
        rdata = captured_dr[33:2];
    endtask

    // ----------------------------------------
    // TASK 6: print_result
    // Prints one register read result and does
    // a pass/fail check against the direct wire.
    // ----------------------------------------
    task print_result(
        input string      name,
        input logic [6:0] addr,
        input logic [31:0] jtag_val,
        input logic [15:0] direct_val
    );
        $display("  [0x%02h] %-20s JTAG=0x%04h  direct=0x%04h  status=%02b  %s",
            addr, name,
            jtag_val[15:0], direct_val,
            captured_dr[1:0],
            (jtag_val[15:0] == direct_val) ? "PASS" : "FAIL");
    endtask

    // ----------------------------------------
    // MAIN TEST
    // ----------------------------------------
    // What happens, step by step:
    //
    // 1. Initialize signals, hold reset low.
    // 2. Release system reset — FFN starts computing.
    // 3. Load BF16 inputs (1.0 = 16'h3F80) so FFN
    //    has valid data during pipeline wait.
    // 4. Wait 25 cycles — FFN pipeline latency.
    // 5. JTAG reset — TAP goes to TestLogicReset
    //    then RunTestIdle (trst_n low 5 cycles).
    // 6. Shift IR = 5'h11 — loads DMIACCESS into
    //    jtag_ir_q, enabling dmi_select.
    // 7. For each register address:
    //    a. DR shift 1 sends {addr, 0, READ}.
    //       UpdateDR fires → dmi_jtag FSM sees
    //       dmi_select & update → moves Idle→Read.
    //    b. Read state asserts dmi_req_valid.
    //       dmi_reg sees dmi_req_valid, looks up
    //       address, puts result in rdata_reg,
    //       asserts dmi_resp_valid.
    //    c. WaitReadValid sees dmi_resp_valid,
    //       latches data into data_q, goes Idle.
    //    d. DR shift 2 (NOOP): CaptureDR loads
    //       {address_q, data_q, 00} into dr_q.
    //       ShiftDR clocks it out via TDO LSB-first.
    //       Testbench samples TDO on each negedge.
    // 8. Compare each JTAG read to direct wire.
    // ----------------------------------------
    integer pass_count;
    integer fail_count;
    logic [31:0] rdata;

    initial begin
        $dumpfile("tb_chip_top.vcd");
        $dumpvars(0, tb_chip_top);

        pass_count = 0;
        fail_count = 0;

        // ----------------------------------
        // 1. Initialize signals
        // ----------------------------------
        rst_n      = 0;
        testmode_i = 0;
        trst_n     = 0;
        tms        = 1;
        tdi        = 0;

        // ----------------------------------
        // 2. Release system reset
        // ----------------------------------
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("=== System reset released ===");

        // ----------------------------------
        // 3. Load BF16 inputs (1.0 = 16'h3F80)
        // Must happen BEFORE the pipeline wait
        // so the FFN has valid data to compute.
        // BF16 format: sign[15] exp[14:7] mant[6:0]
        // 1.0 = 0_01111111_0000000 = 16'h3F80
        // ----------------------------------
        // Use distinct BF16 values so address mismatches are caught
        // 1.0=3F80  2.0=4000  0.5=3F00  1.5=3FC0
        w1[0][0] = 16'h3F80;  w1[0][1] = 16'h4000;
        w1[1][0] = 16'h3F00;  w1[1][1] = 16'h3FC0;

        w2[0][0] = 16'h4000;  w2[0][1] = 16'h3F80;
        w2[1][0] = 16'h3FC0;  w2[1][1] = 16'h3F00;

        b1[0][0] = 16'h3F80;  b1[0][1] = 16'h3F80;
        b1[1][0] = 16'h3F80;  b1[1][1] = 16'h3F80;

        b2[0][0] = 16'h3F80;  b2[0][1] = 16'h3F80;
        b2[1][0] = 16'h3F80;  b2[1][1] = 16'h3F80;

        x[0][0]  = 16'h3F80;  x[0][1]  = 16'h4000;
        x[1][0]  = 16'h3F00;  x[1][1]  = 16'h3FC0;
        $display("=== FFN inputs loaded: distinct BF16 values ===");

        // ----------------------------------
        // 4. Wait for FFN pipeline to finish
        // ----------------------------------
        repeat(25) @(posedge clk);
        $display("=== FFN pipeline done ===");
        $display("    y[0][0]=%04h  y[0][1]=%04h", dut.y[0][0], dut.y[0][1]);
        $display("    y[1][0]=%04h  y[1][1]=%04h", dut.y[1][0], dut.y[1][1]);

        // ----------------------------------
        // 5. JTAG reset
        // trst_n low for 5 TCK cycles forces
        // TAP to TestLogicReset. tms=0 on
        // release moves it to RunTestIdle.
        // ----------------------------------
        jtag_reset();
        $display("=== JTAG reset done — TAP in RunTestIdle ===");

        // ----------------------------------
        // 6. Select DMIACCESS instruction
        // TMS: 1,1,0,0 → ShiftIR
        // Shift in 5'h11 LSB-first
        // TMS: 1,0 → UpdateIR → RunTestIdle
        // Now jtag_ir_q = DMIACCESS (5'h11)
        // and dmi_select = 1 for all DR shifts
        // ----------------------------------
        jtag_shift_ir(5'h11);
        $display("=== IR = DMIACCESS (5'h11) loaded ===");
        $display("");

        // ----------------------------------
        // 7. Read all DMI registers
        // IR stays DMIACCESS for all reads.
        // Each jtag_dmi_read call does:
        //   DR shift 1 → wait 100 → DR shift 2
        // ----------------------------------

        $display("=== Layer 1 MAC outputs (w1*x + b1) ===");
        jtag_dmi_read(7'h00, rdata);
        print_result("mac_out[0][0]", 7'h00, rdata, dut.dbg_mac_out[0][0]);
        if (rdata[15:0] == dut.dbg_mac_out[0][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h01, rdata);
        print_result("mac_out[0][1]", 7'h01, rdata, dut.dbg_mac_out[0][1]);
        if (rdata[15:0] == dut.dbg_mac_out[0][1]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h02, rdata);
        print_result("mac_out[1][0]", 7'h02, rdata, dut.dbg_mac_out[1][0]);
        if (rdata[15:0] == dut.dbg_mac_out[1][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h03, rdata);
        print_result("mac_out[1][1]", 7'h03, rdata, dut.dbg_mac_out[1][1]);
        if (rdata[15:0] == dut.dbg_mac_out[1][1]) pass_count++; else fail_count++;

        $display("");
        $display("=== Layer 1 GELU outputs ===");
        jtag_dmi_read(7'h04, rdata);
        print_result("gelu_out[0][0]", 7'h04, rdata, dut.dbg_gelu_out[0][0]);
        if (rdata[15:0] == dut.dbg_gelu_out[0][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h05, rdata);
        print_result("gelu_out[0][1]", 7'h05, rdata, dut.dbg_gelu_out[0][1]);
        if (rdata[15:0] == dut.dbg_gelu_out[0][1]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h06, rdata);
        print_result("gelu_out[1][0]", 7'h06, rdata, dut.dbg_gelu_out[1][0]);
        if (rdata[15:0] == dut.dbg_gelu_out[1][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h07, rdata);
        print_result("gelu_out[1][1]", 7'h07, rdata, dut.dbg_gelu_out[1][1]);
        if (rdata[15:0] == dut.dbg_gelu_out[1][1]) pass_count++; else fail_count++;

        $display("");
        $display("=== Layer 2 MAC outputs (w2*gelu + b2) ===");
        jtag_dmi_read(7'h08, rdata);
        print_result("mac_out_2[0][0]", 7'h08, rdata, dut.dbg_mac_out_2[0][0]);
        if (rdata[15:0] == dut.dbg_mac_out_2[0][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h09, rdata);
        print_result("mac_out_2[0][1]", 7'h09, rdata, dut.dbg_mac_out_2[0][1]);
        if (rdata[15:0] == dut.dbg_mac_out_2[0][1]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h0A, rdata);
        print_result("mac_out_2[1][0]", 7'h0A, rdata, dut.dbg_mac_out_2[1][0]);
        if (rdata[15:0] == dut.dbg_mac_out_2[1][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h0B, rdata);
        print_result("mac_out_2[1][1]", 7'h0B, rdata, dut.dbg_mac_out_2[1][1]);
        if (rdata[15:0] == dut.dbg_mac_out_2[1][1]) pass_count++; else fail_count++;

        $display("");
        $display("=== Final FFN outputs y[i][j] ===");
        jtag_dmi_read(7'h0C, rdata);
        print_result("y[0][0]", 7'h0C, rdata, dut.y[0][0]);
        if (rdata[15:0] == dut.y[0][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h0D, rdata);
        print_result("y[0][1]", 7'h0D, rdata, dut.y[0][1]);
        if (rdata[15:0] == dut.y[0][1]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h0E, rdata);
        print_result("y[1][0]", 7'h0E, rdata, dut.y[1][0]);
        if (rdata[15:0] == dut.y[1][0]) pass_count++; else fail_count++;

        jtag_dmi_read(7'h0F, rdata);
        print_result("y[1][1]", 7'h0F, rdata, dut.y[1][1]);
        if (rdata[15:0] == dut.y[1][1]) pass_count++; else fail_count++;

        $display("");
        $display("=== Ready flags ===");
        jtag_dmi_read(7'h10, rdata);
        $display("  [0x10] ready1 (packed) = 0x%08h  status=%02b  %s",
            rdata, captured_dr[1:0],
            (captured_dr[1:0] == 2'b00) ? "PASS" : "FAIL");
        if (captured_dr[1:0] == 2'b00) pass_count++; else fail_count++;

        jtag_dmi_read(7'h11, rdata);
        $display("  [0x11] ready2 (packed) = 0x%08h  status=%02b  %s",
            rdata, captured_dr[1:0],
            (captured_dr[1:0] == 2'b00) ? "PASS" : "FAIL");
        if (captured_dr[1:0] == 2'b00) pass_count++; else fail_count++;

        // ----------------------------------
        // 8. Final summary
        // ----------------------------------
        $display("");
        $display("==========================================");
        $display("  RESULTS: %0d PASS  %0d FAIL  (of %0d)",
                 pass_count, fail_count, pass_count + fail_count);
        $display("==========================================");

        $display("=== tb_chip_top done ===");
        $finish;
    end

endmodule
