// `default_nettype none
module SP256K (
    input  wire        CK,
    input  wire [13:0] AD,
    input  wire [15:0] DI,
    output reg  [15:0] DO,
    input  wire  [3:0] MASKWE,
    input  wire        WE,
    input  wire        CS,
    input  wire        STDBY,
    input  wire        SLEEP,
    input  wire        PWROFF_N);

    reg [15:0] mem[0:16383];

    always @(posedge CK) begin
        if (CS && WE && MASKWE[0]) mem[AD][ 3: 0] <= DI[ 3: 0];
        if (CS && WE && MASKWE[1]) mem[AD][ 7: 4] <= DI[ 7: 4];
        if (CS && WE && MASKWE[2]) mem[AD][11: 8] <= DI[11: 8];
        if (CS && WE && MASKWE[3]) mem[AD][15:12] <= DI[15:12];
        DO <= mem[AD];
    end

    initial begin: INIT
        integer i;
        for (i=0; i<16384; i=i+1) begin
            mem[i] = 'h1234;
        end
    end

endmodule
