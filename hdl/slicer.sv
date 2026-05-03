// slicer.sv
// Hard-decision slicer for signed fixed-point input.
//
// Decision rule (NRZ binary):
//   data_in >= 0  →  decision = 1  (represents +1)
//   data_in <  0  →  decision = 0  (represents -1)
//
//
// Tie at zero: data_in == 0 has MSB=0, so decision=1 (+1).
// This matches the MATLAB reference: if sign(x)==0, d=+1.
//
// Parameters:
//   DATA_W : input word width in bits (default 16)

`timescale 1ns/1ps

module slicer #(
    parameter int DATA_W = 16
)(
    input  logic signed [DATA_W-1:0] data_in,   // corrected sample (Q4.11)
    output logic                     decision    // 1 = +1,  0 = -1
);

    assign decision = ~data_in[DATA_W-1];

endmodule
