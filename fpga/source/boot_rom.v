// `default_nettype none
module boot_rom(
    input  wire       clk,
    input  wire [8:0] addr,
    output reg  [7:0] rddata);

    reg [7:0] mem[0:511];

    always @(posedge clk) begin
        rddata <= mem[addr];
    end

    initial begin
        `ifdef __ICARUS__
            $readmemh("../boot_rom.mem", mem);
        `else
            $readmemh("source/boot_rom.mem", mem);
        `endif
    end

endmodule
