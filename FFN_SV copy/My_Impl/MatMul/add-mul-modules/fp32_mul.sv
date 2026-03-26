
module fp32_mul (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    logic        s;
    logic [9:0]  e_sum_wide;  // 10-bit: ea + eb, before bias removal (0 to 510)
    logic [47:0] m_prod;
    logic        zero_a, zero_b;

    assign zero_a     = ~|a[30:23];
    assign zero_b     = ~|b[30:23];
    assign s          = a[31] ^ b[31];

    // Sum exponents WITHOUT subtracting bias yet — keeps full range visible
    assign e_sum_wide = {2'b00, a[30:23]} + {2'b00, b[30:23]};

    assign m_prod     = {1'b1, a[22:0]} * {1'b1, b[22:0]};

    always_comb begin
        if (zero_a || zero_b) begin
            result = {s, 31'b0};

        end else if (e_sum_wide <= 10'd127) begin
            // underflow: ea + eb <= 127 means result exp <= 0 after bias removal
            result = {s, 31'b0};

        end else if (e_sum_wide >= 10'd382) begin
            // overflow: ea + eb >= 382 means result exp >= 255 after bias removal
            result = {s, 8'hFF, 23'b0};  // INF

        end else begin
            // normal range: result exp = e_sum_wide - 127 (or +1 when normalizing)
            // IEEE: 24*24 product has leading 1 at 46 or 47. Fraction = next 23 bits.
            // m_prod[47]=1: 1x.xxxx → shift right, use [46:24], exp+1
            // m_prod[47]=0: 01.xxxx → use [45:23], exp unchanged
            if (m_prod[47])
                result = {s, 8'(e_sum_wide - 10'd127 + 10'd1), m_prod[46:24]};
            else
                result = {s, 8'(e_sum_wide - 10'd127), m_prod[45:23]};
        end
    end
endmodule