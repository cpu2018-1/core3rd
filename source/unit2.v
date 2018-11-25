module unit2(
		input wire clk,
		input wire rstn,
		input wire [5:0] ope,
		input wire [31:0] ds_val,
		input wire [31:0] dt_val,
		input wire [5:0] dd,
		input wire [15:0] imm,
		output wire [6:0] is_busy,
		output reg [5:0] alu_addr,
		output reg [31:0] alu_dd_val,
		output reg [5:0] mem_addr,
		output reg [31:0] mem_dd_val,
		output reg [5:0] io_addr,
		output reg [31:0] io_dd_val,

		output wire [16:0] d_addr,
		output wire [31:0] d_wdata,
		input wire [31:0] d_rdata,
		output wire d_en,
		output wire d_we,

		input wire [7:0] io_in_data,
		output reg io_in_rdy,
		input wire io_in_vld,

		output reg [7:0] io_out_data,
		input wire io_out_rdy,
		output reg io_out_vld
	);
	// ALU or MEM or IO 

	wire [31:0] ex_imm;
	wire [31:0] alu_rs;
	wire [31:0] alu_rt_imm;
	wire [31:0] add;
	wire [31:0] sub;
	wire [31:0] sll;
	wire [31:0] srl;
	wire [31:0] sra;

	reg [16:0] m1_addr;
	reg [31:0] m1_wdata;
	reg [5:0] m1_dd;
	reg m1_is_write;
	reg [5:0] m2_dd;
	reg m2_is_write;
	reg [5:0] m3_dd;
	reg m3_is_write;
	reg [31:0] m3_rdata;

	reg io_state;
	reg io_is_in;
	reg [5:0] io_tmp_addr;

	assign ex_imm = {{16{imm[15]}},imm};
	assign alu_rs = ds_val;
	assign alu_rt_imm = ope[2] ? dt_val : ex_imm;
	assign add = $signed(alu_rs) + $signed(alu_rt_imm);
	assign sub = $signed(alu_rs) - $signed(alu_rt_imm);
	assign sll = alu_rs << alu_rt_imm[4:0];
	assign srl = alu_rs >> alu_rt_imm[4:0];
	assign sra = alu_rs >>> alu_rt_imm[4:0];

	assign is_busy = {6'b0,io_state == 1 || ope[2:0] == 3'b011};
	
	assign d_addr = m1_addr;
	assign d_wdata = m1_wdata;
	assign d_en = 1;
	assign d_we = m1_is_write;

	// alu
	always @(posedge clk) begin
		if (~rstn) begin
			alu_addr <= 0;
			alu_dd_val <= 0;
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
         default:
           begin
             alu_addr <= 0;
           end
       endcase
		end
	end

	//mem
	always @(posedge clk) begin
		if (~rstn) begin
			mem_addr <= 0;
			mem_dd_val <= 0;
			m1_addr <= 0;
			m1_wdata <= 0;
			m1_dd <= 0;
			m1_is_write <= 0;
			m2_dd <= 0;
			m2_is_write <= 0;
			m3_dd <= 0;
			m3_is_write <= 0;
		end else if(ope[2:0] == 4'b111) begin			
			m1_addr <= $signed(ds_val) + $signed(imm);
			m1_wdata <= dt_val;
			m1_dd <= dd;
			m1_is_write <= ~ope[3];

			m2_dd <= m1_dd;
			m2_is_write <= m1_is_write;

			m3_dd <= m2_dd;
			m3_is_write <= m2_is_write;
			m3_rdata <= d_rdata;

			mem_addr <= m3_is_write ? 0 : m3_dd;
			mem_dd_val <= m3_rdata;
		end	
	end

	//io
	always @(posedge clk) begin
		if (~rstn) begin
			io_addr <= 0;
			io_dd_val <= 0;
			io_in_rdy <= 0;
			io_out_data <= 0;
			io_out_vld <= 0;
			io_state <= 0;
			io_is_in <= 0;
			io_tmp_addr <= 0;
		end else if (io_state == 0 && ope[2:0] == 3'b011) begin
			io_addr <= 0;
			io_is_in <= ope[3];
			io_tmp_addr <= dd;
			if (ope[3]) begin // IN
				io_in_rdy <= 1;
			end else begin // OUT
				io_out_data <= ds_val[7:0];
				io_out_vld <= 1;
			end
			io_state <= 1;
		end else if (io_state == 1 && ((io_is_in && io_in_vld) || (~io_is_in && io_out_rdy))) begin
			if(io_is_in) begin
				io_in_rdy <= 0;
				io_addr <= io_tmp_addr;
				io_dd_val <= {24'b0,io_in_data};
			end else begin
				io_out_vld <= 0;
				io_addr <= 0;
			end
			io_state <= 0;
		end else begin
			io_addr <= 0;
		end
	end
endmodule
