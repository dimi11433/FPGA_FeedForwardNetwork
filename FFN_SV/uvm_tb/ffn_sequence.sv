`ifndef FFN_SEQUENCE_SV
`define FFN_SEQUENCE_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"

class ffn_sequence extends uvm_sequence #(ffn_transaction);
    `uvm_object_utils(ffn_sequence)

    rand int num_transactions = 500;

    constraint reasonable_num { num_transactions inside {[1:5000]}; }

    function new(string name = "ffn_sequence");
        super.new(name);
    endfunction

    // --- Helper: broadcast one scalar value to all fields ---
    virtual task send_uniform(
        input logic [15:0] w1v,
        input logic [15:0] w2v,
        input logic [15:0] b1v,
        input logic [15:0] b2v,
        input logic [15:0] xv
    );
        req = ffn_transaction::type_id::create("req");
        start_item(req);
        req.valid_bf16.constraint_mode(0);
        req.gelu_active_region.constraint_mode(0);
        for (int i = 0; i < req.N; i++) begin
            for (int j = 0; j < req.N; j++) begin
                req.w1[i][j] = w1v;
                req.w2[i][j] = w2v;
            end
            req.b1[i] = b1v;
            req.b2[i] = b2v;
            req.x[i]  = xv;
        end
        finish_item(req);
    endtask

    // --- Helper: identity W1/W2 with per-element x, zero biases ---
    // mac1_out[i] = x[i], gelu input = x[i], mac2_out[i] = gelu(x[i])
    virtual task send_gelu_target(
        input logic [15:0] x0,
        input logic [15:0] x1
    );
        req = ffn_transaction::type_id::create("req");
        start_item(req);
        req.valid_bf16.constraint_mode(0);
        req.gelu_active_region.constraint_mode(0);
        for (int i = 0; i < req.N; i++)
            for (int j = 0; j < req.N; j++) begin
                req.w1[i][j] = (i == j) ? 16'h3F80 : 16'h0000;
                req.w2[i][j] = (i == j) ? 16'h3F80 : 16'h0000;
            end
        for (int i = 0; i < req.N; i++) begin
            req.b1[i] = 16'h0000;
            req.b2[i] = 16'h0000;
        end
        req.x[0] = x0;
        req.x[1] = x1;
        finish_item(req);
    endtask

    // --- Helper: fully specified per-element transaction ---
    virtual task send_full(
        input logic [15:0] w1_00, input logic [15:0] w1_01,
        input logic [15:0] w1_10, input logic [15:0] w1_11,
        input logic [15:0] w2_00, input logic [15:0] w2_01,
        input logic [15:0] w2_10, input logic [15:0] w2_11,
        input logic [15:0] b1_0,  input logic [15:0] b1_1,
        input logic [15:0] b2_0,  input logic [15:0] b2_1,
        input logic [15:0] x_0,   input logic [15:0] x_1
    );
        req = ffn_transaction::type_id::create("req");
        start_item(req);
        req.valid_bf16.constraint_mode(0);
        req.gelu_active_region.constraint_mode(0);
        req.w1[0][0] = w1_00; req.w1[0][1] = w1_01;
        req.w1[1][0] = w1_10; req.w1[1][1] = w1_11;
        req.w2[0][0] = w2_00; req.w2[0][1] = w2_01;
        req.w2[1][0] = w2_10; req.w2[1][1] = w2_11;
        req.b1[0] = b1_0; req.b1[1] = b1_1;
        req.b2[0] = b2_0; req.b2[1] = b2_1;
        req.x[0] = x_0;   req.x[1] = x_1;
        finish_item(req);
    endtask

    virtual task body();

        // =============================================================
        // Phase 1: Basic directed corners
        // =============================================================
        `uvm_info("SEQ", "Phase 1: Basic directed corners", UVM_LOW)

        send_uniform(16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000); // all-zero
        send_uniform(16'h3F80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // +1.0 nominal
        send_uniform(16'hBF80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // neg w1 path
        send_uniform(16'h3F80, 16'hBF80, 16'h0000, 16'h0000, 16'hBF80); // neg x path
        send_uniform(16'h7F7F, 16'h3F80, 16'h0000, 16'h0000, 16'h7F7F); // large finite
        send_uniform(16'h0001, 16'h0001, 16'h0000, 16'h0000, 16'h0001); // denorm-like tiny
        send_uniform(16'h7F80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // +INF w1
        send_uniform(16'hFF80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // -INF w1
        send_uniform(16'h3F80, 16'h3F80, 16'h3F80, 16'h3F80, 16'h3F80); // bias=+1 path
        send_uniform(16'h3F80, 16'h3F80, 16'hBF80, 16'hBF80, 16'h3F80); // negative bias
        send_uniform(16'hBF80, 16'hBF80, 16'hBF80, 16'hBF80, 16'hBF80); // all negative

        // Mixed-sign patterns to toggle sign bits across all paths
        send_full(16'h3F80, 16'hBF80, 16'hBF80, 16'h3F80,
                  16'h3F80, 16'hBF80, 16'hBF80, 16'h3F80,
                  16'h0000, 16'h0000, 16'h0000, 16'h0000,
                  16'h3F80, 16'hBF80);
        send_full(16'hBF80, 16'h3F80, 16'h3F80, 16'hBF80,
                  16'hBF80, 16'h3F80, 16'h3F80, 16'hBF80,
                  16'h3F80, 16'hBF80, 16'hBF80, 16'h3F80,
                  16'hBF80, 16'h3F80);

        // =============================================================
        // Phase 2: Hit every GELU LUT segment (indices 0–33)
        // W1=I, W2=I, b=0 so mac1_out = x → direct GELU control
        // =============================================================
        `uvm_info("SEQ", "Phase 2: GELU LUT sweep (all 34 segments)", UVM_LOW)

        // bf16 representative values landing in each GELU segment.
        // Negative side: idx 0-16
        send_gelu_target(16'hC0A0, 16'hC0A0); // idx 0 : < -4.0 (x=-5.0)
        send_gelu_target(16'hC078, 16'hC078); // idx 1 : -3.875
        send_gelu_target(16'hC068, 16'hC068); // idx 2 : -3.625
        send_gelu_target(16'hC058, 16'hC058); // idx 3 : -3.375
        send_gelu_target(16'hC048, 16'hC048); // idx 4 : -3.125
        send_gelu_target(16'hC038, 16'hC038); // idx 5 : -2.875
        send_gelu_target(16'hC028, 16'hC028); // idx 6 : -2.625
        send_gelu_target(16'hC018, 16'hC018); // idx 7 : -2.375
        send_gelu_target(16'hC008, 16'hC008); // idx 8 : -2.125
        send_gelu_target(16'hBFF0, 16'hBFF0); // idx 9 : -1.875
        send_gelu_target(16'hBFD0, 16'hBFD0); // idx 10: -1.625
        send_gelu_target(16'hBFB0, 16'hBFB0); // idx 11: -1.375
        send_gelu_target(16'hBF90, 16'hBF90); // idx 12: -1.125
        send_gelu_target(16'hBF60, 16'hBF60); // idx 13: -0.875
        send_gelu_target(16'hBF20, 16'hBF20); // idx 14: -0.625
        send_gelu_target(16'hBEC0, 16'hBEC0); // idx 15: -0.375
        send_gelu_target(16'hBE00, 16'hBE00); // idx 16: -0.125

        // Positive side: idx 17-33
        send_gelu_target(16'h40A0, 16'h40A0); // idx 17: > +4.0 (x=+5.0)
        send_gelu_target(16'h4078, 16'h4078); // idx 18: +3.875
        send_gelu_target(16'h4068, 16'h4068); // idx 19: +3.625
        send_gelu_target(16'h4058, 16'h4058); // idx 20: +3.375
        send_gelu_target(16'h4048, 16'h4048); // idx 21: +3.125
        send_gelu_target(16'h4038, 16'h4038); // idx 22: +2.875
        send_gelu_target(16'h4028, 16'h4028); // idx 23: +2.625
        send_gelu_target(16'h4018, 16'h4018); // idx 24: +2.375
        send_gelu_target(16'h4008, 16'h4008); // idx 25: +2.125
        send_gelu_target(16'h3FF0, 16'h3FF0); // idx 26: +1.875
        send_gelu_target(16'h3FD0, 16'h3FD0); // idx 27: +1.625
        send_gelu_target(16'h3FB0, 16'h3FB0); // idx 28: +1.375
        send_gelu_target(16'h3F90, 16'h3F90); // idx 29: +1.125
        send_gelu_target(16'h3F60, 16'h3F60); // idx 30: +0.875
        send_gelu_target(16'h3F20, 16'h3F20); // idx 31: +0.625
        send_gelu_target(16'h3EC0, 16'h3EC0); // idx 32: +0.375
        send_gelu_target(16'h3E00, 16'h3E00); // idx 33: +0.125

        // Cross: lane 0 negative, lane 1 positive (and vice versa)
        send_gelu_target(16'hC048, 16'h4048); // idx 4 vs idx 21
        send_gelu_target(16'h3F90, 16'hBF90); // idx 29 vs idx 12
        send_gelu_target(16'hBE00, 16'h40A0); // idx 16 vs idx 17
        send_gelu_target(16'h0000, 16'h3F80); // idx 0(zero) vs idx 29

        // =============================================================
        // Phase 3: fp32_add / fp32_mul arithmetic edge cases
        // =============================================================
        `uvm_info("SEQ", "Phase 3: FP32 arithmetic edge cases", UVM_LOW)

        // Cancellation: w1*x ≈ -b1 → near-zero mac1 output
        send_full(16'h3F80, 16'h0000, 16'h0000, 16'h3F80,
                  16'h3F80, 16'h0000, 16'h0000, 16'h3F80,
                  16'hBF80, 16'hBF80, 16'h0000, 16'h0000,
                  16'h3F80, 16'h3F80); // w*x = +1, b1 = -1 → mac1 = 0

        // Rounding stress: values near bf16 truncation boundary
        send_uniform(16'h3F01, 16'h3F01, 16'h3F01, 16'h3F01, 16'h3F01);
        send_uniform(16'h3EFF, 16'h3EFF, 16'h3EFF, 16'h3EFF, 16'h3EFF);

        // Large-magnitude products (overflow stress in fp32_mul)
        send_uniform(16'h4F00, 16'h4F00, 16'h0000, 16'h0000, 16'h4F00);

        // Tiny * tiny (underflow in fp32_mul)
        send_uniform(16'h0080, 16'h0080, 16'h0000, 16'h0000, 16'h0080);

        // Alternating bit patterns for toggle coverage
        send_uniform(16'h5555, 16'h5555, 16'h5555, 16'h5555, 16'h5555);
        send_uniform(16'hAAAA, 16'hAAAA, 16'hAAAA, 16'hAAAA, 16'hAAAA);
        send_uniform(16'hFF00, 16'h00FF, 16'hF0F0, 16'h0F0F, 16'hCCCC);
        send_uniform(16'h00FF, 16'hFF00, 16'h0F0F, 16'hF0F0, 16'h3333);

        // Powers of two (exercise different exponents and mantissa shifts)
        send_gelu_target(16'h4000, 16'h3C00); // +2.0, +0.015625
        send_gelu_target(16'h4200, 16'h3A00); // +3.0, +0.00097
        send_gelu_target(16'h3D00, 16'h4100); // +0.03125, +2.5

        // =============================================================
        // Phase 4: Constrained random (GELU-active region bias)
        // =============================================================
        `uvm_info("SEQ", $sformatf("Phase 4: %0d constrained random transactions", num_transactions/2), UVM_LOW)

        for (int i = 0; i < num_transactions/2; i++) begin
            req = ffn_transaction::type_id::create($sformatf("gelu_rand_%0d", i));
            start_item(req);
            if (!req.randomize()) begin
                `uvm_error("SEQ", $sformatf("Randomization failed at txn %0d", i))
            end
            finish_item(req);
        end

        // =============================================================
        // Phase 5: Unconstrained random (full bf16 range)
        // =============================================================
        `uvm_info("SEQ", $sformatf("Phase 5: %0d unconstrained random transactions", num_transactions - num_transactions/2), UVM_LOW)

        for (int i = num_transactions/2; i < num_transactions; i++) begin
            req = ffn_transaction::type_id::create($sformatf("full_rand_%0d", i));
            start_item(req);
            req.gelu_active_region.constraint_mode(0);
            if (!req.randomize()) begin
                `uvm_error("SEQ", $sformatf("Randomization failed at txn %0d", i))
            end
            finish_item(req);
        end

    endtask
endclass

`endif
