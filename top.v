module top(
    input CLOCK_50,
    input [3:0] KEY,
    // SDRAM Interface
    output [12:0] DRAM_ADDR,
    output [1:0] DRAM_BA,
    output DRAM_CAS_N,
    output DRAM_CKE,
    output DRAM_CS_N,
    inout [15:0] DRAM_DQ,
    output DRAM_RAS_N,
    output DRAM_WE_N,
    // UART Interface
    input FPGA_UART_RX,
    output FPGA_UART_TX
);

wire clk_100MHz;
wire locked;

wire [7:0] uart_rx_data;
wire uart_rx_valid;
uart_rx u_rx(
    .clk(CLOCK_50),
    .rst_n(KEY[0]),
    .rx(FPGA_UART_RX),
    .data(uart_rx_data),
    .data_valid(uart_rx_valid)
);

wire [23:0] sdram_addr;
wire [15:0] sdram_wr_data;
wire wr_req;
wire rd_req;
wire wr_done;
wire rd_ready;
wire [15:0] sdram_rd_data;

sdram_ctrl controller(
    .clk_100MHz(clk_100MHz),
    .rst_n(KEY[0] & locked),
    .sdram_addr(DRAM_ADDR),
    .sdram_ba(DRAM_BA),
    .sdram_cas_n(DRAM_CAS_N),
    .sdram_cke(DRAM_CKE),
    .sdram_cs_n(DRAM_CS_N),
    .sdram_dq(DRAM_DQ),
    .sdram_ras_n(DRAM_RAS_N),
    .sdram_we_n(DRAM_WE_N),
    .addr(sdram_addr),
    .wr_req(wr_req),
    .wr_data(sdram_wr_data),
    .rd_req(rd_req),
    .rd_data(sdram_rd_data),
    .rd_ready(rd_ready),
    .wr_done(wr_done)
);

// Command Processor
reg [23:0] cmd_addr;
reg [15:0] cmd_data;
reg cmd_wr;
reg cmd_rd;

always @(posedge CLOCK_50) begin
    if(uart_rx_valid) begin
        // Add your command decoding logic here
        // Example: Parse "W000000A55A" commands
    end
end

uart_tx u_tx(
    .clk(CLOCK_50),
    .rst_n(KEY[0]),
    .data(sdram_rd_data[7:0]),
    .send(rd_ready),
    .tx(FPGA_UART_TX),
    .busy()
);

endmodule
