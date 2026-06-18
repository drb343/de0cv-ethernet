`timescale 1ns/1ps

module tb_itch_parser;
	reg clk;
	reg rst;
	reg [511:0] data_in;
	reg data_valid;
	wire [1:0] signal;
	
	
	itch_parser uut(
		.clk(clk),
		.rst(rst),
		.data_in(data_in),
		.data_valid(data_valid),
		.signal(signal)
	);
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0;
		rst = 1;
		data_in = 512'd0;
		data_valid = 1;
		
		#1000;
		
		rst = 0;
		
		//Buy Test - expect BUY
		data_in = 512'd0;
		data_in[511:504] = 8'h41;
		data_in[503:496] = 8'h42;
		data_in[495:464] = 32'd100;
		data_in[463:432] = 32'd1_700_000;
		data_valid = 1;
		#20;
		data_valid = 0;
		#20;
		
		//Sell Test - expect SELL
		data_in = 512'd0;
		data_in[511:504] = 8'h41;
		data_in[503:496] = 8'h53;
		data_in[495:464] = 32'd100;
		data_in[463:432] = 32'd2_100_000;
		data_valid = 1;
		#20;
		data_valid = 0;
		#20;
		
		//HOLD Test - no action
		data_in = 512'd0;
		data_in[511:504] = 8'h41;
		data_in[503:496] = 8'h42;
		data_in[495:464] = 32'd100;
		data_in[463:432] = 32'd1_900_000;
		data_valid = 1;
		#20;
		data_valid = 0;
		#20;
	
	
	end
	
endmodule