module i2cmaster #(
    parameter int REFERENCE_CLK_FREQ = 100_000_000, // Default 100 MHz
    parameter int OPERATING_SCL_FREQ = 5_000_000,   // Default 5 MHz
    parameter int WIDTH              = 16          // Default 16 bits
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
    // Clock Divider Parameters & Local Parameters
    // ------------------------------------------------------------
    // Calculate system clock cycles per SCL half-period
    localparam int DIV_HALF = REFERENCE_CLK_FREQ / (2 * OPERATING_SCL_FREQ);
    localparam int DIV_W    = (DIV_HALF > 1) ? $clog2(DIV_HALF) : 1;

    // Total SCL ticks (half-cycles):
    // 2 ticks for PRE cycle (1 rising edge before data)
    // 2 * WIDTH ticks for DATA cycles
    // 2 ticks for POST cycle (1 rising edge after data)
    localparam int TOTAL_TICKS = (2 * WIDTH) + 4;
    localparam int TICK_W      = $clog2(TOTAL_TICKS + 1);

    // Internal Registers
    logic [DIV_W-1:0]    clk_cnt;
    logic [TICK_W-1:0]   tick_cnt;
    logic [WIDTH-1:0]    shift_reg;
    logic                scl_reg;
    logic                cse_n_reg;
    logic                busy_reg;

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
            cse_n_reg <= 1'b1;
            busy_reg  <= 1'b0;
        end else begin
            if (!busy_reg) begin
                if (write) begin
                    busy_reg  <= 1'b1;
                    cse_n_reg <= 1'b0; // Activate CSE 1 SCL rising edge before data
                    shift_reg <= d_in;
                    tick_cnt  <= '0;
                    scl_reg   <= 1'b1;
                end
            end else if (scl_tick) begin
                // Toggle SCL every half-period tick
                scl_reg  <= ~scl_reg;
                tick_cnt <= tick_cnt + 1'b1;

                if (tick_cnt == TOTAL_TICKS - 1) begin
                    // Complete post-data cycle and reset
                    busy_reg  <= 1'b0;
                    cse_n_reg <= 1 me1; // Deactivate CSE 1 SCL rising edge after data
                    scl_reg   <= 1'b1;
                end else if (scl_reg == 1'b1) begin
                    // On SCL falling edge (scl_reg transitioning 1 -> 0)
                    // Shift out next data bit after the initial PRE-cycle
                    if (tick_cnt > 2 && tick_cnt <= (2 * WIDTH + 1)) begin
                        shift_reg <= shift_reg << 1;
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Output Assignments
    // ------------------------------------------------------------
    assign busy      = busy_reg;
    assign i2c_cse_n = cse_n_reg;
    assign i2c_scl   = scl_reg;
    assign i2c_sda   = shift_reg[WIDTH-1]; // MSB-first transmission

endmodule
