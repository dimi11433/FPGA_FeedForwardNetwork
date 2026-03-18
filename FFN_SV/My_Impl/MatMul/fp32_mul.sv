module fp32_mul (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);

    // Extract fields
    logic sign_a, sign_b, sign_res;
    logic [7:0] exp_a, exp_b, exp_res;
    logic [23:0] mant_a, mant_b;
    logic [47:0] mant_product;

    always_comb begin
        // 1. Extract
        sign_a = a[31];
        sign_b = b[31];
        exp_a  = a[30:23];
        exp_b  = b[30:23];

        // Add implicit 1
        mant_a = {1'b1, a[22:0]};
        mant_b = {1'b1, b[22:0]};

        // 2. Sign
        sign_res = sign_a ^ sign_b;

        // 3. Exponent
        exp_res = exp_a + exp_b - 8'd127;

        // 4. Mantissa multiply
        mant_product = mant_a * mant_b; // 24x24 → 48 bits

        // 5. Normalize
        if (mant_product[47]) begin
            // 10.xxxxx
            mant_product = mant_product >> 1;
            exp_res = exp_res + 1;
        end

        // 6. Pack result (truncate mantissa)
        result = {
            sign_res,
            exp_res,
            mant_product[45:23]  // 23 bits
        };
    end

endmodule