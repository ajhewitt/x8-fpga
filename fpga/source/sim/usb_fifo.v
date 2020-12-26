module usb_fifo(
    input  wire       rst_i,
    input  wire       wr_clk_i,
    input  wire [7:0] wr_data_i,
    input  wire       wr_en_i,
    output wire       full_o,

    input  wire       rp_rst_i,
    input  wire       rd_clk_i,
    output reg  [7:0] rd_data_o,
    input  wire       rd_en_i,
    output wire       empty_o);

    reg [8:0] wridx_r = 0;
    reg [8:0] rdidx_r = 0;

    reg [7:0] mem_r [511:0];

    wire [8:0] wridx_next = wridx_r + 9'd1;
    wire [8:0] rdidx_next = rdidx_r + 9'd1;
    wire [8:0] fifo_count = wridx_r - rdidx_r;

    assign empty_o = (wridx_r == rdidx_r);
    assign full_o  = (wridx_next == rdidx_r);

    always @(posedge wr_clk_i or posedge rst_i) begin
        if (rst_i) begin
            wridx_r <= 0;

        end else begin
            if (wr_en_i && !full_o) begin
                mem_r[wridx_r] <= wr_data_i;
                wridx_r <= wridx_next;
            end
        end
    end

    always @(posedge rd_clk_i or rp_rst_i) begin
        if (rp_rst_i) begin
            rdidx_r <= 0;
            rd_data_o <= 0;

        end else begin
            if (rd_en_i && !empty_o) begin
                rd_data_o <= mem_r[rdidx_r];
                rdidx_r <= rdidx_next;
            end
        end
    end

endmodule
