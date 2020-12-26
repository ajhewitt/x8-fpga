// `default_nettype none
module audio(
    input  wire        rst,
    input  wire        clk,

    // Attribute RAM interface
    input  wire  [4:0] psg_wraddr,
    input  wire  [7:0] psg_wrdata,
    input  wire        psg_write,

    // PCM interface
    input  wire  [7:0] pcm_sample_rate,
    input  wire        pcm_mode_stereo,
    input  wire  [3:0] pcm_volume,

    input  wire        pcm_fifo_reset,
    input  wire  [7:0] pcm_fifo_wrdata,
    input  wire        pcm_fifo_write,
    output wire        pcm_fifo_full,
    output wire        pcm_fifo_almost_empty,

    // PWM audio output
    input  wire        dac_rst,
    input  wire        dac_clk,

    output wire        audio_l,
    output wire        audio_r);

    wire next_sample;

    //////////////////////////////////////////////////////////////////////////
    // PSG
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] psg_left, psg_right;

    psg psg(
        .rst(rst),
        .clk(clk),

        // Register interface
        .attr_addr({1'b0, psg_wraddr}),
        .attr_wrdata(psg_wrdata),
        .attr_write(psg_write),

        .next_sample(next_sample),

        // Audio output
        .left_audio(psg_left),
        .right_audio(psg_right));

    //////////////////////////////////////////////////////////////////////////
    // PCM
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] pcm_left, pcm_right;

    pcm pcm(
        .rst(rst),
        .clk(clk),

        .next_sample(next_sample),

        // Register interface
        .sample_rate(pcm_sample_rate),
        .mode_stereo(pcm_mode_stereo),
        .volume(pcm_volume),

        // Audio FIFO interface
        .fifo_reset(pcm_fifo_reset),
        .fifo_wrdata(pcm_fifo_wrdata),
        .fifo_write(pcm_fifo_write),
        .fifo_full(pcm_fifo_full),
        .fifo_almost_empty(pcm_fifo_almost_empty),

        // Audio output
        .left_audio(pcm_left),
        .right_audio(pcm_right));
        
    //////////////////////////////////////////////////////////////////////////
    // Next sample generator
    //////////////////////////////////////////////////////////////////////////
    reg [15:0] left_data_r;
    reg [15:0] right_data_r;

    reg [7:0] sample_rate_cnt_r;
    assign next_sample = (sample_rate_cnt_r == 'd0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_rate_cnt_r <= 0;
        end else begin
            sample_rate_cnt_r <= sample_rate_cnt_r + 'd1;
        end
    end

    assign next_sample = (sample_rate_cnt_r == 'd0);

    always @(posedge clk) begin
        if (next_sample) begin
            left_data_r  <= psg_left  + pcm_left;
            right_data_r <= psg_right + pcm_right;
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // PWM DAC
    //////////////////////////////////////////////////////////////////////////
    wire dac_next_sample;
    pulse2pulse p2p_next_sample(.in_clk(clk), .in_pulse(next_sample), .out_clk(dac_clk), .out_pulse(dac_next_sample));

    pwm_dac pwm_dac(
        .rst(dac_rst),
        .clk(dac_clk),

        // Sample input
        .next_sample(dac_next_sample),
        .left_data(left_data_r),
        .right_data(right_data_r),

        // PWM audio output
        .audio_l(audio_l),
        .audio_r(audio_r));

endmodule
