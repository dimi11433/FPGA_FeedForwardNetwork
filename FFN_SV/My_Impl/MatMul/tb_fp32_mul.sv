`timescale 1ns/1ps

module tb_fp32_mul;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] result;

    fp32_mul dut (
        .a(a),
        .b(b),
        .result(result)
    );

    int total;
    int mismatches;

    // Generate IEEE-754-like "normal" numbers only (exp in 1..254)
    // so the DUT's simplified math (always assumes implicit leading 1)
    // doesn't immediately break on zeros/denormals/inf/NaNs.
    function automatic logic [31:0] rand_normal_fp32();
        logic sign;
        logic [7:0] exp;
        logic [22:0] mant;

        sign = $urandom_range(0, 1);
        exp  = $urandom_range(1, 254);
        mant = $urandom; // truncated to 23 bits

        return {sign, exp, mant};
    endfunction

    task automatic apply_and_check(input logic [31:0] a_in, input logic [31:0] b_in);
        shortreal sa;
        shortreal sb;
        shortreal sr;
        logic [31:0] golden;

        a = a_in;
        b = b_in;
        #1; // settle combinational logic

        sa = $bitstoshortreal(a_in);
        sb = $bitstoshortreal(b_in);
        sr = sa * sb;
        golden = $shortrealtobits(sr);

        total++;
        if (result !== golden) begin
            mismatches++;
            if (mismatches <= 10) begin
                $display("Mismatch %0d: a=0x%08h b=0x%08h result=0x%08h golden=0x%08h", mismatches, a_in, b_in, result, golden);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_fp32_mul.vcd");
        $dumpvars(0, tb_fp32_mul);

        a = '0;
        b = '0;
        total = 0;
        mismatches = 0;

        // Directed tests
        apply_and_check($shortrealtobits(1.0),  $shortrealtobits(1.0));  // 1 * 1 = 1
        apply_and_check($shortrealtobits(2.0),  $shortrealtobits(3.0));  // 2 * 3 = 6
        apply_and_check($shortrealtobits(-2.0), $shortrealtobits(3.0));  // -2 * 3 = -6
        apply_and_check($shortrealtobits(0.5),  $shortrealtobits(8.0));  // 0.5 * 8 = 4

        // Random normal values
        repeat (100) begin
            apply_and_check(rand_normal_fp32(), rand_normal_fp32());
        end

        $display("Done. Total=%0d mismatches=%0d", total, mismatches);
        $finish;
    end

endmodule

