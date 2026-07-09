`resetall
`timescale 1ns/1ps
`default_nettype none

//=============================================================================
// fpga.v — Top-level: DE0-CV ITCH 5.0 market data parser
//
// RMII RX -> mac_rx (deframe, CRC-32) -> itch_parser (decode, BBO, BUY/SELL/HOLD)
// MDIO -> LAN8720A link status -> LEDR[0]
//
// Raw Ethernet, no IP/UDP. Custom ethertype 0xABF9, 18-byte ITCH payload.
//
// NOTE: RMII sends each byte as 4 dibits, LSB-first, so the RX shift register
// holds bit-permuted bytes. itch_parser's unscramble_byte() inverts this —
// raw data_out is not directly readable.
//=============================================================================

module fpga (
    input  wire        CLOCK_50,

    // RMII pins
    output wire        RMII_REF_CLK,
    output wire        RMII_TXD0,
    output wire        RMII_TXD1,
    output wire        RMII_TXEN,
    input  wire        RMII_RXD0,
    input  wire        RMII_RXD1,
    input  wire        RMII_CRS_DV,
	 input  wire [0:0]  KEY,
    inout  wire        RMII_MDIO,
    output wire        RMII_MDC,

    // LEDs
    output wire [9:0]  LEDR,
	 
	 //HEX
	 output [6:0] HEX0,
	 output [6:0] HEX1,
	 output [6:0] HEX2,
	 output [6:0] HEX3
);

// feed 50MHz clock to LAN8720
assign RMII_REF_CLK = CLOCK_50;

// regs and wire to feed RMII_TX
wire RMII_TXEN_dummy;
wire [1:0] RMII_TXD_vector;

//regs to feed RMII_RX
wire [1:0] RMII_RXD_vector;
 
assign RMII_RXD_vector[0] = RMII_RXD0;
assign RMII_RXD_vector[1] = RMII_RXD1;

wire data_valid_signal;

wire [1:0] signal_reg;

wire [511:0] data_rx; //data_out used in later logic

reg [511:0] data_rx_latch; //used to latch received data

reg data_valid_latched = 0; //used to latch data_valid signal

//reg for start counter
reg [15:0] ifg_counter = 0;
reg start_reg = 0;
reg start;

// hold reset high for 255 cycles on power up
reg [7:0] reset_cnt = 8'hFF;
wire rst = (reset_cnt != 8'd0);
wire ready_signal;

//debug state purposes
wire [2:0] mac_state;

//reset only for itch_parser
wire itch_rst = (reset_cnt != 8'd0) || ~KEY[0];

//Function to view incoming payloads
function [6:0] hex_decode;
    input [3:0] nibble;
    case (nibble)
        4'h0: hex_decode = 7'b1000000;
        4'h1: hex_decode = 7'b1111001;
        4'h2: hex_decode = 7'b0100100;
        4'h3: hex_decode = 7'b0110000;
        4'h4: hex_decode = 7'b0011001;
        4'h5: hex_decode = 7'b0010010;
        4'h6: hex_decode = 7'b0000010;
        4'h7: hex_decode = 7'b1111000;
        4'h8: hex_decode = 7'b0000000;
        4'h9: hex_decode = 7'b0010000;
        4'hA: hex_decode = 7'b0001000;
        4'hB: hex_decode = 7'b0000011;
        4'hC: hex_decode = 7'b1000110;
        4'hD: hex_decode = 7'b0100001;
        4'hE: hex_decode = 7'b0000110;
        4'hF: hex_decode = 7'b0001110;
    endcase
endfunction


always @(posedge CLOCK_50) begin
    if (reset_cnt != 8'd0)
        reset_cnt <= reset_cnt - 8'd1;
end

// MDIO switches between in and out
wire mdio_i;
wire mdio_o;
wire mdio_t;

assign RMII_MDIO = mdio_t ? 1'bz : mdio_o;
assign mdio_i    = RMII_MDIO;

// MDIO master wires
wire [4:0]  cmd_phy_addr  = 5'b00001; // LAN8720 address
wire [4:0]  cmd_reg_addr;
wire [15:0] cmd_data;
wire [1:0]  cmd_opcode;
wire        cmd_valid;
wire        cmd_ready;
wire [15:0] data_out;
wire        data_out_valid;
wire        data_out_ready;
wire        busy;

mdio_master u_mdio_master (
    .clk            (CLOCK_50),
    .rst            (rst),
    .cmd_phy_addr   (cmd_phy_addr),
    .cmd_reg_addr   (cmd_reg_addr),
    .cmd_data       (cmd_data),
    .cmd_opcode     (cmd_opcode),
    .cmd_valid      (cmd_valid),
    .cmd_ready      (cmd_ready),
    .data_out       (data_out),
    .data_out_valid (data_out_valid),
    .data_out_ready (data_out_ready),
    .mdc_o          (RMII_MDC),
    .mdio_i         (mdio_i),
    .mdio_o         (mdio_o),
    .mdio_t         (mdio_t),
    .busy           (busy),
    .prescale       (8'd9)
);

// read register 1 (basic status) repeatedly
localparam STATE_SEND  = 2'd0;
localparam STATE_WAIT  = 2'd1;
localparam STATE_DONE  = 2'd2;

reg [1:0]  state = STATE_SEND;
reg        link_up = 1'b0;

assign cmd_reg_addr   = 5'd1;   // register 1 = basic status
assign cmd_data       = 16'd0;  // not used for reads
assign cmd_opcode     = 2'b10;  // read
assign data_out_ready = 1'b1;

reg cmd_valid_reg = 1'b0;
assign cmd_valid = cmd_valid_reg;

always @(posedge CLOCK_50) begin
    if (rst) begin
        state         <= STATE_SEND;
        cmd_valid_reg <= 1'b0;
        link_up       <= 1'b0;
    end else begin
        case (state)
            STATE_SEND: begin
                if (cmd_ready) begin
                    cmd_valid_reg <= 1'b1;
                    state         <= STATE_WAIT;
                end
            end
            STATE_WAIT: begin
                cmd_valid_reg <= 1'b0;
                if (data_out_valid) begin
                    link_up <= data_out[2]; // bit 2 = link up
                    state   <= STATE_DONE;
                end
            end
            STATE_DONE: begin
                state <= STATE_SEND; // loop back and read again
            end
        endcase
    end
end

//Allow the PHY layer time to set up before sending start
always @(posedge CLOCK_50) begin
    if (ready_signal) begin
        if (ifg_counter == 16'd4800) begin  // 96 Useconds
            start_reg <= 1;
            ifg_counter <= 0;
        end else begin
            ifg_counter <= ifg_counter + 1;
            start_reg <= 0;
        end
    end
end

mac_rx u_mac_rx(
	.clk(CLOCK_50),
	.rst(rst),
	.CRS_DV(RMII_CRS_DV),
	.length(12'd64),
	.rxd(RMII_RXD_vector),
	.data_valid(data_valid_signal),
	.data_out(data_rx),
	.state_out(mac_state)
);

itch_parser u_itch_parser(
	.clk(CLOCK_50),
	.rst(itch_rst),
	.data_in(data_rx),
	.data_valid(data_valid_signal),
	.signal(signal_reg)
);

//When signal is BUY or SELL, get ready to transmit
always @(*) begin
	if (signal_reg == 1 || signal_reg == 2) begin
		start = 1;
	end else begin
		start = 0;
	end 

end 


mac_tx u_mac_tx (
	.clk(CLOCK_50),
	.rst(rst),
	.dst_mac(48'h04_D9_F5_BA_7C_B9),
	.src_mac(48'h02_00_00_00_00_01),
	.ethertype(16'hABF9),
	.data_in(signal_reg),
	.length(12'd64),
	.start(0), //change this to 1 when ready
	.ready(ready_signal),
	.txd(RMII_TXD_vector),
	.tx_en(RMII_TXEN_dummy)
);

// LEDR0 on = link up
assign LEDR[0]   = link_up;
assign LEDR[1]   = RMII_TXEN_dummy;
assign LEDR[8] = 0;
assign LEDR[4] = 0;
assign LEDR[7:5] = mac_state;
assign LEDR[2] = |RMII_RXD_vector;
assign LEDR[3] = RMII_CRS_DV;
assign LEDR[9] = data_valid_latched;

// TX
assign RMII_TXD0 = RMII_TXD_vector[0];
assign RMII_TXD1 = RMII_TXD_vector[1];
assign RMII_TXEN = RMII_TXEN_dummy;

//latch signal
always @(posedge CLOCK_50) begin
	if (data_valid_signal) begin
		data_rx_latch <= data_rx;
		data_valid_latched <= 1;
	end 

end 

//View data_out
assign HEX0 = hex_decode(data_rx_latch[511:508]); 
assign HEX1 = hex_decode(data_rx_latch[507:504]);
assign HEX2 = hex_decode(data_rx_latch[503:500]); 
assign HEX3 = hex_decode(data_rx_latch[499:496]); 


endmodule

`resetall