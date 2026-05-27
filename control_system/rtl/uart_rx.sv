/* from: https://github.com/medalotte/SystemVerilog-UART.git */
module uart_rx #(
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
        input   logic clk,
        input   logic rstb,
        input   logic s_in,
        input   logic ready,

        output  logic [DATA_WIDTH-1:0] d_out,
        output  logic valid
    );
    //-----------------------------------------------------------------------------
    // noise removing filter
    function majority5(input [4:0] val);
        case(val)
            5'b00000: majority5 = 0;
            5'b00001: majority5 = 0;
            5'b00010: majority5 = 0;
            5'b00100: majority5 = 0;
            5'b01000: majority5 = 0;
            5'b10000: majority5 = 0;
            5'b00011: majority5 = 0;
            5'b00101: majority5 = 0;
            5'b01001: majority5 = 0;
            5'b10001: majority5 = 0;
            5'b00110: majority5 = 0;
            5'b01010: majority5 = 0;
            5'b10010: majority5 = 0;
            5'b01100: majority5 = 0;
            5'b10100: majority5 = 0;
            5'b11000: majority5 = 0;
            default:  majority5 = 1;
        endcase
    endfunction

    //-----------------------------------------------------------------------------
    // description about input signal
    logic [1:0] sampling_cnt;
    logic [4:0] sig_q;
    logic       sig_r;

    always_ff @(posedge clk) begin
        if(!rstb) begin
            sampling_cnt <= 0;
            sig_q        <= 5'b11111;
            sig_r        <= 1;
        end else begin
            // connect to deserializer after removing noise
            if(sampling_cnt == 0) begin
                sig_q <= {s_in, sig_q[4:1]};
            end
            sig_r        <= majority5(sig_q);
            sampling_cnt <= sampling_cnt + 1;
        end
    end

    //----------------------------------------------------------------
    // description about receive UART signal
    typedef enum logic [1:0] {
        STT_DATA,
        STT_STOP,
        STT_IDLE
    } statetype;
    
    statetype                state;

    logic [DATA_WIDTH-1:0]   data_tmp_r;
    logic [LB_DATA_WIDTH:0]  data_cnt;
    logic [LB_PULSE_WIDTH:0] clk_cnt;
    logic                    rx_done;

    always_ff @(posedge clk) begin
        if(!rstb) begin
            state      <= STT_IDLE;
            data_tmp_r <= 0;
            data_cnt   <= 0;
            clk_cnt    <= 0;
        end else begin
            //-----------------------------------------------------------------------------
            // 3-state FSM
            case(state)

            //-----------------------------------------------------------------------------
            // state      : STT_DATA
            // behavior   : deserialize and recieve data
            // next state : when all data have recieved -> STT_STOP
            STT_DATA: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end else begin
                    data_tmp_r <= {sig_r, data_tmp_r[DATA_WIDTH-1:1]};
                    clk_cnt    <= PULSE_WIDTH[LB_PULSE_WIDTH:0];

                    if(data_cnt == MAX_VAL[LB_DATA_WIDTH:0]) begin
                        state <= STT_STOP;
                    end else begin
                        data_cnt <= data_cnt + 1;
                    end
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_STOP
            // behavior   : watch stop bit
            // next state : STT_IDLE
            STT_STOP: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end else if(sig_r) begin
                    state <= STT_IDLE;
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_IDLE
            // behavior   : watch start bit
            // next state : when start bit is observed -> STT_DATA
            STT_IDLE: begin
                if(sig_r == 0) begin
                    clk_cnt  <= PULSE_WIDTH[LB_PULSE_WIDTH:0] + HALF_PULSE_WIDTH[LB_PULSE_WIDTH:0];
                    data_cnt <= 0;
                    state    <= STT_DATA;
                end
            end

            default: begin
                state <= STT_IDLE;
            end
            endcase
        end
    end

    assign rx_done = (state == STT_STOP) && (clk_cnt == 0);

    //-----------------------------------------------------------------------------
    // description about output signal
    logic [DATA_WIDTH-1:0] data_r;
    logic                  valid_r;

    always_ff @(posedge clk) begin
        if(!rstb) begin
            data_r  <= 0;
            valid_r <= 0;
        end else if(rx_done && !valid_r) begin
            valid_r <= 1;
            data_r  <= data_tmp_r;
        end else if(valid_r && ready) begin
            valid_r <= 0;
        end
    end

    assign d_out  = data_r;
    assign valid = valid_r;

endmodule