`timescale 1ns/1ps

module shift_register_tb;

	reg clk;
	reg reset;
	reg load;
	reg [7:0] parallel_in;
	wire serial_out;

	reg [7:0] expected_data;
	reg expected_bit;
	integer i;
	integer errors;

	shift_register dut (
		.clk(clk),
		.reset(reset),
		.load(load),
		.parallel_in(parallel_in),
		.serial_out(serial_out)
	);

	always #5 clk = ~clk;

	initial begin
		$dumpfile("shift_register.vcd");
		$dumpvars(0, shift_register_tb);

		clk = 1'b0;
		reset = 1'b1;
		load = 1'b0;
		parallel_in = 8'b0;
		expected_data = 8'b10110010;
		errors = 0;

		repeat (2) @(posedge clk);
		@(negedge clk);
		reset = 1'b0;
		parallel_in = expected_data;
		load = 1'b1;

		@(posedge clk);
		#1;
		load = 1'b0;

		expected_bit = expected_data[7];
		$display("After load: expected serial_out=%b, observed=%b", expected_bit, serial_out);
		if (serial_out !== expected_bit) begin
			$display("ERROR: serial_out did not show the MSB after load.");
			errors = errors + 1;
		end

		for (i = 0; i < 8; i = i + 1) begin
			@(posedge clk);
			#1;

			if (i < 7)
				expected_bit = expected_data[6-i];
			else
				expected_bit = 1'b0;

			$display("Shift cycle %0d: expected serial_out=%b, observed=%b",
					 i + 1, expected_bit, serial_out);
			if (serial_out !== expected_bit) begin
				$display("ERROR: unexpected serial output on shift cycle %0d.", i + 1);
				errors = errors + 1;
			end
		end

		if (errors == 0)
			$display("PASS: all serial output checks matched.");
		else
			$display("FAIL: %0d serial output check(s) failed.", errors);

		$finish;
	end

endmodule
