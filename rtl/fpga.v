`resetall
`timescale 1ns/1ps
`default_nettype none

module fpga (
    input  wire        CLOCK_50,

    // RMII pins
    output wire        RMII_REF_CLK,
    output wire         RMII_TXD0,
    output wire         RMII_TXD1,
    output wire        RMII_TXEN,
    input  wire        RMII_RXD0,
    input  wire        RMII_RXD1,
    input  wire        RMII_CRS_DV,
    inout  wire        RMII_MDIO,
    output wire        RMII_MDC,

    // LEDs
    output wire [9:0]  LEDR
);

// feed 50MHz clock to LAN8720
assign RMII_REF_CLK = CLOCK_50;

// regs and wire to feed RMII_TX
wire RMII_TXEN_dummy;
wire [1:0] RMII_TXD_vector;

//reg for start counter
reg [15:0] ifg_counter = 0;
reg start_reg = 0;

// hold reset high for 255 cycles on power up
reg [7:0] reset_cnt = 8'hFF;
wire rst = (reset_cnt != 8'd0);
wire ready_signal;

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


mac_tx u_mac_tx (
	.clk(CLOCK_50),
	.rst(rst),
	.dst_mac(48'h),
	.src_mac(48'h02_00_00_00_00_01),
	.ethertype(16'hABF9),
	.data_in(8'hAA),
	.length(12'd64),
	.start(start_reg),
	.ready(ready_signal),
	.txd(RMII_TXD_vector),
	.tx_en(RMII_TXEN_dummy)
);


// LEDR0 on = link up
assign LEDR[0]   = link_up;
assign LEDR[1]   = RMII_TXEN_dummy;
assign LEDR[9:2] = 8'd0;

// TX not used yet
assign RMII_TXD0 = RMII_TXD_vector[0];
assign RMII_TXD1 = RMII_TXD_vector[1];
assign RMII_TXEN = RMII_TXEN_dummy;
endmodule

`resetall