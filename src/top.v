`define SYS_CLK_FREQ 27000000   // Tang Nano 1K 27 MHz crystal (see led_prj.sdc)

module top (
    input   sys_clk,            // pin 47
    input   sys_rst_n,          // pin 13, active-low

    output  led_r,              // pin 10
    output  led_g,              // pin 11
    output  led_b               // pin 9
);

led #(
    .CLK_FREQ(`SYS_CLK_FREQ),
    .UPDATE_RATE_HZ(10)
) led_inst (
    .clk_i(sys_clk),
    .rst_n_i(sys_rst_n),
    .led_r_o(led_r),
    .led_g_o(led_g),
    .led_b_o(led_b)
);

endmodule
