`timescale 1ns / 1ps

module multiplier(
    input  [31:0] A,
    input  [31:0] B,
    output [31:0] out_mul
);

    // Decompose inputs
    wire signA       = A[31];
    wire [7:0] expA_n  = A[30:23];
    wire [22:0] fracA = A[22:0];
    wire signB       = B[31];
    wire [7:0] expB_n  = B[30:23];
    wire [22:0] fracB = B[22:0];

    // Classify inputs
    wire isZero_A = (expA_n == 8'd0) && (fracA == 0);
    wire isZero_B = (expB_n == 8'd0) && (fracB == 0);
    wire isInf_A  = (expA_n == 8'hFF) && (fracA == 0);
    wire isInf_B  = (expB_n == 8'hFF) && (fracB == 0);
    wire isNaN_A  = (expA_n == 8'hFF) && (fracA != 0);
    wire isNaN_B  = (expB_n == 8'hFF) && (fracB != 0);
    wire isNormal_A = (expA_n != 0) && (expA_n != 8'hFF);
    wire isNormal_B = (expB_n != 0) && (expB_n != 8'hFF);

    // Effective sign
    wire outSign = signA ^ signB;

    // Mantissas (implicit 1 only for normal numbers)
    wire [23:0] mantA = (expA_n == 8'd0) ? {1'b0, fracA} : {1'b1, fracA};
    wire [23:0] mantB = (expB_n == 8'd0) ? {1'b0, fracB} : {1'b1, fracB};
    wire [7:0] expA = (expA_n == 8'd0) ? 8'd1 : expA_n;
    wire [7:0] expB = (expB_n == 8'd0) ? 8'd1 : expB_n;
    
    // Multiply mantissas (24 x 24 = 48 bits) - single source of product
    wire [47:0] product = mantA * mantB;

    // Compute exponent once as a combinational wire (no multiple drivers)
    wire signed [9:0] expSum = $signed({2'b00, expA}) + $signed({2'b00, expB}) - 10'sd127;

    // Output registers
    reg [22:0] outMant;
    reg [7:0]  outExp;
    reg        isNaN, isInf;
    reg [9:0]  inter;
    reg [47:0] norm_product;
    reg signed [9:0] final_exp;
    integer shift;

    always @(*) begin
        // Default values
        isNaN = 1'b0;
        isInf = 1'b0;
        outExp  = 8'd0;
        outMant = 23'd0;

        // === Exception handling ===
        if (isNaN_A || isNaN_B) begin
            isNaN = 1'b1;
        end
        else if ((isInf_A && isZero_B) || (isInf_B && isZero_A)) begin
            // inf * 0 = NaN
            isNaN = 1'b1;
        end
        else if (isInf_A || isInf_B) begin
            // any finite nonzero * inf = inf
            isInf = 1'b1;
        end
        else if (isZero_A || isZero_B) begin
            // 0 * finite = 0
            outExp  = 8'd0;
            outMant = 23'd0;
        end
        // === Normal case ===
        else begin
            // Normalize product if MSB is 1
            if (product[47]) begin
                // 1.xx * 2^exp → shift right
                norm_product = product >> 1;
                final_exp    = expSum + 10'sd1;
            end else begin
                // 0.xx * 2^exp → already aligned
                norm_product = product;
                final_exp    = expSum;
            end
            
            // Overflow
            if (final_exp >= 10'sd255) begin
            // Overflow → infinity
                isInf   = 1'b1;
                outExp  = 8'hFF;
                outMant = 23'd0;
            end
            //Subnormal and underflow
            else if (final_exp <= 10'sd1) begin
            // Amount to shift to form subnormal
                if( norm_product[46] == 0) begin
                    shift = 1 - final_exp;
                    if (shift >= 25) begin
                        // Too small → flush to zero
                        outExp  = 8'd0;
                        outMant = 23'd0;
                    end else begin
                        // Gradual underflow → subnormal
                        norm_product = norm_product >> shift;
                        outExp  = 8'd0;                    // subnormal exponent
                        outMant = norm_product[45:23];     // no implicit 1
                    end
                end 
                else if (final_exp <= 10'sd0) begin
                    shift = 1 - final_exp;
                    if (shift >= 25) begin
                        // Too small → flush to zero
                        outExp  = 8'd0;
                        outMant = 23'd0;
                    end else begin
                        // Gradual underflow → subnormal
                        norm_product = norm_product >> shift;
                        outExp  = 8'd0;                    // subnormal exponent
                        outMant = norm_product[45:23];     // no implicit 1
                    end
                end
                else begin
                    outExp  = final_exp[7:0];
                    outMant = norm_product[45:23];
                end
            end
 
            else begin
                outExp  = final_exp[7:0];
                outMant = norm_product[45:23];         // drop hidden 1
            end
        end  

        // Pack results for NaN and Inf (override normal outputs)
        if (isNaN) begin
            outExp  = 8'hFF;
            outMant = 23'h400000; 
        end
        else if (isInf) begin
            outExp  = 8'hFF;
            outMant = 23'h0;
        end
    end

    // Pack final output
    assign out_mul = {outSign, outExp, outMant};

endmodule
