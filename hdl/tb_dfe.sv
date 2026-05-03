// tb_dfe.sv
// Testbench for dfe_core.
//
// Flow:
//   1. $readmemh loads Q4.11 channel samples from ../vectors/channel_out.hex
//   2. Holds reset for 4 cycles then releases
//   3. Presents one sample per clock cycle
//   4. Captures decision_out at posedge (pre-NBA update) and writes to
//      ../vectors/hdl_decisions.txt  (one '0' or '1' per line)
//
// Parameters MUST match export_vectors.m and validate_hdl.m.
//
// COEFF_INIT encoding (Q1.15, tap 0 in MSBs):
//   h = [1.0, 0.5, -0.2]  →  post-cursors = [0.5, -0.2]
//   tap0 =  0.5  →  round( 0.5 * 32768) =  16384 = 0x4000
//   tap1 = -0.2  →  round(-0.2 * 32768) =  -6554 = 0xE666
//   packed: {16'h4000, 16'hE666} = 32'h4000E666

`timescale 1ns/1ps

module tb_dfe;

    // -----------------------------------------------------------------------
    // Parameters — keep in sync with export_vectors.m / validate_hdl.m
    // -----------------------------------------------------------------------
    localparam int N_SAMPLES  = 2000;
    localparam int NUM_TAPS   = 2;
    localparam int DATA_W     = 16;
    localparam int COEFF_W    = 16;

    localparam logic [NUM_TAPS*COEFF_W-1:0] COEFF_INIT = 32'h4000E666;

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    logic                     clk;
    logic                     rst_n;
    logic signed [DATA_W-1:0] data_in;
    logic                     decision_out;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    dfe_core #(
        .NUM_TAPS  (NUM_TAPS),
        .DATA_W    (DATA_W),
        .COEFF_W   (COEFF_W),
        .COEFF_INIT(COEFF_INIT)
    ) u_dfe (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_in     (data_in),
        .decision_out(decision_out)
    );

    // -----------------------------------------------------------------------
    // Clock: 10 ns period
    // -----------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Stimulus and capture
    // -----------------------------------------------------------------------
    logic [DATA_W-1:0] samples [0:N_SAMPLES-1];   // unsigned storage for readmemh
    integer out_fid;
    integer i;

    initial begin
        $readmemh("../vectors/channel_out.hex", samples);

        out_fid = $fopen("../vectors/hdl_decisions.txt", "w");
        if (out_fid == 0)
            $fatal(1, "ERROR: cannot open ../vectors/hdl_decisions.txt");

        // Reset
        rst_n   = 1'b0;
        data_in = '0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Feed samples, one per clock cycle
        for (i = 0; i < N_SAMPLES; i++) begin
            @(negedge clk);                          // drive on falling edge
            data_in = signed'(samples[i]);           // reinterpret bits as signed
            @(posedge clk);
            // Sample at posedge event so we record the same decision value
            // that the tap bank flops capture on this clock edge.
            $fdisplay(out_fid, "%b", decision_out);
        end

        $fclose(out_fid);
        $display("Done. Decisions written to ../vectors/hdl_decisions.txt");
        $finish;
    end

endmodule
