module i2cmaster #(
    parameter int WIDTH = 8
)(
    input  logic                clk,
    input  logic                rstb,
    input  logic                write,
    input  logic [WIDTH-1:0]    d_in,

    output logic                busy,

    output logic                i2c_cse_n,
    output logic                i2c_sda,
    output logic                i2c_scl
);

    localparam int MAX_VAL = WIDTH - 1;
    localparam int ADDR_W  = $clog2(WIDTH);

    logic [WIDTH-1:0]         shift_reg;
    logic [ADDR_W-1:0]        bit_cnt;

    // ------------------------------------------------------------
    // Busy flag
    // ------------------------------------------------------------

    assign busy = (bit_cnt != 0);

    // ------------------------------------------------------------
    // Shift register
    // ------------------------------------------------------------

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
        end
        else begin

            // Load parallel data
            if (write) begin
                shift_reg <= d_in;
                bit_cnt   <= MAX_VAL[ADDR_W-1:0];
            end

            // Shift while busy
            else if (bit_cnt != 0) begin
                shift_reg <= shift_reg << 1;
                bit_cnt   <= bit_cnt - 1'b1;
            end

        end
    end

    // ------------------------------------------------------------
    // I2C outputs
    // ------------------------------------------------------------

    // MSB-first serial output
    assign i2c_sda = shift_reg[WIDTH-1];

    // Chip-select active during transfer
    assign i2c_cse_n = ~busy;

    // Generate SCL as normal logic, not a gated clock
    assign i2c_scl = clk & busy;

endmodule