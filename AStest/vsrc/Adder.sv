module Adder_4#(
    parameter DATA_WIDTH = 16
)(
    input logic [DATA_WIDTH-1:0] a1,
    input logic [DATA_WIDTH-1:0] a2,
    input logic [DATA_WIDTH-1:0] a3,
    input logic [DATA_WIDTH-1:0] a4,
    input logic [DATA_WIDTH-1:0] b1,
    input logic [DATA_WIDTH-1:0] b2,
    input logic [DATA_WIDTH-1:0] b3,
    input logic [DATA_WIDTH-1:0] b4,
    output logic [DATA_WIDTH-1:0] sum1,
    output logic [DATA_WIDTH-1:0] sum2,
    output logic [DATA_WIDTH-1:0] sum3,
    output logic [DATA_WIDTH-1:0] sum4
);
    assign sum1 = a1 + b1;
    assign sum2 = a2 + b2;
    assign sum3 = a3 + b3;
    assign sum4 = a4 + b4;
endmodule 