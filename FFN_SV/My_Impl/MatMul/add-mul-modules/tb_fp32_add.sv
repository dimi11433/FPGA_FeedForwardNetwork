`timescale 1ns/1ps

module tb_fp32_add;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] result;

    fp32_add dut (
        .a(a),
        .b(b),
        .result(result)
    );

    int total;
    int mismatches;

    // ----------------------------
    // Golden model (mirrors fp32_add.sv)
    // ----------------------------
    function automatic [4:0] msb_pos(input [24:0] v);
        if      (v[24]) return 5'd24;
        else if (v[23]) return 5'd23;
        else if (v[22]) return 5'd22;
        else if (v[21]) return 5'd21;
        else if (v[20]) return 5'd20;
        else if (v[19]) return 5'd19;
        else if (v[18]) return 5'd18;
        else if (v[17]) return 5'd17;
        else if (v[16]) return 5'd16;
        else if (v[15]) return 5'd15;
        else if (v[14]) return 5'd14;
        else if (v[13]) return 5'd13;
        else if (v[12]) return 5'd12;
        else if (v[11]) return 5'd11;
        else if (v[10]) return 5'd10;
        else if (v[9])  return 5'd9;
        else if (v[8])  return 5'd8;
        else if (v[7])  return 5'd7;
        else if (v[6])  return 5'd6;
        else if (v[5])  return 5'd5;
        else if (v[4])  return 5'd4;
        else if (v[3])  return 5'd3;
        else if (v[2])  return 5'd2;
        else if (v[1])  return 5'd1;
        else if (v[0])  return 5'd0;
        else             return 5'h1f; // zero
    endfunction

    function automatic logic [31:0] golden_add(input logic [31:0] a_in, input logic [31:0] b_in);
        logic        s_a, s_b;
        logic [7:0]  e_a, e_b;
        logic [23:0] m_a, m_b;
        logic        zero_a, zero_b;

        logic        s_l, s_s;
        logic [7:0]  e_l;
        logic [23:0] m_l, m_s;
        logic [7:0]  e_diff;

        logic [23:0] m_s_algn;
        logic [24:0] m_raw;
        logic         r_sign;

        logic [4:0]  mpos;
        logic [4:0]  lshift;
        logic [24:0] m_norm;
        logic [7:0]  e_out;
        logic [22:0] m_out;

        s_a = a_in[31];
        s_b = b_in[31];
        e_a = a_in[30:23];
        e_b = b_in[30:23];
        m_a = {1'b1, a_in[22:0]};
        m_b = {1'b1, b_in[22:0]};

        zero_a = ~|a_in[30:23];
        zero_b = ~|b_in[30:23];

        if (e_a >= e_b) begin
            s_l = s_a; e_l = e_a; m_l = m_a;
            s_s = s_b;          m_s = m_b;
            e_diff = e_a - e_b;
        end else begin
            s_l = s_b; e_l = e_b; m_l = m_b;
            s_s = s_a;            m_s = m_a;
            e_diff = e_b - e_a;
        end

        m_s_algn = (e_diff >= 8'd24) ? 24'b0 : (m_s >> e_diff);

        if (s_l == s_s) begin
            r_sign = s_l;
            m_raw  = {1'b0, m_l} + {1'b0, m_s_algn};
        end else if (m_l >= m_s_algn) begin
            r_sign = s_l;
            m_raw  = {1'b0, m_l} - {1'b0, m_s_algn};
        end else begin
            r_sign = s_s;
            m_raw  = {1'b0, m_s_algn} - {1'b0, m_l};
        end

        mpos   = msb_pos(m_raw);
        lshift = (mpos <= 5'd23) ? (5'd23 - mpos) : 5'd0;
        m_norm = m_raw << lshift;

        e_out = (mpos == 5'd24)              ? (e_l + 8'd1) :
                (e_l >= {3'b0, lshift})     ? (e_l - {3'b0, lshift}) :
                                              8'b0;

        m_out  = (mpos == 5'd24) ? m_raw[23:1]
                                  : m_norm[22:0];

        // Output mux
        if      (zero_a)         golden_add = b_in;
        else if (zero_b)         golden_add = a_in;
        else if (m_raw == 25'b0) golden_add = 32'b0;
        else if (mpos == 5'h1f)  golden_add = 32'b0;
        else                      golden_add = {r_sign, e_out, m_out};
    endfunction

    // Generate normal-ish FP32 (avoid exp=0 and exp=255)
    function automatic logic [31:0] rand_normal_fp32();
        logic sign;
        logic [7:0] exp;
        logic [22:0] mant;
        sign = $urandom_range(0, 1);
        exp  = $urandom_range(1, 254);
        mant = $urandom;
        return {sign, exp, mant};
    endfunction

    task automatic apply_and_check(input logic [31:0] a_in, input logic [31:0] b_in);
        logic [31:0] golden;
        begin
            a = a_in;
            b = b_in;
            #1; // settle combinational logic

            golden = golden_add(a_in, b_in);
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

    initial begin
        $dumpfile("tb_fp32_add.vcd");
        $dumpvars(0, tb_fp32_add);

        a = '0;
        b = '0;
        total = 0;
        mismatches = 0;

        // Directed edge-ish cases
        // a == 0 → result = b
        apply_and_check(32'h0000_0000, 32'h3f80_0000); // 0 + 1.0
        apply_and_check(32'h8000_0000, 32'h3f80_0000); // -0 + 1.0 (sign preserved via DUT mux)

        // b == 0 → result = a
        apply_and_check(32'h3f80_0000, 32'h0000_0000); // 1.0 + 0

        // cancellation-like: x + (-x)
        apply_and_check(32'h3f80_0000, 32'hbf80_0000); // 1.0 + (-1.0)

        // Random tests
        repeat (500) begin
            apply_and_check(rand_normal_fp32(), rand_normal_fp32());
        end

        // Also include exponent==0 cases occasionally
        repeat (100) begin
            logic [31:0] x;
            x = rand_normal_fp32();
            x[30:23] = 8'd0; // force exponent=0 => treated as zero by DUT
            apply_and_check(x, rand_normal_fp32());
        end

        $display("tb_fp32_add done. Total=%0d mismatches=%0d", total, mismatches);
        $finish;
    end

endmodule

