module can_tx (
	input wire clk,
	input wire reset,
	input wire start,
	input wire bit_tick,
	input wire [10:0] can_id,
	input wire [3:0] dlc,
	input wire [63:0] data,
	output wire tx
);

	localparam [2:0] IDLE = 3'd0;
	localparam [2:0] SOF = 3'd1;
	localparam [2:0] SEND_ID = 3'd2;
	localparam [2:0] CONTROL = 3'd3;
	localparam [2:0] DATA = 3'd4;
	localparam [2:0] CRC = 3'd5;
	localparam [2:0] CRC_DELIMITER = 3'd6;
	localparam [2:0] EOF = 3'd7;

	reg [2:0] state;
	reg [10:0] id_shift;
	reg [3:0] id_bit_count;
	reg [3:0] dlc_reg;
	reg [6:0] control_shift;
	reg [2:0] control_bit_count;
	reg [63:0] data_shift;
	reg [6:0] data_bit_count;
	reg [14:0] crc_shift;
	reg [3:0] crc_bit_count;
	wire crc_reset;
	wire crc_enable;
	wire crc_data_bit;
	wire [14:0] crc_value;
	wire stuffer_reset;
	wire stuffer_bit_tick;
	wire stuffer_real_bit;
	wire stuffer_wire_bit;
	wire stuff_bit;
	wire real_bit_consumed;
	wire [2:0] stuffer_run_count;
	reg crc_delimiter_sent;

	assign stuffer_reset = reset || ((state == IDLE) && start);
	assign stuffer_bit_tick = bit_tick &&
		((state == SOF) || (state == SEND_ID) || (state == CONTROL) ||
		 (state == DATA) || (state == CRC));
	assign stuffer_real_bit = (state == SOF) ? 1'b0 :
		(state == SEND_ID) ? id_shift[10] :
		(state == CONTROL) ? control_shift[6] :
		(state == DATA) ? data_shift[63] :
		(state == CRC) ? ((crc_bit_count == 4'd0) ? crc_value[14] : crc_shift[14]) : 1'b1;
	assign tx = ((state == IDLE) ||
		((state == CRC_DELIMITER) && crc_delimiter_sent)) ? 1'b1 : stuffer_wire_bit;

	assign crc_reset = stuffer_reset;
	assign crc_enable = real_bit_consumed &&
		((state == SOF) || (state == SEND_ID) || (state == CONTROL) || (state == DATA));
	assign crc_data_bit = (state == SOF) ? 1'b0 :
		(state == SEND_ID) ? id_shift[10] :
		(state == CONTROL) ? control_shift[6] :
		(state == DATA) ? data_shift[63] : 1'b0;

	can_bit_stuffer bit_stuffer (
		.clk(clk),
		.reset(stuffer_reset),
		.bit_tick(stuffer_bit_tick),
		.real_bit(stuffer_real_bit),
		.wire_bit(stuffer_wire_bit),
		.stuff_bit(stuff_bit),
		.real_bit_consumed(real_bit_consumed),
		.run_count(stuffer_run_count)
	);

	crc15 crc_generator (
		.clk(clk),
		.reset(crc_reset),
		.enable(crc_enable),
		.data_bit(crc_data_bit),
		.crc(crc_value)
	);

	always @(posedge clk) begin
		if (reset) begin
			state <= IDLE;
			id_shift <= 11'd0;
			id_bit_count <= 4'd0;
			dlc_reg <= 4'd0;
			control_shift <= 7'd0;
			control_bit_count <= 3'd0;
			data_shift <= 64'd0;
			data_bit_count <= 7'd0;
			crc_shift <= 15'd0;
			crc_bit_count <= 4'd0;
			crc_delimiter_sent <= 1'b0;
		end else begin
			case (state)
				IDLE: begin
					if (start) begin
						id_shift <= can_id;
						id_bit_count <= 4'd0;
						dlc_reg <= dlc;
						control_shift <= 7'd0;
						control_bit_count <= 3'd0;
						data_shift <= data;
						data_bit_count <= 7'd0;
						crc_shift <= 15'd0;
						crc_bit_count <= 4'd0;
						crc_delimiter_sent <= 1'b0;
						state <= SOF;
					end
				end

				SOF: begin
					if (real_bit_consumed)
						state <= SEND_ID;
				end

				SEND_ID: begin
					if (real_bit_consumed) begin
						id_shift <= {id_shift[9:0], 1'b0};
						if (id_bit_count == 4'd10) begin
							id_bit_count <= 4'd11;
							control_shift <= {3'b000, dlc_reg};
							control_bit_count <= 3'd0;
							state <= CONTROL;
						end else begin
							id_bit_count <= id_bit_count + 1'b1;
						end
					end
				end

				CONTROL: begin
					if (real_bit_consumed) begin
						control_shift <= {control_shift[5:0], 1'b0};
						if (control_bit_count == 3'd6) begin
							// DLC values above 8 safely skip payload transmission.
							if (dlc_reg == 4'd0 || dlc_reg > 4'd8)
								state <= CRC;
							else
								state <= DATA;
						end else begin
							control_bit_count <= control_bit_count + 1'b1;
						end
					end
				end

				DATA: begin
					if (real_bit_consumed) begin
						data_shift <= {data_shift[62:0], 1'b0};
						data_bit_count <= data_bit_count + 1'b1;
						if (data_bit_count == ({dlc_reg, 3'b000} - 7'd1))
							state <= CRC;
					end
				end

				CRC: begin
					if (real_bit_consumed) begin
						if (crc_bit_count == 4'd0) begin
							crc_shift <= {crc_value[13:0], 1'b0};
							crc_bit_count <= 4'd1;
						end else begin
							crc_shift <= {crc_shift[13:0], 1'b0};
							if (crc_bit_count == 4'd14) begin
								crc_delimiter_sent <= 1'b0;
								if (stuffer_run_count == 3'd5) begin
									state <= CRC;
								end else begin
									state <= CRC_DELIMITER;
								end
							end else begin
								crc_bit_count <= crc_bit_count + 1'b1;
							end
						end
					end else if ((crc_bit_count == 4'd14) && stuff_bit) begin
						state <= CRC_DELIMITER;
						crc_delimiter_sent <= 1'b0;
					end
				end

				CRC_DELIMITER: begin
					if (bit_tick)
						crc_delimiter_sent <= 1'b1;
				end

				default: begin
					state <= IDLE;
					id_shift <= 11'd0;
					id_bit_count <= 4'd0;
					dlc_reg <= 4'd0;
					control_shift <= 7'd0;
					control_bit_count <= 3'd0;
					data_shift <= 64'd0;
					data_bit_count <= 7'd0;
					crc_shift <= 15'd0;
					crc_bit_count <= 4'd0;
					crc_delimiter_sent <= 1'b0;
				end
			endcase
		end
	end

endmodule