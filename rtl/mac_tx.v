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
	output reg [1:0] txd,
	output wire tx_en //active when sending a frame

);


parameter IDLE = 0, PREAMBLE = 1, DST = 2, SRC = 3, ETHERTYPE = 4, PAYLOAD = 5,
			 CRC = 6;
			 
//re-usable state counter			 
reg [13:0] counter;
reg [2:0] state;

//instantiate crc32
wire valid;
wire [31:0] crc;
			 
			 
//state machine
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
        if (counter == 63) begin
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
        if (counter == 7) begin
          state <= PAYLOAD;
          counter <= 0;
        end else begin
          counter <= counter + 1;
        end
      end
      PAYLOAD: begin
        if (counter == (length * 4) - 1) begin
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

crc32 u_crc32(
	.clk(clk),
	.rst(rst),
	.valid(valid),
	.dibit(txd),
	.crc_register(crc)
);

assign valid = (state == DST) || (state == SRC) || (state == ETHERTYPE) || (state == PAYLOAD);


//adjust txd output based on state
always @(*) begin
  case (state)
    PREAMBLE: txd = (counter == 63) ? 2'b11 : 2'b01;

    DST: txd = dst_mac[((5 - counter/4)*8) + ((counter%4)*2) +: 2];

    SRC: txd = src_mac[((5 - counter/4)*8) + ((counter%4)*2) +: 2];

    ETHERTYPE: txd = ethertype[((1 - counter/4)*8) + ((counter%4)*2) +: 2];

    PAYLOAD: begin
      if (counter % 4 == 0)
        txd = data_in[1:0];
      else if (counter % 4 == 1)
        txd = data_in[3:2];
      else if (counter % 4 == 2)
        txd = data_in[5:4];
      else
        txd = data_in[7:6];
    end

    CRC: txd = ~crc[(counter*2) +: 2];

    default: txd = 2'b00;

  endcase
end

endmodule

`resetall