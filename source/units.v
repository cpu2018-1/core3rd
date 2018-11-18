module branch(
	input wire clk,
	input wire rstn,
	input wire [13:0] pc,
	input wire [5:0] ope,
	input wire [31:0] rs,
	input wire [31:0] rt,
	input wire [15:0] imm,
	input wire [4:0] opr,
	output wire is_hazard,
	output wire [13:0] addr,
	output wire [5:0] wreg,
	output wire [31:0] wdata
	);
	wire rs_le_rt;
	wire rs_eq_rt;
	wire rs_lt_opr;
	wire rs_eq_opr;
	wire [3:0] jop;

	assign rs_le_rt = $signed(rs) <= $signed(rt);
	assign rs_eq_rt = $signed(rs) == $signed(rt);
	assign rs_lt_opr = $signed(rs) < $signed(opr);
	assign rs_eq_opr = $signed(rs) == $signed(opr);
	assign jop = ope[5:2];
	assign is_hazard = jop == 4'b010 || jop == 4'b0011 ||
											(jop == 4'b0100 && rs_eq_rt) || (jop == 4'b0110 && rs_le_rt) ||
											(jop == 4'b1100 && rs_eq_opr) || (jop == 4'b1110 && ~rs_eq_opr) ||
											(jop == 4'b1000 && (rs_eq_opr || rs_lt_opr)) ||
											(jop == 4'b1010 && ~rs_lt_opr);
	assign addr = imm[13:0];
	assign wreg = ope[2] ? 6'b011111 : 0;
	assign wdata = pc + 1;
endmodule

module alu(
		input wire clk,
		input wire rstn,
		input wire [5:0] ope,
		input wire [31:0] ds,
		input wire [31:0] dt,
		input wire [15:0] imm,
		input wire [5:0] rd,
		output wire wreg,
		output wire wdata
	);
	wire [2:0] aop;
	wire [31:0] ads;
	wire [31:0] adt;

	assign aop = ope[5:3];
	assign ads = ds;
	assign adt = ope[2] ? dt : {{16{imm[15]}},imm};
	assign wreg = rd;
	assign wdata =  aop == 3'b110 ? {adt[15:0],ds[15:0]} :
									aop == 3'b001 ? $signed(ads) + $signed(adt) :
									aop == 3'b010 ? $signed(ads) - $signed(adt) :
									aop == 3'b011 ? ads << adt[4:0] :
									aop == 3'b100 ? ads >> adt[4:0] :
									aop == 3'b101 ? ads >>> adt[4:0] : 0;
endmodule
