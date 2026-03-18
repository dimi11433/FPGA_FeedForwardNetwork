
module fp32_mul (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    logic        s;
    logic [8:0]  e_sum;    // 9-bit to detect over/underflow
    logic [47:0] m_prod;   // 24x24 = 48-bit full mantissa product
    logic        zero_a, zero_b;

    assign zero_a  = ~|a[30:23];                                // exponent == 0 → zero
    assign zero_b  = ~|b[30:23];
    assign s       = a[31] ^ b[31];                             // XOR signs
    assign e_sum   = {1'b0, a[30:23]} + {1'b0, b[30:23]}       // add biased exponents
                     - 9'd127;                                  // remove one bias
    assign m_prod  = {1'b1, a[22:0]} * {1'b1, b[22:0]};        // multiply mantissas (implicit 1)

    always_comb begin
        if (zero_a || zero_b) begin
            // Either operand is zero
            result = {s, 31'b0};

        end else if (e_sum[8]) begin
            // Bit 8 set = underflow (wrapped negative) or overflow (> 255)
            result = {s, 31'b0};

        end else if (m_prod[47]) begin
            // MSB landed at bit 47 → 1x.frac → shift right 1, exp + 1
            result = {s, e_sum[7:0] + 8'd1, m_prod[46:24]};

        end else begin
            // MSB at bit 46 → 01.frac → already normalised
            result = {s, e_sum[7:0], m_prod[45:23]};
        end
    end
endmodule