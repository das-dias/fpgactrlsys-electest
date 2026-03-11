/*from: https://github.com/medalotte/SystemVerilog-UART/tree/master */

module uart_tx #(
    parameter
        DATA_WIDTH = 8,
        BAUD_RATE  = 115200,
        CLK_FREQ   = 100_000_000,

    localparam
        MAX_VAL          = DATA_WIDTH - 1,
        LB_DATA_WIDTH    = $clog2(DATA_WIDTH),
        PULSE_WIDTH      = CLK_FREQ / BAUD_RATE,
        LB_PULSE_WIDTH   = $clog2(PULSE_WIDTH),
        HALF_PULSE_WIDTH = PULSE_WIDTH / 2
    )(
        output  logic               s_out,
        input   logic [DATA_WIDTH-1:0]   d_in,
        input   logic               valid,
        output  logic               ready,

        input   logic               clk,
        input   logic               rst_n
    );

    typedef enum logic [1:0] {
        STT_DATA,
        STT_STOP,
        STT_WAIT
    } statetype;

    statetype                   state;

    logic [DATA_WIDTH-1:0]      data_r;
    logic                       sig_r;
    logic                       ready_r;
    logic [LB_DATA_WIDTH-1:0]   data_cnt;
    logic [LB_PULSE_WIDTH:0]    clk_cnt;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state    <= STT_WAIT;
            sig_r    <= 1;
            data_r   <= 0;
            ready_r  <= 1;
            data_cnt <= 0;
            clk_cnt  <= 0;
        end
        else begin

            //-----------------------------------------------------------------------------
            // 3-state FSM
            case(state)

            //-----------------------------------------------------------------------------
            // state      : STT_DATA
            // behavior   : serialize and transmit data
            // next state : when all data have transmited -> STT_STOP
            STT_DATA: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end
                else begin
                    sig_r   <= data_r[data_cnt];
                    clk_cnt <= PULSE_WIDTH[LB_PULSE_WIDTH:0];

                    if(data_cnt == MAX_VAL[LB_DATA_WIDTH-1:0]) begin
                        state <= STT_STOP;
                    end
                    else begin
                        data_cnt <= data_cnt + 1;
                    end
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_STOP
            // behavior   : assert stop bit
            // next state : STT_WAIT
            STT_STOP: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end
                else begin
                    state   <= STT_WAIT;
                    sig_r   <= 1;
                    clk_cnt <= PULSE_WIDTH[LB_PULSE_WIDTH:0] + HALF_PULSE_WIDTH[LB_PULSE_WIDTH:0];
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_WAIT
            // behavior   : watch valid signal, and assert start bit when valid signal assert
            // next state : when valid signal assert -> STT_STAT
            STT_WAIT: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end
                else if(!ready_r) begin
                    ready_r <= 1;
                end
                else if(valid) begin
                    state    <= STT_DATA;
                    sig_r    <= 0;
                    data_r   <= d_in;
                    ready_r  <= 0;
                    data_cnt <= 0;
                    clk_cnt  <= PULSE_WIDTH[LB_PULSE_WIDTH:0];
                end
            end

            default: begin
                state <= STT_WAIT;
            end
            endcase
        end
    end

    assign s_out   = sig_r;
    assign ready = ready_r;

endmodule