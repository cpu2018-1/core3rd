module unit3(
		input wire clk,
		input wire rstn,
		input wire [5:0] ope,
		input wire [31:0] ds_val,
		input wire [31:0] dt_val,
		input wire [5:0] dd,
		input wire [15:0] imm,
		input wire [3:0] ctrl,
		output wire [6:0] is_busy,
		output wire [5:0] alu_addr,
		output wire [31:0] alu_dd_val,
		output wire [5:0] fpu_addr,
		output wire [31:0] fpu_dd_val
	);
	// ALU FPU

  wire [31:0] ex_imm;
  wire [31:0] alu_rs;
  wire [31:0] alu_rt_imm;
	wire [31:0] add;
	wire [31:0] sub;
	wire [31:0] sll;
	wire [31:0] srl;
	wire [31:0] sra;

	fpu u1(ctrl,ds_val,dt_val,dd,imm,fpu_addr,fpu_dd_val);
		
	assign is_busy = 0;


	assign ex_imm = {{16{imm[15]}},imm};
  assign alu_rs = ds_val;
  assign alu_rt_imm = ope[2] ? dt_val : ex_imm;
	assign add = $signed(alu_rs) + $signed(alu_rt_imm);
	assign sub = $signed(alu_rs) - $signed(alu_rt_imm);
	assign sll = alu_rs << alu_rt_imm[4:0];
	assign srl = alu_rs >> alu_rt_imm[4:0];
	assign sra = alu_rs >>> alu_rt_imm[4:0];
  assign alu_addr =
			ope != 0 && ope[1:0] == 2'b00 ? dd : 0;
	assign alu_dd_val =
			ope == 6'b110000 ? {imm,ds_val[15:0]} :
			ope == 6'b001100 || ope == 6'b001000 ? add :
			ope == 6'b010100 ? sub :
			ope == 6'b011100 || ope == 6'b011000 ? sll :
			ope == 6'b100100 || ope == 6'b100000 ? srl :
			ope == 6'b101100 || ope == 6'b101000 ? sra : 0;

endmodule
