module unit1(
		input wire clk,
		input wire rstn,
		input wire [13:0] pc,
		input wire [5:0] ope,
		input wire [31:0] ds_val,
		input wire [31:0] dt_val,
		input wire [5:0] dd,
		input wire [15:0] imm,
		input wire [4:0] opr,
		input wire [3:0] ctrl,
		output wire [6:0] is_busy,
		output wire b_is_hazard,
		output wire [13:0] b_addr,
		output reg [5:0] alu_addr,
		output reg [31:0] alu_dd_val,
		output reg [5:0] fpu_addr,  // 中にFPUモジュール埋め込む場合はwireに直す！
		output reg [31:0] fpu_dd_val // 上に同じ
	);
	// B or ALU or FPU
	wire rs_eq_opr;
	wire rs_lt_opr;

	wire [31:0] ex_imm;
	wire [31:0] alu_rs;
	wire [31:0] alu_rt_imm;
	wire [31:0] add;
	wire [31:0] sub;
	wire [31:0] sll;
	wire [31:0] srl;
	wire [31:0] sra;
	wire [31:0] pc_1;

	assign rs_eq_opr = $signed(ds_val) == $signed(opr);
	assign rs_lt_opr = $signed(ds_val) < $signed(opr);

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

	assign b_is_hazard =
		(ope == 6'b010010 && $signed(ds_val) == $signed(dt_val)) ||
		(ope == 6'b011010 && $signed(ds_val) <= $signed(dt_val)) ||
		(ope == 6'b110010 && rs_eq_opr) ||
		(ope == 6'b111010 && ~rs_eq_opr) ||
		(ope == 6'b100010 && (rs_eq_opr || rs_lt_opr)) ||
		(ope == 6'b101010 && ~rs_lt_opr);
	assign b_addr = imm[13:0];

	always @(posedge clk) begin
		if (~rstn) begin
			alu_addr <= 0;
			alu_dd_val <= 0;
			fpu_addr <= 0; // fpu組み込んだらそっちで初期化
			fpu_dd_val <= 0; //上に同じ
		end else begin
			case (ope)
         6'b110000: // LUI
           begin
             alu_addr <= dd;
             alu_dd_val <= {imm,ds_val[15:0]};
           end
         6'b001100: //ADD
           begin
             alu_addr <= dd;
             alu_dd_val <= add;
           end
         6'b001000: //ADDI
           begin
             alu_addr <= dd;
             alu_dd_val <= add;
           end
         6'b010100: //SUB
           begin
             alu_addr <= dd;
             alu_dd_val <= sub;
           end
				 6'b011100: // SLL
           begin
             alu_addr <= dd;
             alu_dd_val <= sll;
           end
         6'b011000: //SLLI
           begin
             alu_addr <= dd;
             alu_dd_val <= sll;
           end
         6'b100100: //SRL
           begin
             alu_addr <= dd;
             alu_dd_val <= srl;
           end
         6'b100000: //SRLI
           begin
             alu_addr <= dd;
             alu_dd_val <= srl;
           end
         6'b101100: //SRA
           begin
             alu_addr <= dd;
             alu_dd_val <= sra;
           end
         6'b101000: //SRAI
           begin
             alu_addr <= dd;
             alu_dd_val <= sra;
           end
				 6'b000010: //J
           begin
             alu_addr <= 0;
           end
         6'b000110: //JAL
           begin
             alu_addr <= 6'b011111;
             alu_dd_val <= pc_1;
           end
         6'b001010: //JR
           begin
             alu_addr <= 0;
           end
         6'b001110: //JALR
           begin
             alu_addr <= 6'b011111;
             alu_dd_val <= pc_1;
           end
         default:
           begin
             alu_addr <= 0;
           end
       endcase
		end
	end

endmodule
