`timescale 1ns/1ps

module can_tx_stuffer_tb;

	reg clk;
	reg reset;
	reg start;
	reg bit_tick;
	reg [10:0] can_id;
	reg [3:0] dlc;
	reg [63:0] data;
	wire tx;

	integer errors;
	integer logical_index;
	integer wire_index;
	integer expected_wire_count;
	integer next_real_index;
	integer run_length;
	integer pending_origin;
	integer data_stuff_count;
	integer crc_stuff_count;
	integer observed_data_stuff_count;
	integer observed_crc_stuff_count;
	integer observed_id_bit_count;
	integer observed_crc_bit_count;
	integer control_index;
	integer data_index;
	integer crc_index;
	reg [6:0] control_bits;
	reg [14:0] reference_crc;
	reg [0:41] logical_bits;
	reg [0:63] expected_wire;
	reg expected_stuff [0:63];
	integer expected_logical_index [0:63];
	integer stuff_origin_index [0:63];
	reg last_wire_bit;
	reg last_real_bit;
	reg stuff_pending;
	reg pending_stuff_wait;
	reg five_data_bit_run_found;
	reg trailing_crc_stuff_expected;
	reg trailing_crc_stuff_observed;
	reg same_logical_bit_resumed;

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

	function [14:0] crc_step;
		input [14:0] current_crc;
		input frame_bit;
		reg feedback;
		begin
			feedback = frame_bit ^ current_crc[14];
			crc_step = {current_crc[13:0], 1'b0} ^
				(feedback ? 15'h4599 : 15'b0);
		end
	endfunction

	// One bit_tick emits one wire bit. The low tick interval lets TX observe
	// the stuffer's registered real_bit_consumed pulse before the next tick.
	task send_expected_wire_bit;
		input integer checked_wire_index;
		integer checked_logical_index;
		begin
			@(negedge clk);
			bit_tick = 1'b1;
			@(posedge clk);
			#1;

			checked_logical_index = expected_logical_index[checked_wire_index];
			if (tx !== expected_wire[checked_wire_index]) begin
				$display("FAIL: wire bit %0d expected %b, observed %b.",
					checked_wire_index + 1, expected_wire[checked_wire_index], tx);
				errors = errors + 1;
			end

			if (expected_stuff[checked_wire_index]) begin
				if (tx !== ~last_wire_bit) begin
					$display("FAIL: stuff bit %0d was not opposite the previous wire bit.",
						checked_wire_index + 1);
					errors = errors + 1;
				end
				if (checked_logical_index != next_real_index) begin
					$display("FAIL: logical bit index advanced during stuff bit %0d.",
						checked_wire_index + 1);
					errors = errors + 1;
				end
				if (stuff_origin_index[checked_wire_index] >= 19 &&
					stuff_origin_index[checked_wire_index] <= 26)
					observed_data_stuff_count = observed_data_stuff_count + 1;
				if (stuff_origin_index[checked_wire_index] >= 27)
					observed_crc_stuff_count = observed_crc_stuff_count + 1;
				if (stuff_origin_index[checked_wire_index] == 41)
					trailing_crc_stuff_observed = 1'b1;
				pending_stuff_wait = 1'b1;
			end else begin
				if (checked_logical_index != next_real_index) begin
					$display("FAIL: expected logical bit %0d, received index %0d.",
						next_real_index, checked_logical_index);
					errors = errors + 1;
				end
				if (checked_logical_index < 0 || checked_logical_index > 41) begin
					$display("FAIL: invalid logical bit index %0d.", checked_logical_index);
					errors = errors + 1;
				end else if (tx !== logical_bits[checked_logical_index]) begin
					$display("FAIL: logical bit %0d expected %b, observed %b.",
						checked_logical_index, logical_bits[checked_logical_index], tx);
					errors = errors + 1;
				end
				if (checked_logical_index >= 1 && checked_logical_index <= 11)
					observed_id_bit_count = observed_id_bit_count + 1;
				if (checked_logical_index >= 27 && checked_logical_index <= 41) begin
					if (tx !== reference_crc[14 - (checked_logical_index - 27)]) begin
						$display("FAIL: transmitted CRC bit %0d differs from the unstuffed CRC reference.",
							checked_logical_index - 27);
						errors = errors + 1;
					end
					observed_crc_bit_count = observed_crc_bit_count + 1;
				end
				if (pending_stuff_wait) begin
					same_logical_bit_resumed = 1'b1;
					pending_stuff_wait = 1'b0;
				end
				next_real_index = next_real_index + 1;
			end
			last_wire_bit = tx;

			@(negedge clk);
			bit_tick = 1'b0;
			@(posedge clk);
			#1;
		end
	endtask

	initial begin
		$dumpfile("can_tx_stuffer.vcd");
		$dumpvars(1, can_tx_stuffer_tb);
		$dumpvars(0, can_tx_stuffer_tb.dut.state,
			can_tx_stuffer_tb.dut.bit_tick,
			can_tx_stuffer_tb.dut.tx,
			can_tx_stuffer_tb.dut.id_shift,
			can_tx_stuffer_tb.dut.id_bit_count,
			can_tx_stuffer_tb.dut.control_shift,
			can_tx_stuffer_tb.dut.control_bit_count,
			can_tx_stuffer_tb.dut.data_shift,
			can_tx_stuffer_tb.dut.data_bit_count,
			can_tx_stuffer_tb.dut.crc_value,
			can_tx_stuffer_tb.dut.crc_shift,
			can_tx_stuffer_tb.dut.crc_bit_count,
			can_tx_stuffer_tb.dut.stuffer_real_bit,
			can_tx_stuffer_tb.dut.stuffer_wire_bit,
			can_tx_stuffer_tb.dut.stuff_bit,
			can_tx_stuffer_tb.dut.real_bit_consumed,
			can_tx_stuffer_tb.dut.stuffer_run_count);
		$dumpvars(0, can_tx_stuffer_tb.dut.bit_stuffer.last_wire_bit,
			can_tx_stuffer_tb.dut.bit_stuffer.stuff_pending,
			can_tx_stuffer_tb.dut.bit_stuffer.run_count,
			can_tx_stuffer_tb.dut.bit_stuffer.wire_bit,
			can_tx_stuffer_tb.dut.bit_stuffer.real_bit_consumed,
			can_tx_stuffer_tb.dut.bit_stuffer.stuff_bit);

		clk = 1'b0;
		reset = 1'b1;
		start = 1'b0;
		bit_tick = 1'b0;
		can_id = 11'h000;
		dlc = 4'd1;
		data = 64'hC000_0000_0000_0000;
		errors = 0;
		observed_data_stuff_count = 0;
		observed_crc_stuff_count = 0;
		observed_id_bit_count = 0;
		observed_crc_bit_count = 0;
		next_real_index = 0;
		last_wire_bit = 1'b0;
		pending_stuff_wait = 1'b0;
		trailing_crc_stuff_observed = 1'b0;
		same_logical_bit_resumed = 1'b0;

		// Build the expected unstuffed protected frame: SOF, ID, control, data.
		logical_bits[0] = 1'b0;
		for (logical_index = 0; logical_index < 11; logical_index = logical_index + 1)
			logical_bits[1 + logical_index] = can_id[10 - logical_index];
		control_bits = {3'b000, dlc};
		for (control_index = 0; control_index < 7; control_index = control_index + 1)
			logical_bits[12 + control_index] = control_bits[6 - control_index];
		for (data_index = 0; data_index < 8; data_index = data_index + 1)
			logical_bits[19 + data_index] = data[63 - data_index];

		// Calculate the expected CRC from real protected bits only.
		reference_crc = 15'd0;
		for (logical_index = 0; logical_index < 27; logical_index = logical_index + 1)
			reference_crc = crc_step(reference_crc, logical_bits[logical_index]);
		for (crc_index = 0; crc_index < 15; crc_index = crc_index + 1)
			logical_bits[27 + crc_index] = reference_crc[14 - crc_index];

		// Build an expected wire sequence and mark stuff bits separately.
		expected_wire_count = 0;
		run_length = 0;
		last_real_bit = 1'b0;
		stuff_pending = 1'b0;
		pending_origin = -1;
		data_stuff_count = 0;
		crc_stuff_count = 0;
		trailing_crc_stuff_expected = 1'b0;
		five_data_bit_run_found = 1'b0;
		for (logical_index = 0; logical_index < 42; logical_index = logical_index + 1) begin
			if (stuff_pending) begin
				expected_wire[expected_wire_count] = ~last_real_bit;
				expected_stuff[expected_wire_count] = 1'b1;
				expected_logical_index[expected_wire_count] = logical_index;
				stuff_origin_index[expected_wire_count] = pending_origin;
				expected_wire_count = expected_wire_count + 1;
				if (pending_origin >= 19 && pending_origin <= 26) begin
					data_stuff_count = data_stuff_count + 1;
					five_data_bit_run_found = 1'b1;
				end
				if (pending_origin >= 27)
					crc_stuff_count = crc_stuff_count + 1;
				last_real_bit = ~last_real_bit;
				run_length = 1;
				stuff_pending = 1'b0;
			end

			expected_wire[expected_wire_count] = logical_bits[logical_index];
			expected_stuff[expected_wire_count] = 1'b0;
			expected_logical_index[expected_wire_count] = logical_index;
			stuff_origin_index[expected_wire_count] = -1;
			expected_wire_count = expected_wire_count + 1;
			if (run_length == 0 || logical_bits[logical_index] != last_real_bit) begin
				run_length = 1;
				last_real_bit = logical_bits[logical_index];
			end else if (run_length >= 4) begin
				run_length = 5;
				stuff_pending = 1'b1;
				pending_origin = logical_index;
			end else begin
				run_length = run_length + 1;
				last_real_bit = logical_bits[logical_index];
			end
		end

		// A final CRC bit can create a stuff bit that precedes the delimiter.
		if (stuff_pending) begin
			expected_wire[expected_wire_count] = ~last_real_bit;
			expected_stuff[expected_wire_count] = 1'b1;
			expected_logical_index[expected_wire_count] = 42;
			stuff_origin_index[expected_wire_count] = pending_origin;
			expected_wire_count = expected_wire_count + 1;
			if (pending_origin >= 27)
				crc_stuff_count = crc_stuff_count + 1;
			if (pending_origin == 41)
				trailing_crc_stuff_expected = 1'b1;
		end

		// Reset and start the transmitter. Each later tick is separated by a clock.
		repeat (2) @(posedge clk);
		@(negedge clk);
		reset = 1'b0;
		start = 1'b1;
		@(posedge clk);
		#1;
		start = 1'b0;

		if (logical_bits[0] !== 1'b0) begin
			$display("FAIL: SOF reference bit was not dominant 0.");
			errors = errors + 1;
		end
		send_expected_wire_bit(0);
		if (tx === 1'b0)
			$display("PASS: SOF is transmitted as dominant 0.");
		else begin
			$display("FAIL: SOF was not transmitted as dominant 0.");
			errors = errors + 1;
		end

		for (wire_index = 1; wire_index < expected_wire_count; wire_index = wire_index + 1)
			send_expected_wire_bit(wire_index);

		if (observed_id_bit_count == 11)
			$display("PASS: all 11 ID bits match through the integrated stuffer.");
		else begin
			$display("FAIL: observed %0d of 11 ID bits.", observed_id_bit_count);
			errors = errors + 1;
		end

		if (five_data_bit_run_found && data_stuff_count > 0 &&
			observed_data_stuff_count == data_stuff_count)
			$display("PASS: the deliberate five-identical-bit DATA run inserted a stuff bit.");
		else begin
			$display("FAIL: the DATA five-identical-bit run was not stuffed as expected.");
			errors = errors + 1;
		end

		if (same_logical_bit_resumed && observed_data_stuff_count > 0)
			$display("PASS: stuff bits are opposite the prior wire bit and do not skip the held logical bit.");
		else begin
			$display("FAIL: logical-bit hold/resume after stuffing was not verified.");
			errors = errors + 1;
		end

		if (observed_crc_bit_count == 15 && observed_crc_stuff_count == crc_stuff_count &&
			observed_crc_stuff_count > 0)
			$display("PASS: CRC matches the unstuffed reference and CRC bits are stuffed when required.");
		else begin
			$display("FAIL: CRC/reference or CRC-region stuffing check failed.");
			errors = errors + 1;
		end

		if (trailing_crc_stuff_expected && trailing_crc_stuff_observed &&
			expected_stuff[expected_wire_count - 1]) begin
			$display("PASS: the final CRC bit's required stuff bit appears before the delimiter.");
		end else begin
			$display("FAIL: the final CRC stuff-bit boundary case was not observed.");
			errors = errors + 1;
		end

		// The next tick is the unstuffed CRC delimiter, which must be recessive.
		@(negedge clk);
		bit_tick = 1'b1;
		@(posedge clk);
		#1;
		if (tx === 1'b1)
			$display("PASS: CRC delimiter is recessive 1 and is not stuffed.");
		else begin
			$display("FAIL: CRC delimiter was not recessive 1.");
			errors = errors + 1;
		end
		@(negedge clk);
		bit_tick = 1'b0;

		if (errors == 0)
			$display("PASS: all CAN TX stuffer integration checks passed.");
		else
			$display("FAIL: %0d error(s) detected.", errors);
		$finish;
	end

endmodule