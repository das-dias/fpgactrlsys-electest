module prog_gain_controller #(
    // Set parameter at module declaration, or keep as internal localparam
    localparam int WAIT_CYCLES = 2 
)(
    input  logic       clk,
    input  logic       rstb,
    input  logic       enb,          // Active-high disable (0 for normal operation)

    // Gain programming interface
    input  logic       pga_gain_we,
    input  logic [7:0] gain_data,

    // I2C interface
    output logic       i2c_cse_n,
    output logic       i2c_sda,
    output logic       i2c_scl
);

    // ============================================================
    // Edge Detection for pga_gain_we
    // ============================================================
    logic pga_gain_we_d;
    logic pga_gain_pe;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            pga_gain_we_d <= 1'b0;
        end else begin
            pga_gain_we_d <= pga_gain_we;
        end
    end

    assign pga_gain_pe = pga_gain_we && !pga_gain_we_d;

    // ============================================================
    // PGA Control Signals & ROM
    // ============================================================
    logic [3:0]  gain_index;
    logic [15:0] i2c_data;

    localparam logic [15:0] I2C_ROM [0:9] = '{
        16'h0000, // Index 0
        16'h0001, // Index 1
        16'h0002, // Index 2
        16'h0003, // Index 3
        16'h0007, // Index 4
        16'h000F, // Index 5
        16'h0017, // Index 6
        16'h001F, // Index 7
        16'h003F, // Index 8
        16'h007F  // Index 9
    };

    // Combinational ROM lookup
    assign i2c_data = I2C_ROM[gain_index];

    // ============================================================
    // I2C Serializer
    // ============================================================
    logic i2c_write;
    logic i2c_busy;

    i2cmaster #(
        .REFERENCE_CLK_FREQ (100_000_000),
        .OPERATING_SCL_FREQ (5_000_000),
        .WIDTH              (16),
        .LSB_FIRST          (1'b1)
    ) i2c0 (
        .clk       (clk),
        .rstb      (rstb),
        .write     (i2c_write),
        .d_in      (i2c_data),
        .busy      (i2c_busy),
        .i2c_cse_n (i2c_cse_n),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl)
    );

    // ============================================================
    // FSM with Parameterized Wait Delay
    // ============================================================
    typedef enum logic [2:0] {
        IDLE,
        WAIT_CLKS,
        START_I2C,
        WAIT_BUSY_HIGH,
        WAIT_BUSY_LOW
    } state_t;

    state_t state;
    
    // Automatically sized counter based on WAIT_CYCLES
    localparam int CNT_WIDTH = (WAIT_CYCLES > 0) ? $clog2(WAIT_CYCLES) : 1;
    logic [CNT_WIDTH-1:0] delay_cnt;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            state      <= IDLE;
            gain_index <= 4'd0;
            i2c_write  <= 1'b0;
            delay_cnt  <= '0;
        end else if (enb) begin
            state      <= IDLE;
            i2c_write  <= 1'b0;
            delay_cnt  <= '0;
        end else begin
            i2c_write <= 1'b0; // Default pulse output

            case (state)
                IDLE: begin
                    if (pga_gain_pe) begin
                        if (WAIT_CYCLES == 0) begin
                            gain_index <= (gain_data[3:0] < 4'd10) ? gain_data[3:0] : 4'd0;
                            state      <= START_I2C;
                        end else begin
                            delay_cnt <= (WAIT_CYCLES - 1);
                            state     <= WAIT_CLKS;
                        end
                    end
                end

                WAIT_CLKS: begin
                    if (delay_cnt != '0) begin
                        delay_cnt <= delay_cnt - 1'b1;
                    end else begin
                        // Latch gain_data after WAIT_CYCLES clock delay
                        gain_index <= (gain_data[3:0] < 4'd10) ? gain_data[3:0] : 4'd0;
                        state      <= START_I2C;
                    end
                end

                START_I2C: begin
                    i2c_write <= 1'b1;
                    state     <= WAIT_BUSY_HIGH;
                end

                WAIT_BUSY_HIGH: begin
                    if (i2c_busy) begin
                        state <= WAIT_BUSY_LOW;
                    end
                end

                WAIT_BUSY_LOW: begin
                    if (!i2c_busy) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
