//`include "uart_tx.sv"
//`include "uart_rx.sv"

module uart #(parameter
    DATA_WIDTH = 8,
    BAUD_RATE  = 115200,
    CLK_FREQ   = 100_000_000
    )(
        //rx
        input   logic               s_in,
        input   logic               rx_ready,
        output  logic [DATA_WIDTH-1:0]   d_out,
        output  logic               rx_valid,

        //tx
        output  logic               s_out,
        input   logic [DATA_WIDTH-1:0]   d_in,
        input   logic               tx_valid,
        output  logic               tx_ready,
        
        input logic                 clk,
        input logic                 rst_n
    );

    uart_tx #(DATA_WIDTH, BAUD_RATE, CLK_FREQ)
    uart_tx_inst(
        .s_out(s_out),
        .d_in(d_in),
        .valid(tx_valid),
        .ready(tx_ready),

        .clk(clk),
        .rst_n(rst_n)
    );

    uart_rx #(DATA_WIDTH, BAUD_RATE, CLK_FREQ)
    uart_rx_inst(
        .d_out(d_out),
        .s_in(s_in),
        .valid(rx_valid),
        .ready(rx_ready),

        .clk(clk),
        .rst_n(rst_n)
    );
endmodule