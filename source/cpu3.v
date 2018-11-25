module cpu3(
	input wire clk,
	input wire rstn,
	output reg [7:0] err,
	//instr memory
	output wire [12:0] i_addr,
	input wire [63:0] i_rdata,
	output wire i_en,
	//data memory
	output wire [16:0] d_addr,
	output wire [31:0] d_wdata,
	input wire [31:0] d_rdata,
	output wire d_en,
	output wire d_we,
	//IO
	input wire [7:0] io_in_data,
	output wire io_in_rdy,
	input wire io_in_vld,

	output wire [7:0] io_out_data,
	input wire io_out_rdy,
	output wire io_out_vld,

	input wire [4:0] io_err
	);
	
	localparam st_begin =  3'b001;
	localparam st_normal = 3'b010;

	localparam mod_u1 =  3'b001;
	localparam mod_u2 =  3'b010;
	localparam mod_u3 =  3'b100;

	localparam mask = ~({31'b0,1'b1,31'b0,1'b1});

	reg [13:0] pc;
	reg [2:0] state;

	//register {fpr,gpr}
	reg [31:0] regfile [63:0];
	
	//instruction fetch
	reg [13:0] if_pc;
	wire if_is_en [1:0];
	//decode
	reg [13:0] de_pc;
	reg [31:0] de_tmp_instr [1:0];
	reg [13:0] de_tmp_pc;
	reg de_tmp_is_en [1:0];
	reg de_tmp_used;
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
	wire [2:0] de_mod [1:0];
	wire [6:0] de_latency [1:0];
	wire [72:0] de_data [1:0];
	//wait
	reg [72:0] wa_data [2:0];
	reg wa_is_en [2:0];
	wire [13:0] wa_pc [2:0];
	wire [5:0] wa_ope [2:0];
	wire [5:0] wa_ds [2:0];
	wire [5:0] wa_dt [2:0];
	wire [5:0] wa_dd [2:0];
	wire [15:0] wa_imm [2:0];
	wire [4:0] wa_opr [2:0];
	wire [3:0] wa_ctrl [2:0];
	wire [2:0] wa_mod [2:0];
	wire [6:0] wa_latency [2:0];
	wire [72:0] wa_std_board [2:0];
	wire [31:0] wa_ds_val [2:0];
	wire [31:0] wa_dt_val [2:0];
	wire wa_is_busy;
	reg wa_was_busy;
	wire wa_exist [2:0];
	wire [5:0] wa_sig0;
	wire [4:0] wa_sig1;
	wire [3:0] wa_sig2;
	//exec
		// unit1
	wire [2:0] u1_get;
	reg [13:0] u1_pc;
	reg [5:0] u1_ope;
	reg [31:0] u1_ds_val;
	reg [31:0] u1_dt_val;
	reg [5:0] u1_dd;
	reg [15:0] u1_imm;
	reg [4:0] u1_opr;
	reg [3:0] u1_ctrl;
	wire [6:0] u1_is_busy;
	wire b_is_hazard;
	wire [13:0] b_addr;
	wire [5:0] alu_reg_addr;
	wire [31:0] alu_dd_val;
	wire [5:0] fpu_reg_addr;
	wire [31:0] fpu_dd_val;
	unit1 u1(clk,rstn,u1_pc,u1_ope,u1_ds_val,u1_dt_val,u1_dd,u1_imm,u1_opr,u1_ctrl,
	            u1_is_busy,b_is_hazard,b_addr,alu_reg_addr,alu_dd_val,fpu_reg_addr,fpu_dd_val);
		
		// unit2
	wire [2:0] u2_get;
	reg [5:0] u2_ope;
	reg [31:0] u2_ds_val;
	reg [31:0] u2_dt_val;
	reg [5:0] u2_dd;
	reg [15:0] u2_imm;
	wire [6:0] u2_is_busy;
	wire [5:0] alu2_reg_addr;
	wire [31:0] alu2_dd_val;
	wire [5:0] mem_reg_addr;
	wire [31:0] mem_dd_val;
	wire [5:0] io_reg_addr;
	wire [31:0] io_dd_val;
	unit2 u2(clk,rstn,u2_ope,u2_ds_val,u2_dt_val,u2_dd,u2_imm,
	            u2_is_busy,alu2_reg_addr,alu2_dd_val,mem_reg_addr,mem_dd_val,io_reg_addr,io_dd_val,
							d_addr,d_wdata,d_rdata,d_en,d_we,
							io_in_data,io_in_rdy,io_in_vld,io_out_data,io_out_rdy,io_out_vld);

		// unit3 
	wire [2:0] u3_get;
	reg [31:0] u3_ds_val;
	reg [31:0] u3_dt_val;
	reg [5:0] u3_dd;
	reg [15:0] u3_imm;
	reg [3:0] u3_ctrl;
	wire [6:0] u3_is_busy;
	wire [5:0] fpu2_reg_addr;
	wire [31:0] fpu2_dd_val;
	unit3 u3(clk,rstn,u3_ds_val,u3_dt_val,u3_dd,u3_imm,u3_ctrl,u3_is_busy,fpu2_reg_addr,fpu2_dd_val);

	//write back
	reg [5:0] reg_addr [5:0];
	reg [31:0] reg_wdata [5:0];
	wire [31:0] reg_ds_data [2:0];
	wire [31:0] reg_dt_data [2:0];

	//board {fpr,gpr}
	reg [63:0] board;
	wire dep_ok [2:0];
	wire [2:0] issued;
	wire [63:0] dd_board [2:0];

	//instr mem
	assign i_addr = pc[13:1];
	assign i_en = 1'b1;

	//if
	assign if_is_en[0] = ~if_pc[0] && ~b_is_hazard && ~de_is_j[0] && ~de_is_j[1];
	assign if_is_en[1] = ~b_is_hazard && ~de_is_j[0] && ~de_is_j[1];

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
											de_instr[0][28:26] == 3'b100 || de_instr[0][31:26] == 6'b000111 ?{1'b0,de_instr[0][15:11]} :
										de_instr[0][31:26] == 6'b100111 || 
											(de_instr[0][28:26] == 3'b001 && de_instr[0][0]) ? {1'b1,de_instr[0][15:11]} : 0;
	assign de_dt[1] = de_instr[1][31:26] == 6'b010010 || de_instr[1][31:26] == 6'b011010 || 
											de_instr[1][28:26] == 3'b100 || de_instr[1][31:26] == 6'b000111 ?{1'b0,de_instr[1][15:11]} :
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
	assign de_ctrl[0] = de_instr[0][1:0] == 2'b01 ? de_instr[0][6:3] : 0; ///////  もう少し複雑
	assign de_ctrl[1] = de_instr[1][1:0] == 2'b01 ? de_instr[1][6:3] : 0; ////// FLUPの処理
	assign de_mod[0] = de_instr[0][28:26] == 3'b011 ? mod_u2 :
										 de_instr[0][28:26] == 3'b111 ? mod_u2 :
										 de_instr[0][27:26] == 2'b10 ? mod_u1 :
										 de_instr[0][27:26] == 2'b00 ? mod_u1 | mod_u2 :
										 de_instr[0][28:26] == 2'b01 ? mod_u1 | mod_u3 : 0;
	assign de_mod[1] = de_instr[1][28:26] == 3'b011 ? mod_u2 :
										 de_instr[1][28:26] == 3'b111 ? mod_u2 :
										 de_instr[1][27:26] == 2'b10 ? mod_u1 :
										 de_instr[1][27:26] == 2'b00 ? mod_u1 | mod_u2 :
										 de_instr[1][28:26] == 2'b01 ? mod_u1 | mod_u3 : 0;
	assign de_latency[0] = {6'b0,de_instr[0][2:0] == 3'b011 ? 1'b1 : 1'b0}; 
	assign de_latency[1] = {6'b0,de_instr[1][2:0] == 3'b011 ? 1'b1 : 1'b0}; 
	assign de_data[0] = {{de_pc[13:1],1'b0},de_ope[0],de_ds[0],de_dt[0],de_dd[0],de_imm[0],de_opr[0],de_ctrl[0],de_mod[0],de_latency[0]};
	assign de_data[1] =
			de_is_j[0] ? 0 : {{de_pc[13:1],1'b1},de_ope[1],de_ds[1],de_dt[1],de_dd[1],de_imm[1],de_opr[1],de_ctrl[1],de_mod[1],de_latency[1]};
	
		
	//wa
	assign wa_pc[0] = wa_data[0][72:59];
	assign wa_ope[0] = wa_data[0][58:53];
	assign wa_ds[0] = wa_data[0][52:47];
	assign wa_dt[0] = wa_data[0][46:41];
	assign wa_dd[0] = wa_data[0][40:35];
	assign wa_imm[0] = wa_data[0][34:19];
	assign wa_opr[0] = wa_data[0][18:14];
	assign wa_ctrl[0] = wa_data[0][13:10];
	assign wa_mod[0] = wa_data[0][9:7];
	assign wa_latency[0] = wa_data[0][6:0];
	assign wa_ds_val[0] = reg_ds_data[0];
	assign wa_dt_val[0] = reg_dt_data[0];

	assign wa_pc[1] = wa_data[1][72:59];
	assign wa_ope[1] = wa_data[1][58:53];
	assign wa_ds[1] = wa_data[1][52:47];
	assign wa_dt[1] = wa_data[1][46:41];
	assign wa_dd[1] = wa_data[1][40:35];
	assign wa_imm[1] = wa_data[1][34:19];
	assign wa_opr[1] = wa_data[1][18:14];
	assign wa_ctrl[1] = wa_data[1][13:10];
	assign wa_mod[1] = wa_data[1][9:7];
	assign wa_latency[1] = wa_data[1][6:0];
	assign wa_ds_val[1] = reg_ds_data[1];
	assign wa_dt_val[1] = reg_dt_data[1];

	assign wa_pc[2] = wa_data[2][72:59];
	assign wa_ope[2] = wa_data[2][58:53];
	assign wa_ds[2] = wa_data[2][52:47];
	assign wa_dt[2] = wa_data[2][46:41];
	assign wa_dd[2] = wa_data[2][40:35];
	assign wa_imm[2] = wa_data[2][34:19];
	assign wa_opr[2] = wa_data[2][18:14];
	assign wa_ctrl[2] = wa_data[2][13:10];
	assign wa_mod[2] = wa_data[2][9:7];
	assign wa_latency[2] = wa_data[2][6:0];
	assign wa_ds_val[2] = reg_ds_data[2];
	assign wa_dt_val[2] = reg_dt_data[2];

	assign wa_std_board[0] = (1 << wa_ds[0]) & (1 << wa_dt[0]) & dd_board[0] & mask;
	assign wa_std_board[1] = (1 << wa_ds[1]) & (1 << wa_dt[1]) & dd_board[1] & mask;
	assign wa_std_board[2] = (1 << wa_ds[2]) & (1 << wa_dt[2]) & dd_board[2] & mask;
	// 2個以上残るときはbusy
	assign wa_is_busy = (wa_exist[0] && wa_exist[1]) || (wa_exist[1] && wa_exist[2]) || (wa_exist[2] && wa_exist[0]);

	assign wa_exist[0] = wa_is_en[0] && ~issued[0];
	assign wa_exist[1] = wa_is_en[1] && ~issued[1];
	assign wa_exist[2] = wa_is_en[2] && ~issued[2];

  assign wa_sig0 = 
			b_is_hazard ? 6'b000001 :
			wa_exist[0] ? 6'b100000 :
			wa_exist[1] ? 6'b010000 :
			wa_exist[2] ? 6'b001000 :
			de_is_en[0] ? 6'b000100 :
			de_is_en[1] ? 6'b000010 : 6'b000001;

	assign wa_sig1 = 
			b_is_hazard ? 5'b00001 :
			wa_exist[0] && wa_exist[1] ? 5'b10000 :
			(wa_exist[0] ^ wa_exist[1]) &&  wa_exist[2] ? 5'b01000 :
			(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && de_is_en[0] ? 5'b00100 :
			~wa_exist[0] && ~wa_exist[1] && wa_exist[2] &&  de_is_en[0] ? 5'b00100 :
			(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && ~de_is_en[0] && de_is_en[1] ? 5'b00010 :
			~wa_exist[0] && ~wa_exist[1] && (wa_exist[2] ^ de_is_en[0]) && de_is_en[1] ? 5'b00010 : 5'b00001;

	assign wa_sig2 = 
			b_is_hazard ? 4'b0001 :
			wa_exist[0] && wa_exist[1] && wa_exist[2] ? 4'b1000 :
			wa_is_busy ? 0 : // de_data[0]が来ることはない
			(wa_exist[0] ^ wa_exist[1]) && de_is_en[0] && de_is_en[1] ? 4'b0010 :
			~wa_exist[0] && ~wa_exist[1] && wa_exist[2] && de_is_en[0] && de_is_en[1] ? 4'b0010 : 4'b0001;


	// fowarding は遅くなるのでしない
	assign reg_ds_data[0] = 
			wa_ds[0][4:0] == 0 ? 0 : 
			regfile[wa_ds[0]];
	assign reg_dt_data[0] = 
			wa_dt[0][4:0] == 0 ? 0 : 
			regfile[wa_dt[0]];

	assign reg_ds_data[1] = 
			wa_ds[1][4:0] == 0 ? 0 : 
			regfile[wa_ds[1]];
	assign reg_dt_data[1] = 
			wa_dt[1][4:0] == 0 ? 0 : 
			regfile[wa_dt[1]];


	assign reg_ds_data[2] = 
			wa_ds[2][4:0] == 0 ? 0 : 
			regfile[wa_ds[2]];
	assign reg_dt_data[2] = 
			wa_dt[2][4:0] == 0 ? 0 : 
			regfile[wa_dt[2]];

	//exec
	assign dep_ok[0] = (board & wa_std_board[0] & mask) == 0;
	assign dep_ok[1] =
			((board | dd_board[0]) & wa_std_board[1] & mask) == 0 &&
			(wa_std_board[0] & dd_board[1] & mask) == 0; // 先に書き込むの防止
	assign dep_ok[2] =
			((board | dd_board[0] | dd_board[1]) & wa_std_board[2] & mask) == 0 &&
			((wa_std_board[0] | wa_std_board[1]) & dd_board[2] & mask) == 0;
	assign u1_get =
			b_is_hazard ? 3'b000 :
			dep_ok[0] && wa_mod[0][0] && (wa_latency[0] & u1_is_busy) == 0 &&
					(wa_ope[0][1:0] != 2'b01) ? 3'b001 :
			(wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			dep_ok[1] && wa_mod[1][0] && (wa_latency[1] & u1_is_busy) == 0 && 
					!(wa_ope[0][1:0] != 2'b01 && wa_ope[1][1:0] == 2'b01)  ? 3'b010 :
			(wa_ope[1][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			dep_ok[2] && wa_mod[2][0] && (wa_latency[2] & u1_is_busy) == 0 && 
					!(wa_ope[0][1:0] != 2'b01 && wa_ope[1][1:0] != 2'b01 && wa_ope[2][1:0] == 2'b01) ? 3'b100 :
			3'b000;

	assign u2_get = 
			b_is_hazard ? 3'b000 : 
			dep_ok[0] && wa_mod[0][1] && (wa_latency[0] & u2_is_busy) == 0 && 
					(wa_ope[0][1:0] != 2'b00) ? 3'b001 :
			(wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0) || wa_mod[0] == mod_u2 ? 3'b000 :
			dep_ok[1] && wa_mod[1][1] && (wa_latency[1] & u2_is_busy) == 0 && 
					!(wa_ope[0][1:0] == 2'b01 && wa_ope[1][1:0] == 2'b00) ? 3'b010 :
			(wa_ope[1][1:0] == 2'b10 && wa_ope[0][5:3] != 0) || wa_mod[1] == mod_u2 ? 3'b000 :
			dep_ok[2] && wa_mod[2][1] && (wa_latency[2] & u2_is_busy) == 0 ? 3'b100 :
			3'b000;

	assign u3_get = 
			b_is_hazard ? 3'b000 : 
			dep_ok[0] && wa_mod[0][2] && (wa_latency[0] & u3_is_busy) == 0 ? 3'b001 :
			(wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			dep_ok[1] && wa_mod[1][2] && (wa_latency[1] & u3_is_busy) == 0 ? 3'b010 :
			(wa_ope[1][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			dep_ok[2] && wa_mod[2][2] && (wa_latency[2] & u3_is_busy) == 0 ? 3'b100 : 3'b000;

	assign issued = u3_get | u2_get | u1_get;
	assign dd_board[0] = 1 << wa_dd[0];
	assign dd_board[1] = 1 << wa_dd[1];
	assign dd_board[2] = 1 << wa_dd[2];

	integer i1,i2;

	always @(posedge clk) begin
		if (~rstn) begin
			pc <= 0;
			state <= st_begin;
			if_pc <= 0;
			de_pc <= 0;
			de_tmp_used <= 0;
			de_tmp_pc <= 0;
			for(i1=0;i1 < 2; i1=i1+1) begin
				de_instr[i1] <= 0;
				de_is_en[i1] <= 0;
				de_tmp_instr[i1] <= 0;
				de_tmp_is_en[i1] <= 0;
			end
			for(i2=0;i2 < 3; i2=i2+1) begin
				wa_data[i2] <= 0;
				wa_is_en[i2] <= 0;
			end
			wa_was_busy <= 0;
			board <= 0;

			u1_ope <= 0;
			u1_pc <= 0;
			u1_ds_val <= 0;
			u1_dt_val <= 0;
			u1_dd <= 0;
			u1_imm <= 0;
			u1_opr <= 0;
			u1_ctrl <= 0;
			u2_ope <= 0;
			u2_ds_val <= 0;
			u2_dt_val <= 0;
			u2_dd <= 0;
			u2_imm <= 0;
			u3_ds_val <= 0;
			u3_dt_val <= 0;
			u3_dd <= 0;
			u3_imm <= 0;
			u3_ctrl <= 0;
		end else if(state == st_begin) begin
			pc <= 2;
			state <= st_normal;
		end else if(state == st_normal) begin
			pc <= b_is_hazard ? b_addr :
						de_is_j[0] ? de_imm[0][13:0] :
						de_is_j[1] ? de_imm[1][13:0] :
						wa_is_busy ? pc :
						{pc[13:1]+1,1'b0};


			// instruction fetch
			if_pc <= pc;
			//decode
			de_tmp_pc <= wa_is_busy && ~wa_was_busy ? if_pc : de_tmp_pc;
			de_tmp_instr[0] <= wa_is_busy && ~wa_was_busy ? i_rdata[63:32] : de_tmp_instr[0];
			de_tmp_instr[1] <= wa_is_busy && ~wa_was_busy ? i_rdata[31:0] : de_tmp_instr[1];
			de_tmp_is_en[0] <= b_is_hazard || de_is_j[0] || de_is_j[1] ? 0 :
												 wa_is_busy && ~wa_was_busy ? if_is_en[0] : de_tmp_is_en[0];
			de_tmp_is_en[1] <= b_is_hazard || de_is_j[0] || de_is_j[1] ? 0 :
												 wa_is_busy && ~wa_was_busy ? if_is_en[0] : de_tmp_is_en[1];
			de_tmp_used <= wa_is_busy;

			de_pc <= wa_is_busy ? de_pc :
							 de_tmp_used ? de_tmp_pc : if_pc;
			de_instr[0] <= 
					wa_is_busy ? de_instr[0] :
					de_tmp_used ? de_tmp_instr[0] : i_rdata[63:32];
			de_instr[1] <= 
					wa_is_busy ? de_instr[1] :
					de_tmp_used ? de_tmp_instr[1] : i_rdata[31:0];
			// enなのはifステージでenかつ制御ハザードが起きない
			de_is_en[0] <= 
					b_is_hazard ? 0 :
					wa_is_busy ? de_is_en[0] :
					de_is_j[0] || de_is_j[1] ? 0 :
					de_tmp_used ? de_tmp_is_en[0] : if_is_en[0];
			de_is_en[1] <= 
					b_is_hazard ? 0 :
					wa_is_busy ? de_is_en[1] :
					de_is_j[0] || de_is_j[1] ? 0 :
					de_tmp_used ? (de_tmp_is_en[1] &&
							!(de_tmp_instr[0][31:30] == 2'b00 && de_tmp_instr[0][27:26] == 2'b10)) :
					if_is_en[1] && !(i_rdata[63:62] == 2'b00 && i_rdata[59:58] == 2'b10);
			//wait
			wa_was_busy <= wa_is_busy;

			(* parallel_case *)
			casex (wa_sig0)
				6'b1xxxxx : wa_data[0] <= wa_data[0];
				6'bx1xxxx : wa_data[0] <= wa_data[1];
				6'bxx1xxx : wa_data[0] <= wa_data[2];
				6'bxxx1xx : wa_data[0] <= de_data[0];
				6'bxxxx1x : wa_data[0] <= de_data[1];
				6'bxxxxx1 : wa_data[0] <= 0;
			endcase
			(* parallel_case *)
			casex (wa_sig0)
				6'b1xxxxx : wa_is_en[0] <= wa_is_en[0];
				6'bx1xxxx : wa_is_en[0] <= wa_is_en[1];
				6'bxx1xxx : wa_is_en[0] <= wa_is_en[2];
				6'bxxx1xx : wa_is_en[0] <= de_is_en[0];
				6'bxxxx1x : wa_is_en[0] <= de_is_en[1];
				6'bxxxxx1 : wa_is_en[0] <= 0;
			endcase

			(* parallel_case *)
			casex (wa_sig1)
				5'b1xxxx : wa_data[1] <= wa_data[1];
				5'bx1xxx : wa_data[1] <= wa_data[2];
				5'bxx1xx : wa_data[1] <= de_data[0];
				5'bxxx1x : wa_data[1] <= de_data[1];
				5'bxxxx1 : wa_data[1] <= 0;
			endcase
			(* parallel_case *)
			casex (wa_sig1)
				5'b1xxxx : wa_is_en[1] <= wa_is_en[1];
				5'bx1xxx : wa_is_en[1] <= wa_is_en[2];
				5'bxx1xx : wa_is_en[1] <= de_is_en[0];
				5'bxxx1x : wa_is_en[1] <= de_is_en[1];
				5'bxxxx1 : wa_is_en[1] <= 0;
			endcase
			
			(* parallel_case *)
			casex (wa_sig2)
				4'b1xxx : wa_data[2] <= wa_data[2];
				4'bx1xx : wa_data[2] <= de_data[0];
				4'bxx1x : wa_data[2] <= de_data[1];
				4'bxxx1 : wa_data[2] <= 0;
			endcase
			(* parallel_case *)
			casex (wa_sig2)
				4'b1xxx : wa_is_en[2] <= wa_is_en[2];
				4'bx1xx : wa_is_en[2] <= de_is_en[0];
				4'bxx1x : wa_is_en[2] <= de_is_en[1];
				4'bxxx1 : wa_is_en[2] <= 0;
			endcase

			//exec
			//u1
			if (u1_get[0]) begin
				u1_ope <= wa_ope[0];
				u1_pc <= wa_pc[0];
				u1_ds_val <= wa_ds_val[0];
				u1_dt_val <= wa_dt_val[0];
				u1_dd <= wa_dd[0];
				u1_imm <= wa_imm[0];
				u1_opr <= wa_opr[0];
				u1_ctrl <= wa_ctrl[0];
			end else if (u1_get[1]) begin
				u1_ope <= wa_ope[1];
				u1_pc <= wa_pc[1];
				u1_ds_val <= wa_ds_val[1];
				u1_dt_val <= wa_dt_val[1];
				u1_dd <= wa_dd[1];
				u1_imm <= wa_imm[1];
				u1_opr <= wa_opr[1];
				u1_ctrl <= wa_ctrl[1];
			end else if(u1_get[2]) begin
				u1_ope <= wa_ope[2];
				u1_pc <= wa_pc[2];
				u1_ds_val <= wa_ds_val[2];
				u1_dt_val <= wa_dt_val[2];
				u1_dd <= wa_dd[2];
				u1_imm <= wa_imm[2];
				u1_opr <= wa_opr[2];
				u1_ctrl <= wa_ctrl[2];
			end else begin
				u1_ope <= 0;
				u1_ctrl <= 0;
			end
			
			//u2
			if (u2_get[0]) begin
				u2_ope <= wa_ope[0];
				u2_ds_val <= wa_ds_val[0];
				u2_dt_val <= wa_dt_val[0];
				u2_dd <= wa_dd[0];
				u2_imm <= wa_imm[0];
			end else if (u2_get[1]) begin
				u2_ope <= wa_ope[1];
				u2_ds_val <= wa_ds_val[1];
				u2_dt_val <= wa_dt_val[1];
				u2_dd <= wa_dd[1];
				u2_imm <= wa_imm[1];
			end else if (u2_get[2]) begin
				u2_ope <= wa_ope[2];
				u2_ds_val <= wa_ds_val[2];
				u2_dt_val <= wa_dt_val[2];
				u2_dd <= wa_dd[2];
				u2_imm <= wa_imm[2];
			end else begin
				u2_ope <= 0;
			end

			//u3
			if (u3_get[0]) begin
				u3_ds_val <= wa_ds_val[0];
				u3_dt_val <= wa_dt_val[0];
				u3_dd <= wa_dd[0];
				u3_imm <= wa_imm[0];
				u3_ctrl <= wa_ctrl[0];
			end else if (u3_get[1]) begin
				u3_ds_val <= wa_ds_val[1];
				u3_dt_val <= wa_dt_val[1];
				u3_dd <= wa_dd[1];
				u3_imm <= wa_imm[1];
				u3_ctrl <= wa_ctrl[1];
			end else if (u3_get[2]) begin
				u3_ds_val <= wa_ds_val[2];
				u3_dt_val <= wa_dt_val[2];
				u3_dd <= wa_dd[2];
				u3_imm <= wa_imm[2];
				u3_ctrl <= wa_ctrl[2];
			end else begin
				u3_ctrl <= 0;
			end

			//write back
	//  クロック上がるかも？　forwardingかboard更新回りなおすかする必要あり
			reg_addr[0] <= alu_reg_addr;
			reg_addr[1] <= alu2_reg_addr;
			reg_addr[2] <= io_reg_addr;
			reg_addr[3] <= mem_reg_addr;
			reg_addr[4] <= fpu_reg_addr;
			reg_addr[5] <= fpu2_reg_addr;
			reg_wdata[0] <= alu_dd_val;
			reg_wdata[1] <= alu2_dd_val;
			reg_wdata[2] <= io_dd_val;
			reg_wdata[3] <= mem_dd_val;
			reg_wdata[4] <= fpu_dd_val;
			reg_wdata[5] <= fpu2_dd_val;
			regfile[reg_addr[0]] <= reg_wdata[0];
			regfile[reg_addr[1]] <= reg_wdata[1];
			regfile[reg_addr[2]] <= reg_wdata[2];
			regfile[reg_addr[3]] <= reg_wdata[3];
			regfile[reg_addr[4]] <= reg_wdata[4];
			regfile[reg_addr[5]] <= reg_wdata[5];

			regfile[alu_reg_addr] <= alu_dd_val;
			regfile[alu2_reg_addr] <= alu2_dd_val;
			regfile[io_reg_addr] <= io_dd_val;
			regfile[mem_reg_addr] <= mem_dd_val;
			regfile[fpu_reg_addr] <= fpu_dd_val;
			regfile[fpu2_reg_addr] <= fpu2_dd_val;

			board <= (board & ~(1 << reg_addr[0]) & ~(1 << reg_addr[1]) & ~(1 << reg_addr[2]) & 
									~(1 << reg_addr[3]) & ~(1 << reg_addr[4]) & ~(1 << reg_addr[5])) |
								(issued[0] ? dd_board[0] : 0) | (issued[1] ? dd_board[1] : 0) | 
								(issued[2] ? dd_board[2] : 0);
/*
			board <= (board & ~(1 << alu_reg_addr) & ~(1 << alu2_reg_addr) & ~(1 << io_reg_addr) & 
									~(1 << mem_reg_addr) & ~(1 << fpu_reg_addr) & ~(1 << fpu2_reg_addr)) |
								(issued[0] ? dd_board[0] : 0) | (issued[1] ? dd_board[1] : 0) | 
								(issued[2] ? dd_board[2] : 0);
*/
		end
	end

endmodule

