// `default_nettype none
module fifo_512x8(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] wrdata,
    input  wire       wr_en,

    output reg  [7:0] rddata,
    input  wire       rd_en,
    
    output wire       empty,
    output wire       full);

    reg [8:0] wridx, rdidx;
    reg [7:0] mem_r [511:0];

    wire [8:0] wridx_next = wridx + 9'd1;
    wire [8:0] rdidx_next = rdidx + 9'd1;

    assign empty = (wridx == rdidx);
    assign full  = (wridx_next == rdidx);

    wire do_write = wr_en & !full;
    wire do_read  = rd_en & !empty;

    always @(posedge clk) if (do_write) mem_r[wridx] <= wrdata;
    always @(posedge clk) rddata <= mem_r[rdidx];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wridx <= 9'd0;
            rdidx <= 9'd0;

        end else begin
            if (do_write) wridx <= wridx_next;
            if (do_read)  rdidx <= rdidx_next;
        end
    end

endmodule
