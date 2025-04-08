module uart_rx(
    input clk,
    input rst_n,
    input rx,
    output reg [7:0] data,
    output reg data_valid
);
parameter CLK_FREQ = 50_000_000;
parameter BAUD_RATE = 57600;
localparam BAUD_TICK = CLK_FREQ/(BAUD_RATE*16);

reg [15:0] baud_counter;
reg [3:0] bit_index;
reg rx_busy;
reg [1:0] rx_sync;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_valid <= 0;
        rx_busy <= 0;
        baud_counter <= 0;
        bit_index <= 0;
        rx_sync <= 2'b11;
    end else begin
        data_valid <= 0;
        rx_sync <= {rx_sync[0], rx};
        
        if (rx_busy) begin
            if (baud_counter == BAUD_TICK-1) begin
                baud_counter <= 0;
                if (bit_index == 8) begin
                    rx_busy <= 0;
                    data_valid <= 1;
                end else begin
                    data[bit_index] <= rx_sync[1];
                    bit_index <= bit_index + 1;
                end
            end else begin
                baud_counter <= baud_counter + 1;
            end
        end else if (!rx_sync[1] && rx_sync[0]) begin // Start bit detection
            rx_busy <= 1;
            bit_index <= 0;
            baud_counter <= BAUD_TICK/2;
        end
    end
end
endmodule
