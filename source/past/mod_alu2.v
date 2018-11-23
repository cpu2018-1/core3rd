module alu2(
	input wire clk,
	input wire rstn,
	input wire [5:0] ope,
	input wire [31:0] ds_val,
	input wire [31:0] dt_val,
	input wire [5:0] dd,
	input wire [15:0] imm,
	output reg [5:0] reg_addr,
	output reg [31:0] reg_dd_val
	);

	always @(posedge clk) begin
		if(~rstn) begin
			reg_addr <= 0;
			reg_dd_val <= 0;
		end else begin
			case (ope)
				6'b110000: // LUI
					begin
						reg_addr <= dd;
						reg_dd_val <= {imm,ds_val[15:0]};
					end
				6'b001100: //ADD
					begin
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) + $signed(dt_val);
					end
				6'b001000: //ADDI
					begin
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) + $signed(imm);
					end
				6'b010100: //SUB
					begin
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) - $signed(dt_val);
					end
				6'b011100: // SLL
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val << dt_val[4:0];
					end
				6'b011000: //SLLI
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val << imm[4:0];
					end
				6'b100100: //SRL
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val >> dt_val[4:0];
					end
				6'b100000: //SRLI
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val >> imm[4:0];
					end
				6'b101100: //SRA
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val >>> dt_val[4:0];
					end
				6'b101000: //SRAI
					begin
						reg_addr <= dd;
						reg_dd_val <= ds_val >>> imm[4:0];
					end
				default:
					begin
						reg_addr <= 0;
					end
			endcase
		end
	end
endmodule

