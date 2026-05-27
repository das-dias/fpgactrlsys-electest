module watchdog_pga_controller (

    input  logic       clk,
    input  logic       rstb,
    input  logic       enb,

    // Watchdog programming interface
    input  logic       we,
    input  logic [7:0] watchdog_max,

    // I2C interface
    output logic       i2c_cse_n,
    output logic       i2c_sda,
    output logic       i2c_scl
);

    // ============================================================
    // Internal watchdog register
    // ============================================================

    logic [7:0] watchdog_max_reg;

    always_ff @(posedge clk or negedge rstb) begin

        if (!rstb)
            watchdog_max_reg <= 8'd0;

        else if (we)
            watchdog_max_reg <= watchdog_max;

    end

    // ============================================================
    // Watchdog signals
    // ============================================================

    logic [7:0] watchdog_count;
    logic       watchdog_expired;
    logic       watchdog_clear;

    // ============================================================
    // PGA control
    // ============================================================

    logic [2:0] pga_state;
    logic [2:0] pga_next;

    logic [7:0] i2c_data;

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
        .clk       (clk),
        .rst_n     (rstb),

        .enable    (!enb),

        .clear     (watchdog_clear),

        .max_value (watchdog_max_reg),

        .count     (watchdog_count),

        .max_flag  (watchdog_expired)
    );

    // ============================================================
    // I2C serializer
    // ============================================================

    i2cmaster #(
        .WIDTH(8)
    ) i2c0 (
        .clk       (clk),
        .rst_n     (rstb),

        .write     (i2c_write),

        .d_in      (i2c_data),

        .busy      (i2c_busy),

        .i2c_cse_n (i2c_cse_n),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl)
    );

    // ============================================================
    // PGA sequence
    // 000 -> 001 -> 010 -> 011 -> 111 -> 000
    // ============================================================

    always_comb begin

        case (pga_state)

            3'b000: pga_next = 3'b001;
            3'b001: pga_next = 3'b010;
            3'b010: pga_next = 3'b011;
            3'b011: pga_next = 3'b111;

            default: pga_next = 3'b000;

        endcase
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

            pga_state <= 3'b000;

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

                pga_state <= 3'b000;

                i2c_data <= 8'h00;

                watchdog_clear <= 1'b1;

            end
            else begin

                case (state)

                    // ============================================
                    // Wait for watchdog expiration
                    // ============================================
                    WAIT_TIMEOUT: begin

                        if (watchdog_expired) begin

                            pga_state <= pga_next;

                            i2c_data <= {
                                5'b00000,
                                pga_next
                            };

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