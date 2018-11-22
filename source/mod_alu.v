module alu(
	input wire clk,
	input wire rstn,
	input wire [5:0] ope,
	input wire [13:0] pc,
	input wire [31:0] ds_val,
	input wire [31:0] dt_val,
	input wire [5:0] dd,
	input wire [15:0] imm,
	input wire [4:0] opr,
	output wire b_is_hazard,
	output wire [13:0] b_addr,
	output reg [5:0] reg_addr,
	output reg [31:0] reg_dd_val
	);

	wire [31:0] ex_opr;
	wire rs_eq_opr;
	wire rs_lt_opr;
	
	assign ex_opr = {{27{opr[4]}},opr};
	assign rs_eq_opr = $signed(ds_val) == $signed(ex_opr);
	assign rs_lt_opr = $signed(ds_val) < $signed(ex_opr);

	assign b_is_hazard =
		(ope[5:0] == 6'b010010 && $signed(ds_val) == $signed(dt_val)) ||
		(ope[5:0] == 6'b011010 && $signed(ds_val) <= $signed(dt_val)) ||
		(ope[5:0] == 6'b110010 && rs_eq_opr) ||
		(ope[5:0] == 6'b111010 && ~rs_eq_opr) ||
		(ope[5:0] == 6'b100010 && (rs_eq_opr || rs_lt_opr)) ||
		(ope[5:0] == 6'b101010 && ~rs_lt_opr);
	assign b_addr = imm[13:0];

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
				6'b000010: //J
					begin
						reg_addr <= 0;
					end
				6'b000110: //JAL
					begin
						reg_addr <= 6'b011111;
						reg_dd_val <= pc + 1;
					end
				6'b001010: //JR
					begin
						reg_addr <= 0;
					end
				6'b001110: //JALR
					begin
						reg_addr <= 6'b011111;
						reg_dd_val <= pc + 1;
					end
				default:
					begin
						reg_addr <= 0;
					end
			endcase
		end
	end
endmodule

