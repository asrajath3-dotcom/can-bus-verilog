module crc15 (
	input wire clk,
	input wire reset,
	input wire enable,
	input wire data_bit,
	output reg [14:0] crc
);

	wire feedback;
	// Combine the incoming bit with the CRC bit shifted out from position 14.
	assign feedback = data_bit ^ crc[14];

	always @(posedge clk) begin
		if (reset)
			crc <= 15'b0;
		else if (enable)
			// Shift left once, inserting zero before applying the feedback taps.
			// 15'h4599 selects x^14, x^10, x^8, x^7, x^4, x^3, and x^0.
			crc <= {crc[13:0], 1'b0} ^ (feedback ? 15'h4599 : 15'b0);
	end

endmodule
