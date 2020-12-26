module video_vga(
    // Render interface
    input  wire        render_rst,
    input  wire        render_clk,

    input  wire  [9:0] render_wridx,
    input  wire  [4:0] render_wrdata,
    input  wire        render_write,

    output reg   [7:0] render_line,
    output wire        render_start,
    input  wire        render_hdouble,

    output wire        vblank_pulse,

    // Palette interface
    input  wire        palette_clk,
    input  wire  [4:0] palette_wridx,
    input  wire [15:0] palette_wrdata,
    input  wire  [1:0] palette_bytesel,
    input  wire        palette_write,

    // VGA interface
    input  wire        vga_rst,
    input  wire        vga_clk,

    output reg   [3:0] vga_r,
    output reg   [3:0] vga_g,
    output reg   [3:0] vga_b,
    output reg         vga_hsync,
    output reg         vga_vsync);

    //////////////////////////////////////////////////////////////////////////
    // Line buffer
    //////////////////////////////////////////////////////////////////////////
    reg        display_buf_r;
    wire [9:0] lb_rdidx;
    wire [4:0] lb_rddata;

    dpram #(.ADDR_WIDTH(11), .DATA_WIDTH(5)) linebuf(
        .wr_clk(render_clk),
        .wr_addr({!display_buf_r, render_wridx}),
        .wr_data(render_wrdata),
        .wr_en(render_write),

        .rd_clk(vga_clk),
        .rd_addr({display_buf_r, lb_rdidx}),
        .rd_data(lb_rddata));

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] pal_rddata;

    palette_ram palette_ram(
        .rst_i(1'b0),

        .wr_clk_i(palette_clk),
        .wr_clk_en_i(1'b1),
        .wr_en_i(palette_write),
        .wr_addr_i(palette_wridx),
        .ben_i(palette_bytesel),
        .wr_data_i(palette_wrdata),

        .rd_clk_i(vga_clk),
        .rd_clk_en_i(1'b1),
        .rd_en_i(1'b1),
        .rd_addr_i(lb_rddata),
        .rd_data_o(pal_rddata));

    //////////////////////////////////////////////////////////////////////////
    // Video timing (640x480@60Hz)
    //////////////////////////////////////////////////////////////////////////
    parameter H_ACTIVE      = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC        = 96;
    parameter H_BACK_PORCH  = 48;
    parameter H_TOTAL       = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;

    parameter V_ACTIVE      = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC        = 2;
    parameter V_BACK_PORCH  = 33;
    parameter V_TOTAL       = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    //////////////////////////////////////////////////////////////////////////
    // Video timing generator
    //////////////////////////////////////////////////////////////////////////
    reg [9:0] x_counter;
    reg [9:0] y_counter;
    reg hdouble_r;

    wire h_last = (x_counter == H_TOTAL - 1);
    wire v_last = (y_counter == V_TOTAL - 1);
    
    always @(posedge vga_clk or posedge vga_rst) begin
        if (vga_rst) begin
`ifdef __ICARUS__
            x_counter <= 10'd500;
            y_counter <= 10'd522;
`else
            x_counter <= 10'd0;
            y_counter <= 10'd0;
`endif
        end else begin
            x_counter <= h_last ? 10'd0 : (x_counter + 10'd1);
            if (h_last)
                y_counter <= v_last ? 10'd0 : (y_counter + 10'd1);
        end
    end

    wire hsync    = (x_counter >= H_ACTIVE + H_FRONT_PORCH && x_counter < H_ACTIVE + H_FRONT_PORCH + H_SYNC);
    wire vsync    = (y_counter >= V_ACTIVE + V_FRONT_PORCH && y_counter < V_ACTIVE + V_FRONT_PORCH + V_SYNC);
    wire h_active = (x_counter < H_ACTIVE);
    wire v_active = (y_counter < V_ACTIVE);
    wire active   = h_active && v_active;

    wire vga_vblank_pulse = h_last && (y_counter == V_ACTIVE - 1);
    pulse2pulse p2p_sof(.in_clk(vga_clk), .in_pulse(vga_vblank_pulse), .out_clk(render_clk), .out_pulse(vblank_pulse));

    // Compensate pipeline delays
    reg [1:0] hsync_r, vsync_r, active_r;
    always @(posedge vga_clk) hsync_r  <= {hsync_r[0], hsync};
    always @(posedge vga_clk) vsync_r  <= {vsync_r[0], vsync};
    always @(posedge vga_clk) active_r <= {active_r[0], active};

    always @(posedge vga_clk or posedge vga_rst) begin
        if (vga_rst) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
            vga_hsync <= 0;
            vga_vsync <= 0;

        end else begin
            if (active_r[1]) begin
                vga_r <= pal_rddata[11:8];
                vga_g <= pal_rddata[7:4];
                vga_b <= pal_rddata[3:0];
            end else begin
                vga_r <= 4'd0;
                vga_g <= 4'd0;
                vga_b <= 4'd0;
            end

            vga_hsync <= hsync_r[1];
            vga_vsync <= vsync_r[1];
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Generate render signals
    //////////////////////////////////////////////////////////////////////////
    reg render_start_vga;
    always @(posedge vga_clk or posedge vga_rst) begin
        if (vga_rst) begin
            render_line      <= 8'd0;
            render_start_vga <= 0;
            hdouble_r        <= 0;
            display_buf_r    <= 1'b0;

        end else begin
            render_start_vga <= 0;

            if (h_last) begin
                if (y_counter == V_TOTAL - 3) begin
                    display_buf_r    <= 1'b0;
                    render_start_vga <= 1;
                    render_line      <= 8'd0;

                end else if ((v_active && y_counter[0]) || y_counter == V_TOTAL - 1) begin
                    display_buf_r    <= !display_buf_r;
                    hdouble_r        <= render_hdouble;
                    render_start_vga <= 1;
                    render_line      <= render_line + 8'd1;
                end
            end
        end
    end

    assign lb_rdidx = hdouble_r ? {1'b0, x_counter[9:1]} : x_counter;

    pulse2pulse p2p_render_start(.in_clk(vga_clk), .in_pulse(render_start_vga), .out_clk(render_clk), .out_pulse(render_start));

endmodule
