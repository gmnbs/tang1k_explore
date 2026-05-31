
module led #(
    parameter CLK_FREQ          = 100000000,
    parameter UPDATE_RATE_HZ    = 2
) (
    input       clk_i,
    input       rst_n_i,

    output reg  led_r_o,
    output reg  led_g_o,
    output reg  led_b_o
);

localparam CW = $clog2(CLK_FREQ / UPDATE_RATE_HZ);            // Counter width
localparam MAX_COUNT = CLK_FREQ/UPDATE_RATE_HZ - 1;           // Terminal count = 0.5 s at CLK_FREQ Hz

reg [CW-1:0] counter;

always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        counter <= 0;

        led_r_o <= 1'b1;
        led_g_o <= 1'b1;
        led_b_o <= 1'b0;
    end
    else if (counter < MAX_COUNT[CW-1:0])
        counter <= counter + 1'b1;
    else begin
        counter <= 0;
        {led_r_o, led_g_o, led_b_o} <= {led_g_o, led_b_o, led_r_o};
    end
end

endmodule
