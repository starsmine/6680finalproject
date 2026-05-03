// dfe_tap_bank.sv
// Fixed-tap DFE feedback bank.
//
// Stores the last NUM_TAPS decisions in a shift register, converts each to a
// Q1.15 signed value, multiplies by the corresponding hardcoded coefficient,
// accumulates, and returns a re-normalised Q1.15 result.
//
// Fixed-point arithmetic:
//   decision bit  →  Q1.15: 1 → 0x7FFF (+1), 0 → 0x8000 (-1)
//   Q1.15 × Q1.15 product  →  Q2.30 in a 32-bit accumulator
//   right-shift by (30-OUT_FRAC) converts to output format (Q4.11 by default)
//
// Coefficients:
//   Packed into COEFF_INIT, MSBs = tap 0, LSBs = tap NUM_TAPS-1.
//   Default is all zeros (no feedback).
//
// Parameters:
//   NUM_TAPS   : number of post-cursor feedback taps  (default 2)
//   COEFF_W    : coefficient / data word width in bits (default 16)
//   DATA_W     : output word width
//   OUT_FRAC   : output fractional bits (11 for Q4.11)
//   COEFF_INIT : packed Q1.15 coefficients (NUM_TAPS * COEFF_W bits)

`timescale 1ns/1ps

module dfe_tap_bank #(
    parameter int                                    NUM_TAPS   = 2,
    parameter int                                    COEFF_W    = 16,
    parameter int                                    DATA_W     = 16,
    parameter int                                    OUT_FRAC   = 11,
    parameter logic [NUM_TAPS*COEFF_W-1:0]           COEFF_INIT = '0
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        decision_in,        // current decision (1=+1, 0=-1)
    output logic signed [DATA_W-1:0]    tap_sum             // Q1.15 ISI estimate
);

    localparam int ACC_W = 2 * COEFF_W;   // 32-bit accumulator holds Q2.30 product
    localparam int ACC_FRAC = 2 * (COEFF_W - 1);  // 30 for Q1.15 x Q1.15
    localparam int OUT_SHIFT = ACC_FRAC - OUT_FRAC;

    // -----------------------------------------------------------------------
    // Coefficient ROM: unpack COEFF_INIT into a signed array
    //   tap 0 lives in the MSBs of COEFF_INIT
    // -----------------------------------------------------------------------
    logic signed [COEFF_W-1:0] coeffs [NUM_TAPS];

    generate
        for (genvar gi = 0; gi < NUM_TAPS; gi++) begin : gen_coeffs
            assign coeffs[gi] = signed'(COEFF_INIT[(NUM_TAPS-1-gi)*COEFF_W +: COEFF_W]);
        end
    endgenerate

    // -----------------------------------------------------------------------
    // Decision shift register
    //   decision_sr[0] = most recent past decision
    //   decision_sr[1] = one symbol earlier, etc.
    // -----------------------------------------------------------------------
    logic decision_sr [NUM_TAPS];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                decision_sr[i] <= 1'b0;
        end else begin
            decision_sr[0] <= decision_in;
            for (int i = 1; i < NUM_TAPS; i++)
                decision_sr[i] <= decision_sr[i-1];
        end
    end

    // -----------------------------------------------------------------------
    // Multiply-accumulate (combinational)
    //   Declarations MUST come before any statements (SV LRM 12.2.1)
    // -----------------------------------------------------------------------
    logic signed [ACC_W-1:0] acc;

    always_comb begin
        logic signed [COEFF_W-1:0] dec_val;    // Q1.15 representation of decision bit
        logic signed [ACC_W-1:0]   dec_ext;    // sign-extended decision
        logic signed [ACC_W-1:0]   coeff_ext;  // sign-extended coefficient
        acc = '0;
        for (int i = 0; i < NUM_TAPS; i++) begin
            // Map 1-bit decision → Q1.15 signed: +1 = 0x7FFF, -1 = 0x8000
            dec_val = decision_sr[i] ? {1'b0, {(COEFF_W-1){1'b1}}}   // 0x7FFF
                                     : {1'b1, {(COEFF_W-1){1'b0}}};  // 0x8000

            // Explicit signed extension avoids unsigned-cast corner cases.
            dec_ext   = $signed(dec_val);
            coeff_ext = $signed(coeffs[i]);
            acc       = acc + (dec_ext * coeff_ext);
        end
    end

    // -----------------------------------------------------------------------
    // Re-normalise Q2.30 -> output fixed-point format.
    // Default OUT_FRAC=11 gives Q4.11 output to match channel samples.
    // -----------------------------------------------------------------------
    assign tap_sum = $signed(acc >>> OUT_SHIFT);

endmodule
