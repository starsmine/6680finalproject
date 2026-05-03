// dfe_core.sv
// Top-level DFE core.  Wires the subtractor, slicer, and tap bank.
//
// Data path (per symbol clock):
//   1. tap_sum  = dfe_tap_bank output (Q1.15 ISI estimate from past decisions)
//   2. equalized = data_in - tap_sum  (saturating signed subtraction)
//   3. decision_out = slicer(equalized)
//   4. decision_out is fed back into dfe_tap_bank; registered on next posedge clk
//
// Saturation:
//   Subtraction is widened to DATA_W+1 bits to detect overflow.
//   If the top two bits of the wide result are 2'b01 → positive overflow → MAX.
//   If the top two bits are 2'b10 → negative overflow → MIN.
//   Otherwise the bottom DATA_W bits are taken directly.
//
// Parameters:
//   NUM_TAPS   : number of feedback taps (must match h post-cursor count)
//   DATA_W     : input/output word width in bits        (default 16)
//   DATA_FRAC  : fractional bits of input/output format (11 for Q4.11)
//   COEFF_W    : coefficient word width in bits         (default 16)
//   COEFF_INIT : packed Q1.15 coefficients, tap 0 in MSBs (default all-zero)

`timescale 1ns/1ps

module dfe_core #(
    parameter int                               NUM_TAPS   = 2,
    parameter int                               DATA_W     = 16,
    parameter int                               DATA_FRAC  = 11,
    parameter int                               COEFF_W    = 16,
    parameter logic [NUM_TAPS*COEFF_W-1:0]      COEFF_INIT = '0
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic signed [DATA_W-1:0]    data_in,        // channel sample
    output logic                        decision_out    // 1=+1, 0=-1
);

    // -----------------------------------------------------------------------
    // Tap bank
    // -----------------------------------------------------------------------
    logic signed [DATA_W-1:0] tap_sum;

    dfe_tap_bank #(
        .NUM_TAPS  (NUM_TAPS),
        .COEFF_W   (COEFF_W),
        .DATA_W    (DATA_W),
        .OUT_FRAC  (DATA_FRAC),
        .COEFF_INIT(COEFF_INIT)
    ) u_tap_bank (
        .clk         (clk),
        .rst_n       (rst_n),
        .decision_in (decision_out),   // combinational feedback; registered inside tap bank
        .tap_sum     (tap_sum)
    );

    // -----------------------------------------------------------------------
    // Saturating subtractor:  equalized = data_in - tap_sum
    //   Widen to DATA_W+1 to catch overflow, then saturate.
    // -----------------------------------------------------------------------
    logic signed [DATA_W:0]   sub_wide;
    logic signed [DATA_W-1:0] equalized;

    assign sub_wide = {data_in[DATA_W-1],  data_in}
                    - {tap_sum[DATA_W-1],  tap_sum};

    assign equalized =
        (sub_wide[DATA_W:DATA_W-1] == 2'b01) ? {1'b0, {(DATA_W-1){1'b1}}}  // + overflow → MAX
      : (sub_wide[DATA_W:DATA_W-1] == 2'b10) ? {1'b1, {(DATA_W-1){1'b0}}}  // - overflow → MIN
      :                                         sub_wide[DATA_W-1:0];        // no overflow

    // -----------------------------------------------------------------------
    // Slicer
    // -----------------------------------------------------------------------
    slicer #(
        .DATA_W(DATA_W)
    ) u_slicer (
        .data_in  (equalized),
        .decision (decision_out)
    );

endmodule
