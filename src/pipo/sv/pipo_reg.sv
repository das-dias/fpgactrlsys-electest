module pipo_reg #(
    parameter WIDTH = 8 
)(
    input  logic              we,    // Active-high write-enable
    input  logic              rst_n, // Active-low asynchronous reset
    input  logic [WIDTH-1:0]  d_in,  // Parallel data input
    output logic [WIDTH-1:0]  d_out  // Parallel data output
);

    always_ff @(posedge we or negedge rst_n) begin
        if (!rst_n) begin
            d_out <= '0;
        end else begin
            d_out <= d_in;
        end
    end

endmodule