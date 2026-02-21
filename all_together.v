`timescale 1ns / 1ps

module all_together(
    input  [31:0] A,
    input  [31:0] B,
    input  [1:0]  mux_sel,
    input         add_sub_sel,
    input clk,
    output reg [31:0] outval,
    output reg Nan,
    output reg overflow,
    output reg zero,
    output reg underflow
);

    // Internal wires to hold outputs of each block
    wire [31:0] addsub_out;
    wire [31:0] mul_out;
    wire [31:0] div_out;
    
    wire Nan_add;
    wire overflow_add;
    wire zero_add;
    wire underflow_add;
    
    wire Nan_mul;
    wire overflow_mul;
    wire zero_mul;
    wire underflow_mul;
    
    wire Nan_div;
    wire overflow_div;
    wire zero_div;
    wire underflow_div;

    reg [31:0] output_value;
    // ------------------ Module Instantiations ------------------

    Adder_subtractor u_adder_subtractor (
        .A(A),
        .B(B),
        .add_sub_sel(add_sub_sel),
        .result(addsub_out),
        .Nan(Nan_add),
        .overflow(overflow_add),
        .zero(zero_add),
        .underflow(underflow_add)
    );

    multiplier u_multiplier (
        .A(A),
        .B(B),
        .out_mul(mul_out),
        .Nan(Nan_mul),
        .overflow(overflow_mul),
        .zero(zero_mul),
        .underflow(underflow_mul)
    );

    divider u_divider (
        .A(A),
        .B(B),
        .divide_out(div_out),
        .Nan(Nan_div),
        .overflow(overflow_div),
        .zero(zero_div),
        .underflow(underflow_div)
    );

    // ------------------ Output MUX ------------------
    always @(posedge clk) begin
    // Default safe values
    outval     = 32'b0;
    Nan        = 1'b0;
    overflow   = 1'b0;
    zero       = 1'b0;
    underflow  = 1'b0;

    case (mux_sel)
        2'b00: begin   // ADD / SUB
            outval     = addsub_out;
            Nan        = Nan_add;
            overflow   = overflow_add;
            zero       = zero_add;
            underflow  = underflow_add;
        end

        2'b01: begin   // MULTIPLY
            outval     = mul_out;
            Nan        = Nan_mul;
            overflow   = overflow_mul;
            zero       = zero_mul;
            underflow  = underflow_mul;
        end

        2'b10: begin   // DIVIDE
            outval     = div_out;
            Nan        = Nan_div;
            overflow   = overflow_div;
            zero       = zero_div;
            underflow  = underflow_div;
        end

        default: begin // Invalid op
            outval     = 32'b0;
            Nan        = 1'b0;
            overflow   = 1'b0;
            zero       = 1'b1;   // zero result
            underflow  = 1'b0;
        end
        
        
    endcase
    output_value = outval;
end


endmodule
