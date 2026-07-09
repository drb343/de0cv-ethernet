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

// The 18-byte ITCH payload lands at data_in[399:256], upon running further verification
wire [7:0] msg_type_raw   = data_in[399:392];
wire [7:0] side_reg_raw   = data_in[391:384];
wire [7:0] shares_b3_raw  = data_in[383:376];
wire [7:0] shares_b2_raw  = data_in[375:368];
wire [7:0] shares_b1_raw  = data_in[367:360];
wire [7:0] shares_b0_raw  = data_in[359:352];
wire [7:0] price_b3_raw   = data_in[351:344];
wire [7:0] price_b2_raw   = data_in[343:336];
wire [7:0] price_b1_raw   = data_in[335:328];
wire [7:0] price_b0_raw   = data_in[327:320];
wire [7:0] stock_b0_raw   = data_in[319:312];
wire [7:0] stock_b1_raw   = data_in[311:304];
wire [7:0] stock_b2_raw   = data_in[303:296];
wire [7:0] stock_b3_raw   = data_in[295:288];
wire [7:0] stock_b4_raw   = data_in[287:280];
wire [7:0] stock_b5_raw   = data_in[279:272];
wire [7:0] stock_b6_raw   = data_in[271:264];
wire [7:0] stock_b7_raw   = data_in[263:256];

always @(posedge clk) begin
	data_valid_d <= data_valid;
end

//decode the data_in
always @(posedge clk) begin
	if (data_valid_d) begin
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
end

//Best Bid Offer tracker
always @(posedge clk) begin
	if (rst) begin
		bbo_price_buy <= 32'd0;
		bbo_price_sell <= 32'hFFFFFFFF;
	end else if (data_valid_d) begin
		//Message type Buy - ASCII
		if (side_reg == 8'h42 && bbo_price_buy < price_reg) begin
			bbo_price_buy <= price_reg;
		//Message type Sell - ASCII
		end else if (side_reg == 8'h53 && bbo_price_sell > price_reg) begin
			bbo_price_sell <= price_reg;
		end
	end
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