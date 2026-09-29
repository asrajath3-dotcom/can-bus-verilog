`timescale 1ns/1ps

module bit_timing_tb;

	reg clk;
	reg reset;
	wire bit_tick;

	integer cycle_count;
	integer last_tick_cycle;
	integer tick_count;
	integer errors;
	integer i;
	reg previous_bit_tick;

	bit_timing dut (
		.clk(clk),
		.reset(reset),
		.bit_tick(bit_tick)
	);

	always #5 clk = ~clk;

	initial begin
		$dumpfile("bit_timing.vcd");
		$dumpvars(0, bit_timing_tb);

		clk = 1'b0;
		reset = 1'b1;
		cycle_count = 0;
		last_tick_cycle = 0;
		tick_count = 0;
		errors = 0;
		previous_bit_tick = 1'b0;

		$display("Applying synchronous reset for two rising clock edges.");
		repeat (2) @(posedge clk);
		@(negedge clk);
		reset = 1'b0;
		$display("Reset released. Checking bit_tick for 100 clock cycles.");

		for (i = 0; i < 100; i = i + 1) begin
			@(posedge clk);
			#1;
			cycle_count = cycle_count + 1;

			if (bit_tick) begin
				tick_count = tick_count + 1;
				$display("bit_tick #%0d at active cycle %0d", tick_count, cycle_count);

				if (last_tick_cycle == 0) begin
					if (cycle_count != 20) begin
						$display("ERROR: first bit_tick expected at cycle 20.");
						errors = errors + 1;
					end
				end else if (cycle_count - last_tick_cycle != 20) begin
					$display("ERROR: bit_tick interval was %0d cycles; expected 20.",
							 cycle_count - last_tick_cycle);
					errors = errors + 1;
				end

				last_tick_cycle = cycle_count;
			end

			if (bit_tick && previous_bit_tick) begin
				$display("ERROR: bit_tick stayed high for more than one clock cycle.");
				errors = errors + 1;
			end
			previous_bit_tick = bit_tick;
		end

		if (tick_count != 5) begin
			$display("ERROR: observed %0d bit_tick pulse(s); expected 5.", tick_count);
			errors = errors + 1;
		end

		if (errors == 0)
			$display("PASS: bit_tick pulsed once every 20 clock cycles.");
		else
			$display("FAIL: %0d error(s) detected.", errors);

		$finish;
	end

endmodule
