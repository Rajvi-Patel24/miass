`timescale 1ns/1ps

module failure_detector #(
    parameter integer FAILURE_THRESHOLD = 3
)(
    input clock,
    input reset,
    input failed_attempt,
    output reg repeated_failures
);
    reg [3:0] failure_count;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            failure_count <= 0;
            repeated_failures <= 0;
        end else if (failed_attempt) begin
            if (failure_count < FAILURE_THRESHOLD) failure_count <= failure_count + 1;
            if (failure_count + 1 >= FAILURE_THRESHOLD) repeated_failures <= 1;
        end
    end
endmodule
