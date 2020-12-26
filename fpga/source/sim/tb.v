`timescale 1 ns / 1 ps
// `default_nettype none
module tb();

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    initial begin
        #300000 $finish;
    end

    // Generate 48MHz sysclk
    reg clk48 = 0;
    always #10.41666 clk48 = !clk48;

    wire usb1_dm = 0;
    wire usb1_dp = 0;
    wire usb2_dm = 0;
    wire usb2_dp = 0;

    top top(
        .sysclk_1(clk48),
        .sysclk_2(clk48),

        // VGA interface
        .vga_r(),
        .vga_g(),
        .vga_b(),
        .vga_vsync(),
        .vga_hsync(),

        // SPI interface
        .flash_sck(),
        .flash_mosi(),
        .flash_miso(1'b0),
        .flash_ssel_n(),

        .sd_sck(),
        .sd_mosi(),
        .sd_miso(1'b0),
        .sd_ssel_n(),

        // DBG serial interface
        .dbg_rxd(1'b1),
        .dbg_txd(),

        // USB interfaces
        .usb1_dm(usb1_dm),
        .usb1_dp(usb1_dp),
        .usb2_dm(usb2_dm),
        .usb2_dp(usb2_dp),

        // LED and button
        .led(),
        .button(1'b1),

        // Spare IOs
        .exp3(1'b0),

        // Wi-Fi serial interface
        .wifi_txd(),
        .wifi_rxd(1'b1),
        .wifi_rts(),
        .wifi_cts(1'b0),

        // Audio output
        .audio_l(),
        .audio_r());

endmodule
