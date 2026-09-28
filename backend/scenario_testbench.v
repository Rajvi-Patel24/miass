`timescale 1ns/1ps

module scenario_testbench;
    reg clock, reset, event_valid, event_failed;
    reg [15:0] recipient_code, amount;
    reg [31:0] event_time;
    wire [1:0] decision;
    wire [3:0] reason_code;
    integer passed, failed;

    fraud_engine engine(
        .clock(clock), .reset(reset), .event_valid(event_valid),
        .recipient_code(recipient_code), .amount(amount), .event_time(event_time),
        .event_failed(event_failed), .decision(decision), .reason_code(reason_code)
    );
    always #5 clock = ~clock;

    task send_event;
        input [15:0] next_recipient;
        input [15:0] next_amount;
        input [31:0] next_time;
        input next_failed;
        begin
            recipient_code = next_recipient;
            amount = next_amount;
            event_time = next_time;
            event_failed = next_failed;
            event_valid = 1;
            @(posedge clock);
            #1 event_valid = 0;
        end
    endtask

    task expect_decision;
        input [1:0] expected;
        input [3:0] expected_reason;
        input [127:0] label;
        begin
            if (decision === expected && reason_code === expected_reason) begin
                passed = passed + 1;
                $display("SCENARIO|%0s|PASS|decision=%0d|reason=%0d", label, decision, reason_code);
            end else begin
                failed = failed + 1;
                $display("SCENARIO|%0s|FAIL|expected=%0d/%0d|actual=%0d/%0d", label, expected, expected_reason, decision, reason_code);
            end
        end
    endtask

    task start_case;
        begin
            reset = 1;
            #2 reset = 0;
            event_valid = 0;
            event_failed = 0;
        end
    endtask

    initial begin
        clock = 0; reset = 0; event_valid = 0; event_failed = 0;
        passed = 0; failed = 0;

        start_case; send_event(100, 250, 1000, 0); expect_decision(2'b00, 4'd0, "ordinary");
        start_case; send_event(100, 5000, 2000, 0); expect_decision(2'b01, 4'd1, "amount");
        start_case; send_event(200, 250, 3000, 0); send_event(200, 250, 3100, 0); send_event(200, 250, 3200, 0); expect_decision(2'b01, 4'd2, "repeated");
        start_case; send_event(300, 250, 4000, 0); send_event(301, 250, 4010, 0); send_event(302, 250, 4020, 0); expect_decision(2'b10, 4'd4, "rapid");
        start_case; send_event(11903, 250, 5000, 0); expect_decision(2'b10, 4'd3, "watchlist");
        start_case; send_event(400, 250, 6000, 1); send_event(400, 250, 6100, 1); send_event(400, 250, 6200, 1); expect_decision(2'b10, 4'd5, "failures");
        start_case; send_event(500, 250, 7000, 0); send_event(600, 250, 7500, 0); expect_decision(2'b00, 4'd0, "unrelated");

        $display("SUMMARY|total=7|passed=%0d|failed=%0d", passed, failed);
        $finish;
    end
endmodule
