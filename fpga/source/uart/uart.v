// `default_nettype none
module uart(
    input  wire        rst,
    input  wire        clk,

    // Data interface
    input  wire [15:0] baudrate_div,

    input  wire  [7:0] tx_data,
    input  wire        tx_valid,
    output wire        tx_busy,

    output wire  [7:0] rxfifo_data,
    output wire        rxfifo_not_empty,
    input  wire        rxfifo_read,

    // UART interface
    input  wire        uart_rst,
    input  wire        uart_clk,

    input  wire        uart_rxd,
    output wire        uart_txd);

    //////////////////////////////////////////////////////////////////////////
    // UART TX - 'clk' clock domain
    //////////////////////////////////////////////////////////////////////////
    reg [7:0] tx_data_r;
    reg       tx_busy_r;
    reg       tx_start_r;
    wire      tx_done;

    wire uart_tx_busy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_data_r  <= 8'b0;
            tx_busy_r  <= 1'b0;
            tx_start_r <= 1'b0;

        end else begin
            tx_start_r <= 1'b0;

            if (tx_valid && !tx_busy_r) begin
                tx_data_r  <= tx_data;
                tx_busy_r  <= 1'b1;
                tx_start_r <= 1'b1;
            end else if (tx_done) begin
                tx_busy_r <= 1'b0;
            end
        end
    end

    assign tx_busy = tx_busy_r;

    wire tx_start;
    pulse2pulse p2p_tx_start(.in_clk(clk), .in_pulse(tx_start_r), .out_clk(uart_clk), .out_pulse(tx_start));

    //////////////////////////////////////////////////////////////////////////
    // UART TX - 'uart_clk' clock domain
    //////////////////////////////////////////////////////////////////////////
    uart_tx uart_tx(
        .clk(uart_clk),
        .rst(uart_rst),
        .baudrate_div(baudrate_div),
        .uart_txd(uart_txd),
        .tx_data(tx_data),
        .tx_valid(tx_start),
        .tx_busy(uart_tx_busy));

    reg [1:0] uart_tx_busy_r;
    always @(posedge uart_clk) uart_tx_busy_r <= {uart_tx_busy_r[0], uart_tx_busy};
    wire uart_tx_done = (uart_tx_busy_r == 2'b10);

    pulse2pulse p2p_tx_done(.in_clk(uart_clk), .in_pulse(uart_tx_done), .out_clk(clk), .out_pulse(tx_done));

    //////////////////////////////////////////////////////////////////////////
    // UART RX - 'clk' clock domain
    //////////////////////////////////////////////////////////////////////////
    wire       rxfifo_empty;
    reg  [7:0] rx_data_r;
    wire       rx_valid;

    uart_rx_fifo uart_rx_fifo(
	    .clk(clk),
        .rst(rst),

    	.wrdata(rx_data_r),
	    .wr_en(rx_valid),

        .rddata(rxfifo_data),
    	.rd_en(rxfifo_read),

    	.empty(rxfifo_empty),
    	.full());

    assign rxfifo_not_empty = !rxfifo_empty;

    //////////////////////////////////////////////////////////////////////////
    // UART RX - 'uart_clk' clock domain
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] rx_data;
    wire       uart_rx_valid;

    uart_rx uart_rx(
        .clk(uart_clk),
        .rst(uart_rst),
        .baudrate_div(baudrate_div),
        .uart_rxd(uart_rxd),
        .rx_data(rx_data),
        .rx_valid(uart_rx_valid));

    always @(posedge uart_clk) if (rx_valid) rx_data_r <= rx_data;
    pulse2pulse p2p_rx_valid(.in_clk(uart_clk), .in_pulse(uart_rx_valid), .out_clk(clk), .out_pulse(rx_valid));


endmodule
