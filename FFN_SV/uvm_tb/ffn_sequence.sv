`ifndef FFN_SEQUENCE_SV
`define FFN_SEQUENCE_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"

class ffn_sequence extends uvm_sequence #(ffn_transaction);
    `uvm_object_utils(ffn_sequence)

    rand int num_transactions = 200;

    constraint reasonable_num { num_transactions inside {[1:2000]}; }

    function new(string name = "ffn_sequence");
        super.new(name);
    endfunction

    virtual task send_directed_case(
        input logic [15:0] w1v,
        input logic [15:0] w2v,
        input logic [15:0] b1v,
        input logic [15:0] b2v,
        input logic [15:0] xv
    );
        req = ffn_transaction::type_id::create("req");
        start_item(req);
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

    virtual task body();
        // Directed corners for code coverage:
        // zero paths, sign paths, tiny values, large normals, and inf encodings.
        send_directed_case(16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000); // all-zero
        send_directed_case(16'h3F80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // +1 nominal
        send_directed_case(16'hBF80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // negative multiply
        send_directed_case(16'h3F80, 16'hBF80, 16'h0000, 16'h0000, 16'hBF80); // negative x path
        send_directed_case(16'h7F7F, 16'h3F80, 16'h0000, 16'h0000, 16'h7F7F); // large finite
        send_directed_case(16'h0001, 16'h0001, 16'h0000, 16'h0000, 16'h0001); // denorm-like tiny
        send_directed_case(16'h7F80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // +INF branch
        send_directed_case(16'hFF80, 16'h3F80, 16'h0000, 16'h0000, 16'h3F80); // -INF branch

        // Random traffic for broader branch/toggle coverage.
        for (int i = 0; i < num_transactions; i++) begin
            req = ffn_transaction::type_id::create($sformatf("rand_req_%0d", i));
            start_item(req);
            if (!req.randomize()) begin
                `uvm_error("SEQ", $sformatf("Randomization failed at txn %0d", i))
            end
            finish_item(req);
        end
    endtask
endclass

`endif
