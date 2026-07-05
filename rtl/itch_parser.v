`resetall
`timescale 1ns/1ps
`default_nettype none

module itch_parser(
	input wire clk,
	input wire rst,
	input wire [511:0] data_in,
	input wire data_valid,
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

reg [31:0] bbo_price_buy;

reg [31:0] bbo_price_sell;

reg data_valid_d;

//Function to unscramble the bytes transmitted by Ethernet,
//RMII sends LSB-first, as RMII captures MSB first
//Must swap each bit in the dibit, and reverse order of the 4 dibits
function [7:0] unscramble_byte;
	input [7:0] raw;
	begin
		unscramble_byte = {raw[1], raw[0], raw[3], raw[2], raw[5], raw[4], raw[7], raw[6]};
	end
endfunction

// The 18-byte ITCH payload lands at data_in[397:254], upon running further verification
wire [7:0] msg_type_raw   = data_in[397:390];
wire [7:0] side_reg_raw   = data_in[389:382];
wire [7:0] shares_b3_raw  = data_in[381:374];
wire [7:0] shares_b2_raw  = data_in[373:366];
wire [7:0] shares_b1_raw  = data_in[365:358];
wire [7:0] shares_b0_raw  = data_in[357:350];
wire [7:0] price_b3_raw   = data_in[349:342];
wire [7:0] price_b2_raw   = data_in[341:334];
wire [7:0] price_b1_raw   = data_in[333:326];
wire [7:0] price_b0_raw   = data_in[325:318];
wire [7:0] stock_b0_raw   = data_in[317:310];
wire [7:0] stock_b1_raw   = data_in[309:302];
wire [7:0] stock_b2_raw   = data_in[301:294];
wire [7:0] stock_b3_raw   = data_in[293:286];
wire [7:0] stock_b4_raw   = data_in[285:278];
wire [7:0] stock_b5_raw   = data_in[277:270];
wire [7:0] stock_b6_raw   = data_in[269:262];
wire [7:0] stock_b7_raw   = data_in[261:254];

//decode the data_in
always @(*) begin
	msg_type   = unscramble_byte(msg_type_raw);
	side_reg   = unscramble_byte(side_reg_raw);
	shares_reg = {unscramble_byte(shares_b3_raw), unscramble_byte(shares_b2_raw),
	              unscramble_byte(shares_b1_raw), unscramble_byte(shares_b0_raw)};
	price_reg  = {unscramble_byte(price_b3_raw), unscramble_byte(price_b2_raw),
	              unscramble_byte(price_b1_raw), unscramble_byte(price_b0_raw)};
	stock      = {unscramble_byte(stock_b0_raw), unscramble_byte(stock_b1_raw),
	              unscramble_byte(stock_b2_raw), unscramble_byte(stock_b3_raw),
	              unscramble_byte(stock_b4_raw), unscramble_byte(stock_b5_raw),
	              unscramble_byte(stock_b6_raw), unscramble_byte(stock_b7_raw)};
end

//Best Bid Offer tracker
always @(posedge clk) begin
	if (rst) begin
		bbo_price_buy <= 32'd0;
		bbo_price_sell <= 32'hFFFFFFFF;
	end else begin
		//Message type Buy - ASCII
		if (side_reg == 8'h42 && bbo_price_buy < price_reg) begin
			bbo_price_buy <= price_reg;
		//Message type Sell - ASCII
		end else if (side_reg == 8'h53 && bbo_price_sell > price_reg) begin
			bbo_price_sell <= price_reg;
		end
	end
end

always @(posedge clk) begin
	data_valid_d <= data_valid;
end

//Decision point
always @(posedge clk) begin
	if (rst) begin
		signal <= HOLD;
	end else if (data_valid_d) begin
		if (bbo_price_buy < TARGET_BUY) begin
			signal <= BUY;
		end else if (bbo_price_sell > TARGET_SELL) begin
			signal <= SELL;
		end else begin
			signal <= HOLD;
		end
	
	end
end


endmodule
`resetall