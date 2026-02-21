`timescale 1ns / 1ps
module Adder_subtractor(
    input  [31:0] A,
    input  [31:0] B,
    input  add_sub_sel,
    output [31:0] result
);  
    
    wire signA       = A[31];
    wire [7:0] expA  = A[30:23];
    wire [22:0] fracA= A[22:0];
    
    wire signB;
    wire [7:0] expB  = B[30:23];
    wire [22:0] fracB= B[22:0];
    
    reg [8:0] largeExp;
    reg [8:0] smallExp;
    reg [8:0] ExpDiff;
    reg [23:0] largeNumber;
    reg [23:0] smallNumber;
    reg largeNumsign;
    reg smallNumsign;
    
    reg [24:0] mantissaSum;
    reg [7:0]  finalExp;
    reg [22:0] finalFrac;
    reg finalSign;
    reg [8:0]  expSum;
    
    // For subnormal: exponent field = 0 means unbiased exponent = -126.
    // exp_eff = 1 for denormals when aligning
    wire [7:0] expA_eff = (expA == 8'd0) ? 8'd1 : expA;
    wire [7:0] expB_eff = (expB == 8'd0) ? 8'd1 : expB;
    
    wire denormA = (expA == 0 && fracA != 0);
    wire denormB = (expB == 0 && fracB != 0);
    
    wire zeroA = (expA == 0 && fracA == 0);
    wire zeroB = (expB == 0 && fracB == 0);
    
    wire nanA = (expA == 8'hFF && fracA != 0);
    wire nanB = (expB == 8'hFF && fracB != 0);
    
    wire infA = (expA == 8'hFF && fracA == 0);
    wire infB = (expB == 8'hFF && fracB == 0);
    
    // ---------------- MANTISSA WITH DENORMAL SUPPORT ----------------
    // normal → {1,frac}
    // denorm → {0,frac}
    // Add GRS after the LSB of the mantissa 
    wire [23:0] opA = (expA == 8'd0) ? {1'b0, fracA} : {1'b1, fracA};
    wire [23:0] opB = (expB == 8'd0) ? {1'b0, fracB} : {1'b1, fracB};
    
    assign signB = add_sub_sel ? ~B[31] : B[31];
    
    reg [24:0] normMantissa;
    reg [24:0] temp;
    reg found_one;
    
    integer shiftCount;
    integer k;    
    integer shift_done;
    
    
    always @(*) begin
        // default init
        largeExp     = 0;
        smallExp     = 0;
        largeNumber  = 0;
        smallNumber  = 0;
        largeNumsign = 0;
        smallNumsign = 0;
        ExpDiff      = 0;
    
        // ---------- Exceptions ----------
        if (nanA || nanB) begin
            finalSign = 0;
            finalExp  = 8'hFF;
            finalFrac = 23'h400000;
        end
        else if (infA || infB) begin
            if (infA && infB && (signA ^ signB)) begin
                finalSign = 0;
                finalExp  = 8'hFF;
                finalFrac = 23'h400000;
            end else if (infA) begin
                finalSign = signA;
                finalExp  = 8'hFF;
                finalFrac = 0;
            end else begin
                finalSign = signB;
                finalExp  = 8'hFF;
                finalFrac = 0;
            end
        end
        else if (zeroA && zeroB) begin
            finalSign = 0;
            finalExp  = 0;
            finalFrac = 0;
        end
        else if ((expA_eff == expB_eff) && (opA == opB) && (signA ^ signB)) begin
            // x + (-x) = 0
            finalSign = 0;
            finalExp  = 0;
            finalFrac = 0;
        end
        else if (zeroA) begin
            finalSign = signB;
            finalExp  = expB;
            finalFrac = fracB;
        end
        else if (zeroB) begin
            finalSign = signA;
            finalExp  = expA;
            finalFrac = fracA;
        end
    
        else begin
            // ----- exponent compare -----
            if (expA_eff > expB_eff) begin
                largeExp     = {1'b0, expA_eff};
                smallExp     = {1'b0, expB_eff};
                largeNumber  = opA;
                smallNumber  = opB >> (expA_eff - expB_eff);
                largeNumsign = signA;
                smallNumsign = signB;
                ExpDiff      = expA_eff - expB_eff;
            end
            else if (expB_eff > expA_eff) begin
                largeExp     = {1'b0, expB_eff};
                smallExp     = {1'b0, expA_eff};
                largeNumber  = opB;
                smallNumber  = opA >> (expB_eff - expA_eff);
                largeNumsign = signB;
                smallNumsign = signA;
                ExpDiff      = expB_eff - expA_eff;
            end
            else begin
                // mantissa tie break
                if (opA >= opB) begin
                    largeExp     = {1'b0, expA_eff};
                    largeNumber  = opA;
                    smallNumber  = opB;
                    largeNumsign = signA;
                    smallNumsign = signB;
                end else begin
                    largeExp     = {1'b0, expB_eff};
                    largeNumber  = opB;
                    smallNumber  = opA;
                    largeNumsign = signB;
                    smallNumsign = signA;
                end
            end
    
            expSum = largeExp;
    
            // ---------------- ADD/SUB USING 2'S COMPLEMENT ----------------
            if (~(largeNumsign ^ smallNumsign))
                mantissaSum = {1'b0, largeNumber} + {1'b0, smallNumber};
            else
                mantissaSum = {1'b0, largeNumber} + (~{1'b0, smallNumber} + 1);
    
            finalSign = largeNumsign;
    
            // ---------------- NORMALIZATION ----------------
            normMantissa = mantissaSum;
            finalExp     = expSum;

            if (normMantissa[24]) begin
                normMantissa = normMantissa >> 1;
                finalExp     = finalExp + 1;
            end
            else begin
                shiftCount = 0;
                while (normMantissa[23] == 0 && finalExp > 0 && shiftCount < 24) begin
                    normMantissa = normMantissa << 1;
                    finalExp     = finalExp - 1;
                    shiftCount   = shiftCount + 1;
                end
            end
    
            finalFrac = normMantissa[22:0];
    
            // ------------- OVERFLOW to INF -------------
            if (finalExp >= 8'hFF) begin
                finalExp  = 8'hFF;
                finalFrac = 0;
            end
            
            // ------------- UNDERFLOW to SUBNORMAL (FIXED) -------------
            if (finalExp == 0) begin
                // Convert to subnormal:
                finalFrac = normMantissa[23:1];
            end
        end
    end
    assign result = {finalSign, finalExp, finalFrac};
endmodule