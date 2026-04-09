module uart_rx #(parameter CLKS_PER_BIT = 86)(
    input i_clock,
    input i_rst_n,
    input i_Rx_serial,
    output o_Rx_DV,
    output [7:0] o_Rx_byte
);
    localparam s_IDLE = 3'b000;
    localparam s_RX_START_BIT = 3'b001;
    localparam s_RX_DATA_BITS = 3'b010;
    localparam s_RX_STOP_BIT = 3'b011;
    localparam s_CLEAN_UP = 3'b100;

    reg r_Rx_DATA_p;
    reg r_Rx_Data;

    reg [7:0] r_Clock_Count;
    reg [2:0] r_Bit_Index;
    reg [7:0] r_Rx_Byte;
    reg r_Rx_DV;
    reg [2:0] r_SM_Main;

    always @(posedge i_clock or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_Rx_DATA_p <= 1'b1;
            r_Rx_Data   <= 1'b1;
        end else begin
            r_Rx_DATA_p <= i_Rx_serial;
            r_Rx_Data   <= r_Rx_DATA_p;
        end
    end

    always @(posedge i_clock or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_SM_Main     <= s_IDLE;
            r_Rx_DV       <= 1'b0;
            r_Clock_Count <= 8'd0;
            r_Bit_Index   <= 3'd0;
            r_Rx_Byte     <= 8'd0;
        end else begin
            case(r_SM_Main)
                s_IDLE:
                    begin
                        r_Rx_DV <= 1'b0;
                        r_Clock_Count <= 0;
                        r_Bit_Index <= 0;

                    if(r_Rx_Data == 1'b0)
                        r_SM_Main <= s_RX_START_BIT;
                    else
                        r_SM_Main <= s_IDLE;
                    end
                s_RX_START_BIT:
                    begin
                        if(r_Clock_Count == (CLKS_PER_BIT - 1)/2)begin
                            if(r_Rx_Data == 1'b0)begin
                                r_Clock_Count <= 0;
                                r_SM_Main <= s_RX_DATA_BITS;
                            end
                            else begin
                                r_SM_Main <= s_IDLE;
                            end
                        end else begin
                            r_Clock_Count <= 1 + r_Clock_Count;
                            r_SM_Main <= s_RX_START_BIT;
                        end
                    end
                s_RX_DATA_BITS:
                    begin
                        if(r_Clock_Count < CLKS_PER_BIT)begin
                            r_SM_Main <= s_RX_DATA_BITS;
                            r_Clock_Count <= 1 + r_Clock_Count;
                        end
                        else begin
                            r_Clock_Count <= 0;
                            r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;

                            if(r_Bit_Index < 7)begin
                                r_Bit_Index <= r_Bit_Index +1;
                                r_SM_Main <= s_RX_DATA_BITS;
                            end
                            else begin
                                r_Bit_Index <= 0;
                                r_SM_Main <= s_RX_STOP_BIT;
                            end
                        end
                    end
                s_RX_STOP_BIT:
                    begin
                        if(r_Clock_Count < CLKS_PER_BIT)begin
                            r_Clock_Count <= r_Clock_Count + 1;
                            r_SM_Main <= s_RX_STOP_BIT;
                        end
                        else begin
                            r_Rx_DV <= 1'b1;
                            r_Clock_Count <= 0;
                            r_SM_Main <= s_CLEAN_UP;
                        end
                    end
                s_CLEAN_UP:
                    begin
                        r_SM_Main <= s_IDLE;
                        r_Rx_DV <= 1'b0;
                    end
                default:
                    r_SM_Main <= s_IDLE;

            endcase
        end
    end
    assign o_Rx_DV = r_Rx_DV;
    assign o_Rx_byte = r_Rx_Byte;
endmodule