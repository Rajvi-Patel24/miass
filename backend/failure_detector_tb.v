`timescale 1ns/1ps

module failure_detector_tb;
    reg clock = 0;
    reg reset = 1;
    reg failed_attempt = 0;
    wire repeated_failures;

    failure_detector detector(.clock(clock), .reset(reset), .failed_attempt(failed_attempt), .repeated_failures(repeated_failures));
    always #5 clock = ~clock;

    initial begin
        #7 reset = 0;
        #8 failed_attempt = 1;
        #10 failed_attempt = 0;
        #10 failed_attempt = 1;
        #10 failed_attempt = 0;
        #10 failed_attempt = 1;
        #2;
        if (repeated_failures) $display("FAILURE_DETECTOR|PASS|threshold reached");
        else $display("FAILURE_DETECTOR|FAIL|threshold not reached");
        $finish;
    end
endmodule
