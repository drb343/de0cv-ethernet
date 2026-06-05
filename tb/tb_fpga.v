`timescale 1ns/1ps
module tb_fpga;
    reg        CLOCK_50;
    wire       RMII_REF_CLK;
    wire       RMII_TXD0;
    wire       RMII_TXD1;
    wire       RMII_TXEN;
    reg        RMII_RXD0;
    reg        RMII_RXD1;
    reg        RMII_CRS_DV;
    wire       RMII_MDIO;
    wire       RMII_MDC;
    wire [9:0] LEDR;
	
	fpga uut (
		.CLOCK_50(CLOCK_50),
		.RMII_TXD0(RMII_TXD0),
		.RMII_TXD1(RMII_TXD1),
		.RMII_TXEN(RMII_TXEN),
		.RMII_REF_CLK(RMII_REF_CLK),
		.RMII_RXD0(RMII_RXD0),
		.RMII_RXD1(RMII_RXD1),
		.RMII_CRS_DV(RMII_CRS_DV),
		.RMII_MDIO(RMII_MDIO),
		.RMII_MDC(RMII_MDC)
	);
	
	always #5 CLOCK_50 = ~CLOCK_50;
	
	initial begin
		CLOCK_50 = 0;
		RMII_RXD0   = 0;
		RMII_RXD1   = 0;
		RMII_CRS_DV = 0;
		
		#2600;
		
		#4000;
	
		$stop;
	end
	
	

endmodule