module i2cmaster #(
    parameter int WIDTH = 8
)(
    input  logic                clk,     // Rising edge read-enable to shift out data
    input  logic                rst_n,  // Active-low reset 
    input  logic                write,  // Active-high write for loading parallel data
    input  logic [WIDTH-1:0]    d_in,   // Input parallel data
    output logic                busy,   // Active-high flag signaling shifting is currently ongoing
    
    output reg                i2c_cse_n,  // Active-low flag enabling the slave i2c interface
    output reg                i2c_sda,    // Output serial data
    output reg                i2c_scl     // Output slave-driver clock
);

    localparam int MAX_VAL = WIDTH - 1;
    localparam int ADDR_W  = $clog2(WIDTH);

    reg [WIDTH-1:0]                 shift_reg;
    reg [$clog2(WIDTH)-1:0]         bit_cnt;
    logic                           clk_en;

    // Clock gating to output

    assign busy         = (bit_cnt > 0);

    always_ff @ (negedge clk) begin
        clk_en = busy;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= '0;
            bit_cnt    <= '0;
        end
        else if (write) begin
            shift_reg   <= d_in;
            bit_cnt     <= MAX_VAL[ADDR_W-1:0];
        end
        else if (bit_cnt > 0) begin
            shift_reg  <= shift_reg << 1;
            bit_cnt    <= bit_cnt - 1'b1;
            
        end
    end



    assign i2c_sda      = shift_reg[WIDTH-1];             // MSB first
    assign i2c_cse_n    = (bit_cnt == 0);            // last bit cycle

    assign i2c_scl      = clk_en & !clk;

endmodule
