// `default_nettype none
module palette_ram(
    input  wire        wr_clk_i,
    input  wire        rd_clk_i,
    input  wire        rst_i,
    input  wire        wr_clk_en_i,
    input  wire        rd_en_i,
    input  wire        rd_clk_en_i,
    input  wire        wr_en_i,
    input  wire  [1:0] ben_i,
    input  wire [15:0] wr_data_i,
    input  wire  [4:0] wr_addr_i,
    input  wire  [4:0] rd_addr_i,
    output reg  [15:0] rd_data_o);

    reg [15:0] mem[0:31];

    always @(posedge wr_clk_i) begin
        if (wr_en_i) begin
            if (ben_i[1]) mem[wr_addr_i][15:8] <= wr_data_i[15:8];
            if (ben_i[0]) mem[wr_addr_i][7:0]  <= wr_data_i[7:0];
        end
    end

    always @(posedge rd_clk_i) begin
        rd_data_o <= mem[rd_addr_i];
    end

    initial begin: INIT
        mem[0] = 16'h000;
        mem[1] = 16'h125;
        mem[2] = 16'h725;
        mem[3] = 16'h085;
        mem[4] = 16'hA53;
        mem[5] = 16'h555;
        mem[6] = 16'hCCC;
        mem[7] = 16'hFFF;
        mem[8] = 16'hF04;
        mem[9] = 16'hFA0;
        mem[10] = 16'hFE3;
        mem[11] = 16'h0E3;
        mem[12] = 16'h3AF;
        mem[13] = 16'h879;
        mem[14] = 16'hF7A;
        mem[15] = 16'hFCA;
    end

endmodule
