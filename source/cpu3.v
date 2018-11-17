module cpu3(
	input wire clk,
	input wire rstn,
	output reg [7:0] err,
	//instr memory
	output wire [15:0] i_addr,
	input wire [63:0] i_rdata,
	output wire i_en,
	//data memory
	output wire [21:0] d_addr,
	output wire [31:0] d_wdata,
	input wire [31:0] d_rdata,
	output wire d_en,
	output wire [3:0] d_we,
	//IO
	input wire [7:0] io_in_data,
	output wire io_in_rdy,
	input wire io_in_vld,

	output wire [7:0] io_out_data,
	input wire io_out_rdy,
	output wire io_out_vld,

	input wire [4:0] io_err,
	);
	
	localparam st_begin =  3'b001;
	localparam st_normal = 3'b010;

	localparam mod_b =   9'b000000001;
	localparam mod_io =  9'b000000010;
	localparam mod_mem = 9'b000000100;
	localparam mod_alu = 9'b000001000;
	localparam mod_mv =  9'b000010000;
	localparam mod_fab = 9'b000100000;
	localparam mod_fml = 9'b001000000;
	localparam mod_fds = 9'b010000000;
	localparam mod_fet = 9'b100000000;

	reg [13:0] pc;
	reg [2:0] state;
	
	//instruction fetch
	reg [13:0] if_pc;
	wire if_is_en [1:0];
	//decode
	reg [13:0] de_pc;
	reg [31:0] de_instr [1:0];
	reg de_is_en [1:0];
	wire de_is_j [1:0];
	wire de_is_b [1:0];
	wire [5:0] de_ope [1:0];
	wire [5:0] de_ds [1:0];
	wire [5:0] de_dt [1:0];
	wire [5:0] de_dd [1:0];
	wire [15:0] de_imm [1:0];
	wire [4:0] de_opr [1:0];
	wire [3:0] de_ctrl [1:0];
	wire [9:0] de_mod [1:0]
	//wait
	reg [5:0] wa_ope [3:0];
	reg [5:0] wa_ds [3:0];
	reg [5:0] wa_dt [3:0];
	reg [5:0] wa_dd [3:0];
	reg [15:0] wa_imm [3:0];
	reg [4:0] wa_opr [3:0];
	reg [3:0] wa_ctrl [3:0];
	reg [9:0] wa_mod [3:0];
	wire [63:0] wa_st_board [3:0];
	wire wa_is_busy;

	//branch prediction
	wire bp_is_branch;
	wire bp_is_b_op;
	wire bp_is_taken;
	// module bp2

	//board {fpr,gpr}
	reg [63:0] board;

	//hazard
	wire b_is_hazard;

	//instr mem
	assign i_addr = {pc[13:1],3'b000};
	assign i_en = 1'b1;

	//if
	assign if_is_en[0] = if_pc[0] == 0 && ~b_is_hazard && ~bp_is_taken;
	assign if_is_en[1] = ~b_is_hazard && ~bp_is_taken;

	//de
	assign de_is_j[0] = de_is_en[0] && de_instr[0][31:30] == 2'b00 && de_instr[0][27:26] == 2'b10;
	assign de_is_j[1] = de_is_en[1] && de_instr[1][31:30] == 2'b00 && de_instr[1][27:26] == 2'b10;
	assign de_is_b[0] = de_is_en[0] && de_instr[0][31:30] > 2'b00 && de_instr[0][27:26] == 2'b10;
	assign de_is_b[1] = de_is_en[1] && de_instr[1][31:30] > 2'b00 && de_instr[1][27:26] == 2'b10;
	assign de_ope[0] = de_instr[0][31:26];
	assign de_ope[1] = de_instr[1][31:26];
	assign de_ds[0] = de_instr[0][28:26] == 3'b001 && ~de_instr[0][1] ? 
											{1'b1,de_instr[0][20:16]} : {1'b0,de_instr[0][20:16]};
	assign de_ds[1] = de_instr[1][28:26] == 3'b001 && ~de_instr[1][1] ? 
											{1'b1,de_instr[1][20:16]} : {1'b0,de_instr[1][20:16]};
	assign de_dt[0] = de_instr[0][31:26] == 6'b010010 || de_instr[0][31:26] == 6'b011010 || 
											de_instr[0][28:26] == 3'b100 || de_instr[0][31:26] == 6'b000111 ?{1'b0,de_instr[0][15:11] :
										de_instr[0][31:26] == 6'b100111 || 
											(de_instr[0][28:26] == 3'b001 && de_instr[0][0]) ? {1'b1,de_instr[0][15:11]} : 0;
	assign de_dt[1] = de_instr[1][31:26] == 6'b010010 || de_instr[1][31:26] == 6'b011010 || 
											de_instr[1][28:26] == 3'b100 || de_instr[1][31:26] == 6'b000111 ?{1'b0,de_instr[1][15:11] :
										de_instr[1][31:26] == 6'b100111 || 
											(de_instr[1][28:26] == 3'b001 && de_instr[1][0]) ? {1'b1,de_instr[1][15:11]} : 0;
	assign de_dd[0] = de_instr[0][28:26] == 3'b110 ? 6'b011111 : // JR, JALR
										de_instr[0][27:26] == 2'b00 || de_instr[0][31:26] == 6'b001111 ||
										 	de_instr[0][31:26] == 6'b001011 ||
										  (de_instr[0][28:26] == 3'b001 && de_instr[0][2]) ? {1'b0,de_instr[0][25:21]} :
										de_instr[0][31:26] == 6'b101111 || de_instr[0][28:26] == 3'b101 ||
											(de_instr[0][28:26] == 3'b001 && ~de_instr[0][2]) ? {1'b1,de_instr[0][25:21]} : 0;
	assign de_dd[1] = de_instr[1][28:26] == 3'b110 ? 6'b011111 : // JR, JALR
										de_instr[1][27:26] == 2'b00 || de_instr[1][31:26] == 6'b001111 ||
										 	de_instr[1][31:26] == 6'b001011 ||
										  (de_instr[1][28:26] == 3'b001 && de_instr[1][2]) ? {1'b0,de_instr[1][25:21]} :
										de_instr[1][31:26] == 6'b101111 || de_instr[1][28:26] == 3'b101 ||
											(de_instr[1][28:26] == 3'b001 && ~de_instr[1][2]) ? {1'b1,de_instr[1][25:21]} : 0;
	assign de_imm[0] = de_ope[0] == 6'b010010 || de_ope[0] == 6'b011010 || de_instr[0][29:26] == 4'b0111 ?
											{de_instr[0][25:21],de_instr[0][10:0]} : de_instr[0][15:0];
	assign de_imm[1] = de_ope[1] == 6'b010010 || de_ope[1] == 6'b011010 || de_instr[1][29:26] == 4'b0111 ?
											{de_instr[1][25:21],de_instr[1][10:0]} : de_instr[1][15:0];
	assign de_opr[0] = de_instr[0][25:21];
	assign de_opr[1] = de_instr[1][25:21];
	assign de_ctrl[0] = de_instr[0][6:3];
	assign de_ctrl[1] = de_instr[1][6:3];
	assign de_mod[0] = //////////////
	assign de_mod[1] = //////////////
	
		
	//wa
	assign wa_st_board[0] <= (1 << wa_ds[0]) & (1 << wa_dt[0]);
	assign wa_st_board[1] <= (1 << wa_ds[1]) & (1 << wa_dt[1]);
	assign wa_st_board[2] <= (1 << wa_ds[2]) & (1 << wa_dt[2]);
	assign wa_st_board[3] <= (1 << wa_ds[3]) & (1 << wa_dt[3]);
	assign wa_is_busy = //////////////////

	integer i1,i2;

	always @(posedge clk) begin
		if (~rstn) begin
			pc <= 0;
			state <= st_begin;
			if_pc <= 0;
			de_pc <= 0;
			for(i1=0;i1 < 2; i1=i1+1) begin
				de_instr[i1] <= 0;
				de_is_en[i1] <= 0;
			end
			for(i2=0;i2 < 4; i2=i2+1) begin
				wa_ope[i2] <= 0;
				wa_ds[i2] <= 0;
				wa_dt[i2] <= 0;
				wa_dd[i2] <= 0;
				wa_imm[i2] <= 0;
				wa_opr[i2] <= 0;
				wa_ctrl[i2] <= 0;
				wa_mod[i2] <= 0;
			end
			board <= 0;
		end else if(state == st_begin) begin
			pc <= 1;
			state <= st_normal;
		end else if(state == st_normal) begin
			pc <= //////////////
			// instruction fetch
			if_pc <= pc;
			//decode
			de_pc <= if_pc;
			de_instr[0] <= wa_is_busy ? de_instr[0] : i_rdata[63:32];
			de_instr[1] <= wa_is_busy ? de_instr[1] : i_rdata[31:0];
			// enなのはifステージでenかつ制御ハザードが起きず、前の命令の分岐予測がnot taken
			de_is_en[0] <= wa_is_busy ? de_is_en[0] : if_is_en[0] & ~b_is_hazard & ~bp_is_taken;
			de_is_en[1] <= wa_is_busy ? de_is_en[1] : if_is_en[1] & ~b_is_hazard & ~bp_is_taken;
			//wait
			
			board <= //////////
		end
	end

endmodule

