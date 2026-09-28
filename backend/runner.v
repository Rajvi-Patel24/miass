`timescale 1ns/1ps

module runner;
    reg clock, reset, event_valid, event_failed;
    reg [15:0] recipient_code, amount;
    reg [31:0] event_time;
    reg [31:0] event_count;
    integer input_file, scan_result, index;
    reg [1023:0] input_file_name;
    wire [1:0] decision;
    wire [3:0] reason_code;

    fraud_engine engine(
        .clock(clock), .reset(reset), .event_valid(event_valid),
        .recipient_code(recipient_code), .amount(amount), .event_time(event_time),
        .event_failed(event_failed), .decision(decision), .reason_code(reason_code)
    );

    always #5 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;
        event_valid = 0;
        recipient_code = 0;
        amount = 0;
        event_time = 0;
        event_failed = 0;
        if (!$value$plusargs("input=%s", input_file_name)) begin
            $display("ERROR|missing input file");
            $finish;
        end
        #2 reset = 0;
        input_file = $fopen(input_file_name, "r");
        if (input_file == 0) begin
            $display("ERROR|cannot open input file");
            $finish;
        end
        scan_result = $fscanf(input_file, "%d\n", event_count);
        if (scan_result != 1 || event_count == 0) begin
            $display("ERROR|invalid event stream");
            $finish;
        end
        for (index = 0; index < event_count; index = index + 1) begin
            scan_result = $fscanf(input_file, "%d %d %d %d\n", recipient_code, amount, event_time, event_failed);
            if (scan_result != 4) begin
                $display("ERROR|invalid event row");
                $finish;
            end
            event_valid = 1;
            @(posedge clock);
            #1 event_valid = 0;
        end
        #1;
        $display("DECISION_CODE=%0d|REASON_CODE=%0d", decision, reason_code);
        $fclose(input_file);
        $finish;
    end
endmodule
