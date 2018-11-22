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
	//exec
		// io
	reg [5:0] io_ope;
	reg [31:0] io_ds_val;
	reg [5:0] io_dd;
		//mem
	reg [5:0] mem_ope;
	reg [31:0] mem_ds_val;
	reg [31:0] mem_dt_val;
	reg [5:0] mem_dd;
	reg [15:0] mem_imm;
		//alu(+j/b)
	reg [5:0] alu_ope;
	reg [13:0] alu_pc;
	reg [31:0] alu_ds_val;
	reg [31:0] alu_dt_val;
	reg [5:0] alu_dd;
	reg [15:0] alu_imm;
	reg [4:0] alu_opr;
		//alu2
	reg [5:0] alu2_ope;
	reg [31:0] alu2_ds_val
	reg [31:0] alu2_dt_val;
	reg [5:0] alu2_dd;
	reg [15:0] alu2_imm;
		//fpu
	reg [5:0] fpu_ope;
	reg [31:0] fpu_ds_val;
	reg [31:0] fpu_dt_val;
	reg [5:0] fpu_dd;
	reg [15:0] fpu_imm;
	reg [3:0] fpu_ctrl;
		//fpu2
	reg [5:0] fpu2_ope;
	reg [31:0] fpu2_ds_val;
	reg [31:0] fpu2_dt_val;
	reg [5:0] fpu2_dd;
	reg [15:0] fpu2_imm;
	reg [3:0] fpu2_ctrl;

	//board {fpr,gpr}
	reg [63:0] board;

	//hazard
	wire b_is_hazard;

	//instr mem
	assign i_addr = {pc[13:1],3'b000};
	assign i_en = 1'b1;

	//if
	assign if_is_en[0] = if_pc[0] == 0 && ~b_is_hazard;
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
	assign wa_ds_val[0] = regfile[wa_ds];
	assign wa_dt_val[0] = regfile[wa_dt];
	//あとで複製な
	assign wa_std_board[0] <= (1 << wa_ds[0]) & (1 << wa_dt[0]) & (1 << wa_dd[0]) & mask;
	assign wa_std_board[1] <= (1 << wa_ds[1]) & (1 << wa_dt[1]) & (1 << wa_dd[1]) & mask;
	assign wa_std_board[2] <= (1 << wa_ds[2]) & (1 << wa_dt[2]) & (1 << wa_dd[2]) & mask;
	assign wa_is_busy = //////////////////

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
			for(i2=0;i2 < 4; i2=i2+1) begin
				wa_data[i2] <= 0;
			end
			wa_was_busy <= 0;
			board <= 0;
		end else if(state == st_begin) begin
			pc <= 1;
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
			de_is_en[1] <= b_is_hazard ? 
										 wa_is_busy ? de_is_en[1] :
										 de_tmp_used ? de_tmp_is_en[1] : if_is_en[1];
			//wait
			wa_was_busy <= wa_is_busy;
			board <= //////////
		end
	end

endmodule

