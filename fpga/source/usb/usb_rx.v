// `default_nettype none
module usb_rx(
    input  wire       rst,
    input  wire       clk,

    input  wire       usb_speed,    // 0:low-speed (1.5Mbps), 1:full-speed (12Mbps)

    output wire [7:0] rx_data,
    output wire       rx_valid,
    output wire       rx_active,

    output wire       crc16_valid,

    input  wire       usb_rx_dp,
    input  wire       usb_rx_dm);

    // Differential signal and SE0 detection
    wire diff_val = !usb_rx_dp && usb_rx_dm;
    wire is_se0 = !usb_rx_dp && !usb_rx_dm;

    // Synchronize and denoise signals
    reg [2:0] diff_val_r, is_se0_r;
    always @(posedge clk) is_se0_r <= {is_se0_r[1:0], is_se0};
    always @(posedge clk) diff_val_r <= {diff_val_r[1:0], diff_val};

    wire rx_val = diff_val_r[1];
    wire se0 = (is_se0_r[2:1] == 2'b11);

    // Clock recovery
    reg [4:0] clk_div_cnt_r;
    wire clk_div_pulse = (clk_div_cnt_r == (usb_speed ? 5'd2 : 5'd16));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div_cnt_r <= 5'd0;
            
        end else begin
            if (diff_val_r[2] != diff_val_r[1] || (clk_div_cnt_r == 0)) begin
                clk_div_cnt_r <= usb_speed ? 5'd3 : 5'd31;
            end else begin
                clk_div_cnt_r <= clk_div_cnt_r - 5'd1;
            end
        end
    end

    // Sync detect
    reg [6:0] sync_shift_reg_r;
    always @(posedge clk)
        if (clk_div_pulse)
            sync_shift_reg_r <= {sync_shift_reg_r[5:0], rx_val || se0};

    wire sync = (sync_shift_reg_r == 7'b0101010 && !rx_val && !se0);

    reg [0:0] state_r;
    parameter IDLE = 1'b0, DATA = 1'b1;

    reg [7:0] rx_shift_reg_r;
    reg [2:0] bit_cnt_r, one_cnt_r;
    reg prev_rx_val_r;
    reg rx_valid_r;
    wire decoded_val = (prev_rx_val_r == rx_val);

    wire bit_stuffed = (one_cnt_r == 6);

    reg crc_reset_r, crc_enable_r;
    wire crc_data_valid = crc_enable_r && !bit_stuffed && clk_div_pulse;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r        <= IDLE;
            rx_valid_r     <= 1'b0;
            prev_rx_val_r  <= 1'b1;
            crc_reset_r    <= 1'b0;
            rx_shift_reg_r <= 8'd0;
            one_cnt_r      <= 3'd0;
            crc_enable_r   <= 1'b0;
            bit_cnt_r      <= 3'd0;

        end else begin
            rx_valid_r  <= 1'b0;
            crc_reset_r <= 1'b0;

            if (se0) begin
                state_r       <= IDLE;
                prev_rx_val_r <= 1'b1;

            end else if (clk_div_pulse) begin
                prev_rx_val_r <= rx_val;

                case (state_r)
                    IDLE: begin
                        crc_enable_r <= 1'b0;
                        one_cnt_r    <= 3'b0;
                        bit_cnt_r    <= 3'b0;

                        if (sync) begin
                            state_r     <= DATA;
                            crc_reset_r <= 1'b1;
                        end
                    end

                    DATA: begin
                        if (bit_stuffed) begin
                            one_cnt_r <= 0;

                        end else begin
                            if (bit_cnt_r == 3'd7) begin
                                rx_valid_r   <= 1'b1;
                                crc_enable_r <= 1'b1;
                            end

                            if (decoded_val) begin
                                one_cnt_r <= one_cnt_r + 3'd1;
                            end else begin
                                one_cnt_r <= 3'd0;
                            end

                            rx_shift_reg_r <= {decoded_val, rx_shift_reg_r[7:1]};
                            bit_cnt_r      <= bit_cnt_r + 3'd1;
                        end
                    end

                    default: state_r <= IDLE;
                endcase

            end
        end
    end

    assign rx_data   = rx_shift_reg_r;
    assign rx_valid  = rx_valid_r;
    assign rx_active = (state_r != IDLE);

    wire [15:0] crc16_result;
    assign crc16_valid = (crc16_result == 16'b1000000000001101);

    usb_crc16 crc16(
        .clk(clk),
        .rst(crc_reset_r),
        .data(decoded_val),
        .data_valid(crc_data_valid),
        .result(crc16_result));

endmodule
