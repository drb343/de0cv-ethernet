`resetall
`timescale 1ns/1ps
`default_nettype none
module mac_rx (
	input clk,
	input rst,
	input CRS_DV,
	input [11:0] length,
	input [1:0] rxd,
	output data_valid,
	output reg [511:0] data_out,
	output [2:0] state_out
);

parameter IDLE = 0, PREAMBLE = 1, PAYLOAD = 2;

//re-usable state counter			 
//reg [13:0] counter;
reg [2:0] state = IDLE;

//crc register
wire valid;
wire [31:0] crc;
wire clear;

//data valid reg
reg data_valid_reg;
assign data_valid = data_valid_reg;


always @(posedge clk) begin
	if (rst) begin
		state <= IDLE;
		//counter <= 0;
		data_valid_reg <= 0;
	end else begin
		case(state)
			IDLE: begin
				state <= (CRS_DV) ? PREAMBLE : IDLE;
				data_valid_reg <= 0;
			end
			PREAMBLE: begin
				 if (rxd == 2'b11) begin
					  state <= PAYLOAD;
				 end
			end
			PAYLOAD: begin
				if (!CRS_DV) begin 
				  state <= IDLE;
				  data_valid_reg <= (crc ^ 32'hFFFFFFFF == 32'hDEBB20E3); //Calculate CRC for 
				end
			end
			default: begin
				state <= IDLE;
			end
		endcase
	
	end
end

assign clear = (state == IDLE) || (state == PREAMBLE); 

crc32 u_crc32(
	.clk(clk),
	.rst(rst),
	.valid(valid),
	.dibit(rxd),
	.clear(clear),
	.crc_register(crc)
);
assign valid = (state == PAYLOAD);


always @(posedge clk) begin
    if (state == PAYLOAD && CRS_DV)
        data_out <= (data_out << 2) | rxd;
    else if (state == PREAMBLE)
        data_out <= 512'd0;
end

//Debug state purposes
assign state_out = state;

endmodule
`resetall