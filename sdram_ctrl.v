module sdram_ctrl(
    input clk_100MHz,
    input rst_n,
    // SDRAM Interface
    output reg [12:0] sdram_addr,
    output reg [1:0] sdram_ba,
    output reg sdram_cas_n,
    output reg sdram_cke,
    output reg sdram_cs_n,
    inout [15:0] sdram_dq,
    output reg sdram_ras_n,
    output reg sdram_we_n,
    // Control Interface
    input [23:0] addr,
    input wr_req,
    input [15:0] wr_data,
    input rd_req,
    output reg [15:0] rd_data,
    output reg rd_ready,
    output reg wr_done
);

// MT48LC4M16A2 Timing Parameters @100MHz
parameter tRP = 3'd3;    // 30ns (3 cycles)
parameter tRCD = 3'd3;   // 30ns
parameter tCAS = 3'd3;   // CAS Latency 3 (critical fix)
parameter tRAS = 3'd7;   // 70ns
parameter tREF = 12'd780; // 7.8µs refresh interval

// State Machine
localparam INIT=0, IDLE=1, ACTIVE=2, READ=3, WRITE=4, PRECHARGE=5, REFRESH=6;
reg [2:0] state;

// Counters
reg [3:0] init_cnt;
reg [2:0] cas_counter;
reg [11:0] refresh_counter;

// Tri-state buffer
reg [15:0] sdram_dq_out;
reg sdram_dq_oe;

assign sdram_dq = sdram_dq_oe ? sdram_dq_out : 16'bz;

always @(posedge clk_100MHz or negedge rst_n) begin
    if(!rst_n) begin
        state <= INIT;
        init_cnt <= 0;
        refresh_counter <= 0;
        {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b1111;
        sdram_cke <= 1'b1;
        sdram_dq_oe <= 1'b0;
        rd_ready <= 0;
        wr_done <= 0;
    end else begin
        case(state)
            INIT: begin
                if(init_cnt < 15) init_cnt <= init_cnt + 1;
                case(init_cnt)
                    0: {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0111; // Precharge
                    2,4,6,8: {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0011; // 4x Refresh
                    10: begin
                        sdram_addr <= 13'b0000_0010_0011; // Burst=1, CL=3
                        {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0000; // Load Mode Reg
                    end
                    12: state <= IDLE;
                endcase
            end
            
            IDLE: begin
                refresh_counter <= (refresh_counter < tREF) ? refresh_counter + 1 : 0;
                if(refresh_counter == tREF) state <= REFRESH;
                else if(wr_req) begin
                    sdram_addr <= addr[21:9];
                    sdram_ba <= addr[23:22];
                    {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0011; // ACTIVE
                    state <= ACTIVE;
                end
                else if(rd_req) begin
                    sdram_addr <= addr[21:9];
                    sdram_ba <= addr[23:22];
                    {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0011; // ACTIVE
                    state <= ACTIVE;
                end
            end
            
            ACTIVE: begin
                if(wr_req) begin
                    sdram_addr <= {3'b000, addr[8:0]};
                    sdram_dq_out <= wr_data;
                    sdram_dq_oe <= 1'b1;
                    {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0100; // WRITE
                    state <= WRITE;
                end else begin
                    sdram_addr <= {3'b000, addr[8:0]};
                    {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0101; // READ
                    cas_counter <= 0;
                    state <= READ;
                end
            end
            
            READ: begin
                if(cas_counter < tCAS) cas_counter <= cas_counter + 1;
                else begin
                    rd_data <= sdram_dq;
                    rd_ready <= 1'b1;
                    {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0111; // PRECHARGE
                    state <= PRECHARGE;
                end
            end
            
            WRITE: begin
                wr_done <= 1'b1;
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0111; // PRECHARGE
                state <= PRECHARGE;
            end
            
            PRECHARGE: begin
                rd_ready <= 0;
                wr_done <= 0;
                sdram_dq_oe <= 0;
                state <= IDLE;
            end
            
            REFRESH: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0011;
                state <= IDLE;
            end
        endcase
    end
end
endmodule
