module unit1(
		input wire clk,
		input wire rstn,
		input wire [13:0] pc,
		(* mark_debug = "true" *) input wire [5:0] ope,
		(* mark_debug = "true" *) input wire [31:0] ds_val,
		(* mark_debug = "true" *) input wire [31:0] dt_val,
		input wire [5:0] dd,
		(* mark_debug = "true" *) input wire [15:0] imm,
		(* mark_debug = "true" *) input wire [4:0] opr,
		(* mark_debug = "true" *) input wire [3:0] ctrl,
		output wire [6:0] is_busy,
		(* mark_debug = "true" *) output wire b_is_hazard,
		(* mark_debug = "true" *) output wire [13:0] b_addr,
		(* mark_debug = "true" *) output wire b_is_b_ope,
		(* mark_debug = "true" *) output wire b_is_branch,
		output wire [13:0] b_w_pc,

		output wire [5:0] alu_addr, ////
		output wire [31:0] alu_dd_val, ////
		output wire [5:0] fpu_addr,  // 中にFPUモジュール埋め込む場合はwireに直す！
		output wire [31:0] fpu_dd_val // 上に同じ
	);
	// B or ALU or FPU
	wire rs_eq_opr;
	wire rs_lt_opr;
	wire taken;
	wire was_branch;

	wire [31:0] ex_imm;
	wire [31:0] alu_rs;
	wire [31:0] alu_rt_imm;
	wire [31:0] add;
	wire [31:0] sub;
	wire [31:0] sll;
	wire [31:0] srl;
	wire [31:0] sra;
	wire [31:0] pc_1;

	fpu u1(ctrl,ds_val,dt_val,dd,imm,fpu_addr,fpu_dd_val);

	assign rs_eq_opr = $signed(ds_val) == $signed(opr);
	assign rs_lt_opr = $signed(ds_val) < $signed(opr);
	assign taken =
			(ope == 6'b010010 && $signed(ds_val) == $signed(dt_val)) ||
	    (ope == 6'b011010 && $signed(ds_val) <= $signed(dt_val)) ||
	    (ope == 6'b110010 && rs_eq_opr) ||
	    (ope == 6'b111010 && ~rs_eq_opr) ||
	    (ope == 6'b100010 && (rs_eq_opr || rs_lt_opr)) ||
	    (ope == 6'b101010 && ~rs_lt_opr);
	assign was_branch = ctrl[0];

	assign ex_imm = {{16{imm[15]}},imm};
	assign alu_rs = ds_val;
	assign alu_rt_imm = ope[2] ? dt_val : ex_imm;
	assign add = $signed(alu_rs) + $signed(alu_rt_imm);
	assign sub = $signed(alu_rs) - $signed(alu_rt_imm);
	assign sll = alu_rs << alu_rt_imm[4:0];
	assign srl = alu_rs >> alu_rt_imm[4:0];
	assign sra = alu_rs >>> alu_rt_imm[4:0];
	assign pc_1 = pc + 1;

	assign is_busy = 0; /////// FPUと調整

	assign alu_addr = 
			ope == 6'b000110 || ope == 6'b001110 ? 6'b011111 :
			ope != 0 && ope[1:0] == 2'b00 ? dd : 0;
	assign alu_dd_val = 
		ope == 6'b110000 ? {imm,ds_val[15:0]} :
		ope == 6'b001100 || ope == 6'b001000 ? add :
		ope == 6'b010100 ? sub :
		ope == 6'b011100 || ope == 6'b011000 ? sll :
		ope == 6'b100100 || ope == 6'b100000 ? srl :
		ope == 6'b101100 || ope == 6'b101000 ? sra :
		ope == 6'b000110 || ope == 6'b001110 ? pc_1 : 0;

    assign b_is_hazard =
    		ope == 6'b001110 || // JALR
				(ope == 6'b001010 && ds_val[13:0] != pc[13:0]) || // JR
   			(ope[1:0] == 2'b10 && ope[5:4] != 2'b0 && (taken ^ was_branch));
    assign b_addr =
    		(ope[1:0] == 2'b10 && ope[5:4] == 2'b00) ? ds_val[13:0] :
    		taken ? imm[13:0] : pc_1;
    assign b_is_b_ope = ope[1:0] == 2'b10 && ope[5:4] != 2'b0;
    assign b_is_branch = taken;
    assign b_w_pc = pc;

	always @(posedge clk) begin
		if (~rstn) begin
//			alu_addr <= 0;
//			alu_dd_val <= 0;
		end else begin
/*
		b_is_hazard <= 
				ope == 6'b001010 || ope == 6'b001110 || 
				(ope[1:0] == 2'b10 && ope[5:4] != 2'b0 && (taken ^ was_branch));
		b_addr <= 
				(ope[1:0] == 2'b10 && ope[5:4] == 2'b00) ? ds_val :
				taken ? imm[13:0] : pc_1;
		b_is_b_ope <= ope[1:0] == 2'b10 && ope[5:4] != 2'b0;
		b_is_branch <= taken;
		b_w_pc <= pc;
*/
		end
	end

endmodule
