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
    always #10.416 clk48 = !clk48;

    reg rst48 = 1;
    always #104.166 rst48 = 0;

    reg clk12 = 0;
    always #40 clk12 = !clk12;

    reg rst12 = 1;
    always #120 rst12 = 0;


    wire usb1_dm = 1'bZ;
    wire usb1_dp = 1'bZ;
    wire usb2_dm = 1'bZ;
    wire usb2_dp = 1'bZ;

    reg [7:0] txfifo_data = 0;
    reg       txfifo_write = 0;

    reg [1:0] port1_mode = 0;
    reg       xfer_start = 0;

    usbhost usbhost(
        .rst(rst12),
        .clk(clk12),

        // Register interface
        .port1_mode(port1_mode),
        .port1_dpdm(),
        .port1_addr(3'd0),

        .port2_mode(2'b00),
        .port2_dpdm(),
        .port2_addr(3'd0),

        .crc16_valid(),
        .timeout(),
        .busy(),

        .xfer_reset(1'b0),

        .xfer_done_pulse(),
        .sof_pulse(),

        .xfer_endpoint(4'd0),
        .xfer_type(2'd0),
        .xfer_data_type(1'b0),
        .xfer_port(1'b0),
        .xfer_start(xfer_start),

        .txfifo_data(txfifo_data),
        .txfifo_write(txfifo_write),

        .rxfifo_data(),
        .rxfifo_read(1'b0),
        .rxfifo_not_empty(),

        // USB interfaces
        .usb_rst(rst48),
        .usb_clk(clk48),

        .usb1_dp(usb1_dp),
        .usb1_dm(usb1_dm),

        .usb2_dp(usb2_dp),
        .usb2_dm(usb2_dm));

    reg [7:0] tx_data;
    reg       tx_valid = 0;
    wire      tx_ready;

    wire test_dp, test_dm, test_oe;

    assign usb1_dm = test_oe ? test_dm : 1'bZ;
    assign usb1_dp = test_oe ? test_dp : 1'bZ;

    usb_tx test_tx(
        .rst(rst48),
        .clk(clk48),

        .tx_only_eop(1'b0),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),

        .tx_bit_pulse(),

        .usb_speed(1'b0),    // 0:low-speed (1.5Mbps), 1:full-speed (12Mbps)

        .usb_tx_dp(test_dp),
        .usb_tx_dm(test_dm),
        .usb_tx_oe(test_oe),

        .is_sof_eop());


    initial begin
        #120

        // @(negedge clk48);
        // txfifo_data = 8'h80;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h06;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h00;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h01;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h00;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h00;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h12;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_data = 8'h00;
        // txfifo_write = 1;
        // @(negedge clk48);
        // txfifo_write = 0;

        @(negedge clk12);
        txfifo_data = 8'h11;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h22;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h33;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h44;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h55;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h66;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h77;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_data = 8'h88;
        txfifo_write = 1;
        @(negedge clk12);
        txfifo_write = 0;

        port1_mode = 2'd2;

        @(negedge clk12);
        xfer_start = 1;
        @(negedge clk12);
        xfer_start = 0;
        
        #100000;

        @(negedge clk12);
        tx_valid = 1'b1;

        tx_data = 8'h4B; @(posedge tx_ready);
        tx_data = 8'h12; @(posedge tx_ready);
        tx_data = 8'h01; @(posedge tx_ready);
        tx_data = 8'h00; @(posedge tx_ready);
        tx_data = 8'h20; @(posedge tx_ready);
        tx_data = 8'h00; @(posedge tx_ready);
        tx_data = 8'h00; @(posedge tx_ready);
        tx_data = 8'h00; @(posedge tx_ready);
        tx_data = 8'h08; @(posedge tx_ready);

        tx_data = 8'hAF; @(posedge tx_ready);
        tx_data = 8'hE0; @(posedge tx_ready);

        tx_valid = 1'b0;


    end

endmodule

