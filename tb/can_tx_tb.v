`timescale 1ns/1ps

module can_tx_tb;

	reg clk;
	reg reset;
	reg start;
	reg bit_tick;
	reg [10:0] can_id;
	wire tx;
	integer errors;
	integer i;

	can_tx dut (
		.clk(clk),
		.reset(reset),
		.start(start),
		.bit_tick(bit_tick),
		.can_id(can_id),
		.tx(tx)
	);

	always #5 clk = ~clk;

	initial begin
		$dumpfile("can_tx.vcd");
		$dumpvars(0, can_tx_tb);

		clk = 1'b0;
		reset = 1'b1;
		start = 1'b0;
		bit_tick = 1'b0;
		can_id = 11'b10100110101;
		errors = 0;

		repeat (2) @(posedge clk);
		#1;
		if (tx !== 1'b1 || dut.state !== 3'd0) begin
			$display("ERROR: reset did not return the transmitter to IDLE.");
			errors = errors + 1;
		end

		@(negedge clk);
		reset = 1'b0;
		start = 1'b1;
		@(posedge clk);
		#1;
		start = 1'b0;
		if (tx !== 1'b0 || dut.state !== 3'd1) begin
			$display("ERROR: start did not enter SOF and drive dominant 0.");
			errors = errors + 1;
		end

		@(negedge clk);
		bit_tick = 1'b1;
		@(posedge clk);
		#1;
		if (dut.state !== 3'd2 || tx !== 1'b0) begin
			$display("ERROR: SOF did not advance to SEND_ID on bit_tick.");
			errors = errors + 1;
		end

		for (i = 0; i < 11; i = i + 1) begin
			@(negedge clk);
			bit_tick = 1'b0;
			@(negedge clk);
			bit_tick = 1'b1;
			@(posedge clk);
			#1;
			if (tx !== can_id[10-i]) begin
				$display("ERROR: ID bit %0d expected %b, observed %b.",
						 i + 1, can_id[10-i], tx);
				errors = errors + 1;
			end
			if (i == 10 && dut.state !== 3'd3) begin
				$display("ERROR: transmitter did not enter CONTROL after 11 ID bits.");
				errors = errors + 1;
			end
		end

		@(posedge clk);
		#1;
		if (tx !== can_id[0]) begin
			$display("ERROR: tx did not hold the last ID bit in CONTROL.");
			errors = errors + 1;
		end

		if (errors == 0)
			$display("PASS: reset, SOF, all 11 ID bits, and CONTROL transition verified.");
		else
			$display("FAIL: %0d error(s) detected.", errors);

		$finish;
	end

endmodule