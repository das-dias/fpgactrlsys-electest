module file_reg #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 256,

    //localparam int MAX_DATA_VAL = DATA_WIDTH-1,
    localparam int ADDR_WIDTH   = $clog2(DEPTH),
    localparam int MAX_ADDR_VAL = ADDR_WIDTH-1
)(
    input  logic [ADDR_WIDTH-1:0] addr, // Address for the data read

    input  logic              we,    // Active-high write-enable
    input  logic              re_n,    // Active-low read-enable
    
    input  logic [DATA_WIDTH-1:0]  d_in,  // Parallel data input
    output wire  [DATA_WIDTH-1:0]  d_out  // Parallel data output
);

    logic [DATA_WIDTH-1:0]     mem [DEPTH];
    logic [DATA_WIDTH-1:0]     dout_q;

    // tristate buffering of dout, to allow data to share same bus
    assign d_out = (re_n) ? {DATA_WIDTH{1'bz}} : dout_q;

    always_ff @(posedge we or negedge re_n) begin
        if (we) begin
            mem[addr] <= d_in;
            //size            <= size+1;
        end
        // read
        else if (!(re_n)) begin // prioritize write
            dout_q <= mem[addr];
            //size        <= size-1;
        end
    end

endmodule