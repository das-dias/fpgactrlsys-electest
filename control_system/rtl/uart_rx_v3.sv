// =============================================================================
// UART Receiver for Arty S7-50 FPGA
// -----------------------------------------------------------------------------
// Board clock : 100 MHz
// Default baud : 115200
// Data format  : 8N1  (8 data bits, No parity, 1 stop bit)
//
// Ports
//   clk        - 100 MHz board clock
//   rst_n      - Active-low synchronous reset
//   rx         - UART RX line (connect to USB-UART bridge pin)
//   data_out   - 8-bit received byte (valid when rx_done is high)
//   rx_done    - Pulses high for one clock cycle when a byte is ready
//   frame_err  - Pulses high when the stop bit is not detected (framing error)
// =============================================================================

module uart_rx #(
    parameter int CLK_FREQ  = 100_000_000,  // 100 MHz
    parameter int BAUD_RATE = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,

    output logic [7:0] data_out,
    output logic       rx_done,
    output logic       frame_err
);

    // -------------------------------------------------------------------------
    // Derived parameters
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;           // 868
    localparam int HALF_BIT      = CLKS_PER_BIT / 2;               // 434
    localparam int CTR_WIDTH     = $clog2(CLKS_PER_BIT + 1);       // 10

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP,
        DONE
    } state_t;

    state_t state, state_next;

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    // Two-stage synchroniser for the async RX line
    logic rx_sync0, rx_sync1;

    logic [CTR_WIDTH-1:0] bit_ctr;       // Counts clocks within one bit period
    logic [2:0]           bit_idx;       // Which data bit we are capturing (0-7)
    logic [7:0]           shift_reg;     // Shift register accumulates received bits

    // -------------------------------------------------------------------------
    // Metastability synchroniser (CDC: board I/O → clk domain)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        rx_sync0 <= rx;
        rx_sync1 <= rx_sync0;
    end

    // -------------------------------------------------------------------------
    // FSM — sequential part
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            bit_ctr  <= '0;
            bit_idx  <= '0;
            shift_reg <= '0;
            data_out  <= '0;
            rx_done   <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            // Default pulse outputs to 0 each cycle
            rx_done   <= 1'b0;
            frame_err <= 1'b0;

            case (state)
                // -----------------------------------------------------------------
                // IDLE – wait for the start bit (RX falls from 1 → 0)
                // -----------------------------------------------------------------
                IDLE: begin
                    bit_ctr <= '0;
                    bit_idx <= '0;
                    if (!rx_sync1)          // Falling edge detected
                        state <= START;
                end

                // -----------------------------------------------------------------
                // START – wait to the middle of the start bit, then verify it
                // is still low (avoids false triggers from glitches).
                // -----------------------------------------------------------------
                START: begin
                    if (bit_ctr == HALF_BIT - 1) begin
                        bit_ctr <= '0;
                        if (!rx_sync1)      // Valid start bit
                            state <= DATA;
                        else                // Glitch – go back to idle
                            state <= IDLE;
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -----------------------------------------------------------------
                // DATA – sample each of the 8 data bits at the centre of the
                // bit period.  LSB is received first (standard UART).
                // -----------------------------------------------------------------
                DATA: begin
                    if (bit_ctr == CLKS_PER_BIT - 1) begin
                        bit_ctr              <= '0;
                        shift_reg[bit_idx]   <= rx_sync1;   // Sample at bit centre

                        if (bit_idx == 3'd7) begin
                            bit_idx <= '0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -----------------------------------------------------------------
                // STOP – wait one full bit period; the line must be high.
                // -----------------------------------------------------------------
                STOP: begin
                    if (bit_ctr == CLKS_PER_BIT - 1) begin
                        bit_ctr <= '0;
                        state   <= DONE;

                        if (!rx_sync1)      // Stop bit must be '1'
                            frame_err <= 1'b1;
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -----------------------------------------------------------------
                // DONE – latch the received byte and signal completion for one
                // clock cycle, then return to IDLE.
                // -----------------------------------------------------------------
                DONE: begin
                    data_out <= shift_reg;
                    rx_done  <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
