
module fp32_add (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    // ----------------------------------------------------------
    // Priority encoder: find MSB position in a 25-bit value
    // Returns 5'h1f if input is zero
    // ----------------------------------------------------------
    function automatic [4:0] msb_pos (input [24:0] v);
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
        else            return 5'h1f;  // zero
    endfunction

    // ----------------------------------------------------------
    // Extract fields
    // ----------------------------------------------------------
    logic        s_a, s_b;
    logic [7:0]  e_a, e_b;
    logic [23:0] m_a, m_b;   // 24-bit with implicit leading 1

    assign s_a = a[31]; assign e_a = a[30:23]; assign m_a = {1'b1, a[22:0]};
    assign s_b = b[31]; assign e_b = b[30:23]; assign m_b = {1'b1, b[22:0]};

    logic zero_a, zero_b;
    assign zero_a = ~|a[30:23];
    assign zero_b = ~|b[30:23];

    // ----------------------------------------------------------
    // Swap so 'l' (large) has the larger exponent
    // ----------------------------------------------------------
    logic        s_l, s_s;
    logic [7:0]  e_l;
    logic [23:0] m_l, m_s;
    logic [7:0]  e_diff;

    always_comb begin
        if (e_a >= e_b) begin
            s_l = s_a; e_l = e_a; m_l = m_a;
            s_s = s_b;             m_s = m_b;
            e_diff = e_a - e_b;
        end else begin
            s_l = s_b; e_l = e_b; m_l = m_b;
            s_s = s_a;             m_s = m_a;
            e_diff = e_b - e_a;
        end
    end

    // ----------------------------------------------------------
    // Align smaller mantissa (shift right by exponent difference)
    // ----------------------------------------------------------
    logic [23:0] m_s_algn;
    assign m_s_algn = (e_diff >= 8'd24) ? 24'b0 : (m_s >> e_diff);

    // ----------------------------------------------------------
    // Add or subtract mantissa magnitudes
    // ----------------------------------------------------------
    logic [24:0] m_raw;    // 25-bit: bit 24 captures carry-out
    logic        r_sign;

    always_comb begin
        if (s_l == s_s) begin
            // Same sign → add
            r_sign = s_l;
            m_raw  = {1'b0, m_l} + {1'b0, m_s_algn};
        end else if (m_l >= m_s_algn) begin
            // Different sign, larger mag wins
            r_sign = s_l;
            m_raw  = {1'b0, m_l} - {1'b0, m_s_algn};
        end else begin
            r_sign = s_s;
            m_raw  = {1'b0, m_s_algn} - {1'b0, m_l};
        end
    end

    // ----------------------------------------------------------
    // Normalise result
    //   mpos == 24 → carry out, shift right 1, exp + 1
    //   mpos == 23 → already normalised
    //   mpos <  23 → shift left (23 - mpos), exp - (23 - mpos)
    // ----------------------------------------------------------
    logic [4:0]  mpos;
    logic [4:0]  lshift;
    logic [24:0] m_norm;
    logic [7:0]  e_out;
    logic [22:0] m_out;

    assign mpos   = msb_pos(m_raw);
    assign lshift = (mpos <= 5'd23) ? (5'd23 - mpos) : 5'd0;
    assign m_norm = m_raw << lshift;

    assign e_out  = (mpos == 5'd24)              ? (e_l + 8'd1) :
                    (e_l >= {3'b0, lshift})       ? (e_l - {3'b0, lshift}) :
                                                    8'b0;          // underflow → zero

    assign m_out  = (mpos == 5'd24) ? m_raw[23:1]  // carry: shift right 1
                                    : m_norm[22:0]; // normalise left

    // ----------------------------------------------------------
    // Output mux (handle zeros and zero result)
    // ----------------------------------------------------------
    always_comb begin
        if      (zero_a)          result = b;          // a == 0 → return b
        else if (zero_b)          result = a;          // b == 0 → return a
        else if (m_raw == 25'b0)  result = 32'b0;      // cancellation
        else if (mpos == 5'h1f)   result = 32'b0;      // zero mantissa
        else                      result = {r_sign, e_out, m_out};
    end
endmodule