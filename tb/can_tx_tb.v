`timescale 1ns/1ps

module can_tx_tb;

	reg clk;
	reg reset;
	reg start;
	reg bit_tick;
	reg [10:0] can_id;
	reg [3:0] dlc;
	reg [63:0] data;
	wire tx;
	integer errors;
	integer i;

	can_tx dut (
		.clk(clk),
		.reset(reset),
		.start(start),
		.bit_tick(bit_tick),
		.can_id(can_id),
		.dlc(dlc),
		.data(data),
		.tx(tx)
	);

	always #5 clk = ~clk;

	task pulse_tick;
		begin
			@(negedge clk);
			bit_tick = 1'b1;
			@(posedge clk);
			#1;
			@(negedge clk);
			bit_tick = 1'b0;
		end
	endtask

	task check_data_case;
		input [3:0] test_dlc;
		input [63:0] test_data;
		input [6:0] expected_bit_count;
		integer bit_index;
		reg [10:0] expected_id;
		reg [6:0] expected_control;
		begin
			expected_id = 11'b10100110101;
			expected_control = {3'b000, test_dlc};
			@(negedge clk);
			reset = 1'b1;
			start = 1'b0;
			bit_tick = 1'b0;
			repeat (2) @(posedge clk);
			@(negedge clk);
			reset = 1'b0;
			can_id = expected_id;
			dlc = test_dlc;
			data = test_data;
			start = 1'b1;
			@(posedge clk);
			#1;
			start = 1'b0;
			can_id = ~expected_id;
			dlc = 4'd0;
			data = ~test_data;
			if (tx !== 1'b0 || dut.state !== 3'd1) begin
				$display("ERROR: DLC %0d case failed to enter SOF.", test_dlc);
				errors = errors + 1;
			end

			pulse_tick();
			if (dut.state !== 3'd2) begin
				$display("ERROR: DLC %0d case failed to enter SEND_ID.", test_dlc);
				errors = errors + 1;
			end

			for (bit_index = 0; bit_index < 11; bit_index = bit_index + 1) begin
				pulse_tick();
				if (tx !== expected_id[10-bit_index]) begin
					$display("ERROR: DLC %0d case ID bit %0d was not MSB first.",
							 test_dlc, bit_index + 1);
					errors = errors + 1;
				end
				if (bit_index == 10 && dut.state !== 3'd3) begin
					$display("ERROR: DLC %0d case did not enter CONTROL after the ID.",
							 test_dlc);
					errors = errors + 1;
				end
			end

			for (bit_index = 0; bit_index < 7; bit_index = bit_index + 1) begin
				pulse_tick();
				if (tx !== expected_control[6-bit_index]) begin
					$display("ERROR: DLC %0d control bit %0d expected %b, observed %b.",
							 test_dlc, bit_index + 1,
							 expected_control[6-bit_index], tx);
					errors = errors + 1;
				end
				if (bit_index < 6 && dut.state !== 3'd3) begin
					$display("ERROR: DLC %0d left CONTROL before seven bit_ticks.", test_dlc);
					errors = errors + 1;
				end
			end

			if (expected_bit_count == 0) begin
				if (dut.state !== 3'd5) begin
					$display("ERROR: DLC %0d should skip DATA and enter CRC.", test_dlc);
					errors = errors + 1;
				end
			end else if (dut.state !== 3'd4) begin
				$display("ERROR: DLC %0d should enter DATA.", test_dlc);
				errors = errors + 1;
			end

			for (bit_index = 0; bit_index < expected_bit_count; bit_index = bit_index + 1) begin
				pulse_tick();
				if (tx !== test_data[63-bit_index]) begin
					$display("ERROR: DLC %0d data bit %0d expected %b, observed %b.",
							 test_dlc, bit_index + 1,
							 test_data[63-bit_index], tx);
					errors = errors + 1;
				end
				if (bit_index == expected_bit_count - 1) begin
					if (dut.state !== 3'd5) begin
						$display("ERROR: DLC %0d did not enter CRC after its final data bit.",
								 test_dlc);
						errors = errors + 1;
					end
				end else if (dut.state !== 3'd4) begin
					$display("ERROR: DLC %0d left DATA before all bits were sent.", test_dlc);
					errors = errors + 1;
				end
			end

			$display("Checked DLC %0d: expected %0d data bits.",
					 test_dlc, expected_bit_count);
		end
	endtask

	initial begin
		$dumpfile("can_tx.vcd");
		$dumpvars(0, can_tx_tb);

		clk = 1'b0;
		reset = 1'b1;
		start = 1'b0;
		bit_tick = 1'b0;
		can_id = 11'b10100110101;
		dlc = 4'd0;
		data = 64'd0;
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
		if (tx !== 1'b0 || dut.state !== 3'd3) begin
			$display("ERROR: first CONTROL bit was not RTR=0.");
			errors = errors + 1;
		end

		check_data_case(4'd0, 64'h0123_4567_89AB_CDEF, 7'd0);
		check_data_case(4'd1, 64'hD3A5_7C91_E246_80BF, 7'd8);
		check_data_case(4'd4, 64'hA5C3_96E1_4278_BD0F, 7'd32);
		check_data_case(4'd9, 64'hFFFF_FFFF_FFFF_FFFF, 7'd0);

		if (errors == 0)
			$display("PASS: reset, SOF, 11-bit ID, 7-bit CONTROL, DLC 0/1/4/9, data MSB-first, and CRC transition verified.");
		else
			$display("FAIL: %0d error(s) detected.", errors);

		$finish;
	end

endmodule