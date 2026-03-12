module fsm #(
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
    input   logic rst_n,
    input   logic s_in,
    input   logic ready,
    output  logic [DATA_WIDTH-1:0] d_out,
    output  logic valid
);

    typedef enum logic [4:0] {
        FSM_READY,
        FSM_FETCH_OP,
        FSM_SET_PRBS_CRSS_SEED,
        FSM_SET_PRBS_EN_SEED,
        FSM_PROG_T_R_CTRL,
        FSM_EXEC_T_R_CYCLE,
        FSM_SET_TGC,
        FSM_SET_DC_RST_CYCL,
        FSM_OP_DONE,

        FSM_TEST_PRBS,
        FSM_TEST_SET_TGC,
        FSM_TEST_DRV_CLK,
        FSM_TEST_SMPL_CLK

    } statetype;
    
    statetype                state;