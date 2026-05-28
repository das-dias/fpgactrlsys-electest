module toplevel (

    input  logic clk,       // 100 MHz clock
    input  logic rstb,

    // UART RX input
    input  logic uart_rx_i,

    // RX/TX controller switches
    input  logic testen_toggle_sw,
    input  logic afeen_toggle_sw,
    input  logic test_clock_toggle_sw,
    input  logic test_prbs_toggle_sw,

    // PRBS outputs
    output logic prbs_cross_out,
    output logic prbs_enable_out,

    // I2C
    output logic i2c_cse_n,
    output logic i2c_sda,
    output logic i2c_scl,

    // RX/TX control outputs
    output logic chip_rstb,
    output logic rxtxb,
    output logic rxstate,
    output logic testen,
    output logic afeen,
    output logic cseb,
    output logic clkafe,

    output logic experiment_ongoing,
    output logic experiment_done,

    output logic test_clk100mhz,
    output logic test_prbs50mhz
);

    // ============================================================
    // UART instruction map
    // ============================================================

    localparam logic [7:0] RUN_EXPERIMENT_ADDR      = 8'h01;
    localparam logic [7:0] PRBS_CROSS_ADDR          = 8'h02;
    localparam logic [7:0] PRBS_ENABLE_ADDR         = 8'h03;
    localparam logic [7:0] WATCHDOG_PROGRAM_ADDR    = 8'h04;
    localparam logic [7:0] EXPERIMENT_PROG_ADDR     = 8'h05;
    localparam logic [7:0] TOGGLE_PROG_ADDR         = 8'h06;

    // ============================================================
    // UART RX
    // ============================================================

    logic [7:0] uart_data;
    logic       uart_valid;

    logic uart_ready;

    assign uart_ready = 1'b1;

    uart_rx uart0 (
        .clk   (clk),
        .rstb  (rstb),
        .s_in  (uart_rx_i),
        .ready (uart_ready),
        .d_out (uart_data),
        .valid (uart_valid)
    );

    // ============================================================
    // UART receive FSM
    // Receives:
    // BYTE0 = address/instruction
    // BYTE1 = data
    // ============================================================

    typedef enum logic [0:0] {
        WAIT_ADDR,
        WAIT_DATA
    } uart_state_t;

    uart_state_t uart_state;

    logic [7:0] addr_reg;
    logic [7:0] data_reg;

    // ============================================================
    // Shared 8-bit programming bus
    // ============================================================

    logic [7:0] shared_data_bus;

    assign shared_data_bus = data_reg;

    // ============================================================
    // Decoder WE signals
    // ============================================================

    logic prbs_lfsr_cross_we;
    logic prbs_lfsr_enable_we;
    logic watchdog_pga_controller_we;
    logic experiment_duration_we;
    logic toggle_period_we;

    // ============================================================
    // Experiment enable register
    // Active-low enable
    // ============================================================

    logic experiment_enb;

    // ============================================================
    // Address decoder
    // ============================================================

    address_decoder decoder0 (
        .addr                        (addr_reg),

        .prbs_lfsr_cross_we          (prbs_lfsr_cross_we),
        .prbs_lfsr_enable_we         (prbs_lfsr_enable_we),
        .watchdog_pga_controller_we  (watchdog_pga_controller_we),
        .experiment_duration_we      (experiment_duration_we),
        .toggle_period_we            (toggle_period_we)
    );

    // Clock Testing Pins
    assign test_clk100mhz = test_clock_toggle_sw & clk;
    
    // PRBS testing pins
    // ============================================================
    // PRBS test generator
    // ============================================================
    logic prbs_sw_prev;
    logic prbs_sw_pulse; // one shot pulse to program the seed into test prbs

    always_ff @(posedge clk or negedge rstb) begin
        if (!rstb)
            prbs_sw_prev <= 1'b0;
        else
            prbs_sw_prev <= test_prbs_toggle_sw;
    end

    assign prbs_sw_pulse = test_prbs_toggle_sw & ~prbs_sw_prev; // rising edge pulse


    logic prbs_test_output;
    localparam logic [7:0] prbs_test_seed = 8'd42;
    prbs_lfsr test_prbs (
        .enb    (~test_prbs_toggle_sw),
        .clk    (clk),
        .rstb   (rstb),
        .we     (prbs_sw_pulse),
        .d_seed (prbs_test_seed),
        .s_out  (test_prbs50mhz)
    );


    // ============================================================
    // UART programming FSM
    // ============================================================

    always_ff @(posedge clk or negedge rstb) begin

        if (!rstb) begin

            uart_state <= WAIT_ADDR;

            addr_reg <= 8'h00;
            data_reg <= 8'h00;

            experiment_enb <= 1'b1;

        end
        else begin

            if (uart_valid) begin

                case (uart_state)

                    // ============================================
                    // First byte = address/instruction
                    // ============================================
                    WAIT_ADDR: begin

                        addr_reg <= uart_data;

                        uart_state <= WAIT_DATA;

                    end

                    // ============================================
                    // Second byte = data
                    // ============================================
                    WAIT_DATA: begin

                        data_reg <= uart_data;

                        // RUN experiment command
                        if (addr_reg == RUN_EXPERIMENT_ADDR) begin

                            // data = 0 -> run
                            if (uart_data == 8'h00)
                                experiment_enb <= 1'b0;

                            // nonzero -> stop
                            else
                                experiment_enb <= 1'b1;
                        end

                        uart_state <= WAIT_ADDR;

                    end

                endcase
            end
        end
    end

    // ============================================================
    // PRBS generators
    // ============================================================

    prbs_lfsr prbs_cross (

        .enb    (experiment_enb),

        .clk    (clk),
        .rstb  (rstb),

        .we     (prbs_lfsr_cross_we),

        .d_seed (shared_data_bus),

        .s_out  (prbs_cross_out)
    );

    prbs_lfsr prbs_enable (

        .enb    (experiment_enb),

        .clk    (clk),
        .rstb  (rstb),

        .we     (prbs_lfsr_enable_we),

        .d_seed (shared_data_bus),

        .s_out  (prbs_enable_out)
    );

    // ============================================================
    // Watchdog PGA controller
    // ============================================================

    watchdog_pga_controller watchdog0 (

        .clk           (clk),

        .rstb          (rstb),

        .enb           (experiment_enb),

        .we            (watchdog_pga_controller_we),

        .watchdog_max  (shared_data_bus),

        .i2c_cse_n     (i2c_cse_n),
        .i2c_sda       (i2c_sda),
        .i2c_scl       (i2c_scl)
    );

    // ============================================================
    // RX/TX experiment controller
    // ============================================================

    rx_tx_cycle_controller rx_tx0 (

        .clk                     (clk),
        .rstb                    (rstb),

        .enb                     (experiment_enb),

        .testen_toggle_sw        (testen_toggle_sw),
        .afeen_toggle_sw         (afeen_toggle_sw),

        .we_toggle_period        (toggle_period_we),
        .we_experiment_duration  (experiment_duration_we),
        .experiment_duration_us  (shared_data_bus),
        .toggle_period_us        (shared_data_bus),

        .chip_rstb               (chip_rstb),
        .rxtxb                   (rxtxb),
        .rxstate                 (rxstate),

        .testen                  (testen),
        .afeen                   (afeen),

        .cseb                    (cseb),
        .clkafe                  (clkafe),

        .experiment_ongoing      (experiment_ongoing),
        .experiment_done         (experiment_done)
    );

endmodule