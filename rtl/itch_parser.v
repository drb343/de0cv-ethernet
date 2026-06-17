`resetall
`timescale 1ns/1ps
`default_nettype none

module itch_parser(
	input clk,
	input rst,
	input [511:0] data_in,
	input data_valid,
	output reg [1:0] signal
);

parameter TARGET_BUY  = 32'd1_750_000;  // $175.00
parameter TARGET_SELL = 32'd2_000_000;  // $200.00

parameter HOLD = 0, BUY = 1, SELL = 2;


reg [7:0] msg_type;

reg [7:0] side_reg;

reg [31:0] shares_reg;

reg [31:0] price_reg;

reg [63:0] stock;

reg [511:0] data_in_latch;

reg [31:0] bbo_price_buy;

reg [31:0] bbo_price_sell;


always @(posedge clk) begin
	if (rst) begin
		data_in_latch <= 512'd0;
		bbo_price_buy <= 32'd0;
		bbo_price_sell <= 32'd0;
	end else if (data_valid) begin
		data_in_latch <= data_in;
		
	end 

end

//decode the data_in
always @(*) begin
	msg_type = data_in_latch[511:504];
	side_reg = data_in_latch[503:496];
	shares_reg = data_in_latch[495:464];
	price_reg = data_in_latch[463:432];
	stock = data_in_latch[431:368];
end

//Best Bid Offer tracker
always @(posedge clk) begin
	//Message type Buy - ASCII
	if (msg_type == 8'h42 && bbo_price_buy < price_reg) begin
		bbo_price_buy <= price_reg;
	//Message type Sell - ASCII
	end else if (msg_type == 8'h53 && bbo_price_sell > price_reg) begin
		bbo_price_sell <= price_reg;
	end 

end 

//Decision point
always @(posedge clk) begin
	if (bbo_price_buy < TARGET_BUY) begin
		signal <= BUY;
	end else if (bbo_price_sell > TARGET_SELL) begin
		signal <= SELL;
	end else begin
		signal <= HOLD;
	end
end


endmodule
`resetall