module uart_tx(
    input clk,
    input rst_n,
    input [7:0] data,
    input send,
    output reg tx,
    output reg busy
);
parameter CLK_FREQ = 50_000_000;
parameter BAUD_RATE = 57600;
localparam BAUD_TICK = CLK_FREQ/(BAUD_RATE*16);

reg [15:0] baud_counter;
reg [3:0] bit_index;
reg [9:0] tx_shift;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx <= 1'b1;
        busy <= 0;
    end else begin
        if (busy) begin
            if (baud_counter == BAUD_TICK-1) begin
                baud_counter <= 0;
                if (bit_index == 9) begin
                    busy <= 0;
                    tx <= 1'b1;
                end else begin
                    tx <= tx_shift[bit_index];
                    bit_index <= bit_index + 1;
                end
            end else begin
                baud_counter <= baud_counter + 1;
            end
        end else if (send) begin
            tx_shift <= {1'b1, data, 1'b0};
            busy <= 1;
            bit_index <= 0;
            baud_counter <= 0;
        end
    end
end
endmodule
