//============================================================================
// Testbench: tb_cube_root_bram_ultra
// Paper  : An Ultra-Low Resource FPGA Architecture for Cube Root Computation
//          Using Pre-Scaled BRAM Lookup
//
// Coverage:
//   1. Latency check  : verifies done arrives 3 cycles after start
//   2. Boundary tests : sub-interval boundaries 0.5, 1.0, 2.0, 4.0-eps
//   3. BRAM coverage  : exhaustive test of all 384 lookup midpoints
//   4. Random tests   : 100 uniformly distributed samples in [0.5, 4)
//   5. Precision      : reports max & avg relative error vs. paper bounds
//============================================================================

`timescale 1ns/1ps

module tb_cube_root_bram_ultra_3cyc;

    parameter WIDTH      = 24;
    parameter CLK_PERIOD = 10;            // 100 MHz
    parameter N_PER_R    = 128;
    parameter N_FRAC_OUT = 23;            // Q1.23
    parameter N_FRAC_IN  = 22;            // Q2.22

    reg                 clk;
    reg                 rst_n;
    reg                 start;
    reg  [WIDTH-1:0]    radicand;
    wire                done;
    wire [WIDTH-1:0]    result;

    integer test_count, pass_count, fail_count;
    real    max_rel_error, sum_rel_error;
    real    y_real, expected, actual, rel_error;
    integer latency_cycles, latency_start;
    integer i, r;

    //=========================================================================
    // DUT
    //=========================================================================
    cube_root_bram_ultra_3cyc #(.WIDTH(WIDTH)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .radicand (radicand),
        .done     (done),
        .result   (result)
    );

    //=========================================================================
    // Clock
    //=========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //=========================================================================
    // Reference cube root (Newton iteration on real numbers)
    //=========================================================================
    function real cbrt_ref(input real x);
        real g; integer k;
        begin
            g = (x > 1.0) ? x/3.0 : 1.0;
            for (k = 0; k < 30; k = k + 1)
                g = (2.0*g + x/(g*g)) / 3.0;
            cbrt_ref = g;
        end
    endfunction

    //=========================================================================
    // Single test
    //=========================================================================
    task test_value(input [WIDTH-1:0] val);
        begin
            @(negedge clk);
            radicand = val;
            start    = 1'b1;
            @(negedge clk);
            start    = 1'b0;
            // wait for done (must arrive within 4 cycles for safety)
            @(posedge done);
            @(negedge clk);

            y_real    = $itor(val) / (1 << N_FRAC_IN);
            actual    = $itor(result) / (1 << N_FRAC_OUT);
            expected  = cbrt_ref(y_real);
            rel_error = (actual >= expected) ? (actual - expected)/expected
                                              : (expected - actual)/expected;

            test_count = test_count + 1;
            if (rel_error <= 0.0014) begin   // paper bound 0.13% + small margin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: y=%.6f got=%.6f exp=%.6f rel=%.4f%%",
                         y_real, actual, expected, rel_error*100);
            end
            if (rel_error > max_rel_error) max_rel_error = rel_error;
            sum_rel_error = sum_rel_error + rel_error;
        end
    endtask

    //=========================================================================
    // Latency check
    //=========================================================================
    task check_latency;
        integer cyc;
        begin
            @(negedge clk);
            radicand = 24'h400000;          // y = 1.0
            start    = 1'b1;
            latency_start = $time;
            @(negedge clk);
            start    = 1'b0;
            cyc = 0;
            while (!done && cyc < 10) begin
                @(posedge clk); cyc = cyc + 1;
            end
            latency_cycles = ($time - latency_start) / CLK_PERIOD;
            $display("Latency: %0d cycles (expected 3)", latency_cycles);
            if (latency_cycles != 3) begin
                $display("** LATENCY MISMATCH **"); $finish;
            end
        end
    endtask

    //=========================================================================
    // Main
    //=========================================================================
    initial begin
        $display("============================================");
        $display(" tb_cube_root_bram_ultra_3cyc");
        $display("============================================");
        rst_n         = 0;
        start         = 0;
        radicand      = 0;
        test_count    = 0;
        pass_count    = 0;
        fail_count    = 0;
        max_rel_error = 0.0;
        sum_rel_error = 0.0;

        #(5*CLK_PERIOD) rst_n = 1;
        #(2*CLK_PERIOD);

        // 1) Latency check
        check_latency();

        // 2) Sub-interval boundaries
        $display("\n--- Boundary tests ---");
        test_value(24'h200000);             // y = 0.5
        test_value(24'h3FFFFF);             // y just below 1
        test_value(24'h400000);             // y = 1.0
        test_value(24'h7FFFFF);             // y just below 2
        test_value(24'h800000);             // y = 2.0
        test_value(24'hFFFFFF);             // y just below 4

        // 3) Exhaustive BRAM midpoint test (384 entries)
        $display("\n--- Exhaustive BRAM midpoint test (384 entries) ---");
        for (r = 0; r < 3; r = r + 1) begin
            for (i = 0; i < N_PER_R; i = i + 1) begin
                // y_{r,i} = L_r + (i+0.5)/128 * W_r
                // Y_int = round(y_{r,i} * 2^22)
                // For r=0 (L=0.5,W=0.5): Y = 2^21 + (i+0.5)*2^14
                // For r=1 (L=1.0,W=1.0): Y = 2^22 + (i+0.5)*2^15
                // For r=2 (L=2.0,W=2.0): Y = 2^23 + (i+0.5)*2^16
                case (r)
                    0: test_value(24'h200000 + (i*16384 + 8192));
                    1: test_value(24'h400000 + (i*32768 + 16384));
                    2: test_value(24'h800000 + (i*65536 + 32768));
                endcase
            end
        end

        // 4) Random samples
        $display("\n--- Random tests (100 samples) ---");
        for (i = 0; i < 100; i = i + 1) begin
            test_value({2'b00, $random} & 24'hFFFFFF | 24'h200000);
        end

        // 5) Summary
        $display("\n============================================");
        $display(" TEST SUMMARY");
        $display("============================================");
        $display(" Total tests   : %0d", test_count);
        $display(" Passed        : %0d", pass_count);
        $display(" Failed        : %0d", fail_count);
        $display(" Max rel error : %.4f%% (paper: 0.13%%)",     max_rel_error*100);
        $display(" Avg rel error : %.4f%%",                     sum_rel_error/test_count*100);
        $display(" Latency       : %0d cycles (paper: 3)",      latency_cycles);
        $display("============================================");
        if (fail_count == 0) $display(" >>> ALL TESTS PASSED <<<");
        else                 $display(" *** %0d TESTS FAILED ***", fail_count);
        $display("============================================");
        $finish;
    end

    initial begin
        $dumpfile("tb_cube_root_bram_ultra_3cyc.vcd");
        $dumpvars(0, tb_cube_root_bram_ultra_3cyc);
        #1000000 $display("** TIMEOUT **"); $finish;
    end

endmodule
