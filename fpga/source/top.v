// `default_nettype none
module top(
    input  wire sysclk_1,   // 48MHz
    input  wire sysclk_2,   // 48MHz

    // VGA interface
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire vga_vsync,
    output wire vga_hsync,

    // SPI interfaces
    output wire flash_sck,
    output wire flash_mosi,
    input  wire flash_miso,
    output wire flash_ssel_n,

    output wire sd_sck,
    output wire sd_mosi,
    input  wire sd_miso,
    output wire sd_ssel_n,

    // Debug serial interface
    output wire dbg_txd,
    input  wire dbg_rxd,

    // USB interfaces
    inout  wire usb1_dp,
    inout  wire usb1_dm,
    inout  wire usb2_dp,
    inout  wire usb2_dm,

    // LED and button
    output wire led,
    input  wire button,

    // Spare IOs
    input  wire exp3,

    // Wi-Fi serial interface
    output wire wifi_txd,
    input  wire wifi_rxd,
    output wire wifi_rts,
    input  wire wifi_cts,

    // Audio output
    output wire audio_l,
    output wire audio_r);

    //////////////////////////////////////////////////////////////////////////
    // System controller
    //////////////////////////////////////////////////////////////////////////
    reg  sys_reset_r, sys_reset_next;
    wire vga_clk, vga_rst;
    wire sys_clk, sys_rst;
    wire usb_clk, usb_rst;

    sysctl sysctl(
        .reset_in(sys_reset_r),

        .sysclk_1(sysclk_1),
        .sysclk_2(sysclk_2),

        .vga_clk(vga_clk),
        .vga_rst(vga_rst),

        .usb_clk(usb_clk),
        .usb_rst(usb_rst),

        .sys_clk(sys_clk),
        .sys_rst(sys_rst));

    //////////////////////////////////////////////////////////////////////////
    // FPGA reconfiguration
    //////////////////////////////////////////////////////////////////////////
    reg       fpga_reconfigure_r, fpga_reconfigure_next;
    reg [1:0] fpga_image_sel_r,   fpga_image_sel_next;

