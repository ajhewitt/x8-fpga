module pwm_dac(
    input  wire        rst,
    input  wire        clk,

    // Sample input
    input  wire        next_sample,
    input  wire [15:0] left_data,       // 2's complement signed left data
    input  wire [15:0] right_data,      // 2's complement signed right data

    // PWM audio output
    output wire        audio_l,
    output wire        audio_r);

    reg [15:0] left_sample_r;
    reg [15:0] right_sample_r;

    always @(posedge clk) begin
        if (next_sample) begin
            // Convert to unsigned data
            left_sample_r  <= {!left_data[15],  left_data[14:0]};
            right_sample_r <= {!right_data[15], right_data[14:0]};
        end
    end

    // PWM output
    reg [16:0] pwmacc_left;
    reg [16:0] pwmacc_right;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pwmacc_left  <= 0;
            pwmacc_right <= 0;

        end else begin
            pwmacc_left  <= {1'b0, pwmacc_left[15:0]}  + {1'b0, left_sample_r};
            pwmacc_right <= {1'b0, pwmacc_right[15:0]} + {1'b0, right_sample_r};
        end
    end

    assign audio_l = pwmacc_left[16];
    assign audio_r = pwmacc_right[16];

endmodule
