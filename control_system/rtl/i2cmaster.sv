module i2cmaster #(
    parameter int REFERENCE_CLK_FREQ = 100_000_000, // Default 100 MHz
    parameter int OPERATING_SCL_FREQ = 5_000_000,   // Default 5 MHz
    parameter int WIDTH              = 16,          // Default 16 bits
    parameter bit LSB_FIRST          = 1'b1         // Default 1: LSB-first, 0: MSB-first
)(
    input  logic                 clk,
    input  logic                 rstb,
    input  logic                 write,
    input  logic [WIDTH-1:0]     d_in,

    output logic                 busy,

    output logic                 i2c_cse_n,
    output logic                 i2c_sda,
    output logic                 i2c_scl
);

    // ------------------------------------------------------------
    // Clock Divider Parameters
    // ------------------------------------------------------------
    localparam int DIV_HALF = REFERENCE_CLK_FREQ / (2 * OPERATING_SCL_FREQ);
    localparam int DIV_W    = (DIV_HALF > 1) ? $clog2(DIV_HALF) : 1;

    // Total half-cycles for exactly WIDTH bits = 2 * WIDTH (32 ticks for 16 bits = 16 SCL clock pulses)
    localparam int TOTAL_TICKS = 2 * WIDTH;
    localparam int TICK_W      = $clog2(TOTAL_TICKS + 1);

    // Internal Registers
    logic [DIV_W-1:0]  clk_cnt;
    logic [TICK_W-1:0] tick_cnt;
    logic [TICK_W-1:0] tick_cnt_prev;
    logic [WIDTH-1:0]  shift_reg;
    logic              scl_reg;
    logic              busy_reg;

    // ------------------------------------------------------------
    // Synchronous Glitch-Free Clock Divider (Enable Tick Generator)
    // ------------------------------------------------------------
    logic scl_tick;
    assign scl_tick = (clk_cnt == DIV_HALF - 1);
    
    
    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            clk_cnt <= '0;
        end else if (busy_reg) begin
            if (scl_tick) begin
                clk_cnt <= '0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= '0;
        end
    end

    // ------------------------------------------------------------
    // Sequential Control & Shift Register Logic
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            shift_reg <= '0;
            tick_cnt  <= '0;
            scl_reg   <= 1'b1;
            busy_reg  <= 1'b0;
        end else begin
            if (!busy_reg) begin
                if (write) begin
                    busy_reg  <= 1'b1;
                    shift_reg <= d_in;
                    tick_cnt  <= '0;
                    tick_cnt_prev  <= '0;
                    scl_reg   <= 1'b1; // Hold SCL High during PRE setup
                end
            end else if (scl_tick) begin
                if (tick_cnt == TOTAL_TICKS - 1) begin
                    // Transmission complete after exactly WIDTH SCL cycles (16 clocks)
                    scl_reg         <= 1'b1;
                    // busy_reg        <= 1'b0;
                    tick_cnt_prev   <= TOTAL_TICKS - 1;
                    tick_cnt        <= '0;
                end else if (tick_cnt == 0 && tick_cnt_prev == TOTAL_TICKS - 1) begin 
                    busy_reg        <= 1'b0;
                end else begin
                    scl_reg  <= ~scl_reg;
                    tick_cnt_prev <= tick_cnt;
                    tick_cnt <= tick_cnt + 1'b1;

                    // Shift data on SCL falling edge (scl_reg transitioning 1 -> 0)
                    if (scl_reg == 1'b1) begin
                        if (LSB_FIRST) begin
                            shift_reg <= shift_reg >> 1;
                        end else begin
                            shift_reg <= shift_reg << 1;
                        end
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Output Assignments
    // ------------------------------------------------------------
    assign busy      = busy_reg;
    
    // Active-LOW Enable: Guaranteed LOW (0) during transmission, HIGH (1) when idle
    assign i2c_cse_n = ~busy_reg;
    
    assign i2c_scl   = scl_reg;
    assign i2c_sda   = LSB_FIRST ? shift_reg[0] : shift_reg[WIDTH-1];

endmodule
