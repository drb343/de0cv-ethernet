`resetall
`timescale 1ns / 1ps
`default_nettype none


module mac_tx (

	input wire clk,
	input wire rst,
	
	input wire [47:0] dst_mac,
	input wire [47:0] src_mac,
	input wire [15:0] ethertype,
	input wire [7:0] data_in,
	input wire [11:0] length,
	input wire start,
	output wire ready, //ready to receive information - RMII
	output wire [1:0] txd,
	output wire tx_en //active when sending a frame

);


parameter IDLE = 0, PREAMBLE = 1, DST = 2, SRC = 3, ETHERTYPE = 4, PAYLOAD = 5,
			 CRC = 6;
			 
//re-usable state counter			 
reg [13:0] counter;
reg [2:0] state;
			 
always @(posedge clk) begin
  if (rst) begin
    state <= IDLE;
    counter <= 0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= PREAMBLE;
          counter <= 0;
        end
      end
      PREAMBLE: begin
        if (counter == 31) begin
          state <= DST;
          counter <= 0;
        end else begin
          counter <= counter + 1;
        end
      end
      DST: begin
        if (counter == 23) begin
          state <= SRC;
          counter <= 0;
        end else begin
          counter <= counter + 1;
        end
      end
      SRC: begin
        if (counter == 23) begin
          state <= ETHERTYPE;
          counter <= 0;
        end else begin
          counter <= counter + 1;
        end
      end
      ETHERTYPE: begin
        if (counter == 3) begin
          state <= PAYLOAD;
          counter <= 0;
        end else begin
          counter <= counter + 1;
        end
      end
      PAYLOAD: begin
        if (counter == (PAYLOAD_LEN * 4) - 1) begin
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
        end else begin
          counter <= counter + 1;
        end
      end
    endcase
  end
end	

assign ready = (state == IDLE);	
assign tx_en = (state != IDLE);

always @(*) begin
	case (state)
	
	
	end 
end 
