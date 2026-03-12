`default_nettype none
module pwm
#(
  parameter CLK_FREQ = 100_000_000,
  parameter PWM_FREQ = 20_000,
  parameter MAX_DUTY_CYCLE_CNTR_VAL = $clog2(CLK_FREQ/PWM_FREQ),
  localparam PWM_MAX_CNT = int'(CLK_FREQ/PWM_FREQ)
)
(
  input  wire           rst_n,  // Active low reset
  input  wire           clk,    // 100 MHz, ~83.33ns
  
  input  wire  [MAX_DUTY_CYCLE_CNTR_VAL-1:0] i_duty_cycle,
  output logic                               o_pwm
);

    logic [MAX_DUTY_CYCLE_CNTR_VAL-1:0] pwm_cnt = '0;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            pwm_cnt <= '0;
            o_pwm   <= 1'b0;
        end else begin
            pwm_cnt <= pwm_cnt < PWM_MAX_CNT[MAX_DUTY_CYCLE_CNTR_VAL-1:0] ? pwm_cnt + 1 : '0;
            o_pwm <= (pwm_cnt > i_duty_cycle) ? (1'b0) : (1'b1);
        end 
    end
endmodule
`default_nettype wire