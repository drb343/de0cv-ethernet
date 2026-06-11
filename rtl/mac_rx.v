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
	output reg [511:0] data_out

);

parameter IDLE = 0, PREAMBLE = 1, WAITING = 2, PAYLOAD = 3, CRC = 4;

//re-usable state counter			 
reg [13:0] counter;
reg [2:0] state;

//crc register
wire valid;
wire [31:0] crc;

//data valid reg
reg data_valid_reg;
assign data_valid = data_valid_reg;

always @(posedge clk) begin
	if (rst) begin
		state <= IDLE;
		counter <= 0;
	
	end else begin
		case(state)
			IDLE: begin
				data_valid_reg <= 0;
				state <= (CRS_DV) ? PREAMBLE : IDLE;
			end
			PREAMBLE: begin
				if (rxd == 2'b11) begin
					state <= WAITING;
				end else begin
					state <= PREAMBLE;
				end
			
			end
			WAITING: begin //wait for the DST,SRC,ETHERTYPE bytes to pass
				if (!CRS_DV) begin
					state <= IDLE;
					counter <= 0;
				end else if (counter == 55) begin
					state <= PAYLOAD;
					counter <= 0;
				end else begin
					counter <= counter + 1;
				end
			
			end 
			PAYLOAD: begin
				if (!CRS_DV) begin
					state <= IDLE;
					counter <= 0;
				end else if (counter == (4 * length) - 1) begin
					state <= CRC;
					counter <= 0;
				end else begin
					counter <= counter + 1;
				end 
			
			end
			CRC: begin
				 if (counter == 15) begin
					  state <= IDLE;
					  counter <= 0;
					  data_valid_reg <= (crc ^ 32'hFFFFFFFF == 32'hDEBB20E3);
				 end else begin
					  counter <= counter + 1;
					  data_valid_reg <= 0;
				 end
			end
		
		endcase
	
	end

end

crc32 u_crc32(
	.clk(clk),
	.rst(rst),
	.valid(valid),
	.dibit(rxd),
	.crc_register(crc)
);

assign valid = (state == PREAMBLE) || (state == WAITING) || (state == PAYLOAD);

always @(posedge clk) begin
	if (state == PAYLOAD) begin
		data_out <= (data_out << 2) | rxd;
	end else begin
		data_out <= 512'd0;
	end
	
end


endmodule

`resetall