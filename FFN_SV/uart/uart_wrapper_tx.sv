module uart_tx_serializer #(
    parameter int N = 2  // output vector length (2x1 for 2x2 FFN)
)(
    input  logic        clk,
    input  logic        rst_n,

    // from FFN core
    input  wire [15:0] result [0:N-1],  // BF16 output vector
    input  logic        ffn_done,        // one-cycle strobe from FFN

    // to uart_tx
    output logic [7:0]  tx_byte,
    output logic        tx_dv,           // data valid strobe to uart_tx
    input  logic        tx_done,         // one-cycle strobe from uart_tx: byte sent

    // status
    output logic        tx_busy          // high while frame is transmitting
);

    
    // For N=2: 2 BF16 values × 2 bytes = 4 bytes total
    // Send order: result[0][7:0] → result[0][15:8] → result[1][7:0] → result[1][15:8]
    

    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        LOAD      = 2'b01,   // pulse tx_dv with next byte
        WAIT      = 2'b10    // wait for uart_tx to finish current byte
    } state_t;

    localparam int IDX_W = $clog2(N+1);

    state_t           curr_state;
    logic [IDX_W-1:0] vec_index;    // which BF16 value we are sending
    logic             byte_sel;     // 0 = low byte [7:0], 1 = high byte [15:8]

    // latch result on ffn_done so it doesn't change mid-transmission
    logic [15:0] result_r [0:N-1];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            vec_index  <= '0;
            byte_sel   <= 1'b0;
            tx_dv      <= 1'b0;
            tx_byte    <= '0;
            tx_busy    <= 1'b0;
            for (int i = 0; i < N; i++)
                result_r[i] <= '0;
        end
        else begin
            tx_dv <= 1'b0;  // default: deassert every cycle

            case (curr_state)

               
                IDLE: begin
                    tx_busy   <= 1'b0;
                    vec_index <= '0;
                    byte_sel  <= 1'b0;
                    if (ffn_done) begin
                        result_r   <= result;   // latch entire output vector
                        tx_busy    <= 1'b1;
                        curr_state <= LOAD;
                    end
                end

                
                // Put the next byte on tx_byte and pulse tx_dv for one cycle
                
                LOAD: begin
                    tx_byte <= (byte_sel == 1'b0)
                                ? result_r[vec_index][7:0]
                                : result_r[vec_index][15:8];
                    tx_dv      <= 1'b1;
                    curr_state <= WAIT;
                end

                
                // Hold until uart_tx signals the byte is fully sent
                
                WAIT: begin
                    if (tx_done) begin
                        if (byte_sel == 1'b0) begin
                            // low byte done → send high byte of same value
                            byte_sel   <= 1'b1;
                            curr_state <= LOAD;
                        end
                        else begin
                            // high byte done → move to next BF16 value
                            byte_sel <= 1'b0;
                            if (vec_index == N-1) begin
                                // all values sent
                                curr_state <= IDLE;
                            end
                            else begin
                                vec_index  <= vec_index + 1'b1;
                                curr_state <= LOAD;
                            end
                        end
                    end
                end

                default: curr_state <= IDLE;

            endcase
        end
    end

endmodule