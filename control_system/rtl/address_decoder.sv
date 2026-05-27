module address_decoder #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] addr,

    output logic prbs_lfsr_cross_we,
    output logic prbs_lfsr_enable_we,
    output logic watchdog_pga_controller_we,
    output logic experiment_duration_we,
    output logic toggle_period_we
);

    // ============================================================
    // Address map
    // ============================================================
    //
    // 0x00 -> NONE
    // 0x01 -> PRBS cross register
    // 0x02 -> PRBS enable register
    // 0x03 -> Watchdog PGA register
    // 0x04 -> Experiment duration register
    // 0x05 -> Toggle period register
    //
    // ============================================================

    always_comb begin

        // Default outputs
        prbs_lfsr_cross_we         = 1'b0;
        prbs_lfsr_enable_we        = 1'b0;
        watchdog_pga_controller_we = 1'b0;
        experiment_duration_we     = 1'b0;
        toggle_period_we           = 1'b0;

        case (addr)

            8'h01: begin
                prbs_lfsr_cross_we = 1'b1;
            end

            8'h02: begin
                prbs_lfsr_enable_we = 1'b1;
            end

            8'h03: begin
                watchdog_pga_controller_we = 1'b1;
            end

            8'h04: begin
                experiment_duration_we = 1'b1;
            end

            8'h05: begin
                toggle_period_we = 1'b1;
            end

            default: begin
                // 0x00 and all undefined addresses map to NONE
            end

        endcase
    end

endmodule