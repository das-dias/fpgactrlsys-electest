`default_nettype none
module arty_s7_hello_world_toplevel #(
    parameter CLK_FREQ = 12_000_000,

    localparam RLED_PWM_FREQ = 5_000,
    localparam RLED_PWM_DCYCLE = int'(0.15*CLK_FREQ/RLED_PWM_FREQ),
    localparam GLED_PWM_FREQ = 10_000,
    localparam GLED_PWM_DCYCLE = int'(0.10*CLK_FREQ/GLED_PWM_FREQ),
    localparam BLED_PWM_FREQ = 20_000,
    localparam BLED_PWM_DCYCLE = int'(0.05*CLK_FREQ/BLED_PWM_FREQ)
)(
    input  wire        rst_n,  // reset, active low (top right, red button)
    input  wire        clk_12mhz,  // 12 MHz, ~10.00ns
    
    input  wire  [3:0] sw,  // Switches
    input  wire  [3:0] btn, // buttons
    
    output logic [3:0] led,
    output logic       led0_r,
    output logic       led0_g,
    output logic       led0_b,
    output logic       led1_r,
    output logic       led1_g,
    output logic       led1_b,

    output logic [7:0] ja
);
    
    logic [23:0] rled_cnt = '0;  // 1s -> 12e6 -> log2(): 24bits
    
    logic rled_pwm;
    logic gled_pwm;
    logic bled_pwm;

    logic o_clk_en_latch;


    // TODO: put clock wizard here


    // clock gating:
    always_ff @(negedge clk_12mhz) begin
        o_clk_en_latch <= sw[0] ? '1 : '0;
    end
    assign ja[0] = o_clk_en_latch & clk_12mhz;

    
    always_ff @( posedge clk_12mhz or negedge rst_n ) begin : rled_cnt_proc
        if (!rst_n) begin
            rled_cnt  <= '0;
            led       <= '0;
        end else begin
            rled_cnt <= rled_cnt + 1;
            led      <= sw;
        end 
    end // rled_cnt_proc

    /* verilator lint_off WIDTHTRUNC */
    pwm
    #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(RLED_PWM_FREQ)
    )
    rled_pwm_inst
    (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .i_duty_cycle(RLED_PWM_DCYCLE),
        .o_pwm(rled_pwm)
    );
    assign led0_r = (rled_cnt[23] == 1'b1) ? (rled_pwm) : (1'b0);
    assign led1_r = (rled_cnt[22] == 1'b1) ? (rled_pwm) : (1'b0);
    
    /* verilator lint_off WIDTHTRUNC */
    pwm
    #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(GLED_PWM_FREQ)
    )
    gled_pwm_inst
    (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .i_duty_cycle(GLED_PWM_DCYCLE),
        .o_pwm(gled_pwm)
    );
    assign led0_g = (btn[0]==1'b1) ? (gled_pwm) : (1'b0);
    assign led1_g = (btn[1]==1'b1) ? (gled_pwm) : (1'b0);
    
    /* verilator lint_off WIDTHTRUNC */
    pwm
    #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(BLED_PWM_FREQ)
    )
    bled_pwm_inst
    (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .i_duty_cycle(BLED_PWM_DCYCLE),
        .o_pwm(bled_pwm)
    );
    assign led0_b = (btn[2]==1'b1) ? (bled_pwm) : (1'b0);
    assign led1_b = (btn[3]==1'b1) ? (bled_pwm) : (1'b0);
    
endmodule

`default_nettype wire