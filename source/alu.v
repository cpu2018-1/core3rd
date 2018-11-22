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
	output reg b_is_hazard,
	output reg [13:0] b_addr,
	output reg [5:0] reg_addr,
	output reg [31:0] reg_dd_val
	);

	always @(posedge clk) begin
		if(~rstn) begin
			b_is_hazard <= 0;
			b_addr <= 0;
			reg_addr <= 0;
			reg_dd_val <= 0;
		end else begin
			case (ope)
				6'b110000: // LUI
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= {imm,ds_val[15:0]};
					end
				6'b001100: //ADD
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) + $signed(dt_val);
					end
				6'b001000: //ADDI
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) + $signed(imm);
					end
				6'b010100: //SUB
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= $signed(ds_val) - $signed(dt_val);
					end
				6'b011100: // SLL
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val << dt_val[4:0];
					end
				6'b011000: //SLLI
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val << imm[4:0];
					end
				6'b100100: //SRL
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val >> dt_val[4:0];
					end
				6'b100000: //SRLI
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val >> imm[4:0];
					end
				6'b101100: //SRA
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val >>> dt_val[4:0];
					end
				6'b101000: //SRAI
					begin
						b_is_hazard <= 0;
						reg_addr <= dd;
						reg_dd_val <= ds_val >>> imm[4:0];
					end
				6'b000010: //J
					begin
						b_is_hazard <= 0;
						reg_addr <= 0;
					end
				6'b000110: //JAL
					begin
						b_is_hazard <= 0;
						reg_addr <= 6'b011111;
						reg_dd_val <= pc + 1;
					end
				6'b001010: //JR
					begin
						b_is_hazard <= 1;
						b_addr <= ds_val;
						reg_addr <= 0;
					end
				6'b001110: //JALR
					begin
						b_is_hazard <= 1;
						b_addr <= ds_val;
						reg_addr <= 6'b011111;
						reg_dd_val <= pc + 1;
					end
				6'b010010: //BEQ
					begin
						b_is_hazard <= $signed(ds_val) == $signed(dt_val);
						b_addr <= imm[13:0];
						reg_addr <= 0;
					end
				6'b011010: //BLE
					begin
						b_is_hazard <= $signed(ds_val) <= $signed(dt_val);
						b_addr <= imm[13:0];
						reg_addr <= 0;
					end
				// CONTINUE
			endcase
		end
	end
endmodule

