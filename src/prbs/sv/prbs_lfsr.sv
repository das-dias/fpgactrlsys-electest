module prbs_lfsr(
    input  logic                s_clk,  // Rising edge clock
    input  logic                we,    // Active-high write-enable
    input  logic [7:0]          d_seed,  // Parallel seed input
    output logic                s_out  // Serial data output
);
    logic [7:0]   lfsr_q;
    logic         feedback;

    // create fibonacci polynomials
    /*
    case(WIDTH)
        3: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~lfsr_q[WIDTH-2]);
        end
        4: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~lfsr_q[WIDTH-2]);
        end
        5: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~lfsr_q[WIDTH-3]);
        end
        6: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~lfsr_q[WIDTH-2]);
        end
        7: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~lfsr_q[WIDTH-2]);
        end
        8: begin
            assign feedback = (lfsr_q[WIDTH-1] ^~ lfsr_q[WIDTH-3] ^~ lfsr_q[WIDTH-4] ^~ lfsr_q[WIDTH-5]);
        end
    endcase
    */
    assign feedback = !(lfsr_q[7] ^ lfsr_q[5] ^ lfsr_q[4] ^ lfsr_q[3]);
    assign s_out = lfsr_q[7];
    always_ff @(posedge we or posedge s_clk) begin
        if (we) begin
            lfsr_q <= d_seed;
        end else begin
            lfsr_q <= {lfsr_q[6:0], feedback};
        end
    end
    
endmodule
