// `default_nettype none
module main_ram(
    input  wire        rst,
    input  wire        clk,

    // Slave bus interface
    input  wire [15:0] bus_addr,
    input  wire  [7:0] bus_wrdata,
    output wire  [7:0] bus_rddata,
    input  wire        bus_write);

    reg bus_addr15_r, bus_addr0_r;
    always @(posedge clk) bus_addr15_r <= bus_addr[15];
    always @(posedge clk) bus_addr0_r  <= bus_addr[0];

    wire [3:0] maskwe = bus_addr[0] ? 4'b1100 : 4'b0011;

    wire [15:0] blk0_rddata, blk1_rddata;

    SP256K blk0(
        .CK(clk),
        .AD(bus_addr[14:1]),
        .DI({bus_wrdata, bus_wrdata}),
        .DO(blk0_rddata),
        .MASKWE(maskwe),
        .WE(bus_write && !bus_addr[15]),
        .CS(1'b1),
        .STDBY(1'b0),
        .SLEEP(1'b0),
        .PWROFF_N(1'b1));

    SP256K blk1(
        .CK(clk),
        .AD(bus_addr[14:1]),
        .DI({bus_wrdata, bus_wrdata}),
        .DO(blk1_rddata),
        .MASKWE(maskwe),
        .WE(bus_write && bus_addr[15]),
        .CS(1'b1),
        .STDBY(1'b0),
        .SLEEP(1'b0),
        .PWROFF_N(1'b1));

    wire [7:0] blk0_rddata8 = bus_addr0_r ? blk0_rddata[15:8] : blk0_rddata[7:0];
    wire [7:0] blk1_rddata8 = bus_addr0_r ? blk1_rddata[15:8] : blk1_rddata[7:0];
    assign bus_rddata = bus_addr15_r ? blk1_rddata8 : blk0_rddata8;

endmodule