`ifndef __ICARUS__
    WARMBOOT warmboot(
        .S1(fpga_image_sel_r[1]),
        .S0(fpga_image_sel_r[0]),
        .BOOT(fpga_reconfigure_r));
`endif

    //////////////////////////////////////////////////////////////////////////
    // CPU
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] cpu_addr;
    reg   [7:0] cpu_rddata;
    wire  [7:0] cpu_wrdata;
    wire        cpu_write, cpu_irq;

    cpu_65c02 cpu(
        .clk(sys_clk),
        .reset(sys_rst),
        .AB(cpu_addr),
        .DI(cpu_rddata),
        .DO(cpu_wrdata),
        .WE(cpu_write),
        .IRQ(cpu_irq),
        .NMI(1'b0),
        .RDY(1'b1));

    //////////////////////////////////////////////////////////////////////////
    // RAM
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] main_ram_rddata;

    main_ram main_ram(
        .rst(sys_rst),
        .clk(sys_clk),

        .bus_addr(cpu_addr[15:0]),
        .bus_wrdata(cpu_wrdata),
        .bus_rddata(main_ram_rddata),
        .bus_write(cpu_write));

    //////////////////////////////////////////////////////////////////////////
    // Boot ROM
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] bootrom_rddata;
    reg        bootrom_dis_r = 1'b0, bootrom_dis_next;

    boot_rom bootrom(
        .clk(sys_clk),
        .addr(cpu_addr[8:0]),
        .rddata(bootrom_rddata));

    //////////////////////////////////////////////////////////////////////////
    // Debug UART
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] dbg_baudrate_div = 16'd47;
    wire        dbg_tx_busy;
    wire        dbg_tx_write;
    wire  [7:0] dbg_rxfifo_data;
    wire        dbg_rxfifo_not_empty;
    wire        dbg_rxfifo_read;

    uart dbg_uart(
        .rst(sys_rst),
        .clk(sys_clk),

        // Data interface
        .baudrate_div(dbg_baudrate_div),

        .tx_data(cpu_wrdata),
        .tx_valid(dbg_tx_write),
        .tx_busy(dbg_tx_busy),

        .rxfifo_data(dbg_rxfifo_data),
        .rxfifo_not_empty(dbg_rxfifo_not_empty),
        .rxfifo_read(dbg_rxfifo_read),

        // UART interface
        .uart_rst(usb_rst),
        .uart_clk(usb_clk),

        .uart_rxd(dbg_rxd),
        .uart_txd(dbg_txd));

    //////////////////////////////////////////////////////////////////////////
    // Wi-Fi UART
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] wifi_baudrate_div = 16'd416;
    wire        wifi_tx_busy;
    wire        wifi_tx_write;
    wire  [7:0] wifi_rxfifo_data;
    wire        wifi_rxfifo_not_empty;
    wire        wifi_rxfifo_read;

    uart wifi_uart(
        .rst(sys_rst),
        .clk(sys_clk),

        // Data interface
        .baudrate_div(wifi_baudrate_div),

        .tx_data(cpu_wrdata),
        .tx_valid(wifi_tx_write),
        .tx_busy(wifi_tx_busy),

        .rxfifo_data(wifi_rxfifo_data),
        .rxfifo_not_empty(wifi_rxfifo_not_empty),
        .rxfifo_read(wifi_rxfifo_read),

        // UART interface
        .uart_rst(usb_rst),
        .uart_clk(usb_clk),

        .uart_rxd(wifi_rxd),
        .uart_txd(wifi_txd));

    //////////////////////////////////////////////////////////////////////////
    // SPI
    //////////////////////////////////////////////////////////////////////////
    reg  [7:0] spi_txdata_r,  spi_txdata_next;
    reg        spi_txstart_r, spi_txstart_next;
    wire [7:0] spi_rxdata;
    wire       spi_busy;
    reg        spi_slow_r,    spi_slow_next;
    reg  [1:0] spi_select_r,  spi_select_next;
    reg        spi_auto_tx_r, spi_auto_tx_next;

    wire spi_sck, spi_mosi, spi_miso;

    spictrl spictrl(
        .rst(sys_rst),
        .clk(sys_clk),

        // Register interface
        .txdata(spi_txdata_r),
        .txstart(spi_txstart_r),
        .rxdata(spi_rxdata),
        .busy(spi_busy),

        .slow(spi_slow_r),

        // SPI interface
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso));

    assign sd_ssel_n    = !(spi_select_r == 2'd1);
    assign flash_ssel_n = !(spi_select_r == 2'd2);

    assign sd_sck     = spi_sck  && flash_ssel_n;
    assign sd_mosi    = spi_mosi && flash_ssel_n;
    assign flash_sck  = spi_sck  && !flash_ssel_n;
    assign flash_mosi = spi_mosi && !flash_ssel_n;

    assign spi_miso   = !flash_ssel_n ? flash_miso : sd_miso;

    //////////////////////////////////////////////////////////////////////////
    // USB host
    //////////////////////////////////////////////////////////////////////////
    reg  [1:0] usb_port1_mode_r,     usb_port1_mode_next;
    wire [1:0] usb_port1_dpdm;
    reg  [2:0] usb_port1_addr_r,     usb_port1_addr_next;
    reg  [1:0] usb_port2_mode_r,     usb_port2_mode_next;
    wire [1:0] usb_port2_dpdm;
    reg  [2:0] usb_port2_addr_r,     usb_port2_addr_next;
    wire       usb_rx_crc16_valid;
    wire       usb_timeout;
    wire       usb_busy;
    wire       usb_xfer_reset;
    wire       usb_xfer_done_pulse;
    wire       usb_sof_pulse;
    reg  [3:0] usb_xfer_endpoint_r,  usb_xfer_endpoint_next;
    reg  [1:0] usb_xfer_type_r,      usb_xfer_type_next;
    reg        usb_xfer_data_type_r, usb_xfer_data_type_next;
    reg        usb_xfer_port_r,      usb_xfer_port_next;
    reg        usb_xfer_start_r,     usb_xfer_start_next;
    wire       usb_txfifo_write;
    wire [7:0] usb_rxfifo_data;
    reg        usb_rxfifo_read_r;
    wire       usb_rxfifo_not_empty;

    usbhost usbhost(
        .rst(sys_rst),
        .clk(sys_clk),

        // Register interface
        .port1_mode(usb_port1_mode_r),
        .port1_dpdm(usb_port1_dpdm),
        .port1_addr(usb_port1_addr_r),

        .port2_mode(usb_port2_mode_r),
        .port2_dpdm(usb_port2_dpdm),
        .port2_addr(usb_port2_addr_r),

        .crc16_valid(usb_rx_crc16_valid),
        .timeout(usb_timeout),
        .busy(usb_busy),

        .xfer_reset(usb_xfer_reset),

        .xfer_done_pulse(usb_xfer_done_pulse),
        .sof_pulse(usb_sof_pulse),

        .xfer_endpoint(usb_xfer_endpoint_r),
        .xfer_type(usb_xfer_type_r),
        .xfer_data_type(usb_xfer_data_type_r),
        .xfer_port(usb_xfer_port_r),
        .xfer_start(usb_xfer_start_r),

        .txfifo_data(cpu_wrdata),
        .txfifo_write(usb_txfifo_write),

        .rxfifo_data(usb_rxfifo_data),
        .rxfifo_read(usb_rxfifo_read_r),
        .rxfifo_not_empty(usb_rxfifo_not_empty),

        // USB interfaces
        .usb_rst(usb_rst),
        .usb_clk(usb_clk),

        .usb1_dp(usb1_dp),
        .usb1_dm(usb1_dm),

        .usb2_dp(usb2_dp),
        .usb2_dm(usb2_dm));

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////
    reg  [1:0] vid_bg_mode_r,    vid_bg_mode_next;
    reg        vid_bg_en_r,      vid_bg_en_next;
    reg        vid_bg_pal_r,     vid_bg_pal_next;
    reg        vid_sprites_en_r, vid_sprites_en_next;
    reg  [7:0] vid_irq_line_r,   vid_irq_line_next;
    reg  [7:0] vid_rambank_r,    vid_rambank_next;
    reg  [9:0] vid_x_scroll_r,   vid_x_scroll_next;
    reg  [9:0] vid_y_scroll_r,   vid_y_scroll_next;
    wire       vblank_irq_pulse;
    wire       line_irq_pulse;
    wire [7:0] vram_rddata;
    wire       vram_select;
    wire       spr_write;
    wire       pal_write;

    video video(
        .rst(sys_rst),
        .clk(sys_clk),

        // Video registers
        .bg_mode(vid_bg_mode_r),
        .bg_en(vid_bg_en_r),
        .bg_pal(vid_bg_pal_r),
        .sprites_en(vid_sprites_en_r),
        .irq_line(vid_irq_line_r),
        .x_scroll(vid_x_scroll_r),
        .y_scroll(vid_y_scroll_r),

        // Interrupt outputs
        .vblank_irq_pulse(vblank_irq_pulse),
        .line_irq_pulse(line_irq_pulse),

        // Video RAM interface
        .vram_addr({vid_rambank_r, cpu_addr[7:0]}),
        .vram_wrdata(cpu_wrdata),
        .vram_rddata(vram_rddata),
        .vram_strobe(vram_select),
        .vram_write(cpu_write),

        // Sprite attributes
        .spr_wraddr(cpu_addr[7:0]),
        .spr_wrdata(cpu_wrdata),
        .spr_write(spr_write),

        // Palette interface
        .pal_wraddr(cpu_addr[5:0]),
        .pal_wrdata(cpu_wrdata),
        .pal_write(pal_write),

        // VGA interface
        .vga_rst(vga_rst),
        .vga_clk(vga_clk),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync));

    //////////////////////////////////////////////////////////////////////////
    // Audio
    //////////////////////////////////////////////////////////////////////////
    wire        psg_write;

    reg   [7:0] pcm_sample_rate_r, pcm_sample_rate_next;
    reg         pcm_mode_stereo_r, pcm_mode_stereo_next;
    reg   [3:0] pcm_volume_r,      pcm_volume_next;
    reg         pcm_fifo_reset_r,  pcm_fifo_reset_next;

    wire        pcm_fifo_write;
    wire        pcm_fifo_full;
    wire        pcm_fifo_almost_empty;

    audio audio(
        .rst(sys_rst),
        .clk(sys_clk),

        // Attribute RAM interface
        .psg_wraddr({cpu_addr[2:0], cpu_addr[4:3]}),
        .psg_wrdata(cpu_wrdata),
        .psg_write(psg_write),

        // PCM interface
        .pcm_sample_rate(pcm_sample_rate_r),
        .pcm_mode_stereo(pcm_mode_stereo_r),
        .pcm_volume(pcm_volume_r),

        .pcm_fifo_reset(pcm_fifo_reset_r),
        .pcm_fifo_wrdata(cpu_wrdata),
        .pcm_fifo_write(pcm_fifo_write),
        .pcm_fifo_full(pcm_fifo_full),
        .pcm_fifo_almost_empty(pcm_fifo_almost_empty),

        // PWM audio output
        .dac_rst(usb_rst),
        .dac_clk(usb_clk),

        .audio_l(audio_l),
        .audio_r(audio_r));

    //////////////////////////////////////////////////////////////////////////
    // LED
    //////////////////////////////////////////////////////////////////////////
    led_if led_if(
        .rst(sys_rst),
        .clk(sys_clk),

        .activity(spi_busy),

        .led(led));

    //////////////////////////////////////////////////////////////////////////
    // Memory map
    //////////////////////////////////////////////////////////////////////////
    // 0000 - 03FF RAM
    // 0400 - 04FF Video RAM banked access area
    // 0500 - 059F Sprite attributes (write only)
    // 05A0 - 05BF PSG (write only)
    // 05C0 - 05FF Palette 0/1 (write only)
    // 0600        IEN
    // 0601        ISR
    // 0602        SYSCTRL
    // 0603        VID_CTRL
    // 0604        VID_IRQLINE
    // 0605        VID_RAMBANK
    // 0606        VID_SCRX_L
    // 0607        VID_SCRX_H
    // 0608        VID_SCRY_L
    // 0609        VID_SCRY_H
    // 060A        SPI_CTRL
    // 060B        SPI_DATA
    // 060C        PCM_CTRL
    // 060D        PCM_RATE
    // 060E        PCM_DATA
    // 060F        USB_PORT1
    // 0610        USB_PORT2
    // 0611        USB_STATUS
    // 0612        USB_XFER
    // 0613        USB_FIFO
    // 0614        DBG_STATUS
    // 0615        DBG_DATA
    // 0616        WIFI_STATUS
    // 0617        WIFI_DATA
    // 0618 - FFFF RAM
    //(FE00 - FFFF Boot ROM)
    //////////////////////////////////////////////////////////////////////////

    // Interrupt registers
    reg        ien_pcm_txfifo_r,    ien_pcm_txfifo_next;
    reg        ien_wifi_rxfifo_r,   ien_wifi_rxfifo_next;
    reg        ien_dbg_rxfifo_r,    ien_dbg_rxfifo_next;
    reg        ien_usb_sof_r,       ien_usb_sof_next;
    reg        ien_usb_xfer_done_r, ien_usb_xfer_done_next;
    reg        ien_vid_line_r,      ien_vid_line_next;
    reg        ien_vid_vblank_r,    ien_vid_vblank_next;

    wire       isr_pcm_txfifo  = pcm_fifo_almost_empty;
    wire       isr_wifi_rxfifo = wifi_rxfifo_not_empty;
    wire       isr_dbg_rxfifo  = dbg_rxfifo_not_empty;

    reg        isr_usb_sof_r,       isr_usb_sof_next;
    reg        isr_usb_xfer_done_r, isr_usb_xfer_done_next;
    reg        isr_vid_line_r,      isr_vid_line_next;
    reg        isr_vid_vblank_r,    isr_vid_vblank_next;

    // Address decoding
    assign vram_select      = ((cpu_addr & ~'hFF) == 16'h0400);
    assign spr_write        = ((cpu_addr & ~'hFF) == 16'h0500) &&  cpu_write;
    assign psg_write        = ((cpu_addr & ~'h1F) == 16'h05A0) &&  cpu_write;
    assign pal_write        = ((cpu_addr & ~'h3F) == 16'h05C0) &&  cpu_write;
    assign pcm_fifo_write   = ( cpu_addr          == 16'h060E) &&  cpu_write;
    assign usb_xfer_reset   = ( cpu_addr          == 16'h0611) &&  cpu_write;
    assign usb_txfifo_write = ( cpu_addr          == 16'h0613) &&  cpu_write;
    wire   usb_rxfifo_read  = ( cpu_addr          == 16'h0613) && !cpu_write;
    assign dbg_tx_write     = ( cpu_addr          == 16'h0615) &&  cpu_write;
    assign dbg_rxfifo_read  = ( cpu_addr          == 16'h0615) && !cpu_write;
    assign wifi_tx_write    = ( cpu_addr          == 16'h0617) &&  cpu_write;
    assign wifi_rxfifo_read = ( cpu_addr          == 16'h0617) && !cpu_write;

    reg [15:0] cpu_addr_r;
    always @(posedge sys_clk) cpu_addr_r <= cpu_addr;

    always @(posedge sys_clk) usb_rxfifo_read_r <= usb_rxfifo_read;

    always @* begin
        // Interrupt registers
        ien_pcm_txfifo_next     = ien_pcm_txfifo_r;
        ien_wifi_rxfifo_next    = ien_wifi_rxfifo_r;
        ien_dbg_rxfifo_next     = ien_dbg_rxfifo_r;
        ien_usb_sof_next        = ien_usb_sof_r;
        ien_usb_xfer_done_next  = ien_usb_xfer_done_r;
        ien_vid_line_next       = ien_vid_line_r;
        ien_vid_vblank_next     = ien_vid_vblank_r;

        isr_usb_sof_next        = isr_usb_sof_r;
        isr_usb_xfer_done_next  = isr_usb_xfer_done_r;
        isr_vid_line_next       = isr_vid_line_r   | line_irq_pulse;
        isr_vid_vblank_next     = isr_vid_vblank_r | vblank_irq_pulse;

        // System control register
        sys_reset_next          = sys_reset_r;
        bootrom_dis_next        = bootrom_dis_r;
        fpga_reconfigure_next   = fpga_reconfigure_r;
        fpga_image_sel_next     = fpga_image_sel_r;
        
        // Video registers
        vid_bg_mode_next        = vid_bg_mode_r;
        vid_bg_en_next          = vid_bg_en_r;
        vid_bg_pal_next         = vid_bg_pal_r;
        vid_sprites_en_next     = vid_sprites_en_r;
        vid_irq_line_next       = vid_irq_line_r;
        vid_rambank_next        = vid_rambank_r;
        vid_x_scroll_next       = vid_x_scroll_r;
        vid_y_scroll_next       = vid_y_scroll_r;

        // SPI registers
        spi_select_next         = spi_select_r;
        spi_slow_next           = spi_slow_r;
        spi_auto_tx_next        = spi_auto_tx_r;
        spi_txdata_next         = spi_txdata_r;
        spi_txstart_next        = 1'b0;

        // PCM registers
        pcm_sample_rate_next    = pcm_sample_rate_r;
        pcm_mode_stereo_next    = pcm_mode_stereo_r;
        pcm_volume_next         = pcm_volume_r;

        // USB registers
        usb_port1_mode_next     = usb_port1_mode_r;
        usb_port1_addr_next     = usb_port1_addr_r;
        usb_port2_mode_next     = usb_port2_mode_r;
        usb_port2_addr_next     = usb_port2_addr_r;
        usb_xfer_endpoint_next  = usb_xfer_endpoint_r;
        usb_xfer_type_next      = usb_xfer_type_r;
        usb_xfer_data_type_next = usb_xfer_data_type_r;
        usb_xfer_port_next      = usb_xfer_port_r;
        usb_xfer_start_next     = 1'b0;

        if (cpu_write) begin
            case (cpu_addr)
                16'h0600: begin
                    ien_pcm_txfifo_next    = cpu_wrdata[6];
                    ien_wifi_rxfifo_next   = cpu_wrdata[5];
                    ien_dbg_rxfifo_next    = cpu_wrdata[4];
                    ien_usb_sof_next       = cpu_wrdata[3];
                    ien_usb_xfer_done_next = cpu_wrdata[2];
                    ien_vid_line_next      = cpu_wrdata[1];
                    ien_vid_vblank_next    = cpu_wrdata[0];
                end

                16'h0601: begin
                    isr_usb_sof_next       = !cpu_wrdata[3] & isr_usb_sof_r;
                    isr_usb_xfer_done_next = !cpu_wrdata[2] & isr_usb_xfer_done_r;
                    isr_vid_line_next      = !cpu_wrdata[1] & isr_vid_line_r;
                    isr_vid_vblank_next    = !cpu_wrdata[0] & isr_vid_vblank_r;
                end

                16'h0602: begin
                    sys_reset_next         = cpu_wrdata[4];
                    bootrom_dis_next       = !cpu_wrdata[3];
                    fpga_reconfigure_next  = cpu_wrdata[2];
                    fpga_image_sel_next    = cpu_wrdata[1:0];
                end

                16'h0603: begin
                    vid_sprites_en_next    = cpu_wrdata[4];
                    vid_bg_pal_next        = cpu_wrdata[3];
                    vid_bg_en_next         = cpu_wrdata[2];
                    vid_bg_mode_next       = cpu_wrdata[1:0];
                end

                16'h0604: vid_irq_line_next      = cpu_wrdata;
                16'h0605: vid_rambank_next       = cpu_wrdata;
                16'h0606: vid_x_scroll_next[7:0] = cpu_wrdata;
                16'h0607: vid_x_scroll_next[9:8] = cpu_wrdata[1:0];
                16'h0608: vid_y_scroll_next[7:0] = cpu_wrdata;
                16'h0609: vid_y_scroll_next[9:8] = cpu_wrdata[1:0];

                16'h060A: begin
                    spi_auto_tx_next     = cpu_wrdata[3];
                    spi_slow_next        = cpu_wrdata[2];
                    spi_select_next      = cpu_wrdata[1:0];
                end
                16'h060B: begin
                    spi_txdata_next      = cpu_wrdata;
                    spi_txstart_next     = 1'b1;
                end

                16'h060C: begin
                    pcm_mode_stereo_next = cpu_wrdata[4];
                    pcm_volume_next      = cpu_wrdata[3:0];
                end
                16'h060D: pcm_sample_rate_next = cpu_wrdata;

                16'h060F: begin
                    usb_port1_mode_next = cpu_wrdata[5:4];
                    usb_port1_addr_next = cpu_wrdata[2:0];
                end
                16'h0610: begin
                    usb_port2_mode_next = cpu_wrdata[5:4];
                    usb_port2_addr_next = cpu_wrdata[2:0];
                end
                16'h0612: begin
                    usb_xfer_port_next      = cpu_wrdata[7];
                    usb_xfer_data_type_next = cpu_wrdata[6];
                    usb_xfer_type_next      = cpu_wrdata[5:4];
                    usb_xfer_endpoint_next  = cpu_wrdata[3:0];
                    usb_xfer_start_next     = 1'b1;
                end
            endcase

        end else begin  // Read

            // SPI Auto-TX
            if (cpu_addr_r == 16'h060B && spi_auto_tx_r) begin
                spi_txdata_next  = 8'hFF;
                spi_txstart_next = 1'b1;
            end

        end

        if (usb_xfer_done_pulse) begin
            isr_usb_xfer_done_next = 1'b1;
        end
        if (usb_sof_pulse) begin
            isr_usb_sof_next = 1'b1;
        end

        if (!button) begin
            sys_reset_next   = 1'b1;
            bootrom_dis_next = 1'b0;
        end
    end

    wire [7:0] reg_ien = {1'b0, ien_pcm_txfifo_r, ien_wifi_rxfifo_r, ien_dbg_rxfifo_r, ien_usb_sof_r, ien_usb_xfer_done_r, ien_vid_line_r, ien_vid_vblank_r};
    wire [7:0] reg_isr = {1'b0, isr_pcm_txfifo,   isr_wifi_rxfifo,   isr_dbg_rxfifo,   isr_usb_sof_r, isr_usb_xfer_done_r, isr_vid_line_r, isr_vid_vblank_r};

    assign cpu_irq = (reg_isr & reg_ien) != 0;

    always @* begin
        cpu_rddata = main_ram_rddata;

        if ((cpu_addr_r & ~'hFF) == 16'h0400)
            cpu_rddata = vram_rddata;

        if (!bootrom_dis_r && (cpu_addr_r & ~'h1FF) == 16'hFE00)
            cpu_rddata = bootrom_rddata;

        case (cpu_addr_r)
            16'h0600: cpu_rddata = reg_ien;
            16'h0601: cpu_rddata = reg_isr;
            16'h0602: cpu_rddata = {4'b0, !bootrom_dis_r, 1'b0, fpga_image_sel_r};
            16'h0603: cpu_rddata = {3'b0, vid_sprites_en_r, 1'b0, vid_bg_en_r, vid_bg_mode_r};
            16'h0604: cpu_rddata = vid_irq_line_r;
            16'h0605: cpu_rddata = vid_rambank_r;
            16'h0606: cpu_rddata = vid_x_scroll_r[7:0];
            16'h0607: cpu_rddata = {6'b0, vid_x_scroll_r[9:8]};
            16'h0608: cpu_rddata = vid_y_scroll_r[7:0];
            16'h0609: cpu_rddata = {6'b0, vid_y_scroll_r[9:8]};
            16'h060A: cpu_rddata = {spi_busy, 3'b0, spi_auto_tx_r, spi_slow_r, spi_select_r};
            16'h060B: cpu_rddata = spi_rxdata;
            16'h060C: cpu_rddata = {pcm_fifo_full, 2'b0, pcm_mode_stereo_r, pcm_volume_r};
            16'h060D: cpu_rddata = pcm_sample_rate_r;
            16'h060E: cpu_rddata = 8'h00;
            16'h060F: cpu_rddata = {usb_port1_dpdm, usb_port1_mode_r, 1'b0, usb_port1_addr_r};
            16'h0610: cpu_rddata = {usb_port2_dpdm, usb_port2_mode_r, 1'b0, usb_port2_addr_r};
            16'h0611: cpu_rddata = {usb_rxfifo_not_empty, usb_busy, 4'b0, usb_timeout, usb_rx_crc16_valid};
            16'h0612: cpu_rddata = {usb_xfer_port_r, usb_xfer_data_type_r, usb_xfer_type_r, usb_xfer_endpoint_r};
            16'h0613: cpu_rddata = usb_rxfifo_data;
            16'h0614: cpu_rddata = {dbg_tx_busy, dbg_rxfifo_not_empty, 6'b0};
            16'h0615: cpu_rddata = dbg_rxfifo_data;
            16'h0616: cpu_rddata = {wifi_tx_busy, wifi_rxfifo_not_empty, 6'b0};
            16'h0617: cpu_rddata = wifi_rxfifo_data;
        endcase
    end

    always @(posedge sys_clk) begin
        bootrom_dis_r <= bootrom_dis_next;
    end

    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            // Interrupt registers
            ien_pcm_txfifo_r     <= 1'b0;
            ien_wifi_rxfifo_r    <= 1'b0;
            ien_dbg_rxfifo_r     <= 1'b0;
            ien_usb_sof_r        <= 1'b0;
            ien_usb_xfer_done_r  <= 1'b0;
            ien_vid_line_r       <= 1'b0;
            ien_vid_vblank_r     <= 1'b0;

            isr_usb_sof_r        <= 1'b0;
            isr_usb_xfer_done_r  <= 1'b0;
            isr_vid_line_r       <= 1'b0;
            isr_vid_vblank_r     <= 1'b0;

            // System control register
            sys_reset_r          <= 1'b0;
            fpga_reconfigure_r   <= 1'b0;
            fpga_image_sel_r     <= 2'b0;

            // Video registers
`ifdef __ICARUS__
            vid_bg_mode_r        <= 2'd3;
            vid_bg_en_r          <= 1'b1;
            vid_sprites_en_r     <= 1'b1;
`else
            vid_bg_mode_r        <= 2'd0;
            vid_bg_en_r          <= 1'b0;
            vid_sprites_en_r     <= 1'b0;
`endif
            vid_bg_pal_r         <= 1'b0;
            vid_irq_line_r       <= 8'd0;
            vid_rambank_r        <= 8'b0;
            vid_x_scroll_r       <= 10'd0;
            vid_y_scroll_r       <= 10'd0;

            // SPI registers
            spi_select_r         <= 2'b0;
            spi_slow_r           <= 1'b0;
            spi_auto_tx_r        <= 1'b0;
            spi_txdata_r         <= 8'b0;
            spi_txstart_r        <= 1'b0;

            // PCM registers
            pcm_mode_stereo_r    <= 1'b0;
            pcm_volume_r         <= 4'd0;
            pcm_sample_rate_r    <= 8'd0;
            pcm_fifo_reset_r     <= 1'd1;

            // USB registers
            usb_port1_mode_r     <= 2'b0;
            usb_port1_addr_r     <= 3'b0;
            usb_port2_mode_r     <= 2'b0;
            usb_port2_addr_r     <= 3'b0;
            usb_xfer_endpoint_r  <= 4'b0;
            usb_xfer_type_r      <= 2'b0;
            usb_xfer_data_type_r <= 1'b0;
            usb_xfer_port_r      <= 1'b0;
            usb_xfer_start_r     <= 1'b0;

        end else begin
            // Interrupt registers
            ien_pcm_txfifo_r     <= ien_pcm_txfifo_r;
            ien_wifi_rxfifo_r    <= ien_wifi_rxfifo_next;
            ien_dbg_rxfifo_r     <= ien_dbg_rxfifo_next;
            ien_usb_sof_r        <= ien_usb_sof_next;
            ien_usb_xfer_done_r  <= ien_usb_xfer_done_next;
            ien_vid_line_r       <= ien_vid_line_next;
            ien_vid_vblank_r     <= ien_vid_vblank_next;

            isr_usb_sof_r        <= isr_usb_sof_next;
            isr_usb_xfer_done_r  <= isr_usb_xfer_done_next;
            isr_vid_line_r       <= isr_vid_line_next;
            isr_vid_vblank_r     <= isr_vid_vblank_next;

            // System control register
            sys_reset_r          <= sys_reset_next;
            fpga_reconfigure_r   <= fpga_reconfigure_next;
            fpga_image_sel_r     <= fpga_image_sel_next;
            
            // Video registers
            vid_bg_mode_r        <= vid_bg_mode_next;
            vid_bg_en_r          <= vid_bg_en_next;
            vid_bg_pal_r         <= vid_bg_pal_next;
            vid_sprites_en_r     <= vid_sprites_en_next;
            vid_irq_line_r       <= vid_irq_line_next;
            vid_rambank_r        <= vid_rambank_next;
            vid_x_scroll_r       <= vid_x_scroll_next;
            vid_y_scroll_r       <= vid_y_scroll_next;

            // SPI registers
            spi_select_r         <= spi_select_next;
            spi_slow_r           <= spi_slow_next;
            spi_auto_tx_r        <= spi_auto_tx_next;
            spi_txdata_r         <= spi_txdata_next;
            spi_txstart_r        <= spi_txstart_next;

            // PCM registers
            pcm_mode_stereo_r    <= pcm_mode_stereo_next;
            pcm_volume_r         <= pcm_volume_next;
            pcm_sample_rate_r    <= pcm_sample_rate_next;
            pcm_fifo_reset_r     <= pcm_fifo_reset_next;

            // USB registers
            usb_port1_mode_r     <= usb_port1_mode_next;
            usb_port1_addr_r     <= usb_port1_addr_next;
            usb_port2_mode_r     <= usb_port2_mode_next;
            usb_port2_addr_r     <= usb_port2_addr_next;
            usb_xfer_endpoint_r  <= usb_xfer_endpoint_next;
            usb_xfer_type_r      <= usb_xfer_type_next;
            usb_xfer_data_type_r <= usb_xfer_data_type_next;
            usb_xfer_port_r      <= usb_xfer_port_next;
            usb_xfer_start_r     <= usb_xfer_start_next;
        end
    end

endmodule
