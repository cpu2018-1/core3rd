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

	localparam mod_io =   6'b000001;
	localparam mod_mem =  6'b000010;
	localparam mod_alu =  6'b000100;
	localparam mod_alu2 = 6'b001000;
	localparam mod_fpu =  6'b010000;
	localparam mod_fpu2 = 6'b100000;

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
	wire [5:0] de_mod [1:0];
	wire [68:0] de_data [1:0];
	//wait
	reg [68:0] wa_data [2:0];
	reg wa_is_en [2:0];
	wire [13:0] wa_pc [2:0];
	wire [5:0] wa_ope [2:0];
	wire [5:0] wa_ds [2:0];
	wire [5:0] wa_dt [2:0];
	wire [5:0] wa_dd [2:0];
	wire [15:0] wa_imm [2:0];
	wire [4:0] wa_opr [2:0];
	wire [3:0] wa_ctrl [2:0];
	wire [5:0] wa_mod [2:0];
	wire [63:0] wa_std_board [2:0];
	wire [31:0] wa_ds_val [2:0];
	wire [31:0] wa_dt_val [2:0];
	wire wa_is_busy;
	reg wa_was_busy;
	wire wa_exist [2:0];
	//exec
		// io
	wire [2:0] io_get;
	reg [5:0] io_ope;
	reg [31:0] io_ds_val;
	reg [5:0] io_dd;
	wire [5:0] io_reg_addr;
	wire [31:0] io_dd_val;
	wire io_busy;
	io uio(clk,rstn,io_ope,io_ds_val,io_dd,io_reg_addr,io_dd_val,io_busy,
			io_in_data,io_in_rdy,io_in_vld,io_out_data,io_out_rdy,io_out_vld);
		//mem
	wire [2:0] mem_get;
	reg [5:0] mem_ope;
	reg [31:0] mem_ds_val;
	reg [31:0] mem_dt_val;
	reg [5:0] mem_dd;
	reg [15:0] mem_imm;
	wire [5:0] mem_reg_addr;
	wire [31:0] mem_dd_val;
	mem umem(clk,rstn,mem_ope,mem_ds_val,mem_dt_val,mem_dd,mem_imm,mem_reg_addr,mem_dd_val,
			d_addr,d_wdata,d_rdata,d_en,d_we);
		//alu(+j/b)
	wire [2:0] alu_get;
	reg [5:0] alu_ope;
	reg [13:0] alu_pc;
	reg [31:0] alu_ds_val;
	reg [31:0] alu_dt_val;
	reg [5:0] alu_dd;
	reg [15:0] alu_imm;
	reg [4:0] alu_opr;
	wire b_is_hazard;
	wire [13:0] b_addr;
	wire [5:0] alu_reg_addr;
	wire [31:0] alu_dd_val;
	alu ualu(clk,rstn,alu_ope,alu_pc,alu_ds_val,alu_dt_val,alu_dd,alu_imm,alu_opr,
			b_is_hazard,b_addr,alu_reg_addr,alu_dd_val);
		//alu2
	wire [2:0] alu2_get;
	reg [5:0] alu2_ope;
	reg [31:0] alu2_ds_val;
	reg [31:0] alu2_dt_val;
	reg [5:0] alu2_dd;
	reg [15:0] alu2_imm;
	wire [5:0] alu2_reg_addr;
	wire [31:0] alu2_dd_val;
	alu2 ualu2(clk,rstn,alu2_ope,alu2_ds_val,alu2_dt_val,alu2_dd,alu2_imm,alu2_reg_addr,alu2_dd_val);
		//fpu
	wire [2:0] fpu_get;
	reg [5:0] fpu_ope;
	reg [31:0] fpu_ds_val;
	reg [31:0] fpu_dt_val;
	reg [5:0] fpu_dd;
	reg [15:0] fpu_imm;
	reg [3:0] fpu_ctrl;
	wire [5:0] fpu_reg_addr;
	wire [31:0] fpu_dd_val;

	assign fpu_reg_addr = 0; //////
	assign fpu_dd_val = 0; /////////

		//fpu2
	wire [2:0] fpu2_get;
	reg [5:0] fpu2_ope;
	reg [31:0] fpu2_ds_val;
	reg [31:0] fpu2_dt_val;
	reg [5:0] fpu2_dd;
	reg [15:0] fpu2_imm;
	reg [3:0] fpu2_ctrl;
	wire [5:0] fpu2_reg_addr;
	wire [31:0] fpu2_dd_val;

	assign fpu2_reg_addr = 0; //////
	assign fpu2_dd_val = 0; //////

	//board {fpr,gpr}
	reg [63:0] board;
	wire [63:0] board0;
	wire [63:0] board1;
	wire [63:0] board2;
	wire [2:0] issued;
	wire [63:0] dd_board [2:0];

	//instr mem
	assign i_addr = pc[13:1];
	assign i_en = 1'b1;

	//if
	assign if_is_en[0] = ~if_pc[0] && ~b_is_hazard;
	assign if_is_en[1] = ~b_is_hazard;

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
	assign de_ctrl[0] = de_instr[0][6:3];
	assign de_ctrl[1] = de_instr[1][6:3];
	assign de_mod[0] = de_instr[0][28:26] == 3'b011 ? mod_io :
										 de_instr[0][28:26] == 3'b111 ? mod_mem :
										 de_instr[0][27:26] == 2'b10 ? mod_alu :
										 de_instr[0][27:26] == 2'b00 ? mod_alu | mod_alu2 :
										 de_instr[0][28:26] == 2'b01 ? mod_fpu | mod_fpu2 : 0;
	assign de_mod[1] = de_instr[1][28:26] == 3'b011 ? mod_io :
										 de_instr[1][28:26] == 3'b111 ? mod_mem :
										 de_instr[1][27:26] == 2'b10 ? mod_alu :
										 de_instr[1][27:26] == 2'b00 ? mod_alu | mod_alu2 :
										 de_instr[1][28:26] == 2'b01 ? mod_fpu | mod_fpu2 : 0;
	assign de_data[0] = {{de_pc[13:1],1'b0},de_ope[0],de_ds[0],de_dt[0],de_dd[0],de_imm[0],de_opr[0],de_ctrl[0],de_mod[0]};
	assign de_data[1] = {{de_pc[13:1],1'b1},de_ope[1],de_ds[1],de_dt[1],de_dd[1],de_imm[1],de_opr[1],de_ctrl[1],de_mod[1]};
	
		
	//wa
	assign wa_pc[0] = wa_data[0][68:55];
	assign wa_ope[0] = wa_data[0][54:49];
	assign wa_ds[0] = wa_data[0][48:43];
	assign wa_dt[0] = wa_data[0][42:37];
	assign wa_dd[0] = wa_data[0][36:31];
	assign wa_imm[0] = wa_data[0][30:15];
	assign wa_opr[0] = wa_data[0][14:10];
	assign wa_ctrl[0] = wa_data[0][9:6];
	assign wa_mod[0] = wa_data[0][5:0];
	assign wa_ds_val[0] = wa_ds[0][4:0] == 0 ? 0 : regfile[wa_ds[0]];
	assign wa_dt_val[0] = wa_dt[0][4:0] == 0 ? 0 : regfile[wa_dt[0]];
	assign wa_pc[1] = wa_data[1][68:55];
	assign wa_ope[1] = wa_data[1][54:49];
	assign wa_ds[1] = wa_data[1][48:43];
	assign wa_dt[1] = wa_data[1][42:37];
	assign wa_dd[1] = wa_data[1][36:31];
	assign wa_imm[1] = wa_data[1][30:15];
	assign wa_opr[1] = wa_data[1][14:10];
	assign wa_ctrl[1] = wa_data[1][9:6];
	assign wa_mod[1] = wa_data[1][5:0];
	assign wa_ds_val[1] = wa_ds[1][4:0] == 0 ? 0 : regfile[wa_ds[1]];
	assign wa_dt_val[1] = wa_dt[1][4:0] == 0 ? 0 : regfile[wa_dt[1]];
	assign wa_pc[2] = wa_data[2][68:55];
	assign wa_ope[2] = wa_data[2][54:49];
	assign wa_ds[2] = wa_data[2][48:43];
	assign wa_dt[2] = wa_data[2][42:37];
	assign wa_dd[2] = wa_data[2][36:31];
	assign wa_imm[2] = wa_data[2][30:15];
	assign wa_opr[2] = wa_data[2][14:10];
	assign wa_ctrl[2] = wa_data[2][9:6];
	assign wa_mod[2] = wa_data[2][5:0];
	assign wa_ds_val[2] = wa_ds[2][4:0] == 0 ? 0 : regfile[wa_ds[2]];
	assign wa_dt_val[2] = wa_dt[2][4:0] == 0 ? 0 : regfile[wa_dt[2]];

	assign wa_std_board[0] = (1 << wa_ds[0]) & (1 << wa_dt[0]) & dd_board[0] & mask;
	assign wa_std_board[1] = (1 << wa_ds[1]) & (1 << wa_dt[1]) & dd_board[1] & mask;
	assign wa_std_board[2] = (1 << wa_ds[2]) & (1 << wa_dt[2]) & dd_board[2] & mask;
	// 2個以上残るときはbusy
	assign wa_is_busy = (wa_exist[0] && wa_exist[1]) || (wa_exist[1] && wa_exist[2]) || (wa_exist[2] && wa_exist[0]);

	assign wa_exist[0] = wa_is_en[0] && ~issued[0];
	assign wa_exist[1] = wa_is_en[1] && ~issued[1];
	assign wa_exist[2] = wa_is_en[2] && ~issued[2];


	//exec
	assign board0 = board & wa_std_board[0] & mask;
	assign board1 = board & dd_board[0] & wa_std_board[1] & mask;
	assign board2 = board & dd_board[0] & dd_board[1] & wa_std_board[2] & mask; 
	assign alu_get =
			b_is_hazard ? 3'b000 :
 			board0 == 0 && (wa_mod[0] & mod_alu) != 0 && ~alu2_get[0] ? 3'b001 :
			board1 == 0 && (wa_mod[1] & mod_alu) != 0 && ~alu2_get[1] ? 3'b010 :
			board2 == 0 && (wa_mod[2] & mod_alu) != 0 && ~alu2_get[2] ? 3'b100 : 3'b000;
	assign alu2_get = 
			b_is_hazard ? 3'b000 :
			board0 == 0 && (wa_mod[0] & mod_alu2) != 0 ? 3'b001 :
			wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0 ? 3'b000 :
			board1 == 0 && (wa_mod[1] & mod_alu2) != 0 ? 3'b010 :
			wa_ope[1][1:0] == 2'b10 && wa_ope[0][5:3] != 0 ? 3'b000 :
			board2 == 0 && (wa_mod[2] & mod_alu2) != 0 ? 3'b100 : 3'b000;
	assign io_get = 
			b_is_hazard || io_busy ? 3'b000 :
			board0 == 0 && (wa_mod[0] == mod_io) ? 3'b001 :
			wa_mod[0] == mod_io || (wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			board1 == 0 && (wa_mod[1] == mod_io) ? 3'b010 :
			wa_mod[1] == mod_io || (wa_ope[1][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			board2 == 0 && (wa_mod[2] == mod_io) ? 3'b100 : 3'b000;
	assign mem_get = 
			b_is_hazard ? 3'b000 :
			board0 == 0 && (wa_mod[0] == mod_mem) ? 3'b001 :
			wa_mod[0] == mod_mem || (wa_ope[0][1:0] == 2'b10 && wa_ope[0][5:3] != 0) ? 3'b000 :
			board1 == 0 && (wa_mod[1] == mod_mem) ? 3'b010 :
			wa_mod[1] == mod_mem || (wa_ope[1][1:0] == 2'b10 && wa_ope[1][5:3] != 0) ?  3'b000 :
			board2 == 0 && (wa_mod[2] == mod_mem) ? 3'b100 : 3'b000;
	assign fpu_get = 0;///////
	assign fpu2_get = 0;///////
	
	assign issued = alu_get | alu2_get | io_get | mem_get | fpu_get | fpu2_get;
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

			io_ope <= 0;
			io_ds_val <= 0;
			io_dd <= 0;
			mem_ope <= 0;
			mem_ds_val <= 0;
			mem_dt_val <= 0;
			mem_dd <= 0;
			mem_imm <= 0;
			alu_ope <= 0;
			alu_pc <= 0;
			alu_ds_val <= 0;
			alu_dt_val <= 0;
			alu_dd <= 0;
			alu_imm <= 0;
			alu_opr <= 0;
			alu2_ope <= 0;
			alu2_ds_val <= 0;
			alu2_dt_val <= 0;
			alu2_dd <= 0;
			alu2_imm <= 0;
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
			de_tmp_is_en[0] <= b_is_hazard ? 0 :
												 wa_is_busy && ~wa_was_busy ? if_is_en[0] : de_tmp_is_en[0];
			de_tmp_is_en[1] <= b_is_hazard ? 0 :
												 wa_is_busy && ~wa_was_busy ? if_is_en[0] : de_tmp_is_en[1];
			de_tmp_used <= wa_is_busy;

			de_pc <= wa_is_busy ? de_pc :
							 de_tmp_used ? de_tmp_pc : if_pc;
			de_instr[0] <= wa_is_busy ? de_instr[0] :
										 de_tmp_used ? de_tmp_instr[0] : i_rdata[63:32];
			de_instr[1] <= wa_is_busy ? de_instr[1] :
										 de_tmp_used ? de_tmp_instr[1] : i_rdata[31:0];
			// enなのはifステージでenかつ制御ハザードが起きない
			de_is_en[0] <= b_is_hazard ? 0 :
										 wa_is_busy ? de_is_en[0] :
										 de_tmp_used ? de_tmp_is_en[0] : if_is_en[0];
			de_is_en[1] <= b_is_hazard ? 0 :
										 wa_is_busy ? de_is_en[1] :
										 de_tmp_used ? de_tmp_is_en[1] : if_is_en[1];
			//wait
			wa_was_busy <= wa_is_busy;
			wa_data[0] <= b_is_hazard ? 0 : 
										wa_exist[0] ? wa_data[0] :
										wa_exist[1] ? wa_data[1] :
										wa_exist[2] ? wa_data[2] :
										de_is_en[0] ? de_data[0] :
										de_is_en[1] ? de_data[1] : 0;
			wa_data[1] <= b_is_hazard ? 0 :
										wa_exist[0] && wa_exist[1] ? wa_data[1] :
										(wa_exist[0] ^ wa_exist[1]) &&	wa_exist[2] ? wa_data[2] :
										(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && de_is_en[0] ? de_data[0] :
										~wa_exist[0] && ~wa_exist[1] && wa_exist[2] && 	de_is_en[0] ? de_data[0] :
										(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && ~de_is_en[0] && de_is_en[1] ? de_data[1] :
										~wa_exist[0] && ~wa_exist[1] &&	(wa_exist[2] ^ de_is_en[0]) && de_is_en[1] ? de_data[1] : 0;
			wa_data[2] <= b_is_hazard ? 0 : 
										wa_exist[0] && wa_exist[1] && wa_exist[2] ? wa_data[2] :
										wa_exist[0] && wa_exist[1] &&	~wa_exist[2] && de_is_en[0] ? de_data[0] :
										(wa_exist[0] ^ wa_exist[1]) && wa_exist[2] && de_is_en[0] ? de_data[0] :
										wa_exist[0] && wa_exist[1] && ~wa_exist[2] && ~de_is_en[0] && de_is_en[1] ? de_data[1] :
										(wa_exist[0] ^ wa_exist[1]) && (wa_exist[2] ^ de_is_en[0]) && de_is_en[1] ? de_data[1] :
										~wa_exist[0] && ~wa_exist[1] &&	wa_exist[2] && de_is_en[0] && de_is_en[1] ? de_data[1] : 0;
			wa_is_en[0] <= b_is_hazard ? 0 :
										wa_exist[0] ? wa_is_en[0] :
										wa_exist[1] ? wa_is_en[1] :
										wa_exist[2] ? wa_is_en[2] :
										de_is_en[0] ? de_is_en[0] :
										de_is_en[1] ? de_is_en[1] : 0;
			wa_is_en[1] <= b_is_hazard ? 0 :
										wa_exist[0] && wa_exist[1] ? wa_is_en[1] :
										(wa_exist[0] ^ wa_exist[1]) &&	wa_exist[2] ? wa_is_en[2] :
										(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && de_is_en[0] ? de_is_en[0] :
										~wa_exist[0] && ~wa_exist[1] && wa_exist[2] && 	de_is_en[0] ? de_is_en[0] :
										(wa_exist[0] ^ wa_exist[1]) && ~wa_exist[2] && ~de_is_en[0] && de_is_en[1] ? de_is_en[1] :
										~wa_exist[0] && ~wa_exist[1] &&	(wa_exist[2] ^ de_is_en[0]) && de_is_en[1] ? de_is_en[1] : 0;
			wa_is_en[2] <= b_is_hazard ? 0 :
										wa_exist[0] && wa_exist[1] && wa_exist[2] ? wa_is_en[2] :
										wa_exist[0] && wa_exist[1] &&	~wa_exist[2] && de_is_en[0] ? de_is_en[0] :
										(wa_exist[0] ^ wa_exist[1]) && wa_exist[2] && de_is_en[0] ? de_is_en[0] :
										wa_exist[0] && wa_exist[1] && ~wa_exist[2] && ~de_is_en[0] && de_is_en[1] ? de_is_en[1] :
										(wa_exist[0] ^ wa_exist[1]) && (wa_exist[2] ^ de_is_en[0]) && de_is_en[1] ? de_is_en[1] :
										~wa_exist[0] && ~wa_exist[1] &&	wa_exist[2] && de_is_en[0] && de_is_en[1] ? de_is_en[1] : 0;


			board <= (board & ~(1 << alu_reg_addr) & ~(1 << alu2_reg_addr) & ~(1 << io_reg_addr) & 
									~(1 << mem_reg_addr) & ~(1 << fpu_reg_addr) & ~(1 << fpu2_reg_addr)) |
								(issued[0] ? dd_board[0] : 0) | (issued[1] ? dd_board[1] : 0) | 
								(issued[2] ? dd_board[2] : 0);

			//exec
			//alu
			if (alu_get == 3'b001) begin
				alu_ope <= wa_ope[0];
				alu_pc <= wa_pc[0];
				alu_ds_val <= wa_ds_val[0];
				alu_dt_val <= wa_dt_val[0];
				alu_dd <= wa_dd[0];
				alu_imm <= wa_imm[0];
				alu_opr <= wa_opr[0];
			end else if (alu_get == 3'b010 ) begin
				alu_ope <= wa_ope[1];
				alu_pc <= wa_pc[1];
				alu_ds_val <= wa_ds_val[1];
				alu_dt_val <= wa_dt_val[1];
				alu_dd <= wa_dd[1];
				alu_imm <= wa_imm[1];
				alu_opr <= wa_opr[1];
			end else if(alu_get == 3'b100) begin
				alu_ope <= wa_ope[2];
				alu_pc <= wa_pc[2];
				alu_ds_val <= wa_ds_val[2];
				alu_dt_val <= wa_dt_val[2];
				alu_dd <= wa_dd[2];
				alu_imm <= wa_imm[2];
				alu_opr <= wa_opr[2];
			end else begin
				alu_ope <= 0;
			end
			//alu2
			if (alu2_get == 3'b001) begin
				alu2_ope <= wa_ope[0];
				alu2_ds_val <= 	wa_ds_val[0];
				alu2_dt_val <= wa_dt_val[0];
				alu2_dd <= wa_dd[0];
				alu2_imm <= wa_imm[0];
			end else if (alu2_get == 3'b010) begin
				alu2_ope <= wa_ope[1];
				alu2_ds_val <= 	wa_ds_val[1];
				alu2_dt_val <= wa_dt_val[1];
				alu2_dd <= wa_dd[1];
				alu2_imm <= wa_imm[1];
			end else if (alu2_get == 3'b100) begin
				alu2_ope <= wa_ope[2];
				alu2_ds_val <= 	wa_ds_val[2];
				alu2_dt_val <= wa_dt_val[2];
				alu2_dd <= wa_dd[2];
				alu2_imm <= wa_imm[2];
			end else begin
				alu2_ope <= 0;
			end
			//io
			if (io_get == 3'b001) begin
				io_ope <= wa_ope[0];
				io_ds_val <= wa_ds_val[0];
				io_dd <= wa_dd[0];
			end else if (io_get == 3'b010) begin
				io_ope <= wa_ope[1];
				io_ds_val <= wa_ds_val[1];
				io_dd <= wa_dd[1];
			end else if (io_get == 3'b100) begin
				io_ope <= wa_ope[2];
				io_ds_val <= wa_ds_val[2];
				io_dd <= wa_dd[2];
			end else begin
				io_ope <= 0;
			end
			//mem
			if (mem_get == 3'b001) begin
				mem_ope <= wa_ope[0];
				mem_ds_val <= wa_ds_val[0];
				mem_dt_val <= wa_dt_val[0];
				mem_dd <= wa_dd[0];
				mem_imm <= wa_imm[0];
			end else if(mem_get == 3'b010) begin
				mem_ope <= wa_ope[1];
				mem_ds_val <= wa_ds_val[1];
				mem_dt_val <= wa_dt_val[1];
				mem_dd <= wa_dd[1];
				mem_imm <= wa_imm[1];
			end else if(mem_get == 3'b100) begin
				mem_ope <= wa_ope[2];
				mem_ds_val <= wa_ds_val[2];
				mem_dt_val <= wa_dt_val[2];
				mem_dd <= wa_dd[2];
				mem_imm <= wa_imm[2];
			end else begin
				mem_ope <= 0;
			end
			//fpu

			//fpu2


			//write back
			regfile[alu_reg_addr] <= alu_dd_val;
			regfile[alu2_reg_addr] <= alu2_dd_val;
			regfile[io_reg_addr] <= io_dd_val;
			regfile[mem_reg_addr] <= mem_dd_val;
			regfile[fpu_reg_addr] <= fpu_dd_val;
			regfile[fpu2_reg_addr] <= fpu2_dd_val;

		end
	end

endmodule

