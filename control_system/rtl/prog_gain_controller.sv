module prog_gain_controller (

    input  logic       clk,
    input  logic       rstb,
    input  logic       enb,

    // Watchdog programming interface
    input  logic       we,
    input  logic       lna_gain_we,
    input  logic       pga_gain_we,
    input  logic [7:0] watchdog_data,

    // I2C interface
    output logic       i2c_cse_n,
    output logic       i2c_sda,
    output logic       i2c_scl
);

    // ============================================================
    // Watchdog signals
    // ============================================================

    logic [7:0] watchdog_count;
    logic       watchdog_expired;
    logic       watchdog_clear;

    // ============================================================
    // PGA control
    // ============================================================

    logic [2:0] lna_gain;
    logic [2:0] pga_gain;

    logic [15:0] i2c_data;

    // ============================================================
    // I2C serializer signals
    // ============================================================

    logic i2c_write;
    logic i2c_busy;

    // ============================================================
    // Watchdog counter
    // ============================================================

    us_programmable_counter #(
        .COUNTER_WIDTH(8)
    ) watchdog_counter (
        .clk        (clk),
        .rstb      (rstb),

        .enable     (!enb),
        .clear      (watchdog_clear),

        .we         (we),
        .max_value  (watchdog_data),

        .count      (watchdog_count),
        .overflow_flag   (watchdog_expired)
    );

    // ============================================================
    // I2C serializer
    // ============================================================

    i2cmaster #(
        .WIDTH(16)
    ) i2c0 (
        .clk       (clk),
        .rstb     (rstb),
        .write     (i2c_write),
        .d_in      (i2c_data),
        .busy      (i2c_busy),
        .i2c_cse_n (i2c_cse_n),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl)
    );

    always_latch begin
        if (!rstb) begin
            lna_gain = 3'b111;         // Asynchronously clear the latch
            pga_gain = 3'b111;        
        end 
        else if (lna_gain_we) begin
            lna_gain = watchdog_data[2:0];   
        end
        else if (pga_gain_we) begin
            pga_gain = watchdog_data[2:0];   
        end
        // When 'we' is low, the latch automatically holds its previous value
    end

    // ============================================================
    // FSM
    // ============================================================

    typedef enum logic [1:0] {
        WAIT_TIMEOUT,
        START_I2C,
        WAIT_BUSY_HIGH,
        WAIT_BUSY_LOW
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rstb) begin

        if (!rstb) begin

            state <= WAIT_TIMEOUT;
            i2c_data <= 8'h00;
            i2c_write <= 1'b0;
            watchdog_clear <= 1'b1;
        end
        else begin

            // defaults
            i2c_write <= 1'b0;
            watchdog_clear <= 1'b0;
            // inactive
            if (enb) begin
                state <= WAIT_TIMEOUT;
                i2c_data <= 16'h0000;
                watchdog_clear <= 1'b1;
            end
            
            else begin

                case (state)

                    // ============================================
                    // Wait for watchdog expiration
                    // ============================================
                    WAIT_TIMEOUT: begin
                        if (watchdog_expired) begin
                            i2c_data <= {<<{ // Pack and reverse register
                                7'b000_0000, // Padding (7 bits)
                                lna_gain,    // 3rd field
                                pga_gain,    // 2nd field
                                lna_gain     // 1st field
                            }};
                            state <= START_I2C;
                        end
                    end

                    // ============================================
                    // Start serializer
                    // ============================================
                    START_I2C: begin
                        i2c_write <= 1'b1;
                        state <= WAIT_BUSY_HIGH;
                    end

                    // ============================================
                    // Wait busy asserted
                    // ============================================
                    WAIT_BUSY_HIGH: begin
                        if (i2c_busy)
                            state <= WAIT_BUSY_LOW;
                    end

                    // ============================================
                    // Wait serialization complete
                    // ============================================
                    WAIT_BUSY_LOW: begin
                        if (!i2c_busy) begin
                            watchdog_clear <= 1'b1;
                            state <= WAIT_TIMEOUT;
                        end
                    end

                    default: begin
                        state <= WAIT_TIMEOUT;
                    end

                endcase
            end
        end
    end

endmodule
