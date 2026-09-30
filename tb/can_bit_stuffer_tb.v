`timescale 1ns/1ps

module can_bit_stuffer_tb;

    reg clk;
    reg reset;
    reg bit_tick;
    reg real_bit;
    wire wire_bit;
    wire stuff_bit;
    wire real_bit_consumed;
    wire [2:0] run_count;

    integer errors;

    can_bit_stuffer dut (
        .clk(clk),
        .reset(reset),
        .bit_tick(bit_tick),
        .real_bit(real_bit),
        .wire_bit(wire_bit),
        .stuff_bit(stuff_bit),
        .real_bit_consumed(real_bit_consumed),
        .run_count(run_count)
    );

    always #5 clk = ~clk;

    task run_case;
        input [191:0] case_name;
        input integer input_length;
        input [15:0] input_bits;
        input integer expected_length;
        input [15:0] expected_bits;
        input integer expected_stuff_count;
        integer input_index;
        integer wire_index;
        integer stuff_count;
        integer expected_run_count;
        reg previous_expected_bit;
        reg pending_check;
        reg held_real_bit;
        begin
            @(negedge clk);
            reset = 1'b1;
            bit_tick = 1'b0;
            real_bit = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (wire_bit !== 1'b0 || stuff_bit !== 1'b0 ||
                real_bit_consumed !== 1'b0 || run_count !== 3'd0) begin
                $display("FAIL [%0s]: reset did not initialize outputs and run_count.", case_name);
                errors = errors + 1;
            end

            @(negedge clk);
            reset = 1'b0;
            input_index = 0;
            wire_index = 0;
            stuff_count = 0;
            expected_run_count = 0;
            previous_expected_bit = 1'b0;
            pending_check = 1'b0;

            while (wire_index < expected_length) begin
                @(negedge clk);
                if (input_index < input_length)
                    real_bit = input_bits[input_length - 1 - input_index];
                bit_tick = 1'b1;

                @(posedge clk);
                #1;
                if (wire_bit !== expected_bits[expected_length - 1 - wire_index]) begin
                    $display("FAIL [%0s]: wire bit %0d expected %b, observed %b.",
                             case_name, wire_index + 1,
                             expected_bits[expected_length - 1 - wire_index], wire_bit);
                    errors = errors + 1;
                end

                if (expected_run_count == 0 ||
                    expected_bits[expected_length - 1 - wire_index] !== previous_expected_bit)
                    expected_run_count = 1;
                else
                    expected_run_count = expected_run_count + 1;
                previous_expected_bit = expected_bits[expected_length - 1 - wire_index];
                if (run_count !== expected_run_count[2:0]) begin
                    $display("FAIL [%0s]: run_count after wire bit %0d expected %0d, observed %0d.",
                             case_name, wire_index + 1, expected_run_count, run_count);
                    errors = errors + 1;
                end

                if (stuff_bit === 1'b1) begin
                    stuff_count = stuff_count + 1;
                    if (real_bit_consumed !== 1'b0) begin
                        $display("FAIL [%0s]: real input consumed during stuff bit %0d.",
                                 case_name, wire_index + 1);
                        errors = errors + 1;
                    end
                    if (input_index < input_length) begin
                        held_real_bit = real_bit;
                        pending_check = 1'b1;
                    end
                end else begin
                    if (real_bit_consumed !== 1'b1) begin
                        $display("FAIL [%0s]: real bit was not consumed at wire bit %0d.",
                                 case_name, wire_index + 1);
                        errors = errors + 1;
                    end else begin
                        if (pending_check && real_bit !== held_real_bit) begin
                            $display("FAIL [%0s]: pending real bit changed after stuffing.", case_name);
                            errors = errors + 1;
                        end
                        pending_check = 1'b0;
                        input_index = input_index + 1;
                    end
                end

                wire_index = wire_index + 1;
                @(negedge clk);
                bit_tick = 1'b0;
            end

            if (input_index != input_length) begin
                $display("FAIL [%0s]: consumed %0d of %0d real bits.",
                         case_name, input_index, input_length);
                errors = errors + 1;
            end
            if (stuff_count != expected_stuff_count) begin
                $display("FAIL [%0s]: expected %0d stuff bits, observed %0d.",
                         case_name, expected_stuff_count, stuff_count);
                errors = errors + 1;
            end
            $display("Checked [%0s]: %0d real bits, %0d wire bits, %0d stuff bits.",
                     case_name, input_length, expected_length, stuff_count);
        end
    endtask

    initial begin
        $dumpfile("can_bit_stuffer.vcd");
        $dumpvars(0, can_bit_stuffer_tb);

        clk = 1'b0;
        reset = 1'b1;
        bit_tick = 1'b0;
        real_bit = 1'b0;
        errors = 0;

        run_case("A: 111110", 6, 16'b0000_0000_0011_1110,
                 7, 16'b0000_0000_0111_1100, 1);
        run_case("B: 000001", 6, 16'b0000_0000_0000_0001,
                 7, 16'b0000_0000_0000_0011, 1);
        run_case("C: 11111011111", 11, 16'b0000_0111_1101_1111,
                 13, 16'b0001_1111_0011_1110, 2);
        run_case("D: no five-bit run", 7, 16'b0000_0000_0101_1010,
                 7, 16'b0000_0000_0101_1010, 0);

        if (errors == 0)
            $display("PASS: all bit-stuffing sequences and real-bit hold checks passed.");
        else
            $display("FAIL: %0d bit-stuffer check(s) failed.", errors);

        $finish;
    end

endmodule
