module adc_fifo_cache #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 256,
    //localparam int MAX_DATA_VAL = DATA_WIDTH-1,
    localparam int ADDR_WIDTH   = $clog2(DEPTH)
    //localparam int MAX_ADDR_VAL = ADDR_WIDTH-1
)(
    input  logic              clk,   // Rising-edge clock
    input  logic              rstb, // Active-low asynchronous reset

    input  logic              we,    // Active-high write-enable
    input  logic              re_n,    // Active-low read-enable
    
    input  logic [DATA_WIDTH-1:0]  d_in,  // Parallel data input
    output wire  [DATA_WIDTH-1:0]  d_out,  // Parallel data output

    // flags
    output logic              full,
    output logic              empty
);

    logic [DATA_WIDTH-1:0]     mem [DEPTH];
    logic [DATA_WIDTH-1:0]     dout_q;
    // read and write pointer to avoid expensive shifting operations
    logic [ADDR_WIDTH-1:0]     write_ptr, read_ptr;

    assign full     = (write_ptr + 1) == read_ptr;
    assign empty    = write_ptr == read_ptr;

    // tristate buffering of dout, to allow data to share same bus
    assign d_out = (re_n) ? {DATA_WIDTH{1'bz}} : dout_q;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            write_ptr   <= '0;
            read_ptr    <= '0;
            //size        <= '0;
        end else begin
            // write
            if (we && !full) begin
                mem[write_ptr]  <= d_in;
                write_ptr       <= write_ptr+1;
                //size            <= size+1;
            end
            // read
            if (!(re_n || empty)) begin
                dout_q      <= mem[read_ptr];
                read_ptr    <= read_ptr+1;
                //size        <= size-1;
            end
        end
    end

endmodule