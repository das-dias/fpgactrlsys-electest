module address_decoder #(
    parameter int WIDTH = 8
)(
    input  logic             write_strobe, // Strobe pulse when write data is valid
    input  logic [WIDTH-1:0] addr,

    output logic             prbs_lfsr_cross_we,
    output logic             prbs_lfsr_enable_we,
    output logic             watchdog_pga_controller_we,
    output logic             experiment_duration_we,
    output logic             toggle_period_we,
    output logic             lna_gain_we,
    output logic             pga_gain_we
);

    // ============================================================
    // Address map
    // ============================================================
    // 0x01 -> RUN_EXPERIMENT (Handled directly in top-level FSM)
    // 0x02 -> PRBS cross register
    // 0x03 -> PRBS enable register
    // 0x04 -> Watchdog PGA register
    // 0x05 -> Experiment duration register
    // 0x06 -> Toggle period register
    // 0x07 -> LNA gain register
    // 0x08 -> PGA gain register
    // ============================================================

    always_comb begin
        // Default outputs
        prbs_lfsr_cross_we         = 1'b0;
        prbs_lfsr_enable_we        = 1'b0;
        watchdog_pga_controller_we = 1 me; // 1'b0
        watchdog_pga_controller_we = 1'b0;
        experiment_duration_we     = 1'b0;
        toggle_period_we           = 1'b0;
        lna_gain_we                = 1'b0;
        pga_gain_we                = 1'b0;

        // Gate write enables with the write_strobe signal
        if (write_strobe) begin
            case (addr)
                8'h02: prbs_lfsr_cross_we         = 1'b1;
                8'h03: prbs_lfsr_enable_we        = 1'b1;
                8'h04: watchdog_pga_controller_we = 1'b1;
                8'h05: experiment_duration_we     = 1'b1;
                8'h06: toggle_period_we           = 1'b1;
                8'h07: lna_gain_we                = 1'b1;
                8'h08: pga_gain_we                = 1'b1;
                default: ; // Undefined addresses remain 1'b0
            endcase
        end
    end

endmodule
