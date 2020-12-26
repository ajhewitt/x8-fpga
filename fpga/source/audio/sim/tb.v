`timescale 1 ns / 1 ps
// `default_nettype none
module tb();

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    initial begin
        #5000000 $finish;
    end

    // Generate 12MHz sysclk
    reg clk = 0;
    always #41.666666 clk = !clk;

    reg rst = 1;
    always #416.66666 rst = 0;

    reg  [4:0] bus_addr;
    reg  [7:0] bus_wrdata;
    reg        bus_write;

    audio audio(
        .ram_wrclk(clk),
        .ram_wraddr(bus_addr),
        .ram_wrdata(bus_wrdata),
        .ram_write(bus_write),

        .rst(rst),
        .clk(clk),

        // PWM audio output
        .audio_l(),
        .audio_r());

    task extbus_write;
        input [4:0] addr;
        input [7:0] data;

        begin
            @(negedge clk)
            bus_addr   = addr;
            bus_wrdata = data;
            bus_write  = 1;

            @(negedge clk)
            bus_write  = 0;
        end
    endtask

    initial begin
        bus_addr   = 0;
        bus_wrdata = 0;
        bus_write  = 0;

        #100
        @(posedge clk);

        extbus_write(5'h00, 8'h00);
        extbus_write(5'h01, 8'h0F);
        extbus_write(5'h02, 8'hFF);
        extbus_write(5'h03, 8'h40);

        // extbus_write(7'h04, 8'hFF);
        // extbus_write(7'h05, 8'h09);
        // extbus_write(7'h06, 8'hFF);
        // extbus_write(7'h07, 8'h7F);
    end


endmodule
