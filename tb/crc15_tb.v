`timescale 1ns/1ps

module crc15_tb;

	reg clk;
	reg reset;
	reg enable;
	reg data_bit;
	wire [14:0] crc;

	localparam [7:0] DATA_SEQUENCE = 8'b1101_0110;
	// Start at zero and apply feedback = data_bit ^ crc[14], then shift left
	// and XOR 15'h4599 when feedback is 1, for bits 7 down to 0.
	// This recurrence gives 15'h6A25 for DATA_SEQUENCE.
	localparam [14:0] EXPECTED_CRC = 15'h6A25;

	integer bit_index;
	integer errors;

	crc15 dut (
		.clk(clk),
		.reset(reset),
		.enable(enable),
		.data_bit(data_bit),
		.crc(crc)
	);

	always #5 clk = ~clk;

	initial begin
		$dumpfile("crc15.vcd");
		$dumpvars(0, crc15_tb);

		clk = 1'b0;
		reset = 1'b1;
		enable = 1'b0;
		data_bit = 1'b0;
		errors = 0;

		repeat (2) @(posedge clk);
		#1;
		if (crc !== 15'b0) begin
			$display("FAIL: reset expected CRC 0000, observed %h.", crc);
			errors = errors + 1;
		end

		@(negedge clk);
		reset = 1'b0;
		for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
			@(negedge clk);
			data_bit = DATA_SEQUENCE[bit_index];
			enable = 1'b1;
			@(negedge clk);
			enable = 1'b0;
		end

		$display("CRC after DATA_SEQUENCE %b: %h", DATA_SEQUENCE, crc);
		if (crc !== EXPECTED_CRC) begin
			$display("FAIL: expected CRC %h, observed %h.", EXPECTED_CRC, crc);
			errors = errors + 1;
		end

		if (errors == 0)
			$display("PASS: reset and CRC sequence checks matched.");
		else
			$display("FAIL: %0d check(s) failed.", errors);

		$finish;
	end

endmodule
