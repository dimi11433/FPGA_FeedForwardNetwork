`timescale 1ns/1ps

module tb_test_cl;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] result;

    // IMPORTANT:
    // This testbench is intended to be compiled with `test_cl.sv` only.
    // Your repository also has another `fp32_mul` module in `fp32_mul.sv`,
    // and compiling both will typically cause a duplicate-module error.
    fp32_mul dut (
        .a(a),
        .b(b),
        .result(result)
    );

    int total;
    int mismatches;

    // Golden model that mirrors the arithmetic in `test_cl.sv`.
    function automatic logic [31:0] golden_mul(input logic [31:0] a_in, input logic [31:0] b_in);
        logic        s;
        logic [8:0]  e_sum;
        logic [47:0] m_prod;
        logic        zero_a, zero_b;
        logic [7:0]  e_next;

        s = a_in[31] ^ b_in[31];
        zero_a = ~|a_in[30:23]; // exponent == 0
        zero_b = ~|b_in[30:23];

        e_sum  = {1'b0, a_in[30:23]} + {1'b0, b_in[30:23]} - 9'd127;
        m_prod = {1'b1, a_in[22:0]} * {1'b1, b_in[22:0]};

        if (zero_a || zero_b) begin
            golden_mul = {s, 31'b0};
        end else if (e_sum[8]) begin
            // Underflow (negative wrapped) or overflow (>255)
            golden_mul = {s, 31'b0};
        end else if (m_prod[47]) begin
            // 1x.frac -> shift right 1, exp + 1
            e_next = e_sum[7:0] + 8'd1;
            golden_mul = {s, e_next, m_prod[46:24]};
        end else begin
            // 0.5x.frac already normalised
            golden_mul = {s, e_sum[7:0], m_prod[45:23]};
        end
    endfunction

    task automatic apply_and_check(input logic [31:0] a_in, input logic [31:0] b_in);
        logic [31:0] golden;
        begin
            a = a_in;
            b = b_in;
            #1; // combinational settle

            golden = golden_mul(a_in, b_in);
            total++;
            if (result !== golden) begin
                mismatches++;
                if (mismatches <= 20) begin
                    $display("Mismatch %0d: a=0x%08h b=0x%08h result=0x%08h golden=0x%08h",
                             mismatches, a_in, b_in, result, golden);
                end
            end
        end
    endtask

    function automatic logic [31:0] make_fp32(input logic sign, input logic [7:0] exp, input logic [22:0] mant);
        return {sign, exp, mant};
    endfunction

    initial begin
        $dumpfile("tb_test_cl.vcd");
        $dumpvars(0, tb_test_cl);

        total = 0;
        mismatches = 0;
        a = '0;
        b = '0;

        // Directed edge cases
        // Zero handling
        apply_and_check(make_fp32(1'b0, 8'd0,  23'd123), make_fp32(1'b0, 8'd127, 23'd5));   // a=0
        apply_and_check(make_fp32(1'b1, 8'd0,  23'd999), make_fp32(1'b0, 8'd127, 23'd5));   // a=0, sign matters
        apply_and_check(make_fp32(1'b0, 8'd127, 23'd7),  make_fp32(1'b1, 8'd0,   23'd1));   // b=0

        // Underflow: exp small => e_sum becomes negative => flush to zero
        apply_and_check(make_fp32(1'b0, 8'd1, 23'd0), make_fp32(1'b0, 8'd1, 23'd0));

        // Overflow: exp large => e_sum[8]=1 => flush to zero
        apply_and_check(make_fp32(1'b0, 8'd254, 23'd0), make_fp32(1'b0, 8'd254, 23'd0));

        // A couple of normal-ish patterns
        apply_and_check(make_fp32(1'b0, 8'd127, 23'd0), make_fp32(1'b0, 8'd127, 23'd0)); // ~1.0 * ~1.0
        apply_and_check(make_fp32(1'b1, 8'd127, 23'd1), make_fp32(1'b0, 8'd127, 23'd2));

        // Random tests (includes exponent==0, ==255, etc.)
        repeat (500) begin
            logic sign_a, sign_b;
            logic [7:0] exp_a, exp_b;
            logic [22:0] mant_a, mant_b;

            sign_a = $urandom_range(0, 1);
            sign_b = $urandom_range(0, 1);
            exp_a  = $urandom;
            exp_b  = $urandom;
            mant_a = $urandom;
            mant_b = $urandom;

            apply_and_check(make_fp32(sign_a, exp_a, mant_a), make_fp32(sign_b, exp_b, mant_b));
        end

        $display("tb_test_cl done: total=%0d mismatches=%0d", total, mismatches);
        $finish;
    end

endmodule

