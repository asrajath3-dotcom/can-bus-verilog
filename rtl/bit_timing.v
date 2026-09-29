// Generate one bit_tick every 20 system clock cycles.
// Synchronous active-high reset.
// bit_tick should pulse HIGH for exactly one system clock cycle.

module bit_timing (
    input wire clk,
    input wire reset,
    output reg bit_tick
);
    reg [4:0] counter; // internal 5 bit counter

    always @(posedge clk) begin
        if (reset) begin
            counter <= 5'd0;
            bit_tick <= 1'b0;
        end else if (counter == 5'd19) begin
            counter <= 5'd0;
            bit_tick <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
            bit_tick <= 1'b0;
        end
    end
endmodule