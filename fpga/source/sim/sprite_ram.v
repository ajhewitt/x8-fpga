// `default_nettype none

module sprite_ram(
    input  wire        wr_clk_i,
    input  wire        rd_clk_i,
    input  wire        rst_i,
    input  wire        wr_clk_en_i,
    input  wire        rd_en_i,
    input  wire        rd_clk_en_i,
    input  wire        wr_en_i,
    input  wire  [4:0] ben_i,
    input  wire [39:0] wr_data_i,
    input  wire  [4:0] wr_addr_i,
    input  wire  [4:0] rd_addr_i,
    output reg  [39:0] rd_data_o);

    reg [39:0] mem[0:31];

    always @(posedge wr_clk_i) begin
        if (wr_en_i) begin
            if (ben_i[4]) mem[wr_addr_i][39:32] <= wr_data_i[39:32];
            if (ben_i[3]) mem[wr_addr_i][31:24] <= wr_data_i[31:24];
            if (ben_i[2]) mem[wr_addr_i][23:16] <= wr_data_i[23:16];
            if (ben_i[1]) mem[wr_addr_i][15:8]  <= wr_data_i[15:8];
            if (ben_i[0]) mem[wr_addr_i][7:0]   <= wr_data_i[7:0];
        end
    end

    always @(posedge rd_clk_i) begin
        rd_data_o <= mem[rd_addr_i];
    end

    initial begin: INIT
        integer i;
        for (i=0; i<32; i=i+1) begin
            mem[i] = 0;
        end

        mem[1][15] = 1;
        mem[1][25:16] = 'd123;
        mem[1][14] = 1;

        mem[1][12] = 1;

    end

endmodule
