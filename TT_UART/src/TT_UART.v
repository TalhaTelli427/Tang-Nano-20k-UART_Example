module uart #(
    parameter wait_clk_time=235
) (
    input obsr,
    input Button,
    input clk,
    input i_rx,
    output reg [5:0] o_reg=255,
    output o_Tx
     
);

localparam HALF_DELAY_WAIT = (wait_clk_time / 2);

localparam IDLE_T = 5'b00001;
localparam START_T = 5'b00010;
localparam Data_T = 5'b01000;
localparam Stop_T = 5'b10000;
localparam Tx_Debounce = 5'b00100;

localparam IDLE            = 5'b00001;
localparam START           = 5'b00010;
localparam GET_BIT         = 5'b00100;
localparam WAIT_NEXT_BIT   = 5'b01000;
localparam STOP            = 5'b10000;

reg rx_buffer = 1'b1;
reg rx        = 1'b1;

reg [4:0] state = IDLE;
reg [15:0] counter = 0;
reg Data_Avail = 0;
reg [7:0] Rx_byte = 0;
reg [3:0] bit_index = 0;




reg D_ready=0;
reg [4:0] Tx_State = IDLE_T;
reg [7:0] Tx_Data_Buffer[5:0];
reg [32:0] clk_counter = 0;
reg Tx = 1;
reg [2:0] Bit_counter = 0;
reg O_Data_t = 0;
reg [2:0] byte_counter = 0;

initial begin
    Tx_Data_Buffer[0] = "D";
    Tx_Data_Buffer[1] = "A";
    Tx_Data_Buffer[2] = "L";
    Tx_Data_Buffer[3] = "H";
    Tx_Data_Buffer[4] = "A";
    Tx_Data_Buffer[5] = "\n";
end




always @(posedge clk) begin
    rx_buffer <= i_rx;
    rx <= rx_buffer;
end

always @(posedge clk) begin
    case (state)
        IDLE: begin
            if (rx == 0) begin
                state <= START;
                counter <= 1;
                Data_Avail <= 0;
                bit_index <= 0;
            end
        end

        START: begin
            if (counter == HALF_DELAY_WAIT ) begin
                if (rx == 0) begin
                    state <= GET_BIT;
                    counter <= 1;
                end else begin
                    state <= IDLE;
                end
            end else begin
                counter <= counter + 1;
            end
        end

        WAIT_NEXT_BIT: begin
            if (counter < wait_clk_time ) begin
                counter <= counter + 1;
            end else begin
                counter <= 1;
                state <= GET_BIT;
            end
        end

        GET_BIT: begin
            Rx_byte <= {rx, Rx_byte[7:1]};
            bit_index <= bit_index + 1;
            if (bit_index > 7) begin
                state <= STOP;
                bit_index<=0;
            end else begin
                state <= WAIT_NEXT_BIT;
            end
        end

        STOP: begin
            if (counter < wait_clk_time ) begin
                counter <= counter + 1;
            end else begin
                Data_Avail <= 1;
                state <= IDLE;
                counter <= 0;
            end
        end
        default:
            state<=IDLE;
    endcase
end

// Output the received byte when available
always @(posedge clk) begin
    if (Data_Avail) begin
        o_reg <= ~Rx_byte[5:0];
    end
end






always @(posedge clk) begin
    case (Tx_State)
        IDLE_T: begin
            if (Button == 1) begin
                clk_counter = 0;
                Bit_counter = 0;
                byte_counter = 0; 
                Tx_State <= START_T;
            end else begin
                Tx <= 1;
            end
        end
        START_T: begin
            Tx <= 0;
            if (clk_counter == wait_clk_time - 1) begin
                Tx_State <= Data_T;
                clk_counter = 0;
                Bit_counter = 0;
            end else begin
                clk_counter = clk_counter + 1;
            end
        end
        Data_T: begin
            Tx <= Tx_Data_Buffer[byte_counter][Bit_counter];
            if (clk_counter == wait_clk_time - 1) begin
                clk_counter <= 0;
                if (Bit_counter == 3'b111) begin
                    Tx_State <= Stop_T;
                end else begin
                    Bit_counter <= Bit_counter + 1;
                    Tx_State <= Data_T;
                end
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
        Stop_T: begin
            Tx <= 1;
            if (clk_counter == wait_clk_time - 1) begin
                clk_counter <= 0;
                O_Data_t <= 1;
                if (O_Data_t) begin
                    if (byte_counter == 3'd5) begin
                        byte_counter <= 0;
                        Tx_State <= Tx_Debounce;
                    end else begin
                        byte_counter <= byte_counter + 1; 
                        Tx_State <= START_T;
                    end
                end
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
        Tx_Debounce: begin
            if (clk_counter == 16777215) begin
                if (Button == 0) begin
                    Tx_State <= IDLE_T;
                    clk_counter <= 0;
                end
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    endcase
end

assign o_Tx = Tx;

endmodule