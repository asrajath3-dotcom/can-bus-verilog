`timescale 1ns/1ps

module can_tx_data_tb;

	localparam [2:0] STATE_IDLE = 3'd0;
	localparam [2:0] STATE_SOF = 3'd1;
	localparam [2:0] STATE_SEND_ID = 3'd2;
	localparam [2:0] STATE_CONTROL = 3'd3;
	localparam [2:0] STATE_DATA = 3'd4;
	localparam [2:0] STATE_CRC = 3'd5;
	localparam [31:0] EXPECTED_DATA_BITS =
		32'b00010001001000100011001101000100;

	reg clk;
	reg reset;
	reg start;
	reg bit_tick;
	reg [10:0] can_id;
	reg [3:0] dlc;
	reg [63:0] data;
	wire tx;
	integer errors;
	integer bit_index;
	integer data_bits_seen;

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

	initial begin
		$dumpfile("can_tx_data.vcd");
		$dumpvars(0, can_tx_data_tb);

		clk = 1'b0;
		reset = 1'b1;
		start = 1'b0;
		bit_tick = 1'b0;
		can_id = 11'b10100110101;
		dlc = 4'd4;
		data = 64'h1122_3344_5566_7788;
		errors = 0;
		data_bits_seen = 0;

		$display("CAN TX DATA waveform test: ID=%b DLC=%0d data=%h",
				 can_id, dlc, data);
		repeat (2) @(posedge clk);
		#1;
		if (tx !== 1'b1 || dut.state !== STATE_IDLE) begin
			$display("ERROR: reset did not return the transmitter to IDLE.");
			errors = errors + 1;
		end

		@(negedge clk);
		reset = 1'b0;
		start = 1'b1;
		@(posedge clk);
		#1;
		start = 1'b0;
		if (tx !== 1'b0 || dut.state !== STATE_SOF) begin
			$display("ERROR: start did not enter SOF and drive dominant 0.");
			errors = errors + 1;
		end

		pulse_tick();
		if (dut.state !== STATE_SEND_ID) begin
			$display("ERROR: SOF did not advance to SEND_ID on bit_tick.");
			errors = errors + 1;
		end

		for (bit_index = 0; bit_index < 11; bit_index = bit_index + 1) begin
			pulse_tick();
			if (tx !== can_id[10-bit_index]) begin
				$display("ERROR: ID bit %0d expected %b, observed %b.",
						 bit_index + 1, can_id[10-bit_index], tx);
				errors = errors + 1;
			end
			if (bit_index == 10 && dut.state !== STATE_CONTROL) begin
				$display("ERROR: transmitter did not enter CONTROL after 11 ID bits.");
				errors = errors + 1;
			end
		end

		pulse_tick();
		if (dut.state !== STATE_DATA) begin
			$display("ERROR: DLC 4 did not advance from CONTROL to DATA.");
			errors = errors + 1;
		end

		for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
			pulse_tick();
			data_bits_seen = data_bits_seen + 1;
			if (tx !== EXPECTED_DATA_BITS[31-bit_index]) begin
				$display("ERROR: DATA bit %0d expected %b, observed %b.",
						 bit_index + 1, EXPECTED_DATA_BITS[31-bit_index], tx);
				errors = errors + 1;
			end
			if (dut.data_bit_count !== bit_index + 1) begin
				$display("ERROR: internal data-bit count was %0d after bit %0d.",
						 dut.data_bit_count, bit_index + 1);
				errors = errors + 1;
			end
			if (bit_index == 31) begin
				if (dut.state !== STATE_CRC) begin
					$display("ERROR: transmitter did not enter CRC after data bit 32.");
					errors = errors + 1;
				end
			end else if (dut.state !== STATE_DATA) begin
				$display("ERROR: transmitter left DATA before bit 32.");
				errors = errors + 1;
			end
		end

		if (data_bits_seen != 32) begin
			$display("ERROR: observed %0d DATA bits; expected exactly 32.",
					 data_bits_seen);
			errors = errors + 1;
		end

		if (errors == 0)
			$display("PASS: one DLC=4 frame transmitted 32 DATA bits MSB first and reached CRC.");
		else
			$display("FAIL: %0d error(s) detected.", errors);

		$finish;
	end

endmodule