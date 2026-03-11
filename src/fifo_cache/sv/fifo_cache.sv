module fifo_cache #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 255,

    localparam int MAX_DATA_VAL = DATA_WIDTH-1,
    localparam int ADDR_WIDTH   = $clog2(DEPTH+1),
    localparam int MAX_ADDR_VAL = ADDR_WIDTH-1
)(
    input  logic              clk,   // Rising-edge clock
    input  logic              rst_n, // Active-low asynchronous reset

    input  logic              we,    // Active-high write-enable
    input  logic              re_n,    // Active-low read-enable
    
    input  logic [DATA_WIDTH-1:0]  d_in,  // Parallel data input
    output wire  [DATA_WIDTH-1:0]  d_out,  // Parallel data output

    // flags
    output logic              full,
    output logic              empty
);

    logic [DATA_WIDTH-1:0]     mem [0:DEPTH];
    logic [DATA_WIDTH-1:0]     dout_q;
    // read and write pointer to avoid expensive shifting operations
    logic [ADDR_WIDTH-1:0]     write_ptr, read_ptr;
    logic [ADDR_WIDTH-1:0]     size;

    assign full     = (size == DEPTH[ADDR_WIDTH-1:0]);
    assign empty    = (size == 0);

    // tristate buffering of dout, to allow data to share same bus
    assign d_out = (re_n) ? {DATA_WIDTH{1'bz}} : dout_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr   <= '0;
            read_ptr    <= '0;
            size        <= '0;
        end else begin
            // write
            if (we && !full) begin
                mem[write_ptr]  <= d_in;
                write_ptr       <= (write_ptr == MAX_ADDR_VAL[ADDR_WIDTH-1:0]) ? '0 : write_ptr+1'b1;
                size            <= size+1;
            end
            // read
            if (!(re_n || empty)) begin
                dout_q      <= mem[read_ptr];
                read_ptr    <= (read_ptr == MAX_ADDR_VAL[ADDR_WIDTH-1:0]) ? '0 : read_ptr+1'b1;
                size        <= size-1;
            end
        end
    end

endmodule