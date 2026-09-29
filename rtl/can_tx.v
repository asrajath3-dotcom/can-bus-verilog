module can_tx (
	input wire clk,
	input wire reset,
	input wire start,
	input wire bit_tick,
	input wire [10:0] can_id,
	input wire [3:0] dlc,
	input wire [63:0] data,
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
	reg [3:0] dlc_reg;
	reg [63:0] data_shift;
	reg [6:0] data_bit_count;

	always @(posedge clk) begin
		if (reset) begin
			state <= IDLE;
			id_shift <= 11'd0;
			id_bit_count <= 4'd0;
			dlc_reg <= 4'd0;
			data_shift <= 64'd0;
			data_bit_count <= 7'd0;
			tx <= 1'b1;
		end else begin
			case (state)
				IDLE: begin
					tx <= 1'b1;
					if (start) begin
						id_shift <= can_id;
						id_bit_count <= 4'd0;
						dlc_reg <= dlc;
						data_shift <= data;
						data_bit_count <= 7'd0;
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
					if (bit_tick) begin
						// DLC values above 8 safely skip payload transmission.
						if (dlc_reg == 4'd0 || dlc_reg > 4'd8)
							state <= CRC;
						else
							state <= DATA;
					end
				end

				DATA: begin
					if (bit_tick) begin
						tx <= data_shift[63];
						data_shift <= {data_shift[62:0], 1'b0};
						data_bit_count <= data_bit_count + 1'b1;
						if (data_bit_count == ({dlc_reg, 3'b000} - 7'd1))
							state <= CRC;
					end
				end

				CRC: begin
					state <= CRC;
				end

				default: begin
					state <= IDLE;
					id_shift <= 11'd0;
					id_bit_count <= 4'd0;
					dlc_reg <= 4'd0;
					data_shift <= 64'd0;
					data_bit_count <= 7'd0;
					tx <= 1'b1;
				end
			endcase
		end
	end

endmodule