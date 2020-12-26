// `default_nettype none
module usb_tx(
    input  wire       rst,
    input  wire       clk,

    input  wire       tx_only_eop,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,

    output wire       tx_bit_pulse,

    input  wire       usb_speed,    // 0:low-speed (1.5Mbps), 1:full-speed (12Mbps)

    output reg        usb_tx_dp,
    output reg        usb_tx_dm,
    output reg        usb_tx_oe,

    output reg        is_sof_eop);

    //
    // Clock divider
    //
    reg [4:0] div_cnt_r;
    reg pre_div_pulse_r, div_pulse_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt_r       <= 5'd0;
            pre_div_pulse_r <= 1'b0;
            div_pulse_r     <= 1'b0;
            
        end else begin
            pre_div_pulse_r <= 1'b0;
            div_pulse_r     <= 1'b0;

            if (div_cnt_r == 5'd1)
                pre_div_pulse_r <= 1'b1;

            if (div_cnt_r == 5'd0) begin
                div_cnt_r   <= usb_speed ? 5'd3 : 5'd31;
                div_pulse_r <= 1;
            end else begin
                div_cnt_r <= div_cnt_r - 5'd1;
            end
        end
    end

    assign tx_bit_pulse = div_pulse_r;

    //
    // State machine
    //
    parameter IDLE = 3'b000, DATA = 3'b001, EOP = 3'b010, EOP2 = 3'b011, EOP3 = 3'b100, DONE = 3'b101;
    reg [2:0] state_r;
    reg [7:0] hold_reg_r;
    reg [2:0] bitcnt_r;
    reg [2:0] onecnt_r;
    reg tx_valid_r;
    reg stop_r;
    reg nrzi_r;
    reg se0_r;
    reg oe_r;

    reg only_eop_r;

    wire current_bit = hold_reg_r[bitcnt_r];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r    <= IDLE;
            tx_ready   <= 1'b0;
            tx_valid_r <= 1'b0;
            stop_r     <= 1'b0;
            onecnt_r   <= 3'b0;
            nrzi_r     <= 1'b1;
            se0_r      <= 1'b0;
            oe_r       <= 1'b0;
            only_eop_r <= 1'b0;
            hold_reg_r <= 8'h0;
            bitcnt_r   <= 3'd0;
            is_sof_eop <= 1'b0;

        end else begin
            tx_ready   <= 1'b0;
            tx_valid_r <= tx_valid;

            if (tx_valid_r && !tx_valid) begin
                stop_r <= 1'b1;
            end

            case (state_r)
                IDLE: begin
                    se0_r      <= 1'b0;
                    oe_r       <= 1'b0;
                    only_eop_r <= tx_only_eop;
                    is_sof_eop <= 1'b0;

                    if (tx_only_eop) begin
                        state_r <= EOP;

                    end else if (tx_valid && div_pulse_r) begin
                        hold_reg_r <= 8'h80;
                        bitcnt_r   <= 0;
                        state_r    <= DATA;
                        stop_r     <= 1'b0;
                        nrzi_r     <= 1'b0;
                        se0_r      <= 1'b0;
                        oe_r       <= 1'b1;
                    end
                end

                DATA: begin
                    if (pre_div_pulse_r) begin
                        if (onecnt_r != 6) begin
                            if (bitcnt_r == 7) begin
                                hold_reg_r <= tx_data;
                                bitcnt_r <= 0;

                                if (!stop_r) begin
                                    tx_ready <= 1'b1;
                                end

                            end else begin
                                bitcnt_r <= bitcnt_r + 3'd1;
                            end
                        end

                    end else if (div_pulse_r) begin
                        if (onecnt_r == 6) begin
                            onecnt_r <= 3'b0;

                            nrzi_r <= !nrzi_r;
                        end else begin
                            if (current_bit)
                                onecnt_r <= onecnt_r + 3'd1;
                            else
                                onecnt_r <= 3'b0;

                            if (!current_bit)
                                nrzi_r <= !nrzi_r;

                            if (bitcnt_r == 7 && stop_r) begin
                                state_r <= EOP;
                            end
                        end
                    end
                end

                EOP: begin
                    is_sof_eop <= only_eop_r;

                    if (div_pulse_r) begin
                        oe_r    <= 1'b1;
                        se0_r   <= 1'b1;
                        state_r <= EOP2;
                    end
                end

                EOP2: begin
                    if (div_pulse_r) begin
                        se0_r   <= 1'b1;
                        state_r <= EOP3;
                    end
                end

                EOP3: begin
                    if (div_pulse_r) begin
                        se0_r   <= 1'b0;
                        nrzi_r  <= 1'b1;
                        state_r <= DONE;
                    end
                end

                DONE: begin
                    if (div_pulse_r) begin
                        oe_r    <= 0;
                        state_r <= IDLE;
                    end
                end

                default:
                    state_r <= IDLE;

            endcase
        end
    end

    always @(posedge clk) begin
        usb_tx_dp <= se0_r ? 0 : !nrzi_r;
        usb_tx_dm <= se0_r ? 0 : nrzi_r;
        usb_tx_oe <= oe_r;
    end

endmodule
