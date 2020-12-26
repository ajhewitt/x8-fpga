// `default_nettype none
module usbhost(
    input  wire       rst,
    input  wire       clk,

    // Register interface
    input  wire [1:0] port1_mode,
    output wire [1:0] port1_dpdm,
    input  wire [2:0] port1_addr,

    input  wire [1:0] port2_mode,
    output wire [1:0] port2_dpdm,
    input  wire [2:0] port2_addr,

    output wire       crc16_valid,
    output wire       timeout,
    output reg        busy,

    input  wire       xfer_reset,

    output wire       xfer_done_pulse,
    output wire       sof_pulse,

    input  wire [3:0] xfer_endpoint,
    input  wire [1:0] xfer_type,
    input  wire       xfer_data_type,
    input  wire       xfer_port,
    input  wire       xfer_start,

    input  wire [7:0] txfifo_data,
    input  wire       txfifo_write,

    output wire [7:0] rxfifo_data,
    input  wire       rxfifo_read,
    output wire       rxfifo_not_empty,

    // USB interfaces
    input  wire       usb_rst,
    input  wire       usb_clk,

    inout  wire       usb1_dp,
    inout  wire       usb1_dm,

    inout  wire       usb2_dp,
    inout  wire       usb2_dm);

    wire usb_tx_dp, usb_tx_dm, usb_tx_oe;
    wire is_sof_eop;

    //////////////////////////////////////////////////////////////////////////
    // IO conversion
    //////////////////////////////////////////////////////////////////////////

    // USB1: Bidirectional I/O conversion
    wire usb_tx_dp1 = (port1_mode == 2'd1) ? 1'b0 : usb_tx_dp;
    wire usb_tx_dm1 = (port1_mode == 2'd1) ? 1'b0 : usb_tx_dm;
    wire usb_tx_oe1 = (port1_mode == 2'd1) ? 1'b1 : (port1_mode[1] && (xfer_port == 0 || is_sof_eop) && usb_tx_oe);

    assign usb1_dp = usb_tx_oe1 ? usb_tx_dp1 : 1'bz;
    assign usb1_dm = usb_tx_oe1 ? usb_tx_dm1 : 1'bz;
    wire usb_rx_dp1 = usb1_dp;
    wire usb_rx_dm1 = usb1_dm;

    // USB2: Bidirectional I/O conversion
    wire usb_tx_dp2 = (port2_mode == 2'd1) ? 1'b0 : usb_tx_dp;
    wire usb_tx_dm2 = (port2_mode == 2'd1) ? 1'b0 : usb_tx_dm;
    wire usb_tx_oe2 = (port2_mode == 2'd1) ? 1'b1 : (port2_mode[1] && (xfer_port == 1 || is_sof_eop) && usb_tx_oe);

    assign usb2_dp = usb_tx_oe2 ? usb_tx_dp2 : 1'bz;
    assign usb2_dm = usb_tx_oe2 ? usb_tx_dm2 : 1'bz;
    wire usb_rx_dp2 = usb2_dp;
    wire usb_rx_dm2 = usb2_dm;

    // USB1: Synchronize RX signals
    reg [3:0] rx_dp1_r, rx_dm1_r;
    always @(posedge clk) rx_dp1_r <= {rx_dp1_r[2:0], usb_rx_dp1};
    always @(posedge clk) rx_dm1_r <= {rx_dm1_r[2:0], usb_rx_dm1};

    // only capture stable signal
    reg rx_dp1_synced, rx_dm1_synced;
    always @(posedge clk)
        if (rx_dp1_r[3] == rx_dp1_r[2] && rx_dm1_r[3] == rx_dm1_r[2]) begin
            rx_dp1_synced <= rx_dp1_r[3];
            rx_dm1_synced <= rx_dm1_r[3];
        end

    assign port1_dpdm = {rx_dp1_synced, rx_dm1_synced};

    // USB2: Synchronize RX signals
    reg [3:0] rx_dp2_r, rx_dm2_r;
    always @(posedge clk) rx_dp2_r <= {rx_dp2_r[2:0], usb_rx_dp2};
    always @(posedge clk) rx_dm2_r <= {rx_dm2_r[2:0], usb_rx_dm2};

    // only capture stable signal
    reg rx_dp2_synced, rx_dm2_synced;
    always @(posedge clk)
        if (rx_dp2_r[3] == rx_dp2_r[2] && rx_dm2_r[3] == rx_dm2_r[2]) begin
            rx_dp2_synced <= rx_dp2_r[3];
            rx_dm2_synced <= rx_dm2_r[3];
        end

    assign port2_dpdm = {rx_dp2_synced, rx_dm2_synced};

    //////////////////////////////////////////////////////////////////////////
    // Registers
    //////////////////////////////////////////////////////////////////////////

    // Bus registers
    wire [6:0] per_addr = (xfer_port == 0) ? {4'b0, port1_addr} : {4'b0, port2_addr};

    wire rx_crc16_valid;
    reg  rx_crc16_valid_r;
    assign crc16_valid = rx_crc16_valid_r;

    wire is_timeout;
    assign timeout = is_timeout;

    reg sof_pulse_r;
    pulse2pulse p2p_sof(.in_clk(usb_clk), .in_pulse(sof_pulse_r), .out_clk(clk), .out_pulse(sof_pulse));

    reg xfer_done_pulse_r;
    pulse2pulse p2p_xfer_done(.in_clk(usb_clk), .in_pulse(xfer_done_pulse_r), .out_clk(clk), .out_pulse(xfer_done_pulse));

    wire xfer_do_start;
    pulse2pulse p2p_xfer_start(.in_clk(clk), .in_pulse(xfer_start), .out_clk(usb_clk), .out_pulse(xfer_do_start));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            
        end else begin
            if (xfer_start) begin
                busy <= 1'b1;
            end
            if (xfer_done_pulse) begin
                busy <= 1'b0;
            end
        end
    end

    parameter TT_SETUP = 0, TT_IN = 1, TT_OUT = 2;

    //////////////////////////////////////////////////////////////////////////
    // TX FIFO
    //////////////////////////////////////////////////////////////////////////
    reg        txfifo_read_r;
    wire       txfifo_read;

    wire [7:0] txfifo_rddata;
    wire       txfifo_empty;
    pulse2pulse p2p_txfifo_read(.in_clk(usb_clk), .in_pulse(txfifo_read_r), .out_clk(clk), .out_pulse(txfifo_read));

    wire txfifo_reset = rst || xfer_reset;

    fifo_512x8 usb_txfifo(
        .clk(clk),
        .rst(txfifo_reset),

        .wrdata(txfifo_data),
        .wr_en(txfifo_write),

        .rddata(txfifo_rddata),
        .rd_en(txfifo_read),

        .empty(txfifo_empty),
        .full());

    //////////////////////////////////////////////////////////////////////////
    // RX FIFO
    //////////////////////////////////////////////////////////////////////////
    reg [7:0] rxfifo_wrdata_r;
    reg       rxfifo_write_r;
    wire      rxfifo_write;
    wire      rxfifo_empty;

    pulse2pulse p2p_rxfifo_write(.in_clk(usb_clk), .in_pulse(rxfifo_write_r), .out_clk(clk), .out_pulse(rxfifo_write));

    wire rxfifo_reset = rst || xfer_reset || xfer_start;

    fifo_512x8 usb_rxfifo(
        .clk(clk),
        .rst(rxfifo_reset),

        .wrdata(rxfifo_wrdata_r),
        .wr_en(rxfifo_write),

        .rddata(rxfifo_data),
        .rd_en(rxfifo_read),

        .empty(rxfifo_empty),
        .full());
    
    assign rxfifo_not_empty = !rxfifo_empty;

    //////////////////////////////////////////////////////////////////////////
    // USB control logic
    //////////////////////////////////////////////////////////////////////////

    reg [7:0] tx_data_r;
    reg       tx_valid;
    reg       tx_only_eop;
    wire      tx_ready, tx_bit_pulse;

    // Receiver
    wire [7:0] rx_data;
    wire       rx_valid, rx_active;
    reg        rx_active_r;

    always @(posedge usb_clk) rx_active_r <= rx_active;

    //
    // 1ms Start-of-Frame timer
    //
    reg [15:0] sof_timer_r;

    always @(posedge usb_clk or posedge usb_rst) begin
        if (usb_rst) begin
            sof_timer_r <= 16'd100;
            sof_pulse_r <= 0;

        end else begin
            sof_pulse_r <= 0;

            if (sof_timer_r == 0) begin
                sof_pulse_r <= 1;
                sof_timer_r <= 48000 - 1; // 1ms @ 48MHz

            end else begin
                sof_timer_r <= sof_timer_r - 16'd1;
            end
        end
    end

    parameter
        PID_OUT   = 4'b0001,
        PID_IN    = 4'b1001,
        PID_SOF   = 4'b0101,
        PID_SETUP = 4'b1101,
        PID_DATA0 = 4'b0011,
        PID_DATA1 = 4'b1011,
        PID_ACK   = 4'b0010,
        PID_NAK   = 4'b1010,
        PID_STALL = 4'b1110,
        PID_PRE   = 4'b1100;

    reg  [3:0] pid_r;
    reg [10:0] token_data_r;
    wire [4:0] token_crc5_result;
    usb_crc5_11 token_crc5(
        .data_in(token_data_r),
        .result(token_crc5_result));

    parameter
        IDLE = 4'd0,
        TOKEN = 4'd1, TOKEN_DATA0 = 4'd2, TOKEN_DATA1 = 4'd3, TOKEN_DONE = 4'd4,
        TX_DATA = 4'd5, TX_DATA_PAYLOAD = 4'd6, TX_DATA_CRC_H = 4'd7, TX_DATA_CRC_L = 4'd8, TX_DATA_DONE = 4'd9,
        WAIT_RX = 4'd11, RX_DATA = 4'd12, SEND_ACK = 4'd13, SEND_ACK2 = 4'd14;

    reg [3:0] state_r;
    reg sof_required_r;

    reg [3:0] state_after_token_r;

    reg crc16_reset_r, crc16_data_valid_r;
    wire [15:0] crc16_result;

    reg sof_sent_r;
    reg send_ack_after_rx_r;
    reg [2:0] ack_delay_cnt_r;

    reg [4:0] timeout_cnt_r;
    assign is_timeout = (timeout_cnt_r == 5'd0);

    reg xfer_started;

    always @(posedge usb_clk or posedge usb_rst) begin
        if (usb_rst) begin
            state_r             <= IDLE;
            sof_required_r      <= 0;
            xfer_done_pulse_r   <= 1'b0;
            state_after_token_r <= IDLE;
            sof_sent_r          <= 1'b0;
            rx_crc16_valid_r    <= 1'b0;
            send_ack_after_rx_r <= 1'b0;
            tx_valid            <= 1'b0;
            tx_only_eop         <= 1'b0;
            tx_data_r           <= 8'b0;
            token_data_r        <= 11'b0;
            timeout_cnt_r       <= 5'b0;
            pid_r               <= 4'b0;
            txfifo_read_r       <= 1'b0;
            rxfifo_wrdata_r     <= 8'b0;
            rxfifo_write_r      <= 1'b0;
            crc16_reset_r       <= 1'b0;
            crc16_data_valid_r  <= 1'b0;
            ack_delay_cnt_r     <= 3'b0;
            xfer_started        <= 1'b0;

        end else begin
            txfifo_read_r      <= 1'b0;
            rxfifo_write_r     <= 1'b0;
            tx_only_eop        <= 0;
            xfer_done_pulse_r  <= 1'b0;
            crc16_reset_r      <= 1'b0;
            crc16_data_valid_r <= 1'b0;

            if (sof_pulse_r) begin
                sof_required_r <= 1;
            end

            case (state_r)
                IDLE: begin
                    state_after_token_r <= IDLE;
                    send_ack_after_rx_r <= 1'b0;

                    if (sof_required_r || sof_pulse_r) begin
                        sof_required_r <= 0;

                        tx_only_eop <= 1;
                        sof_sent_r <= 1'b1;

                    end else if (sof_sent_r && xfer_started) begin
                        xfer_started <= 1'b0;

                        // Start transfer
                        case (xfer_type)
                            TT_SETUP: begin
                                pid_r               <= PID_SETUP;
                                token_data_r        <= {xfer_endpoint, per_addr};
                                state_r             <= TOKEN;
                                state_after_token_r <= TX_DATA;
                            end

                            TT_OUT: begin
                                pid_r               <= PID_OUT;
                                token_data_r        <= {xfer_endpoint, per_addr};
                                state_r             <= TOKEN;
                                state_after_token_r <= TX_DATA;
                            end

                            TT_IN: begin
                                pid_r               <= PID_IN;
                                token_data_r        <= {xfer_endpoint, per_addr};
                                state_r             <= TOKEN;
                                state_after_token_r <= WAIT_RX;
                                send_ack_after_rx_r <= 1'b1;
                            end

                            default: begin
                                xfer_done_pulse_r <= 1'b1;
                            end
                        endcase

                    end else begin
                        sof_sent_r <= 1'b0;
                    end
                end

                TOKEN: begin
                    tx_valid  <= 1'b1;
                    tx_data_r <= {~pid_r, pid_r};
                    state_r   <= TOKEN_DATA0;
                end

                TOKEN_DATA0: begin
                    if (tx_ready) begin
                        tx_data_r <= token_data_r[7:0];
                        state_r   <= TOKEN_DATA1;
                    end
                end

                TOKEN_DATA1: begin
                    if (tx_ready) begin
                        tx_data_r <= {token_crc5_result, token_data_r[10:8]};
                        state_r   <= TOKEN_DONE;
                    end
                end

                TOKEN_DONE: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b0;

                        state_r       <= state_after_token_r;
                        timeout_cnt_r <= 5'd31;
                    end
                end

                //
                // DATA0/DATA1
                //
                TX_DATA: begin
                    tx_valid       <= 1'b1;
                    tx_data_r      <= (xfer_data_type == 0) ? {~PID_DATA0, PID_DATA0} : {~PID_DATA1, PID_DATA1};
                    crc16_reset_r  <= 1'b1;
                    state_r        <= TX_DATA_PAYLOAD;
                end

                TX_DATA_PAYLOAD: begin
                    if (txfifo_empty) begin
                        state_r <= TX_DATA_CRC_H;
                    end

                    if (tx_ready) begin
                        tx_data_r          <= txfifo_rddata;
                        txfifo_read_r      <= 1'b1;
                        crc16_data_valid_r <= 1;
                    end
                end

                TX_DATA_CRC_H: begin
                    if (tx_ready) begin
                        tx_data_r <= ~crc16_result[7:0];
                        state_r   <= TX_DATA_CRC_L;
                    end
                end

                TX_DATA_CRC_L: begin
                    if (tx_ready) begin
                        tx_data_r <= ~crc16_result[15:8];
                        state_r   <= TX_DATA_DONE;
                    end
                end

                TX_DATA_DONE: begin
                    if (tx_ready) begin
                        tx_valid      <= 1'b0;
                        timeout_cnt_r <= 5'd31;
                        state_r       <= WAIT_RX;
                    end
                end

                //
                // Get data from device
                //
                WAIT_RX: begin
                    rx_crc16_valid_r <= 1'b0;

                    if (tx_bit_pulse) begin
                        timeout_cnt_r <= timeout_cnt_r - 1;
                    end

                    if (!rx_active_r && rx_active) begin
                        state_r <= RX_DATA;
                    end

                    if (is_timeout) begin
                        state_r           <= IDLE;
                        xfer_done_pulse_r <= 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_active) begin
                        if (rx_valid) begin
                            rx_crc16_valid_r <= rx_crc16_valid;
                            rxfifo_wrdata_r <= rx_data;
                            rxfifo_write_r  <= 1'b1;
                        end

                    end else begin
                        if (send_ack_after_rx_r && rx_crc16_valid_r) begin
                            state_r         <= SEND_ACK;
                            ack_delay_cnt_r <= 3'd7;
                        end else begin
                            state_r           <= IDLE;
                            xfer_done_pulse_r <= 1'b1;
                        end
                    end
                end

                //
                // Send ACK after data RX
                //
                SEND_ACK: begin
                    if (ack_delay_cnt_r == 3'd0) begin
                        tx_valid  <= 1;
                        tx_data_r <= {~PID_ACK, PID_ACK};
                        state_r   <= SEND_ACK2;
                    end else if (tx_bit_pulse) begin
                        ack_delay_cnt_r <= ack_delay_cnt_r - 1;
                    end
                end

                SEND_ACK2: begin
                    if (tx_ready) begin
                        tx_valid        <= 0;
                        state_r         <= IDLE;
                        xfer_done_pulse_r <= 1'b1;
                    end
                end

                default: state_r <= state_after_token_r;
            endcase

            if (xfer_do_start) begin
                xfer_started <= 1'b1;
            end
        end
    end

    usb_crc16_8 crc16(
        .clk(usb_clk),
        .rst(crc16_reset_r),
        .data(tx_data_r),
        .data_valid(crc16_data_valid_r),
        .result(crc16_result));

    usb_tx usb_tx(
        .rst(usb_rst),
        .clk(usb_clk),
        .tx_only_eop(tx_only_eop),
        .tx_data(tx_data_r),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .tx_bit_pulse(tx_bit_pulse),
        .usb_speed(1'b0),
        .usb_tx_dp(usb_tx_dp),
        .usb_tx_dm(usb_tx_dm),
        .usb_tx_oe(usb_tx_oe),
        .is_sof_eop(is_sof_eop));

    wire usb_rx_dp = !xfer_port ? usb_rx_dp1 : usb_rx_dp2;
    wire usb_rx_dm = !xfer_port ? usb_rx_dm1 : usb_rx_dm2;

    usb_rx usb_rx(
        .rst(usb_rst),
        .clk(usb_clk),
        .usb_speed(1'b0),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_active(rx_active),
        .crc16_valid(rx_crc16_valid),
        .usb_rx_dp(usb_rx_dp),
        .usb_rx_dm(usb_rx_dm));

endmodule
