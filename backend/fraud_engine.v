`timescale 1ns/1ps

module fraud_engine #(
    parameter integer VERIFY_THRESHOLD = 5000,
    parameter integer REPEAT_THRESHOLD = 3,
    parameter integer RAPID_THRESHOLD = 3,
    parameter integer FAILURE_THRESHOLD = 3,
    parameter integer REPEAT_WINDOW = 300,
    parameter integer RAPID_WINDOW = 30,
    parameter [15:0] WATCHLIST_ONE = 16'd11903,
    parameter [15:0] WATCHLIST_TWO = 16'd2065
)(
    input clock,
    input reset,
    input event_valid,
    input [15:0] recipient_code,
    input [15:0] amount,
    input [31:0] event_time,
    input event_failed,
    output reg [1:0] decision,
    output reg [3:0] reason_code
);
    localparam [1:0] ALLOW = 2'b00;
    localparam [1:0] VERIFY = 2'b01;
    localparam [1:0] FLAG = 2'b10;
    localparam [3:0] REASON_NONE = 4'd0;
    localparam [3:0] REASON_AMOUNT = 4'd1;
    localparam [3:0] REASON_REPEAT = 4'd2;
    localparam [3:0] REASON_WATCHLIST = 4'd3;
    localparam [3:0] REASON_RAPID = 4'd4;
    localparam [3:0] REASON_FAILURES = 4'd5;

    reg [15:0] previous_recipient;
    reg [31:0] previous_time;
    reg has_previous;
    integer repeat_count;
    integer rapid_count;
    integer failure_count;

    wire watchlist_match = (recipient_code == WATCHLIST_ONE) || (recipient_code == WATCHLIST_TWO);
    wire same_recipient = has_previous && (recipient_code == previous_recipient) && ((event_time - previous_time) <= REPEAT_WINDOW);
    wire rapid_event = has_previous && (recipient_code != previous_recipient) && ((event_time - previous_time) <= RAPID_WINDOW);
    wire repeated_payment = repeat_count >= REPEAT_THRESHOLD;
    wire rapid_attempts = rapid_count >= RAPID_THRESHOLD;
    wire repeated_failures = event_failed && ((failure_count + 1) >= FAILURE_THRESHOLD);

    always @(*) begin
        decision = ALLOW;
        reason_code = REASON_NONE;
        if (watchlist_match) begin
            decision = FLAG;
            reason_code = REASON_WATCHLIST;
        end else if (rapid_attempts) begin
            decision = FLAG;
            reason_code = REASON_RAPID;
        end else if (repeated_failures) begin
            decision = FLAG;
            reason_code = REASON_FAILURES;
        end else if (amount >= VERIFY_THRESHOLD) begin
            decision = VERIFY;
            reason_code = REASON_AMOUNT;
        end else if (repeated_payment) begin
            decision = VERIFY;
            reason_code = REASON_REPEAT;
        end
    end

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            previous_recipient <= 0;
            previous_time <= 0;
            has_previous <= 0;
            repeat_count <= 0;
            rapid_count <= 0;
            failure_count <= 0;
        end else if (event_valid) begin
            if (same_recipient) repeat_count <= repeat_count + 1;
            else repeat_count <= 1;
            if (rapid_event) rapid_count <= rapid_count + 1;
            else rapid_count <= 1;
            if (event_failed) failure_count <= failure_count + 1;
            else failure_count <= 0;
            previous_recipient <= recipient_code;
            previous_time <= event_time;
            has_previous <= 1;
        end
    end
endmodule
