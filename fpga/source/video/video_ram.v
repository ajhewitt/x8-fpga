// `default_nettype none

module video_ram(
    input  wire        clk,

    // Slave bus interface
    input  wire [13:0] bus_addr,
    input  wire [31:0] bus_wrdata,
    input  wire  [3:0] bus_wrbytesel,
    output wire [31:0] bus_rddata,
    input  wire        bus_write);

    SP256K blk0(
        .CK(clk),
        .AD(bus_addr[13:0]),
        .DI(bus_wrdata[15:0]),
        .DO(bus_rddata[15:0]),
        .MASKWE({{2{bus_wrbytesel[1]}}, {2{bus_wrbytesel[0]}}}),
        .WE(bus_write),
        .CS(1'b1),
        .STDBY(1'b0),
        .SLEEP(1'b0),
        .PWROFF_N(1'b1));

    SP256K blk1(
        .CK(clk),
        .AD(bus_addr[13:0]),
        .DI(bus_wrdata[31:16]),
        .DO(bus_rddata[31:16]),
        .MASKWE({{2{bus_wrbytesel[3]}}, {2{bus_wrbytesel[2]}}}),
        .WE(bus_write),
        .CS(1'b1),
        .STDBY(1'b0),
        .SLEEP(1'b0),
        .PWROFF_N(1'b1));

endmodule
