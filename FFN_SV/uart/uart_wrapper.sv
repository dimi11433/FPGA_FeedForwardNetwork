module uart_wrapper(
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_in,
    input logic rx,
    output logic tx,
   
);

    //so we get a byte and we want to concatenate it to get 16 bits
    //we need to do that for W1, W2, b1, b2 and x
    //then once all done we send it to the top level as a packet

    //in total we need to get  16 bytes to get the whole packet
    parameter IDLE = 3'b000, RECEIVE_W1 = 3'b001, RECEIVE_W2 = 3'b010, RECEIVE_B1 = 3'b011, RECEIVE_B2 = 3'b100, RECEIVE_X = 3'b101, PACKET_DONE = 3'b110;

    logic [15:0] w1 [0:N-1];
    logic [15:0] w1_2 [0:N-1];
    logic [15:0] w2 [0:N-1];
    logic [15:0] w2_2 [0:N-1];
    logic [15:0] b1 [0:N-1];
    logic [15:0] b2 [0:N-1];
    logic [15:0] x [0:N-1];
    logic [15:0] x_2 [0:N-1];

    logic [2:0] curr_state, next_state;
    logic byte_count;
    logic [1:0] index_count;



    always_comb begin
        case(curr_state)
            IDLE: begin
                if(rx)begin
                    next_state = RECEIVE_W1;
                end
            end
            RECEIVE_W1: begin
                if(rx)begin
                    if(index_count == 0)begin
                        if(byte_count == 1'b0)begin
                            w1[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            w1[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end 
                    else if(index_count == 1)begin
                        if(byte_count == 1'b0)begin
                            w1_2[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            w1_2[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end
                    else begin
                        next_state = RECEIVE_W2;
                    end                     
                end
            end
            RECEIVE_W2: begin
                if(rx)begin
                    if(index_count == 0)begin
                        if(byte_count == 1'b0)begin
                            w2[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            w2[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end 
                    else if(index_count == 1)begin
                        if(byte_count == 1'b0)begin
                            w2_2[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            w2_2[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end
                    else begin
                        next_state = RECEIVE_X;
                    end                     
                end
            end 
            RECEIVE_X: begin
                if(rx)begin
                    if(index_count == 0)begin
                        if(byte_count == 1'b0)begin
                            x[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            x[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end 
                    else if(index_count == 1)begin
                        if(byte_count == 1'b0)begin
                            x_2[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            x_2[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end
                    else begin
                        next_state = RECEIVE_B1;
                    end                     
                end
            end
            RECEIVE_B1: begin
                if(rx)begin
                    if(index_count == 0)begin
                        if(byte_count == 1'b0)begin
                            b1[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            b1[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end 
                    else begin
                        next_state = RECEIVE_B2;
                    end                     
                end
            end
            RECEIVE_B2: begin
                if(rx)begin
                    if(index_count == 0)begin
                        if(byte_count == 1'b0)begin
                            b2[index_count][7:0] = data_in;
                            byte_count = ~byte_count;
                        end
                        else begin
                            b2[index_count][15:8] = data_in;
                            byte_count = ~byte_count;
                        end
                    end 
                    else begin
                        next_state = RECEIVE_DONE;
                    end                     
                end
            end
            RECEIVE_DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            curr_state <= IDLE;
            tx <= 0;
            byte_count <= 0;
            index_count <= 0;
            w1 <= 0;
            w1_2 <= 0;
            w2 <= 0;
            w2_2 <= 0;
            b1 <= 0;
            b2 <= 0;
            x <= 0;
            x_2 <= 0;
        end
        else begin
            
            curr_state <= next_state;
        end
    end 

endmodule