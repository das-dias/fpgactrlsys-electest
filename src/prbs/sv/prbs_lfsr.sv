module prbs_lfsr #(
    parameter int WIDTH = 8
)(
    input  logic                s_clk,  // Rising edge clock
    input  logic                we,    // Active-high write-enable
    input  logic                rst_n, // Active-low asynchronous reset
    input  logic [WIDTH-1:0]    d_seed,  // Parallel seed input
    output logic                s_out  // Serial data output
);

    logic [WIDTH-1:0]   lfsr_q;
    logic               feedback;

    assign feedback = !(lfsr_q[WIDTH-1] ^ lfsr_q[WIDTH-3] ^ lfsr_q[WIDTH-4] ^ lfsr_q[WIDTH-5]);

    always_ff @(negedge rst_n or posedge we or posedge s_clk) begin
        if (!rst_n) begin
            lfsr_q <= 'h1; // lfsr lock-up at all zeros reset
        end else if (we) begin
            lfsr_q <= d_seed;
        end else begin
            lfsr_q <= {lfsr_q[WIDTH-2:0], feedback};
        end
    end

    

endmodule