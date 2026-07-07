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
    input  logic         rstb,      // FPGA reset (active low)

    input  logic         enb,        // Active-low experiment enable

    input  logic         testen_toggle_sw,
    input  logic         afeen_toggle_sw,

    input  logic        we_experiment_duration,
    input  logic        we_toggle_period,
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

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb)
            clk50_en <= 1'b0;
        else
            clk50_en <= ~clk50_en;
    end

    // ============================================================
    // Falling-edge detector for ENB
    // ============================================================

    logic enb_d;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb)
            enb_d <= 1'b1;
        else
            enb_d <= enb;
    end

    logic start_experiment;

    assign start_experiment = (enb_d == 1'b1) &&
                              (enb   == 1'b0);

    // ============================================================
    // FSM state (declared here so start_pending can reference it)
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

    // FIX 2: start_experiment is a single-cycle pulse at 100 MHz, but the FSM
    // only advances on clk50_en cycles, so the pulse could land on the "wrong"
    // phase and be missed entirely, leaving the FSM stuck in IDLE forever.
    // Latch it into a sticky bit that's held until the FSM (running at the
    // 50 MHz update rate) actually consumes it.
    logic start_pending;

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb)
            start_pending <= 1'b0;
        else if (start_experiment)
            start_pending <= 1'b1;
        else if (clk50_en && state == IDLE && start_pending)
            start_pending <= 1'b0;
    end

    // ============================================================
    // Experiment duration timer
    // ============================================================

    logic exp_clear;
    logic exp_done;

    us_programmable_counter #(
        .COUNTER_WIDTH(8)
    ) experiment_timer (
        .clk       (clk),
        .rstb     (rstb),
        .enable    (experiment_ongoing),
        .clear     (exp_clear),
        .we        (we_experiment_duration),
        .max_value (experiment_duration_us),
        .count     (),
        .overflow_flag  (exp_done)
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
        .rstb     (rstb),
        .enable    (experiment_ongoing),
        .clear     (toggle_clear),
        .we        (we_toggle_period),
        .max_value (toggle_period_us),
        .count     (),
        .overflow_flag  (toggle_event)
    );

    // ============================================================
    // Glitch-free gated clock for clkafe
    // ============================================================

    // FIX 3: a plain "experiment_ongoing && clk" AND-gate can produce a
    // runt/glitch pulse on clkafe if experiment_ongoing transitions while clk
    // is high. Standard integrated-clock-gating (ICG) technique: latch the
    // enable while clk is LOW (transparent low phase), so it can only change
    // clkafe's behavior during the low phase of clk, never mid-high-pulse.
    logic experiment_ongoing_latched;

    always_latch begin
        if (!clk)
            experiment_ongoing_latched <= experiment_ongoing;
    end

    assign clkafe = experiment_ongoing_latched && clk;

    // NOTE: if targeting an FPGA, prefer a vendor primitive instead of this
    // inferred latch (e.g. Xilinx BUFGCE/BUFGMUX), since FPGA tools often
    // don't infer/route latch-based clock gates cleanly. This RTL is the
    // portable/ASIC-style equivalent; swap in the vendor cell if available.

    // ============================================================
    // testen / afeen: live combinational pass-through
    // ============================================================

    // FIX 5/6: testen and afeen now directly follow their toggle switches at
    // all times, independent of FSM state. Previously these were sampled
    // once at START_RX (or briefly tracked only during RUN_EXPERIMENT),
    // so changes to the switches outside that state/window were ignored.
    // They are now combinational and fully live, and have been removed
    // from the always_ff block below (including the reset branch, since a
    // continuously-driven wire doesn't need a reset value).
    assign testen = testen_toggle_sw;
    assign afeen  = afeen_toggle_sw;

    // ============================================================
    // Main FSM
    // Runs only at 50 MHz update rate
    // ============================================================
    
    always_ff @(posedge clk or negedge rstb) begin

        if (!rstb) begin

            state <= IDLE;

            chip_rstb <= 1'b1;

            rxtxb <= 1'b1;

            rxstate <= 1'b0;

            cseb <= 1'b1;

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

                case (state)

                    // ============================================
                    // Idle
                    // ============================================
                    IDLE: begin

                        chip_rstb <= 1'b1;

                        rxtxb <= 1'b1;

                        rxstate <= 1'b0;

                        cseb <= 1'b1;

                        experiment_ongoing <= 1'b0;

                        // FIX 2: check the latched sticky bit instead of the
                        // raw, possibly-missed start_experiment pulse.
                        if (start_pending) begin
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

                        cseb <= 1'b1;

                        rxtxb <= 1'b1;

                        experiment_done <= 1'b1;

                        // FIX 7: cyclic operation. If enb is still asserted
                        // (low), loop directly back into RESET_PULSE to
                        // refresh and restart the experiment automatically,
                        // instead of waiting in IDLE for a new falling edge
                        // that will never come while enb stays low.
                        // If enb has been deasserted, fall back to IDLE as
                        // before, ready for the next falling-edge trigger.
                        if (!enb) begin
                            state <= RESET_PULSE;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end

                endcase
            end
        end
    end

endmodule
