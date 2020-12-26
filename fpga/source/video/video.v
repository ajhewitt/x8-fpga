// `default_nettype none
module video(
    input  wire        rst,
    input  wire        clk,

    // Video registers
    input  wire  [1:0] bg_mode,
    input  wire        bg_en,
    input  wire        bg_pal,
    input  wire        sprites_en,
    input  wire  [7:0] irq_line,
    input  wire  [9:0] x_scroll,
    input  wire  [9:0] y_scroll,

    // Interrupt outputs
    output wire        vblank_irq_pulse,
    output wire        line_irq_pulse,

    // Video RAM interface
    input  wire [15:0] vram_addr,
    input  wire  [7:0] vram_wrdata,
    output reg   [7:0] vram_rddata,
    input  wire        vram_strobe,
    input  wire        vram_write,

    // Sprite attributes
    input  wire  [7:0] spr_wraddr,
    input  wire  [7:0] spr_wrdata,
    input  wire        spr_write,

    // Palette interface
    input  wire  [5:0] pal_wraddr,
    input  wire  [7:0] pal_wrdata,
    input  wire        pal_write,

    // VGA interface
    input  wire        vga_rst,
    input  wire        vga_clk,

    output wire  [3:0] vga_r,
    output wire  [3:0] vga_g,
    output wire  [3:0] vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync);

    wire [31:0] membus_rddata;

    //////////////////////////////////////////////////////////////////////////
    // Line renderer
    //////////////////////////////////////////////////////////////////////////
    wire  [4:0] sprite_idx;
    wire [39:0] sprite_attr;

    wire  [9:0] render_wridx;
    wire  [4:0] render_wrdata;
    wire        render_write;
    wire  [7:0] render_line;
    wire        render_start;
    wire        render_hdouble;

    wire [13:0] renderer_bus_addr;
    wire        renderer_bus_strobe;
    reg         renderer_bus_ack_r, renderer_bus_ack_next;

    line_renderer line_renderer(
        .rst(rst),
        .clk(clk),

        .line_irq_pulse(line_irq_pulse),

        // Register interface
        .bg_mode(bg_mode),
        .bg_en(bg_en),
        .bg_pal(bg_pal),
        .sprites_en(sprites_en),
        .irq_line(irq_line),
        .x_scroll(x_scroll),
        .y_scroll(y_scroll),

        // Sprite attributes interface
        .sprite_idx(sprite_idx),
        .sprite_attr(sprite_attr),

        // Display interface
        .render_wridx(render_wridx),
        .render_wrdata(render_wrdata),
        .render_write(render_write),

        .render_line(render_line),
        .render_start(render_start),
        .render_hdouble(render_hdouble),

        // VRAM interface
        .bus_addr(renderer_bus_addr),
        .bus_strobe(renderer_bus_strobe),
        .bus_rddata(membus_rddata),
        .bus_ack(renderer_bus_ack_r));

    //////////////////////////////////////////////////////////////////////////
    // Video RAM
    //////////////////////////////////////////////////////////////////////////
    reg [3:0] membus_bytesel;
    always @* case (vram_addr[1:0])
        2'b00: membus_bytesel = 4'b0001;
        2'b01: membus_bytesel = 4'b0010;
        2'b10: membus_bytesel = 4'b0100;
        2'b11: membus_bytesel = 4'b1000;
    endcase

    reg  [13:0] membus_addr;
    reg         membus_write;
    video_ram video_ram(
        .clk(clk),
        .bus_addr(membus_addr),
        .bus_wrdata({4{vram_wrdata}}),
        .bus_wrbytesel(membus_bytesel),
        .bus_rddata(membus_rddata),
        .bus_write(membus_write));

    always @* begin
        membus_addr           = 14'b0;
        membus_write          = 1'b0;
        renderer_bus_ack_next = 1'b0;

        if (vram_strobe) begin
            membus_addr        = vram_addr[15:2];
            membus_write       = vram_write;

        end else if (renderer_bus_strobe) begin
            membus_addr           = renderer_bus_addr;
            renderer_bus_ack_next = 1'b1;
        end
    end

    always @(posedge clk) renderer_bus_ack_r <= renderer_bus_ack_next;

    reg [1:0] vram_addr_r;
    always @(posedge(clk)) vram_addr_r <= vram_addr[1:0];

    always @* case (vram_addr_r[1:0])
        2'b00: vram_rddata = membus_rddata[7:0];
        2'b01: vram_rddata = membus_rddata[15:8];
        2'b10: vram_rddata = membus_rddata[23:16];
        2'b11: vram_rddata = membus_rddata[31:24];
    endcase

    //////////////////////////////////////////////////////////////////////////
    // Sprite attribute RAM
    //////////////////////////////////////////////////////////////////////////
    reg [4:0] spr_bytesel;
    always @* begin
        spr_bytesel = 5'b0;
        case (spr_wraddr[7:5])
            3'd0: spr_bytesel = 5'b00001;
            3'd1: spr_bytesel = 5'b00010;
            3'd2: spr_bytesel = 5'b00100;
            3'd3: spr_bytesel = 5'b01000;
            3'd4: spr_bytesel = 5'b10000;
        endcase
    end

    sprite_ram sprite_ram(
        .rst_i(1'b0),

        .wr_clk_i(clk),
        .wr_clk_en_i(1'b1),
        .wr_en_i(spr_write),
        .wr_addr_i(spr_wraddr[4:0]),
        .ben_i(spr_bytesel),
        .wr_data_i({5{spr_wrdata}}),

        .rd_clk_i(clk),
        .rd_clk_en_i(1'b1),
        .rd_en_i(1'b1),
        .rd_addr_i(sprite_idx),
        .rd_data_o(sprite_attr));

    //////////////////////////////////////////////////////////////////////////
    // VGA display output
    //////////////////////////////////////////////////////////////////////////
    wire vblank_pulse;
    assign vblank_irq_pulse = vblank_pulse;

    wire [1:0] pal_bytesel = pal_wraddr[0] ? 2'b10 : 2'b01;

    video_vga video_vga(
        // Render interface
        .render_rst(rst),
        .render_clk(clk),

        .render_wridx(render_wridx),
        .render_wrdata(render_wrdata),
        .render_write(render_write),

        .render_line(render_line),
        .render_start(render_start),
        .render_hdouble(render_hdouble),

        .vblank_pulse(vblank_pulse),

        // Palette interface
        .palette_clk(clk),
        .palette_wridx(pal_wraddr[5:1]),
        .palette_wrdata({2{pal_wrdata}}),
        .palette_bytesel(pal_bytesel),
        .palette_write(pal_write),

        // VGA interface
        .vga_rst(vga_rst),
        .vga_clk(vga_clk),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync));

endmodule
