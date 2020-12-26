// `default_nettype none
module usb_crc5_11(
    input  wire [10:0] data_in,
    output wire  [4:0] result);

    // CRC5 polynomial: x^5 + x^2 + 1

    assign result[4] = data_in[10-0] ^ data_in[10-3] ^ data_in[10-5] ^ data_in[10-6] ^ data_in[10-9] ^ data_in[10-10];
    assign result[3] = data_in[10-1] ^ data_in[10-4] ^ data_in[10-6] ^ data_in[10-7] ^ data_in[10-10];
    assign result[2] = data_in[10-0] ^ data_in[10-2] ^ data_in[10-3] ^ data_in[10-6] ^ data_in[10-7] ^ data_in[10-8] ^ data_in[10-9] ^ data_in[10-10];
    assign result[1] = 1 ^ data_in[10-1] ^ data_in[10-3] ^ data_in[10-4] ^ data_in[10-7] ^ data_in[10-8] ^ data_in[10-9] ^ data_in[10-10];
    assign result[0] = data_in[10-2] ^ data_in[10-4] ^ data_in[10-5] ^ data_in[10-8] ^ data_in[10-9] ^ data_in[10-10];

endmodule
