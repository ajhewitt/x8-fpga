// `default_nettype none
module sysctl(
    input  wire reset_in,

    input  wire sysclk_1,   // 48 MHz
    input  wire sysclk_2,   // 48 MHz

    output wire vga_clk,    // 25 MHz
    output wire vga_rst,

    output wire usb_clk,    // 48 MHz
    output wire usb_rst,

    output wire sys_clk,    // 12.5 MHz
    output wire sys_rst);

    //////////////////////////////////////////////////////////////////////////
    // PLL: 48MHz -> 25MHz
    //////////////////////////////////////////////////////////////////////////

    // Generate reset signal for PLL
    reg [3:0] pll_rst_cnt_r /* synthesis syn_keep=1 */ = 4'd0;
    always @(posedge sysclk_2) begin
        if (!pll_rst_cnt_r[3]) begin
            pll_rst_cnt_r <= pll_rst_cnt_r + 4'd1;
        end
    end

    // PLL: 48MHz -> 25MHz
    wire pll_lock;
    wire pll_rst_n = pll_rst_cnt_r[3];

    vga_pll vga_pll(
        .ref_clk_i(sysclk_1),
        .rst_n_i(pll_rst_n),
        .outcore_o(),
        .outglobal_o(vga_clk),
        .lock_o(pll_lock));

    //////////////////////////////////////////////////////////////////////////
    // System reset
    //////////////////////////////////////////////////////////////////////////

    wire rst_in = !pll_lock || reset_in || !pll_rst_cnt_r[3];

    // Generate reset signal
    reg [7:0] rst_cnt_r /* synthesis syn_keep=1 */ = 8'd0;
    wire rst = !rst_cnt_r[7];

    always @(posedge sysclk_2) begin
        if (rst_in) begin
            rst_cnt_r <= 8'd0;
        end else begin
            if (rst) begin
                rst_cnt_r <= rst_cnt_r + 8'd1;
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Generate 12.5MHz system clock
    //////////////////////////////////////////////////////////////////////////
    reg clk_div_r = 0;
    always @(posedge vga_clk) clk_div_r <= !clk_div_r;
    assign sys_clk = clk_div_r;

    //////////////////////////////////////////////////////////////////////////
    // USB clock
    //////////////////////////////////////////////////////////////////////////
    assign usb_clk = sysclk_2;

    //////////////////////////////////////////////////////////////////////////
    // Generate reset signals for system
    //////////////////////////////////////////////////////////////////////////
    reset_sync reset_sync_vga(.async_rst_in(rst), .clk(vga_clk), .reset_out(vga_rst));
    reset_sync reset_sync_sys(.async_rst_in(rst), .clk(sys_clk), .reset_out(sys_rst));
    reset_sync reset_sync_usb(.async_rst_in(rst), .clk(usb_clk), .reset_out(usb_rst));

endmodule
