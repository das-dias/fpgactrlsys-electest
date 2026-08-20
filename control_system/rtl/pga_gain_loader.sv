module pga_gain_loader (
    input  logic       clk,
    input  logic       rstb,
    input  logic       enb,

    // Gain programming interface
    input  logic       pga_gain_we,
    input  logic [7:0] gain_data,       // Renamed from watchdog_data for clarity

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

    // High for 1 clock cycle on rising edge of pga_gain_we
    assign pga_gain_pe = pga_gain_we && !pga_gain_we_d;

    // ============================================================
    // PGA control & ROM Lookup
    // ============================================================
    logic [3:0]  gain_index; // 4-bit index to cover 10 gain entries (0-9)
    logic [15:0] i2c_data;

    // Constant ROM lookup for 10 PGA gain words (16-bit wide)
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

    // Synchronous gain index capture on rising edge
    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            gain_index <= 4'b0000;
        end else if (pga_gain_pe) begin
            if (gain_data[3:0] < 4'd10) begin
                gain_index <= gain_data[3:0];
            end else begin
                gain_index <= 4'b0000;
            end
        end
    end

    // ============================================================
    // I2C serializer signals
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
    // FSM
    // ============================================================
    typedef enum logic [1:0] {
        IDLE,
        START_I2C,
        WAIT_BUSY_HIGH,
        WAIT_BUSY_LOW
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            state     <= IDLE;
            i2c_data  <= 16'h0000;
            i2c_write <= 1'b0;
        end else begin
            // Default pulse output
            i2c_write <= 1'b0;

            if (enb) begin
                state    <= IDLE;
                i2c_data <= 16'h0000;
            end else begin
                case (state)
                    IDLE: begin
                        // Trigger I2C packet write on pga_gain_we rising edge
                        if (pga_gain_pe) begin
                            // Use incoming data if valid, else default to index 0
                            if (gain_data[3:0] < 4'd10) begin
                                i2c_data <= I2C_ROM[gain_data[3:0]];
                            end else begin
                                i2c_data <= I2C_ROM[0];
                            end
                            state <= START_I2C;
                        end
                    end

                    START_I2C: begin
                        i2c_write <= 1'b1;
                        state     <= WAIT_BUSY_HIGH;
                    end

                    WAIT_BUSY_HIGH: begin
                        if (i2c_busy)
                            state <= WAIT_BUSY_LOW;
                    end

                    WAIT_BUSY_LOW: begin
                        if (!i2c_busy) begin
                            state <= IDLE;
                        end
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
