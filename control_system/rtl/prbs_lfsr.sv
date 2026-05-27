module prbs_lfsr (
    input  logic       enb,        // Active-low enable
    input  logic       clk,      // 100 MHz system clock
    input  logic       rstb,

    input  logic       we,       // Seed load enable
    input  logic [7:0] d_seed,

    output logic       s_out

);
    // Internal registers
    logic [7:0] lfsr_q;
    logic feedback;
    logic clk50_en;

    // 50 MHz enable generation, using a clock divider-by-2 flip flop toggle
    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb)
            clk50_en <= 1'b0;
        else
            clk50_en <= ~clk50_en;
    end

    // PRBS polynomial
    // x^8 + x^6 + x^5 + x^4 + 1
    assign feedback =
        lfsr_q[7] ^
        lfsr_q[5] ^
        lfsr_q[4] ^
        lfsr_q[3];
    assign s_out = lfsr_q[7];
    // ============================================================
    // LFSR update
    // Advances only at 50 MHz rate
    // ============================================================

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            lfsr_q <= 8'h1;
        end
        else begin
            if (we) begin
                lfsr_q <= d_seed;
            end
            // Advance at 50 MHz effective rate
            else if (!enb && clk50_en) begin
                lfsr_q <= {
                    lfsr_q[6:0],
                    feedback
                };
            end
        end
    end

endmodule
