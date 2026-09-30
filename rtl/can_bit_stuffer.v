module can_bit_stuffer (
    input wire clk,
    input wire reset,
    input wire bit_tick,
    input wire real_bit,
    output reg wire_bit,
    output reg stuff_bit,
    output reg real_bit_consumed,
    output reg [2:0] run_count
);

    reg last_wire_bit;
    reg stuff_pending;

    always @(posedge clk) begin
        if (reset) begin
            wire_bit <= 1'b0;
            stuff_bit <= 1'b0;
            real_bit_consumed <= 1'b0;
            run_count <= 3'd0;
            last_wire_bit <= 1'b0;
            stuff_pending <= 1'b0;
        end else begin
            stuff_bit <= 1'b0;
            real_bit_consumed <= 1'b0;

            if (bit_tick) begin
                if (stuff_pending) begin
                    wire_bit <= ~last_wire_bit;
                    last_wire_bit <= ~last_wire_bit;
                    stuff_bit <= 1'b1;
                    run_count <= 3'd1;
                    stuff_pending <= 1'b0;
                end else begin
                    wire_bit <= real_bit;
                    last_wire_bit <= real_bit;
                    real_bit_consumed <= 1'b1;

                    if (run_count == 3'd0 || real_bit != last_wire_bit) begin
                        run_count <= 3'd1;
                    end else if (run_count >= 3'd4) begin
                        run_count <= 3'd5;
                        stuff_pending <= 1'b1;
                    end else begin
                        run_count <= run_count + 1'b1;
                    end
                end
            end
        end
    end

endmodule
