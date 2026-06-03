/* Original source: https://github.com/medalotte/SystemVerilog-UART.git */
module uart_rx_v2 #(
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
    // Asynchronous input synchronizer
    //-----------------------------------------------------------------------------
    logic s_in_sync0, s_in_sync1;
    always_ff @(posedge clk) begin
        if(!rstb) begin
            s_in_sync0 <= 1'b1;
            s_in_sync1 <= 1'b1;
        end else begin
            s_in_sync0 <= s_in;
            s_in_sync1 <= s_in_sync0;
        end
    end

    //-----------------------------------------------------------------------------
    // State Machine Type Definition
    //-----------------------------------------------------------------------------
    typedef enum logic [1:0] {
        STT_DATA,
        STT_STOP,
        STT_IDLE
    } statetype;
    
    statetype               state;

    logic [DATA_WIDTH-1:0]   data_tmp_r;
    logic [LB_DATA_WIDTH-1:0] data_cnt;
    logic [LB_PULSE_WIDTH:0] clk_cnt;
    logic                    rx_done;

    //-----------------------------------------------------------------------------
    // Receive FSM Logic
    //-----------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if(!rstb) begin
            state      <= STT_IDLE;
            data_tmp_r <= 0;
            data_cnt   <= 0;
            clk_cnt    <= 0;
        end else begin
            case(state)

            //-----------------------------------------------------------------------------
            // state      : STT_DATA
            // behavior   : deserialize and receive data
            STT_DATA: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end else begin
                    data_tmp_r <= {s_in_sync1, data_tmp_r[DATA_WIDTH-1:1]};
                    clk_cnt    <= PULSE_WIDTH[LB_PULSE_WIDTH:0] - 1'b1;

                    if(data_cnt == MAX_VAL[LB_DATA_WIDTH-1:0]) begin
                        state <= STT_STOP;
                    end else begin
                        data_cnt <= data_cnt + 1'b1;
                    end
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_STOP
            // behavior   : watch stop bit
            STT_STOP: begin
                if(0 < clk_cnt) begin
                    clk_cnt <= clk_cnt - 1;
                end else begin
                    state <= STT_IDLE;
                end
            end

            //-----------------------------------------------------------------------------
            // state      : STT_IDLE
            // behavior   : watch start bit
            STT_IDLE: begin
                if(s_in_sync1 == 0) begin
                    clk_cnt  <= PULSE_WIDTH[LB_PULSE_WIDTH:0] + HALF_PULSE_WIDTH[LB_PULSE_WIDTH:0] - 1'b1;
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

    assign rx_done = (state == STT_STOP) && (clk_cnt == 0) && s_in_sync1;

    //-----------------------------------------------------------------------------
    // Output Interface Logic (Valid / Ready Handshake)
    //-----------------------------------------------------------------------------
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

    assign d_out = data_r;
    assign valid = valid_r;

endmodule
