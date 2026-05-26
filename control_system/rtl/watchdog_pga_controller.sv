module watchdog_pga_controller (

    input  logic       clk,
    input  logic       rst_n,

    // Watchdog timeout in microseconds
    input  logic [7:0] watchdog_max,

    // I2C interface
    output logic       i2c_cse_n,
    output logic       i2c_sda,
    output logic       i2c_scl
);

/*
* 1. Program watchdog timer span from input parallel 8 bit
* 2. Each time watchdog reaches max, increment PGA state
* 3. Serialize it to the output through the I2C master
* 4. Reset watchdog timer
*/

/* Controller Architecture:
+-----------------------------+
| watchdog_controller         |
|                             |
|  +----------------------+   |
|  | us_programmable_     |   |
|  | counter              |--- watchdog_expired
|  +----------------------+   |
|                             |
|  +----------------------+   |
|  | PGA state register   |   |
|  +----------------------+   |
|                             |
|  +----------------------+   |
|  | I2C FSM              |--- i2c_start
|  +----------------------+   |
|                             |
|  +----------------------+   |
|  | i2cmaster            |--- SDA/SCL, while 'busy' is HIGH
|  +----------------------+   |
+-----------------------------+
*/

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

    logic       i2c_write;
    logic       i2c_busy;

    // ============================================================
    // Watchdog counter
    // ============================================================

    us_programmable_counter #(
        .COUNTER_WIDTH(8)
    ) watchdog_counter (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (1'b1),
        .clear     (watchdog_clear),
        .max_value (watchdog_max),
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
        .rst_n     (rst_n),

        .write     (i2c_write),
        .d_in      (i2c_data),

        .busy      (i2c_busy),

        .i2c_cse_n (i2c_cse_n),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl)
    );

    // ============================================================
    // PGA next-state logic
    // Sequence:
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
    // Controller FSM
    // ============================================================

    typedef enum logic [1:0] {
        WAIT_TIMEOUT,
        START_I2C,
        WAIT_BUSY_HIGH,
        WAIT_BUSY_LOW
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state           <= WAIT_TIMEOUT;

            pga_state       <= 3'b000;

            i2c_data        <= 8'h00;

            i2c_write       <= 1'b0;
            watchdog_clear  <= 1'b0;

        end
        else begin

            // Default pulse signals
            i2c_write      <= 1'b0;
            watchdog_clear <= 1'b0;

            case (state)

                // ================================================
                // Wait for watchdog expiration
                // ================================================
                WAIT_TIMEOUT: begin

                    if (watchdog_expired) begin

                        // Advance PGA state
                        pga_state <= pga_next;

                        // Pack 3-bit PGA word into byte
                        i2c_data <= {5'b00000, pga_next};

                        state <= START_I2C;
                    end
                end

                // ================================================
                // Pulse serializer write
                // ================================================
                START_I2C: begin

                    i2c_write <= 1'b1;

                    state <= WAIT_BUSY_HIGH;
                end

                // ================================================
                // Wait until serializer becomes busy
                // ================================================
                WAIT_BUSY_HIGH: begin

                    if (i2c_busy) begin
                        state <= WAIT_BUSY_LOW;
                    end
                end

                // ================================================
                // Wait until serialization completes
                // ================================================
                WAIT_BUSY_LOW: begin

                    if (!i2c_busy) begin

                        // Reset watchdog timer
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

endmodule