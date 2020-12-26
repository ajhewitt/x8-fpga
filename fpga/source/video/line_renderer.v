module line_renderer(
    input  wire        rst,
    input  wire        clk,

    output wire        line_irq_pulse,

    // Register interface
    input  wire  [1:0] bg_mode,
    input  wire        bg_en,
    input  wire        bg_pal,
    input  wire        sprites_en,
    input  wire  [7:0] irq_line,
    input  wire  [9:0] x_scroll,
    input  wire  [9:0] y_scroll,

    // Sprite attributes interface
    output wire  [4:0] sprite_idx,
    input  wire [39:0] sprite_attr,

    // Display interface
    output wire  [9:0] render_wridx,
    output reg   [4:0] render_wrdata,
    output reg         render_write,

    input  wire  [7:0] render_line,
    input  wire        render_start,
    output wire        render_hdouble,

    // VRAM interface
    output wire [13:0] bus_addr,
    output wire        bus_strobe,
    input  wire [31:0] bus_rddata,
    input  wire        bus_ack);

    // Z-buffer:
    //                 z-value
    // bg color 0  ->  0
    // bg normal   ->  1
    // bg priority ->  2
    //
    // sprite color 0            -> do nothing
    // sprite normal, z-value <2 -> write color, z-value=1
    // sprite priority           -> write color, z-value=2

    // Background modes:
    // 0: text mode 80x30     (640x240)
    // 1: text mode 40x30     (320x240)
    // 2: tile mode 128x128   (320x240)
    // 3: bitmap mode 512x256 (320x240)

    reg   [3:0] state_r,        state_next;
    reg   [1:0] bg_mode_r,      bg_mode_next;
    reg         bg_en_r,        bg_en_next;
    reg         bg_pal_r,       bg_pal_next;
    reg         sprites_en_r,   sprites_en_next;
    reg   [9:0] xpos_r,         xpos_next;
    reg   [9:0] ypos_r,         ypos_next;
    reg  [15:0] map_data_r,     map_data_next;
    reg  [31:0] pat_data_r,     pat_data_next;
    reg   [6:0] tile_count_r,   tile_count_next;

    reg   [4:0] sprite_idx_r,   sprite_idx_next;

    reg  [13:0] bus_addr_r,     bus_addr_next;
    reg         bus_strobe_r,   bus_strobe_next;

    assign render_hdouble = (bg_mode_r != 2'b0);

    // Tile map attributes
    wire [9:0] map_pattern_idx   = (bg_mode_r == 2'd2) ? map_data_r[9:0] : {2'b0, map_data_r[7:0]};
    wire [3:0] map_text_fg_color = map_data_r[11:8];
    wire [3:0] map_text_bg_color = map_data_r[15:12];
    wire       map_hflip         = (bg_mode_r == 2'd2) ? map_data_r[10] : 1'b0;
    wire       map_vflip         = (bg_mode_r == 2'd2) ? map_data_r[11] : 1'b0;
    wire       map_priority      = (bg_mode_r == 2'd2) ? map_data_r[12] : 1'b0;
    wire       map_palette       = (bg_mode_r == 2'd2) ? (map_data_r[13] ^ bg_pal_r) : bg_pal_r;

    // Sprite attributes
    wire [7:0] spr_y             = sprite_attr[39:32];
    wire [9:0] spr_x             = sprite_attr[25:16];
    wire       spr_enable        = sprite_attr[15];
    wire       spr_size          = sprite_attr[14];
    wire       spr_palette       = sprite_attr[13];
    wire       spr_priority      = sprite_attr[12];
    wire       spr_vflip         = sprite_attr[11];
    wire       spr_hflip         = sprite_attr[10];

    // Decode sprite height
    wire [3:0] sprite_height_pixels = spr_size ? 4'd15 : 4'd7;

    // Determine if sprite is on current line
    wire [7:0] ydiff          = render_line - spr_y;
    wire       sprite_on_line = ydiff <= {4'b0, sprite_height_pixels};
    wire [3:0] sprite_line    = spr_vflip ? (sprite_height_pixels - ydiff[3:0]) : ydiff[3:0];

    wire [9:0] spr_pattern_idx = spr_size ? {sprite_attr[9:2], sprite_line[3], spr_hflip} : sprite_attr[9:0];

    reg [31:0] rast_data_r,     rast_data_next;
    reg        rast_pal_r,      rast_pal_next;
    reg        rast_sprite_r,   rast_sprite_next;
    reg        rast_priority_r, rast_priority_next;
    reg  [9:0] rast_pos_r,      rast_pos_next;
    reg        rast_start_r,    rast_start_next;
    reg        rast_busy;


    assign bus_addr   = bus_addr_next;
    assign bus_strobe = bus_strobe_next;

    assign sprite_idx = sprite_idx_next;

    reg [13:0] bg_pat_addr;
    always @* begin
        case (bg_mode_r)
            2'd0, 2'd1:  bg_pat_addr = {1'b1, 2'b0, map_pattern_idx, ypos_r[2]};
            2'd2:        bg_pat_addr = {1'b1, map_pattern_idx, map_vflip ? ~ypos_r[2:0] : ypos_r[2:0]};
            2'd3:        bg_pat_addr = {ypos_r[7:0], xpos_r[8:3]};
        endcase
    end

    wire [13:0] spr_pat_addr = {1'b1, spr_pattern_idx, sprite_line[2:0]};


    reg [7:0] font_data;
    always @* begin
        case (ypos_r[1:0])
            2'd0: font_data = pat_data_r[7:0];
            2'd1: font_data = pat_data_r[15:8];
            2'd2: font_data = pat_data_r[23:16];
            2'd3: font_data = pat_data_r[31:24];
        endcase
    end

    wire [31:0] pat_data_hflipped = {pat_data_r[3:0], pat_data_r[7:4], pat_data_r[11:8], pat_data_r[15:12], pat_data_r[19:16], pat_data_r[23:20], pat_data_r[27:24], pat_data_r[31:28]};

    reg [31:0] rast_data;
    always @* begin
        rast_data = 32'b0;

        if (bg_en_r) begin
            case (bg_mode_r)
                2'd0, 2'd1: begin
                    rast_data[7:4]   = font_data[7] ? map_text_fg_color : map_text_bg_color;
                    rast_data[3:0]   = font_data[6] ? map_text_fg_color : map_text_bg_color;
                    rast_data[15:12] = font_data[5] ? map_text_fg_color : map_text_bg_color;
                    rast_data[11:8]  = font_data[4] ? map_text_fg_color : map_text_bg_color;
                    rast_data[23:20] = font_data[3] ? map_text_fg_color : map_text_bg_color;
                    rast_data[19:16] = font_data[2] ? map_text_fg_color : map_text_bg_color;
                    rast_data[31:28] = font_data[1] ? map_text_fg_color : map_text_bg_color;
                    rast_data[27:24] = font_data[0] ? map_text_fg_color : map_text_bg_color;
                end

                2'd2: rast_data = map_hflip ? pat_data_hflipped : pat_data_r;
                2'd3: rast_data = pat_data_r;
            endcase
        end
    end

    parameter
        WAIT_START   = 4'd0,
        BG_MAP       = 4'd1,
        BG_MAP_WAIT  = 4'd2,
        BG_PAT       = 4'd3,
        BG_PAT_WAIT  = 4'd4,
        BG_RENDER    = 4'd5,
        SPR_FIND     = 4'd6,
        SPR_PAT_WAIT = 4'd7,
        SPR_RENDER   = 4'd8;

    always @* begin
        state_next         = state_r;
        bg_mode_next       = bg_mode_r;
        bg_en_next         = bg_en_r;
        bg_pal_next        = bg_pal_r;
        sprites_en_next    = sprites_en_r;
        xpos_next          = xpos_r;
        ypos_next          = ypos_r;
        map_data_next      = map_data_r;
        pat_data_next      = pat_data_r;
        tile_count_next    = tile_count_r;
        sprite_idx_next    = sprite_idx_r;

        bus_addr_next      = bus_addr_r;
        bus_strobe_next    = 1'b0;

        rast_data_next     = rast_data_r;
        rast_pal_next      = rast_pal_r;
        rast_sprite_next   = rast_sprite_r;
        rast_priority_next = rast_priority_r;
        rast_pos_next      = rast_pos_r;
        rast_start_next    = 1'b0;

        case (state_r)
            BG_MAP: begin
                bus_addr_next   = {1'b0, ypos_r[9:3], xpos_r[9:4]};
                bus_strobe_next = 1'b1;
                state_next      = BG_MAP_WAIT;
            end

            BG_MAP_WAIT: begin
                bus_strobe_next = 1'b1;
                if (bus_ack) begin
                    bus_strobe_next = 1'b0;
                    map_data_next   = xpos_r[3] ? bus_rddata[31:16] : bus_rddata[15:0];
                    state_next      = BG_PAT;
                end
            end

            BG_PAT: begin
                bus_addr_next   = bg_pat_addr;
                bus_strobe_next = 1'b1;
                state_next      = BG_PAT_WAIT;
            end

            BG_PAT_WAIT: begin
                bus_strobe_next = 1'b1;
                if (bus_ack) begin
                    bus_strobe_next = 1'b0;
                    pat_data_next   = bus_rddata;
                    state_next      = BG_RENDER;
                end
            end

            BG_RENDER: begin
                if (!rast_busy) begin
                    rast_data_next     = rast_data;
                    rast_pal_next      = map_palette;
                    rast_priority_next = map_priority;
                    rast_sprite_next   = 1'b0;
                    rast_pos_next      = rast_pos_r + 10'd8;
                    rast_start_next    = 1'b1;
                    xpos_next          = xpos_r + 10'd8;
                    tile_count_next    = tile_count_r + 7'd1;
                    state_next         = BG_MAP;

                    if (tile_count_r == ((bg_mode_r == 2'd0) ? 7'd80 : 7'd40)) begin
                        state_next = sprites_en_r ? SPR_FIND : WAIT_START;
                    end
                end
            end

            SPR_FIND: begin
                if (sprite_on_line && spr_enable) begin
                    bus_addr_next   = spr_pat_addr;
                    bus_strobe_next = 1'b1;
                    state_next      = SPR_PAT_WAIT;

                end else begin
                    sprite_idx_next = sprite_idx_r + 5'd1;

                    if (sprite_idx_r == 5'd31) begin
                        state_next = WAIT_START;
                    end
                end
            end

            SPR_PAT_WAIT: begin
                bus_strobe_next = 1'b1;
                if (bus_ack) begin
                    bus_strobe_next = 1'b0;
                    pat_data_next   = bus_rddata;
                    state_next      = SPR_RENDER;
                end
            end

            SPR_RENDER: begin
                if (!rast_busy) begin
                    rast_data_next     = spr_hflip ? pat_data_hflipped : pat_data_r;
                    rast_pal_next      = spr_palette;
                    rast_priority_next = spr_priority;
                    rast_sprite_next   = 1'b1;
                    if (spr_size && (bus_addr_r[3] ^ spr_hflip)) begin
                        rast_pos_next = spr_x + 10'd8;
                    end else begin
                        rast_pos_next = spr_x;
                    end
                    rast_start_next    = 1'b1;

                    if (spr_size && !(bus_addr_r[3] ^ spr_hflip)) begin
                        bus_addr_next[3] = !bus_addr_r[3];
                        bus_strobe_next  = 1'b1;
                        state_next       = SPR_PAT_WAIT;
                        
                    end else begin
                        sprite_idx_next    = sprite_idx_r + 5'd1;
                        state_next         = SPR_FIND;
                    end

                end
            end
        endcase

        if (render_start) begin
            state_next      = BG_MAP;
            bg_mode_next    = bg_mode;
            bg_en_next      = bg_en;
            bg_pal_next     = bg_pal;
            sprites_en_next = sprites_en;
            xpos_next       = x_scroll;
            rast_pos_next   = 10'd1016 - x_scroll[2:0];
            ypos_next       = y_scroll + {2'b0, render_line};
            tile_count_next = 7'd0;
            sprite_idx_next = 5'd0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r         <= WAIT_START;
            bg_mode_r       <= 2'd0;
            bg_en_r         <= 1'b0;
            bg_pal_r        <= 1'b0;
            sprites_en_r    <= 1'b0;
            xpos_r          <= 10'd0;
            ypos_r          <= 10'd0;
            map_data_r      <= 16'd0;
            pat_data_r      <= 32'd0;
            tile_count_r    <= 7'd0;
            sprite_idx_r    <= 5'd0;

            bus_addr_r      <= 14'd0;
            bus_strobe_r    <= 1'b0;

            rast_data_r     <= 32'b0;
            rast_pal_r      <= 1'b0;
            rast_sprite_r   <= 1'b0;
            rast_priority_r <= 1'b0;
            rast_pos_r      <= 10'd0;
            rast_start_r    <= 1'b0;

        end else begin
            state_r         <= state_next;
            bg_mode_r       <= bg_mode_next;
            bg_en_r         <= bg_en_next;
            bg_pal_r        <= bg_pal_next;
            sprites_en_r    <= sprites_en_next;
            xpos_r          <= xpos_next;
            ypos_r          <= ypos_next;
            map_data_r      <= map_data_next;
            pat_data_r      <= pat_data_next;
            tile_count_r    <= tile_count_next;
            sprite_idx_r    <= sprite_idx_next;

            bus_addr_r      <= bus_addr_next;
            bus_strobe_r    <= bus_strobe_next;

            rast_data_r     <= rast_data_next;
            rast_pal_r      <= rast_pal_next;
            rast_sprite_r   <= rast_sprite_next;
            rast_priority_r <= rast_priority_next;
            rast_pos_r      <= rast_pos_next;
            rast_start_r    <= rast_start_next;
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Rasterizer
    //////////////////////////////////////////////////////////////////////////
    reg [9:0] zbuf_rdidx_r, zbuf_rdidx_next;
    reg [9:0] render_wridx_r, render_wridx_next;
    reg [2:0] rast_cnt_r, rast_cnt_next;

    assign render_wridx = render_wridx_next;

    // Z-buffer
    reg  [1:0] z_buffer_wrdata;
    wire [1:0] z_buffer_rddata;

    dpram #(.ADDR_WIDTH(10), .DATA_WIDTH(2)) z_buffer(
        .wr_clk(clk),
        .wr_addr(render_wridx),
        .wr_data(z_buffer_wrdata),
        .wr_en(render_write),

        .rd_clk(clk),
        .rd_addr(zbuf_rdidx_next),
        .rd_data(z_buffer_rddata));
    
    always @* begin
        zbuf_rdidx_next = zbuf_rdidx_r + 10'd1;
        if (rast_start_next) begin
            zbuf_rdidx_next = rast_pos_next;
        end
    end
    always @(posedge clk) zbuf_rdidx_r <= zbuf_rdidx_next;


    wire is_transparent = (render_wrdata[3:0] == 4'd0);

    always @* begin
        z_buffer_wrdata   = z_buffer_rddata;
        render_wridx_next = render_wridx_r;
        rast_cnt_next     = rast_cnt_r;
        render_write      = 1'b0;
        rast_busy         = 1'b0;

        if (rast_start_r) begin
            rast_busy         = 1'b1;
            rast_cnt_next     = 3'd0;
            render_write      = !rast_sprite_r || !is_transparent;
            render_wridx_next = rast_pos_r;

        end else begin
            if (rast_cnt_r < 3'd7) begin
                rast_busy         = 1'b1;
                render_wridx_next = render_wridx_r + 10'd1;
                rast_cnt_next     = rast_cnt_r + 3'd1;
                render_write      = !rast_sprite_r || !is_transparent;
            end

            if (rast_cnt_r >= 3'd6) begin
                rast_busy = 1'b0;
            end
        end

        if (!rast_sprite_r) begin
            // Background render stage
            if (render_wrdata[3:0] == 4'd0) begin
                z_buffer_wrdata = 2'd0;
            end else begin
                z_buffer_wrdata = rast_priority_r ? 2'd2 : 2'd1;
            end

        end else begin
            // Sprite render stage
            if (rast_priority_r) begin
                z_buffer_wrdata = 2'd2;
            end else if (z_buffer_rddata == 2'd0) begin
                z_buffer_wrdata = 2'd1;
            end else if (z_buffer_rddata == 2'd2) begin
                render_write = 0;
            end
        end
    end

    always @* begin
        render_wrdata[4] = rast_pal_r;
        case (rast_cnt_next[2:0])
            3'd0: render_wrdata[3:0] = rast_data_r[7:4];
            3'd1: render_wrdata[3:0] = rast_data_r[3:0];
            3'd2: render_wrdata[3:0] = rast_data_r[15:12];
            3'd3: render_wrdata[3:0] = rast_data_r[11:8];
            3'd4: render_wrdata[3:0] = rast_data_r[23:20];
            3'd5: render_wrdata[3:0] = rast_data_r[19:16];
            3'd6: render_wrdata[3:0] = rast_data_r[31:28];
            3'd7: render_wrdata[3:0] = rast_data_r[27:24];
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            render_wridx_r <= 10'd0;
            rast_cnt_r     <= 3'd0;

        end else begin
            render_wridx_r <= render_wridx_next;
            rast_cnt_r     <= rast_cnt_next;
        end
    end

endmodule
