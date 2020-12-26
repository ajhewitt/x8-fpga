module led_if(
    input  wire        rst,
    input  wire        clk,

    input  wire        activity,

    output reg         led);

    reg [16:0] pulse_cnt_r;
    wire pulse_cnt_zero = (pulse_cnt_r == 17'd0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pulse_cnt_r <= 17'd0;
        end else begin
            if (!pulse_cnt_zero) begin
                pulse_cnt_r <= pulse_cnt_r - 17'd1;
            end
            if (activity) begin
                pulse_cnt_r <= 17'h1FFFF;
            end
        end
    end

    wire [7:0] val = pulse_cnt_zero ? 8'd64 : 8'd255;

    reg [7:0] cnt_r = 0;
    always @(posedge clk) cnt_r <= cnt_r + 8'd1;
    always @(posedge clk) led <= val >= cnt_r;

endmodule
