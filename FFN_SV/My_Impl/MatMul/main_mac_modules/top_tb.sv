// ============================================================
// mac_model: mirrors mac_8cyc using shortreal (FP32) arithmetic
// $bitstoshortreal / $shortrealtobits handle IEEE 754 correctly
// ============================================================
class mac_model;
    bit [3:0]  counter;
    bit [15:0] t_a, t_b, t_c;
    bit        rst_n;
    bit [15:0] t_data_out;
    shortreal  accumulator;       // FP32 accumulator (mirrors acc_reg in RTL)

    function void reset();
        counter     = 0;
        accumulator = 0.0;
        t_data_out  = 0;
    endfunction

    function void mac(bit [15:0] a_in, bit [15:0] b_in, bit [15:0] c_in);
        shortreal  sr_a, sr_b, sr_c;
        logic [31:0] acc_bits;

        this.t_a = a_in;
        this.t_b = b_in;
        this.t_c = c_in;

        if (!rst_n) begin
            accumulator = 0.0;
            t_data_out  = 0;
            counter     = 0;
        end else begin
            // Decode BF16 → FP32 → shortreal
            // BF16 is the top 16 bits of FP32, so zero-padding gives exact FP32
            sr_a = $bitstoshortreal({t_a, 16'h0000});
            sr_b = $bitstoshortreal({t_b, 16'h0000});
            sr_c = $bitstoshortreal({t_c, 16'h0000});

            if (counter < 4'd8) begin
                // Cycles 0-7: accumulate W * x
                counter++;
                accumulator += sr_a * sr_b;

            end else if (counter == 4'd8) begin
                // Cycle 8: add bias
                counter++;
                accumulator += sr_c;

            end else begin
                // Cycle 9: truncate FP32 → BF16 (top 16 bits)
                acc_bits   = $shortrealtobits(accumulator);
                t_data_out = acc_bits[31:16];
            end
        end
    endfunction

    function void display();
        $display("Model  @%0t: a=%0d b=%0d c=%0d acc=%f out=0x%04h",
                 $time, t_a, t_b, t_c, accumulator, t_data_out);
    endfunction
endclass

// ============================================================
// mac_packet: random stimulus
// ============================================================
class mac_packet;
    rand bit [15:0] t_a;
    rand bit [15:0] t_b;
    rand bit [15:0] t_c;

    // Constrain to valid normal BF16 range to avoid NaN/inf in test vectors
    // Exponent field (bits[14:7]) should not be all-ones (0xFF = inf/NaN)
    constraint valid_bf16 {
        t_a[14:7] != 8'hFF;
        t_b[14:7] != 8'hFF;
        t_c[14:7] != 8'hFF;
    }
endclass

// ============================================================
// Testbench
// ============================================================
module tb_mac_8yc;
    mac_model  packet;
    mac_packet driver;

    logic        clk;
    logic        rst_n;
    logic [15:0] data_in_a;
    logic [15:0] data_in_b;
    logic [15:0] data_in_c;
    logic [15:0] data_out;
    logic        ready;

    mac_8cyc dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .data_in_a (data_in_a),
        .data_in_b (data_in_b),
        .data_in_c (data_in_c),
        .data_out  (data_out),
        .ready     (ready)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_mac_8yc.vcd");
        $dumpvars(0, tb_mac_8yc);

        packet = new();
        driver = new();

        // Reset
        rst_n = 0;
        @(posedge clk);
        packet.rst_n = 0;
        packet.reset();
        #5;
        rst_n = 1;
        packet.rst_n = 1;

        // Lock bias after first randomise (same bias for whole MAC run)
        assert(driver.randomize());
        driver.t_c.rand_mode(0);

        repeat(10) begin
            assert(driver.randomize());

            data_in_a = driver.t_a;
            data_in_b = driver.t_b;
            data_in_c = driver.t_c;

            @(posedge clk);
            packet.mac(driver.t_a, driver.t_b, driver.t_c);
            #1;  // small delay to sample DUT outputs after clock edge

            packet.display();
            $display("DUT    @%0t: a=%0d b=%0d c=%0d data_out=0x%04h ready=%0b",
                     $time, data_in_a, data_in_b, data_in_c, data_out, ready);
        end

        // Final pass/fail check
        if (packet.t_data_out == data_out)
            $display("PASS: model=0x%04h dut=0x%04h", packet.t_data_out, data_out);
        else
            $display("FAIL: model=0x%04h dut=0x%04h", packet.t_data_out, data_out);

        $finish;
    end
endmodule