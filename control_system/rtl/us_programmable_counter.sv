module us_programmable_counter #(
    parameter int COUNTER_WIDTH = 8
)(
    input  logic                         clk,       // 100 MHz clock
    input  logic                         rstb,

    input  logic                         enable,
    input  logic                         clear,

    input  logic                         we,
    input  logic [COUNTER_WIDTH-1:0]     max_value,

    output logic [COUNTER_WIDTH-1:0]     count,
    output logic                         overflow_flag
);

    // 1 us tick generator
    // 100 MHz clock => 100 cycles per microsecond

    logic [6:0] us_divider; // needs to count 0..99
    logic       us_tick;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            us_divider <= 0;
            us_tick    <= 1'b0;
        end
        else begin
            if (us_divider == 99) begin
                us_divider <= 0;
                us_tick    <= 1'b1;
            end
            else begin
                us_divider <= us_divider + 1'b1;
                us_tick    <= 1'b0;
            end
        end
    end

    // Programmable counter
    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            count    <= 0;
            max_flag <= 1'b0;
        end
        else begin

            max_flag <= 1'b0;

            if (clear) begin
                count <= 0;
            end
            else if (enable && us_tick) begin

                if (count >= max_value) begin
                    count    <= 0; // reset when reaching maximum
                    max_flag <= 1'b1;
                end
                else begin
                    count <= count + 1'b1;
                end

            end
        end
    end

endmodule