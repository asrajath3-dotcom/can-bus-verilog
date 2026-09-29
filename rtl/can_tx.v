module can_tx (
	input wire clk,
	input wire reset,
	input wire start,
	input wire bit_tick,
	input wire [10:0] can_id,
	output reg tx
);

	localparam [2:0] IDLE = 3'd0;
	localparam [2:0] SOF = 3'd1;
	localparam [2:0] SEND_ID = 3'd2;
	localparam [2:0] CONTROL = 3'd3;
	localparam [2:0] DATA = 3'd4;
	localparam [2:0] CRC = 3'd5;
	localparam [2:0] ACK = 3'd6;
	localparam [2:0] EOF = 3'd7;

	reg [2:0] state;
	reg [10:0] id_shift;
	reg [3:0] id_bit_count;

	always @(posedge clk) begin
		if (reset) begin
			state <= IDLE;
			id_shift <= 11'd0;
			id_bit_count <= 4'd0;
			tx <= 1'b1;
		end else begin
			case (state)
				IDLE: begin
					tx <= 1'b1;
					if (start) begin
						id_shift <= can_id;
						id_bit_count <= 4'd0;
						tx <= 1'b0;
						state <= SOF;
					end
				end

				SOF: begin
					tx <= 1'b0;
					if (bit_tick)
						state <= SEND_ID;
				end

				SEND_ID: begin
					if (bit_tick) begin
						tx <= id_shift[10];
						id_shift <= {id_shift[9:0], 1'b0};
						if (id_bit_count == 4'd10) begin
							id_bit_count <= 4'd11;
							state <= CONTROL;
						end else begin
							id_bit_count <= id_bit_count + 1'b1;
						end
					end
				end

				CONTROL: begin
					state <= CONTROL;
				end

				default: begin
					state <= IDLE;
					id_shift <= 11'd0;
					id_bit_count <= 4'd0;
					tx <= 1'b1;
				end
			endcase
		end
	end

endmodule