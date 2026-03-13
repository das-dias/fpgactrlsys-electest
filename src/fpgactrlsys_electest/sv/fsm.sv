module fsm #(
    parameter
        DATA_WIDTH = 8,
        //BAUD_RATE           = 115200,
        CLK_FREQ            = 400_000_000,
        SAMPL_CLK_FREQ      = 50_000_000,
        DAT_READ_CLK_FREQ   = 25_000_000,
        INTERFACE_CLK_FREQ  = 100_000_000,
        PRBS_DRV_CLK_FREQ   = 50_000_000

    localparam
        MAX_VAL             = DATA_WIDTH - 1,
        //LB_DATA_WIDTH     = $clog2(DATA_WIDTH),
        //PULSE_WIDTH       = CLK_FREQ / BAUD_RATE,
        //LB_PULSE_WIDTH    = $clog2(PULSE_WIDTH),
        //HALF_PULSE_WIDTH  = PULSE_WIDTH / 2
)(
    input   logic clk, // 300 MHz
    input   logic rst_n,

    input   logic [DATA_WIDTH-1:0] next_operation,
    input   logic [DATA_WIDTH-1:0] operation_data_d_in,
    output  logic [DATA_WIDTH-1:0] operation_data_d_out,
    input   logic next_operation_ready,
    output  logic current_operation_done_success,
    //output  logic current_operation_done_error,

    input   logic sampled_data_d_in_ready,
    output  logic off_load_sampled_data_d_in,
    input   logic sampled_data_d_in_off_loading_done,

    input   logic prbs_crss_vector_ready_for_off_load,
    output  logic off_load_prbs_crss_memory,
    input   logic prbs_crss_memory_off_loading_done,

    input   logic prbs_en_vector_ready_for_off_load,
    output  logic off_load_prbs_en_memory,
    input   logic prbs_en_memory_off_loading_done,

    input   logic prbs_crss_programming_routine_done_success,
    //input   logic prbs_crss_programming_routine_done_error,
    output  logic start_prbs_crss_programming_routine,

    input   logic prbs_en_programming_routine_done_success,
    //input   logic prbs_en_programming_routine_done_error,
    output  logic start_prbs_en_programming_routine,

    input   logic tgc_programming_routine_done_success,
    //input   logic tgc_programming_routine_done_error,
    output  logic start_tgc_programming_routine,

    input   logic tr_cycle_programming_routine_done_success,
    //input   logic tr_cycle_imaging_routine_done_error,
    output  logic start_tr_cycle_programming_routine,

    input   logic dc_rst_cycle_programming_routine_done_success,
    //input   logic tr_cycle_imaging_routine_done_error,
    output  logic start_dc_rst_cycle_programming_routine,

    input   logic tr_cycle_imaging_routine_done_success,
    //input   logic tr_cycle_imaging_routine_done_error,
    output  logic start_tr_cycle_imaging_routine
);
    // FSM States:
    typedef enum logic [3:0] {
        FSM_WAITING_FETCH,
        FSM_OP_DONE,

        FSM_SET_PRBS_CRSS_SEED,
        FSM_SET_PRBS_EN_SEED,
        FSM_SET_T_R_CTRL_CLK_COUNT,
        FSM_SET_DC_RST_CYCL_CLK_COUNT,

        FSM_EXEC_T_R_CYCLE,
        FSM_SET_TGC_SETTING,

        FSM_TEST_PRBS,
        FSM_TEST_SET_TGC,
        FSM_TEST_DRV_CLK,
        FSM_TEST_SMPL_CLK
    } statetype;
    statetype   fsm_state;

    output  logic [DATA_WIDTH-1:0]  next_operation_q;
    output  logic [DATA_WIDTH-1:0]  next_operation_data_q;
    output  logic [DATA_WIDTH-1:0]  operation_data_d_out_q;

    assign operation_data_d_out <= operation_data_d_out_q;

    output  logic current_operation_done_success_q;
    //output  logic current_operation_done_error_q;
    assign current_operation_done_success = current_operation_done_success_q;
    //assign current_operation_done_error = current_operation_done_error_q;
    
    output  logic start_prbs_crss_programming_routine_q;
    assign start_prbs_crss_programming_routine = start_prbs_crss_programming_routine_q;

    output  logic start_prbs_en_programming_routine_q;
    assign start_prbs_en_programming_routine = start_prbs_en_programming_routine_q;

    output  logic start_tgc_programming_routine_q;
    assign start_tgc_programming_routine = start_tgc_programming_routine_q;

    output  logic start_tr_cycle_programming_routine_q;
    assign start_tr_cycle_programming_routine = start_tr_cycle_programming_routine_q;

    output  logic start_dc_rst_cycle_programming_routine_q;
    assign start_dc_rst_cycle_programming_routine = start_dc_rst_cycle_programming_routine_q;

    output  logic start_tr_cycle_imaging_routine_q;
    assign start_tr_cycle_imaging_routine = start_tr_cycle_imaging_routine_q;


    always_ff @(posedge clk of negedge rst_n) begin
        if (!rst_n) begin // async reset
        end else begin
            case (fsm_state)
                FSM_WAITING_FETCH: begin
                    if (next_operation_ready) begin
                        next_operation_q <= next_operation;
                        next_operation_data_q <= next_operation_data_q;
                        // Type-Safe checking and truncation of next operation
                        case (next_operation_q[3:0])
                            FSM_SET_PRBS_CRSS_SEED,
                            FSM_SET_PRBS_EN_SEED,
                            FSM_SET_T_R_CTRL_CLK_COUNT,
                            FSM_SET_DC_RST_CYCL_CLK_COUNT,
                            FSM_EXEC_T_R_CYCLE,
                            FSM_SET_TGC_SETTING,
                            FSM_TEST_PRBS,
                            FSM_TEST_SET_TGC,
                            FSM_TEST_DRV_CLK,
                            FSM_TEST_SMPL_CLK: fsm_state <= next_operation_q[3:0];
                            default: fsm_state <= FSM_WAITING_FETCH;
                        endcase
                    end
                end

                FSM_OP_DONE: begin  // 1 clk cycle delay on the fsm to make sure everything in sync
                    fsm_state <= FSM_WAITING_FETCH; 
                end

                FSM_SET_PRBS_CRSS_SEED: begin
                    if (!start_prbs_crss_programming_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_prbs_crss_programming_routine_q <= '1;
                    end
                    if (prbs_crss_programming_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end

                FSM_SET_PRBS_EN_SEED: begin
                    if (!start_prbs_en_programming_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_prbs_en_programming_routine_q <= '1;
                    end
                    if (prbs_en_programming_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end
                FSM_SET_T_R_CTRL_CLK_COUNT: begin
                    if (!start_tr_cycle_programming_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_tr_cycle_programming_routine_q <= '1;
                    end
                    if (tr_cycle_programming_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end

                FSM_SET_DC_RST_CYCL_CLK_COUNT: begin
                    if (!start_dc_rst_cycle_programming_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_dc_rst_cycle_programming_routine_q <= '1;
                    end
                    if (dc_rst_cycle_programming_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end

                FSM_EXEC_T_R_CYCLE: begin
                    if (!start_tr_cycle_imaging_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_tr_cycle_imaging_routine_q <= '1;
                    end
                    if (tr_cycle_imaging_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end

                FSM_SET_TGC: begin
                    if (!start_tgc_programming_routine_q) begin
                        operation_data_d_out_q <= next_operation_data_q;
                        start_tgc_programming_routine_q <= '1;
                    end
                    if (tgc_programming_routine_done_success)
                        fsm_state <= FSM_OP_DONE;
                end

                FSM_TEST_PRBS: begin
                end
                FSM_TEST_SET_TGC: begin
                end
                FSM_TEST_DRV_CLK: begin
                end
                FSM_TEST_SMPL_CLK: begin
                end
            endcase
        end
    end

endmodule;