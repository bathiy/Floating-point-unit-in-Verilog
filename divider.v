`timescale 1ns / 1ps

module divider(
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] divide_out
);

    // ---------- Extract fields ----------
    wire signA        = A[31];
    wire [7:0] expA   = A[30:23];
    wire [22:0] fracA = A[22:0];

    wire signB        = B[31];
    wire [7:0] expB   = B[30:23];
    wire [22:0] fracB = B[22:0];

    // ---------- Construct mantissa with hidden 1 ----------
    // (handles denormals: hidden 0)
    wire [23:0] mantA = (expA == 0) ? {1'b0, fracA} : {1'b1, fracA};
    wire [23:0] mantB = (expB == 0) ? {1'b0, fracB} : {1'b1, fracB};
    
    wire [7:0] expA_act = (expA == 0) ? 8'd1 : expA;
    wire [7:0] expB_act = (expB == 0) ? 8'd1 : expB;

    // ---------- Exception detect ----------
    wire nanA  = (expA == 8'hFF && fracA != 0);
    wire nanB  = (expB == 8'hFF && fracB != 0);
    wire infA  = (expA == 8'hFF && fracA == 0);
    wire infB  = (expB == 8'hFF && fracB == 0);
    wire zeroA = (expA == 0 && fracA == 0);
    wire zeroB = (expB == 0 && fracB == 0);

    // ---------- divide_output sign ----------
    wire divide_outSign = signA ^ signB;

    // ---------- Module level regs for algorithm ----------
    reg signed [9:0] expSum;        // signed exponent accumulator (allows negative)
    reg [47:0] divResult;           // 48-bit division result
    reg [7:0] finalExp;             // final biased exponent for output
    reg [22:0] finalFrac;           // final fraction for output
    reg [23:0] mant24;              // 24-bit mantissa (including hidden bit) after normalization
    reg signed [9:0] normExp;       // normalized exponent (signed) before bias/packing

    integer i;
    reg done;
    
    reg [47:0] normShift;
    reg [22:0] shifted;
    reg [22:0] denormFrac;
    
    integer shiftAmount;
    integer shift;
    integer found; 

always @(*) begin
    // defaults
    divide_out = 32'd0;
    finalExp   = 8'd0;
    finalFrac  = 23'd0;
    mant24     = 24'd0;
    normExp    = 10'sd0;
    divResult  = 48'd0;

    // ---------- Exception Logic ----------
    if (nanA || nanB || (infA && infB) || (zeroA && zeroB)) begin
        // qNaN
        divide_out = {1'b0, 8'hFF, 23'h400000};
    end
    else if (infA && !zeroB) begin
        // Inf (A is Inf, B non-zero)
        divide_out = {divide_outSign, 8'hFF, 23'd0};
    end
    else if (infB && !infA) begin
        // 0 (A finite, B Inf)
        divide_out = {divide_outSign, 8'd0, 23'd0};
    end
    else if (zeroB && !zeroA) begin
        // Division by zero -> Inf
        divide_out = {divide_outSign, 8'hFF, 23'd0};
    end
    else if (zeroA) begin
        // 0 numerator -> zero
        divide_out = {divide_outSign, 8'd0, 23'd0};
    end
    
    else begin
        expSum = $signed({1'b0, expA_act}) - $signed({1'b0, expB_act}) + 10'sd127;
        divResult = ({mantA, 23'b0} / mantB);  
        // Leading zero count from bit 47 (MSB)
        shift = 0;
        done  = 0;
    
        for (i = 47; i >= 0; i = i - 1) begin
            if (!done) begin
                if (divResult[i] == 1'b0)
                    shift = shift + 1;
                else
                    done = 1;
            end
        end
    
        // If divResult == 0 → output zero
        if (shift == 48) begin
            divide_out = {divide_outSign, 8'd0, 23'd0};
        end
        else begin  
            normExp = expSum + (24 - shift);
    
            if (shift < 24)
                mant24 = divResult >> (24 - shift);
            else
                mant24 = divResult << (shift - 24);
    
            // Overflow
            if (normExp >= 9'sd255) begin
                divide_out = {divide_outSign, 8'hFF, 23'd0};
            end
    
            // Normal number
            else if (normExp > 0) begin
                divide_out = {
                    divide_outSign,
                    normExp[7:0],
                    mant24[22:0]
                };
            end
    
            // Subnormal / underflow
            else begin
                shiftAmount = 1 - normExp;
    
                if (shiftAmount >= 24) begin
                    // underflow to zero
                    divide_out = {divide_outSign, 8'd0, 23'd0};
                end
                else begin
                    denormFrac = mant24 >> shiftAmount;
                    divide_out = {
                        divide_outSign,
                        8'd0,
                        denormFrac[22:0]
                    };
                end
            end
        end
    end   
end
endmodule