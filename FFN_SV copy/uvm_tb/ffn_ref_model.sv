`ifndef FFN_REF_MODEL_SV
`define FFN_REF_MODEL_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"

class ffn_ref_model extends uvm_subscriber #(ffn_transaction);
    parameter int N = 2;

    uvm_analysis_port #(ffn_transaction) out_port;

    `uvm_component_utils(ffn_ref_model)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        out_port = new("out_port", this);
    endfunction

    virtual function shortreal bf16_to_fp32(input logic [15:0] bf16);
        return $bitstoshortreal({bf16, 16'h0000});
    endfunction

    virtual function logic [15:0] fp32_to_bf16(input shortreal fp32);
        logic [31:0] fp32_bits;
        logic [15:0] bf16;
        fp32_bits = $shortrealtobits(fp32);
        bf16 = fp32_bits[31:16];
        // Mirror RTL conversion: round using fp32_bits[15] and saturate if already max.
        if (fp32_bits[15] && (bf16 != 16'hFFFF))
            bf16 = bf16 + 16'd1;
        return bf16;
    endfunction

    // --- GELU PWL reference (mirrors Stage1/gelu_pwl exactly) ---
    // gelu_pwl does:
    //   idx = bf16_LUT(x_bf16)
    //   (slope_bf16, intercept_bf16) = gelu_LUT(idx)
    //   slope_fp32  = {slope_bf16, 16'h0000}  (pad to FP32)
    //   intercept_fp32 = {intercept_bf16, 16'h0000}
    //   y_fp32 = slope_fp32 * x_fp32 + intercept_fp32
    //   y_bf16 = fp32_to_bf16(y_fp32) (same rounding rule as RTL)

    virtual function logic [4:0] bf16_to_gelu_index(input logic [15:0] data_in);
        logic sign;
        logic [4:0] idx;
        sign = data_in[15];
        idx   = 5'd0;
        if (sign) begin
            if      (data_in > 16'hC080) idx = 0;
            else if (data_in > 16'hC070) idx = 1;
            else if (data_in > 16'hC060) idx = 2;
            else if (data_in > 16'hC050) idx = 3;
            else if (data_in > 16'hC040) idx = 4;
            else if (data_in > 16'hC030) idx = 5;
            else if (data_in > 16'hC020) idx = 6;
            else if (data_in > 16'hC010) idx = 7;
            else if (data_in > 16'hC000) idx = 8;
            else if (data_in > 16'hBFE0) idx = 9;
            else if (data_in > 16'hBFC0) idx = 10;
            else if (data_in > 16'hBFA0) idx = 11;
            else if (data_in > 16'hBF80) idx = 12;
            else if (data_in > 16'hBF40) idx = 13;
            else if (data_in > 16'hBF00) idx = 14;
            else if (data_in > 16'hBE80) idx = 15;
            else                             idx = 16;
        end else begin
            if      (data_in > 16'h4080) idx = 17;
            else if (data_in > 16'h4070) idx = 18;
            else if (data_in > 16'h4060) idx = 19;
            else if (data_in > 16'h4050) idx = 20;
            else if (data_in > 16'h4040) idx = 21;
            else if (data_in > 16'h4030) idx = 22;
            else if (data_in > 16'h4020) idx = 23;
            else if (data_in > 16'h4010) idx = 24;
            else if (data_in > 16'h4000) idx = 25;
            else if (data_in > 16'h3FE0) idx = 26;
            else if (data_in > 16'h3FC0) idx = 27;
            else if (data_in > 16'h3FA0) idx = 28;
            else if (data_in > 16'h3F80) idx = 29;
            else if (data_in > 16'h3F40) idx = 30;
            else if (data_in > 16'h3F00) idx = 31;
            else if (data_in > 16'h3E80) idx = 32;
            else if (data_in > 16'h0000) idx = 33;
            else                             idx = 0;
        end
        return idx;
    endfunction

    virtual function void gelu_lut(input  logic [4:0] index_in,
                                    output logic [15:0] slope_out,
                                    output logic [15:0] intercept_out);
        slope_out     = 16'h0000;
        intercept_out = 16'h0000;
        case (index_in)
            0:  begin slope_out = 16'h0000; intercept_out = 16'h0000; end
            1:  begin slope_out = 16'hba56; intercept_out = 16'hbb5f; end
            2:  begin slope_out = 16'hbafd; intercept_out = 16'hbbf8; end
            3:  begin slope_out = 16'hbb8b; intercept_out = 16'hbc80; end
            4:  begin slope_out = 16'hbc0e; intercept_out = 16'hbcf6; end
            5:  begin slope_out = 16'hbc87; intercept_out = 16'hbd5c; end
            6:  begin slope_out = 16'hbcf0; intercept_out = 16'hbdb5; end
            7:  begin slope_out = 16'hbd44; intercept_out = 16'hbe0a; end
            8:  begin slope_out = 16'hbd93; intercept_out = 16'hbe42; end
            9:  begin slope_out = 16'hbdc9; intercept_out = 16'hbe78; end
            10: begin slope_out = 16'hbdf6; intercept_out = 16'hbe8f; end
            11: begin slope_out = 16'hbe02; intercept_out = 16'hbe95; end
            12: begin slope_out = 16'hbdd9; intercept_out = 16'hbe87; end
            13: begin slope_out = 16'hbd39; intercept_out = 16'hbe50; end
            14: begin slope_out = 16'h3d80; intercept_out = 16'hbdfb; end
            15: begin slope_out = 16'h3e5c; intercept_out = 16'hbd3d; end
            16: begin slope_out = 16'h3ecd; intercept_out = 16'h0000; end
            17: begin slope_out = 16'h3f80; intercept_out = 16'hbb5f; end
            18: begin slope_out = 16'h3f80; intercept_out = 16'hbb5f; end
            19: begin slope_out = 16'h3f80; intercept_out = 16'hbbf8; end
            20: begin slope_out = 16'h3f80; intercept_out = 16'hbc80; end
            21: begin slope_out = 16'h3f81; intercept_out = 16'hbcf6; end
            22: begin slope_out = 16'h3f82; intercept_out = 16'hbd5c; end
            23: begin slope_out = 16'h3f83; intercept_out = 16'hbdb5; end
            24: begin slope_out = 16'h3f86; intercept_out = 16'hbe0a; end
            25: begin slope_out = 16'h3f89; intercept_out = 16'hbe42; end
            26: begin slope_out = 16'h3f8c; intercept_out = 16'hbe78; end
            27: begin slope_out = 16'h3f8f; intercept_out = 16'hbe8f; end
            28: begin slope_out = 16'h3f90; intercept_out = 16'hbe95; end
            29: begin slope_out = 16'h3f8d; intercept_out = 16'hbe87; end
            30: begin slope_out = 16'h3f85; intercept_out = 16'hbe50; end
            31: begin slope_out = 16'h3f6f; intercept_out = 16'hbdfb; end
            32: begin slope_out = 16'h3f48; intercept_out = 16'hbd3d; end
            33: begin slope_out = 16'h3f19; intercept_out = 16'h0000; end
            default: begin slope_out = 16'h0000; intercept_out = 16'h0000; end
        endcase
    endfunction

    virtual function logic [15:0] gelu_pwl_bf16(input logic [15:0] x_bf16);
        logic [4:0]  idx;
        logic [15:0] slope_bf16, intercept_bf16;
        shortreal x_fp32;
        shortreal slope_fp32;
        shortreal intercept_fp32;
        shortreal y_fp32;
        begin
            idx = bf16_to_gelu_index(x_bf16);
            gelu_lut(idx, slope_bf16, intercept_bf16);
            x_fp32        = bf16_to_fp32(x_bf16);
            slope_fp32    = $bitstoshortreal({slope_bf16, 16'h0000});
            intercept_fp32= $bitstoshortreal({intercept_bf16, 16'h0000});
            y_fp32        = (slope_fp32 * x_fp32) + intercept_fp32;
            return fp32_to_bf16(y_fp32);
        end
    endfunction

    virtual function void predict(ffn_transaction tr);
        shortreal mac1_fp32;
        shortreal mac2_fp32;
        logic [15:0] mac1_bf16;
        logic [15:0] gelu_bf16;
        begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    // MAC1 output is BF16 (RTL trunc/rounds FP32 -> BF16)
                    mac1_fp32 = bf16_to_fp32(tr.w1[i][j]) * bf16_to_fp32(tr.x[i][j])
                              + bf16_to_fp32(tr.b1[i][j]);
                    mac1_bf16 = fp32_to_bf16(mac1_fp32);

                    // GELU operates on BF16 input and produces BF16 output
                    gelu_bf16 = gelu_pwl_bf16(mac1_bf16);

                    // MAC2 output is BF16
                    mac2_fp32 = bf16_to_fp32(tr.w2[i][j]) * bf16_to_fp32(gelu_bf16)
                              + bf16_to_fp32(tr.b2[i][j]);
                    tr.y_exp[i][j] = fp32_to_bf16(mac2_fp32);
                end
            end
        end
    endfunction

    virtual function void write(ffn_transaction t);
        ffn_transaction tr_out;
        tr_out = ffn_transaction::type_id::create("tr_out");
        tr_out.copy(t);
        predict(tr_out);
        out_port.write(tr_out);
    endfunction
endclass

`endif
