module piso_reg #(
    parameter int WIDTH = 8
)(
    input  logic                re,     // Rising edge read-enable to shift out data
    input  logic                rst_n,  // Active-low reset 
    input  logic                write,  // Active-high write for loading parallel data
    input  logic [WIDTH-1:0]    d_in,   // Input parallel data
    output logic                s_out,  // Output serial data
    output logic                busy,   // Active-high flag signaling shifting is currently ongoing
    output logic                done    // Active-high flag signaling all data was shifted out
);

    localparam int MAX_VAL = WIDTH - 1;
    localparam int ADDR_W  = $clog2(WIDTH);

    logic [WIDTH-1:0]           shift_reg;
    logic [$clog2(WIDTH)-1:0]     bit_cnt;

    always_ff @(posedge re or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= '0;
            bit_cnt    <= '0;
        end
        else if (write) begin
            shift_reg  <= d_in;
            bit_cnt    <= MAX_VAL[ADDR_W-1:0];
        end
        else if (bit_cnt > 0) begin
            shift_reg  <= shift_reg << 1;
            bit_cnt    <= bit_cnt - 1'b1;
        end
    end

    assign s_out = shift_reg[WIDTH-1];             // MSB first
    assign busy       = (bit_cnt > 0);
    assign done       = (bit_cnt == 0);            // last bit cycle

endmodule
