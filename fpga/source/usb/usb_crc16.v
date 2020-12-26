// `default_nettype none
module usb_crc16(
    input  wire        clk,
    input  wire        rst,
    input  wire        data,
    input  wire        data_valid,
    output wire [15:0] result);

    // CRC16 polynomial: x^16 + x^15 + x^2 + 1

    reg [15:0] crc_r;

    assign result = crc_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            crc_r <= 16'hffff;

        end else if (data_valid) begin
            crc_r[0] <= data ^ crc_r[15];
            crc_r[1] <= crc_r[0];
            crc_r[2] <= data ^ crc_r[1] ^ crc_r[15];
            crc_r[3] <= crc_r[2];
            crc_r[4] <= crc_r[3];
            crc_r[5] <= crc_r[4];
            crc_r[6] <= crc_r[5];
            crc_r[7] <= crc_r[6];
            crc_r[8] <= crc_r[7];
            crc_r[9] <= crc_r[8];
            crc_r[10] <= crc_r[9];
            crc_r[11] <= crc_r[10];
            crc_r[12] <= crc_r[11];
            crc_r[13] <= crc_r[12];
            crc_r[14] <= crc_r[13];
            crc_r[15] <= data ^ crc_r[14] ^ crc_r[15];
        end
    end

endmodule
