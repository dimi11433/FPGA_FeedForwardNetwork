module uart_wrapper #(
    parameter int N = 2  // matrix/vector dimension (2 for 2x2 FFN)
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  data_in,   // byte from uart_rx
    input  logic        rx,        // strobe: high for one cycle when data_in is valid
    output logic [15:0] W1 [0:N-1][0:N-1],
    output logic [15:0] W2 [0:N-1][0:N-1],
    output logic [15:0] X  [0:N-1],          // 2x1 column vector
    output logic [15:0] b1 [0:N-1],
    output logic [15:0] b2 [0:N-1],
    output logic        ready,                // one-cycle strobe: full frame received
    output logic [2:0]  dbg_state             // FSM state for debug
);

   
    // Fixed order: W1 → W2 → X → b1 → b2
    // Total bytes: (N*N + N*N + N + N + N) * 2 = 28 bytes for N=2
    

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        RECEIVE_W1  = 3'b001,
        RECEIVE_W2  = 3'b010,
        RECEIVE_X   = 3'b011,
        RECEIVE_B1  = 3'b100,
        RECEIVE_B2  = 3'b101,
        PACKET_DONE = 3'b110
    } state_t;

    // internal storage
    logic [15:0] w1_r [0:N-1][0:N-1];
    logic [15:0] w2_r [0:N-1][0:N-1];
    logic [15:0] x_r  [0:N-1];
    logic [15:0] b1_r [0:N-1];
    logic [15:0] b2_r [0:N-1];

    // drive outputs directly from internal arrays
    assign W1 = w1_r;
    assign W2 = w2_r;
    assign X  = x_r;
    assign b1 = b1_r;
    assign b2 = b2_r;

    // counters
    localparam int IDX_W = $clog2(N+1);  // safe for all N

    state_t              curr_state;
    assign dbg_state = curr_state;
    logic                byte_sel;              // 0 = low byte, 1 = high byte
    logic [IDX_W-1:0]    col_count;
    logic [IDX_W-1:0]    row_count;
    logic [7:0]          low_byte;              // holds [7:0] while waiting for [15:8]

   
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            byte_sel   <= 1'b0;
            col_count  <= '0;
            row_count  <= '0;
            low_byte   <= '0;
            ready      <= 1'b0;
            // zero all storage
            for (int r = 0; r < N; r++) begin
                for (int c = 0; c < N; c++) begin
                    w1_r[r][c] <= '0;
                    w2_r[r][c] <= '0;
                end
                x_r [r] <= '0;
                b1_r[r] <= '0;
                b2_r[r] <= '0;
            end
        end
        else begin
            ready <= 1'b0;  // default: deassert every cycle

            case (curr_state)

                
                IDLE: begin
                    if (rx) begin
                        // first byte of frame has arrived — start assembling W1
                        low_byte   <= data_in;
                        byte_sel   <= 1'b1;   // next byte completes first BF16
                        col_count  <= '0;
                        row_count  <= '0;
                        curr_state <= RECEIVE_W1;
                    end
                end

                
                RECEIVE_W1: begin
                    if (rx) begin
                        if (byte_sel == 1'b0) begin
                            low_byte <= data_in;
                            byte_sel <= 1'b1;
                        end
                        else begin
                            w1_r[row_count][col_count] <= {data_in, low_byte};
                            byte_sel <= 1'b0;
                            // advance col → row → next state
                            if (col_count == N-1) begin
                                col_count <= '0;
                                if (row_count == N-1) begin
                                    row_count  <= '0;
                                    curr_state <= RECEIVE_W2;
                                end
                                else begin
                                    row_count <= row_count + 1'b1;
                                end
                            end
                            else begin
                                col_count <= col_count + 1'b1;
                            end
                        end
                    end
                end

                
                RECEIVE_W2: begin
                    if (rx) begin
                        if (byte_sel == 1'b0) begin
                            low_byte <= data_in;
                            byte_sel <= 1'b1;
                        end
                        else begin
                            w2_r[row_count][col_count] <= {data_in, low_byte};
                            byte_sel <= 1'b0;
                            if (col_count == N-1) begin
                                col_count <= '0;
                                if (row_count == N-1) begin
                                    row_count  <= '0;
                                    curr_state <= RECEIVE_X;
                                end
                                else begin
                                    row_count <= row_count + 1'b1;
                                end
                            end
                            else begin
                                col_count <= col_count + 1'b1;
                            end
                        end
                    end
                end

                RECEIVE_X: begin
                    if (rx) begin
                        if (byte_sel == 1'b0) begin
                            low_byte <= data_in;
                            byte_sel <= 1'b1;
                        end
                        else begin
                            x_r[col_count] <= {data_in, low_byte};
                            byte_sel <= 1'b0;
                            if (col_count == N-1) begin
                                col_count  <= '0;
                                curr_state <= RECEIVE_B1;
                            end
                            else begin
                                col_count <= col_count + 1'b1;
                            end
                        end
                    end
                end

               
                RECEIVE_B1: begin
                    if (rx) begin
                        if (byte_sel == 1'b0) begin
                            low_byte <= data_in;
                            byte_sel <= 1'b1;
                        end
                        else begin
                            b1_r[col_count] <= {data_in, low_byte};
                            byte_sel <= 1'b0;
                            if (col_count == N-1) begin
                                col_count  <= '0;
                                curr_state <= RECEIVE_B2;
                            end
                            else begin
                                col_count <= col_count + 1'b1;
                            end
                        end
                    end
                end

                
                RECEIVE_B2: begin
                    if (rx) begin
                        if (byte_sel == 1'b0) begin
                            low_byte <= data_in;
                            byte_sel <= 1'b1;
                        end
                        else begin
                            b2_r[col_count] <= {data_in, low_byte};
                            byte_sel <= 1'b0;
                            if (col_count == N-1) begin
                                col_count  <= '0;
                                curr_state <= PACKET_DONE;
                            end
                            else begin
                                col_count <= col_count + 1'b1;
                            end
                        end
                    end
                end

        
                PACKET_DONE: begin
                    ready      <= 1'b1;   // one-cycle strobe to FFN
                    curr_state <= IDLE;
                end

                default: curr_state <= IDLE;

            endcase
        end
    end

endmodule