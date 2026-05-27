module us_programmable_counter #(
    parameter int COUNTER_WIDTH = 8
)(
    input  logic                         clk,       // 100 MHz clock
    input  logic                         rstb,      // active-low reset

    input  logic                         enable,
    input  logic                         clear,

    // Write-enable for updating max_value_reg
    input  logic                         we,
    input  logic [COUNTER_WIDTH-1:0]     max_value,

    output logic [COUNTER_WIDTH-1:0]     count,
    output logic                         overflow_flag
);

    // ----------------------------------------------------------------
    // 1 us tick generator
    // 100 MHz clock => 100 cycles per microsecond
    // ----------------------------------------------------------------

    logic [6:0] us_divider;
    logic       us_tick;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            us_divider <= '0;
            us_tick    <= 1'b0;
        end
        else begin
            if (us_divider == 7'd99) begin
                us_divider <= '0;
                us_tick    <= 1'b1;
            end
            else begin
                us_divider <= us_divider + 1'b1;
                us_tick    <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------------------
    // Registered programmable maximum value
    // ----------------------------------------------------------------

    logic [COUNTER_WIDTH-1:0] max_value_reg;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            max_value_reg <= '0;
        end
        else if (we) begin
            max_value_reg <= max_value;
        end
    end

    // ----------------------------------------------------------------
    // Programmable microsecond counter
    // ----------------------------------------------------------------

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            count         <= '0;
            overflow_flag <= 1'b0;
        end
        else begin

            // Default
            overflow_flag <= 1'b0;

            // Clear counter
            if (clear) begin
                count <= '0;
            end

            // Count every microsecond when enabled
            else if (enable && us_tick) begin

                if (count >= max_value_reg) begin
                    count         <= '0;
                    overflow_flag <= 1'b1;
                end
                else begin
                    count <= count + 1'b1;
                end

            end
        end
    end

endmodule