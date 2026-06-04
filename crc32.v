`resetall
`timescale 1ns / 1ps
`default_nettype none
module crc32 (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire [1:0]  dibit,
    output reg  [31:0] crc_register
);

localparam POLYNOMIAL = 32'hEDB88320;

reg [31:0] crc_next;

// compute next CRC from both bits
always @(*) begin
    crc_next = crc_register;
    if (crc_next[0] ^ dibit[0])
        crc_next = (crc_next >> 1) ^ POLYNOMIAL;
    else
        crc_next = crc_next >> 1;
    if (crc_next[0] ^ dibit[1])
        crc_next = (crc_next >> 1) ^ POLYNOMIAL;
    else
        crc_next = crc_next >> 1;
end

//register the result
always @(posedge clk) begin
    if (rst)
        crc_register <= 32'hFFFFFFFF;
    else if (valid)
        crc_register <= crc_next;
end

endmodule
`resetall