/*
    Behaviour:
    0. when enb goes low in the falling edge, and while it is low, start sequence:
    1. 1 clock rstb, 
    2. wait one clock
    3. set rxstate high, cseb to low, to activate internal digital circuits
    4. set testen high if  testen_toggle_sw is High, set afeen if afeen_toggle_sw is High
    5. start microsecond counter
    6. while microsecond counter didn't reach maximum programmable duration of experiment, 
           every X (prog) microseconds toggle rxtxb, for a single 50MHz clock cycle
    7. when microsecond counter reaches maximum programmable duration of RX cycle, 
        turn all enable flags off to the default state, waiting for the next enb signal
    
*/
module rx_tx_cycle_controller (

    input  logic         clk,        // 100 MHz system clock
    input  logic         rst_n,      // FPGA reset (active low)

    input  logic         enb,        // Active-low experiment enable

    input  logic         testen_toggle_sw,
    input  logic         afeen_toggle_sw,

    input  logic [7:0]  experiment_duration_us,
    input  logic [7:0]  toggle_period_us,

    output logic         chip_rstb,
    output logic         rxtxb,
    output logic         rxstate,
    output logic         testen,
    output logic         afeen,
    output logic         cseb,
    output logic         clkafe,

    output logic         experiment_ongoing,
    output logic         experiment_done
);

    // ============================================================
    // 50 MHz enable generator
    // ============================================================

    logic clk50_en;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk50_en <= 1'b0;
        else
            clk50_en <= ~clk50_en;
    end

    // ============================================================
    // Falling-edge detector for ENB
    // ============================================================

    logic enb_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            enb_d <= 1'b1;
        else
            enb_d <= enb;
    end

    logic start_experiment;

    assign start_experiment = (enb_d == 1'b1) &&
                              (enb   == 1'b0);

    // ============================================================
    // Experiment duration timer
    // ============================================================

    logic exp_clear;
    logic exp_done;

    us_programmable_counter #(
        .COUNTER_WIDTH(8)
    ) experiment_timer (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (experiment_ongoing),
        .clear     (exp_clear),
        .max_value (experiment_duration_us),
        .count     (),
        .max_flag  (exp_done)
    );

    // ============================================================
    // RX/TX toggle timer
    // ============================================================

    logic toggle_clear;
    logic toggle_event;

    us_programmable_counter #(
        .COUNTER_WIDTH(8)
    ) toggle_timer (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (experiment_ongoing),
        .clear     (toggle_clear),
        .max_value (toggle_period_us),
        .count     (),
        .max_flag  (toggle_event)
    );

    // ============================================================
    // FSM
    // ============================================================

    typedef enum logic [2:0] {
        IDLE,
        RESET_PULSE,
        WAIT_ONE_CLOCK,
        START_RX,
        RUN_EXPERIMENT,
        COMPLETE
    } state_t;

    state_t state;

    // ============================================================
    // Main FSM
    // Runs only at 50 MHz update rate
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state <= IDLE;

            chip_rstb <= 1'b1;

            rxtxb <= 1'b1;

            rxstate <= 1'b0;

            testen <= 1'b0;
            afeen  <= 1'b0;

            cseb <= 1'b1;

            clkafe <= 1'b0;

            experiment_ongoing <= 1'b0;
            experiment_done    <= 1'b0;

            exp_clear    <= 1'b1;
            toggle_clear <= 1'b1;

        end
        else begin

            // defaults
            exp_clear       <= 1'b0;
            toggle_clear    <= 1'b0;

            experiment_done <= 1'b0;

            // ====================================================
            // 50 MHz-controlled outputs/FSM
            // ====================================================

            if (clk50_en) begin

                // Optional generated 50 MHz output clock
                clkafe <= ~clkafe;

                case (state)

                    // ============================================
                    // Idle
                    // ============================================
                    IDLE: begin

                        chip_rstb <= 1'b1;

                        rxtxb <= 1'b1;

                        rxstate <= 1'b0;

                        testen <= 1'b0;
                        afeen  <= 1'b0;

                        cseb <= 1'b1;

                        experiment_ongoing <= 1'b0;

                        if (start_experiment) begin
                            state <= RESET_PULSE;
                        end
                    end

                    // ============================================
                    // Assert chip reset for 1 cycle
                    // ============================================
                    RESET_PULSE: begin

                        chip_rstb <= 1'b0;

                        state <= WAIT_ONE_CLOCK;
                    end

                    // ============================================
                    // Wait one clock after reset
                    // ============================================
                    WAIT_ONE_CLOCK: begin

                        chip_rstb <= 1'b1;

                        state <= START_RX;
                    end

                    // ============================================
                    // Enable RX experiment
                    // ============================================
                    START_RX: begin

                        rxstate <= 1'b1;

                        testen <= testen_toggle_sw;
                        afeen  <= afeen_toggle_sw;

                        cseb <= 1'b0;

                        experiment_ongoing <= 1'b1;

                        exp_clear    <= 1'b1;
                        toggle_clear <= 1'b1;

                        state <= RUN_EXPERIMENT;
                    end

                    // ============================================
                    // Main experiment loop
                    // ============================================
                    RUN_EXPERIMENT: begin

                        // periodic RX/TX toggle
                        if (toggle_event) begin

                            rxtxb <= ~rxtxb;

                            toggle_clear <= 1'b1;
                        end

                        // experiment complete
                        if (exp_done) begin

                            experiment_ongoing <= 1'b0;

                            state <= COMPLETE;
                        end
                    end

                    // ============================================
                    // Cleanup
                    // ============================================
                    COMPLETE: begin

                        rxstate <= 1'b0;

                        testen <= 1'b0;
                        afeen  <= 1'b0;

                        cseb <= 1'b1;

                        rxtxb <= 1'b1;

                        experiment_done <= 1'b1;

                        state <= IDLE;
                    end

                    default: begin
                        state <= IDLE;
                    end

                endcase
            end
        end
    end

endmodule
