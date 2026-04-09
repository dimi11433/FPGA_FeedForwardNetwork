module uart_tx #(parameter CLKS_PER_BIT = 86)(
    input i_Clock,
    input i_rst_n,
    input i_Tx_DV,
    input [7:0] i_Tx_Byte,
    output o_Tx_Active,
    output reg o_Tx_Bit,
    output o_Tx_Done
);

    localparam s_IDLE = 3'b000;
    localparam s_TX_START_BIT = 3'b001;
    localparam s_TX_DATA_BITS = 3'b010;
    localparam s_TX_STOP_BIT = 3'b011;
    localparam s_CLEAN_UP = 3'b100;

    reg [7:0]   r_Clock_Count;
    reg [2:0]   r_Bit_Index;
    reg [7:0]   r_Tx_Data;
    reg [2:0]   r_SM_Main;
    reg         r_Tx_Done;
    reg         r_Tx_Active;

    always @(posedge i_Clock or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_SM_Main     <= s_IDLE;
            o_Tx_Bit      <= 1'b1;
            r_Clock_Count <= 8'd0;
            r_Bit_Index   <= 3'd0;
            r_Tx_Data     <= 8'd0;
            r_Tx_Done     <= 1'b0;
            r_Tx_Active   <= 1'b0;
        end else begin
            case(r_SM_Main)
                s_IDLE:
                    begin
                        o_Tx_Bit <= 1'b1;
                        r_Bit_Index <= 0;
                        r_Clock_Count <= 0;
                        r_Tx_Done <= 1'b0;
                        if(i_Tx_DV == 1'b1)begin
                            r_Tx_Data <= i_Tx_Byte;
                            r_Tx_Active <= 1;
                            r_SM_Main <= s_TX_START_BIT;
                        end
                        else begin
                            r_SM_Main <= s_IDLE;
                        end
                    end
                s_TX_START_BIT:
                    begin
                        o_Tx_Bit <= 1'b0;

                        if(r_Clock_Count < CLKS_PER_BIT -1)begin
                            r_Clock_Count <= r_Clock_Count + 1;
                            r_SM_Main <= s_TX_START_BIT;
                        end
                        else begin
                            r_SM_Main <= s_TX_DATA_BITS;
                            r_Clock_Count <= 0;
                        end
                    end
                s_TX_DATA_BITS:
                    begin
                        o_Tx_Bit <= r_Tx_Data[r_Bit_Index];

                        if(r_Clock_Count < CLKS_PER_BIT - 1)begin
                            r_Clock_Count <= r_Clock_Count + 1;
                            r_SM_Main <= s_TX_DATA_BITS;
                        end
                        else begin
                            r_Clock_Count <= 0;
                            if(r_Bit_Index < 7)begin
                                r_Bit_Index <= r_Bit_Index + 1;
                                r_SM_Main <= s_TX_DATA_BITS;
                            end
                            else begin
                                r_SM_Main <= s_TX_STOP_BIT;
                                r_Bit_Index <= 0;
                            end
                        end
                    end
                s_TX_STOP_BIT:
                    begin
                        o_Tx_Bit <= 1'b1;
                        if(r_Clock_Count < CLKS_PER_BIT - 1)begin
                            r_Clock_Count <= r_Clock_Count + 1;
                            r_SM_Main <= s_TX_STOP_BIT;
                        end
                        else begin
                            r_Tx_Active <= 1'b0;
                            r_Tx_Done <= 1'b1;
                            r_Clock_Count <= 0;
                            r_SM_Main <= s_CLEAN_UP;
                        end
                    end
                s_CLEAN_UP:
                    begin
                        r_SM_Main <= s_IDLE;
                        r_Tx_Done <= 1'b1;
                    end
                default:
                    r_SM_Main <= s_IDLE;
            endcase
        end
    end
    assign o_Tx_Active = r_Tx_Active;
    assign o_Tx_Done = r_Tx_Done;

endmodule