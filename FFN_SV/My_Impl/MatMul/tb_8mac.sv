module tb_8mac;

    // Parameters
    localparam int N = 8;

    // DUT interface signals
    logic clk;
    logic rst_n;

    logic [15:0] data_in_a [0:N-1];
    logic [15:0] data_in_b [0:N-1];
    logic [15:0] data_in_c [0:N-1];

    logic        ready    [0:N-1];
    logic [15:0] data_out [0:N-1];

    // DUT instantiation
    8mac #(.N(N)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .data_in_a (data_in_a),
        .data_in_b (data_in_b),
        .data_in_c (data_in_c),
        .ready     (ready),
        .data_out  (data_out)
    );

    // Clock generation: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin : stimulus
        int vec;
        int i;

        $dumpfile("tb_8mac.vcd");
        $dumpvars(0, tb_8mac);

        // Reset
        rst_n = 1'b0;
        // Initialize inputs
        for (i = 0; i < N; i++) begin
            data_in_a[i] = '0;
            data_in_b[i] = '0;
            data_in_c[i] = '0;
        end

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // Apply multiple randomized vectors
        for (vec = 0; vec < 10; vec++) begin
            // Randomize inputs for all MAC lanes
            for (i = 0; i < N; i++) begin
                data_in_a[i] = $urandom;
                data_in_b[i] = $urandom;
                data_in_c[i] = $urandom;
            end

            $display("Time %0t: Applied vector %0d", $time, vec);
            for (i = 0; i < N; i++) begin
                $display("  lane %0d: a=%0d b=%0d c=%0d", i,
                         data_in_a[i], data_in_b[i], data_in_c[i]);
            end

            // Hold the inputs long enough for the 8-cycle MAC + add stage
            repeat (12) @(posedge clk);

            // Display outputs and ready flags
            $display("Time %0t: Observing outputs for vector %0d", $time, vec);
            for (i = 0; i < N; i++) begin
                $display("  lane %0d: ready=%0b data_out=%0d (0x%0h)",
                         i, ready[i], data_out[i], data_out[i]);
            end
        end

        $display("Simulation finished.");
        $finish;
    end

endmodule

