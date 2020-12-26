// `default_nettype none
module vga_pll(
    input  wire ref_clk_i,      // 48MHz
    input  wire rst_n_i,

    output wire outcore_o,
    output wire outglobal_o,   // 25MHz

    output wire lock_o);

    // Generate 25MHz clk
    reg clk = 0;
    always #20 clk = !clk;
    assign outglobal_o = clk;

    reg lock = 0;
    always #100 lock = 1;
    assign lock_o = lock;

endmodule
