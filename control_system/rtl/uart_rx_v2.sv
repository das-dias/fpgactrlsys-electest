// =============================================================================
// UART Receiver for Arty S7-50 FPGA
// -----------------------------------------------------------------------------
// Board clock  : 100 MHz
// Default baud : 115200
// Data format  : 8N1  (8 data bits, No parity, 1 stop bit)
//
// Ports
//   clk            - 100 MHz board clock
//   rstb           - Active-low synchronous reset
//   s_in           - UART RX serial input line
//   ready          - Consumer asserts high when it can accept a new byte;
//                    d_out and valid are held until ready is seen
//   d_out          - DATA_WIDTH-bit received word (held until handshake)
//   valid          - High when d_out holds a complete, un-consumed byte
// =============================================================================

module uart_rx #(
    parameter int CLK_FREQ   = 100_000_000,  // 100 MHz
    parameter int BAUD_RATE  = 115_200,
    parameter int DATA_WIDTH = 8             // bits per frame (normally 8)
) (
    input   logic                  clk,
    input   logic                  rstb,    // active-low reset
    input   logic                  s_in,    // serial RX line
    input   logic                  ready,   // consumer ready (valid/ready handshake)
    output  logic [DATA_WIDTH-1:0] d_out,
    output  logic                  valid
);

    // -------------------------------------------------------------------------
    // Derived parameters
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;        // 868 @ 115200
    localparam int HALF_BIT     = CLKS_PER_BIT / 2;            // 434
    localparam int CTR_WIDTH    = $clog2(CLKS_PER_BIT + 1);    // 10
    localparam int IDX_WIDTH    = $clog2(DATA_WIDTH);           // 3 for 8-bit

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

    state_t state;

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    // Two-stage synchroniser — prevents metastability on the async s_in pin
    logic s_sync0, s_sync1;

    logic [CTR_WIDTH-1:0]    bit_ctr;   // clock counter within one bit period
    logic [IDX_WIDTH-1:0]    bit_idx;   // data bit currently being captured
    logic [DATA_WIDTH-1:0]   shift_reg; // assembles received bits (LSB first)

    // -------------------------------------------------------------------------
    // Metastability synchroniser
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        s_sync0 <= s_in;
        s_sync1 <= s_sync0;
    end

    // -------------------------------------------------------------------------
    // FSM + datapath
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstb) begin
            state     <= IDLE;
            bit_ctr   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
            d_out     <= '0;
            valid     <= 1'b0;
        end else begin

            case (state)
                // -------------------------------------------------------------
                // IDLE – line is high; wait for start bit (falling edge)
                // If valid is asserted and the consumer is ready, deassert it.
                // -------------------------------------------------------------
                IDLE: begin
                    bit_ctr <= '0;
                    bit_idx <= '0;

                    // Handshake: clear valid once consumer accepts
                    if (valid && ready)
                        valid <= 1'b0;

                    // Detect start bit only when no pending data is waiting,
                    // or the handshake just completed this cycle
                    if (!s_sync1 && !(valid && !ready))
                        state <= START;
                end

                // -------------------------------------------------------------
                // START – advance to the centre of the start bit and verify
                // it is still low (rejects glitches shorter than half a bit).
                // -------------------------------------------------------------
                START: begin
                    if (bit_ctr == HALF_BIT - 1) begin
                        bit_ctr <= '0;
                        if (!s_sync1)
                            state <= DATA;
                        else
                            state <= IDLE;   // glitch — abort
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -------------------------------------------------------------
                // DATA – sample each bit at the centre of its window.
                // LSB is received first, per the UART standard.
                // -------------------------------------------------------------
                DATA: begin
                    if (bit_ctr == CLKS_PER_BIT - 1) begin
                        bit_ctr            <= '0;
                        shift_reg[bit_idx] <= s_sync1;

                        if (bit_idx == IDX_WIDTH'(DATA_WIDTH - 1)) begin
                            bit_idx <= '0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -------------------------------------------------------------
                // STOP – sample at the centre of the stop bit.
                // A low stop bit is a framing error; data is discarded.
                // -------------------------------------------------------------
                STOP: begin
                    if (bit_ctr == CLKS_PER_BIT - 1) begin
                        bit_ctr <= '0;
                        if (s_sync1)        // valid stop bit → latch
                            state <= DONE;
                        else                // framing error → discard
                            state <= IDLE;
                    end else begin
                        bit_ctr <= bit_ctr + 1;
                    end
                end

                // -------------------------------------------------------------
                // DONE – present data to consumer; hold until ready handshake.
                // -------------------------------------------------------------
                DONE: begin
                    d_out <= shift_reg;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
