module unit2(
		input wire clk,
		input wire rstn,
		input wire [5:0] ope,
		input wire [31:0] ds_val,
		input wire [31:0] dt_val,
		input wire [5:0] dd,
		input wire [15:0] imm,
		output wire [6:0] is_busy,
		output wire [5:0] mem_addr,
		output wire [31:0] mem_dd_val,
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
	//MEM or IO 

	reg [16:0] m1_addr;
	reg [31:0] m1_wdata;
	reg [5:0] m1_dd;
	reg m1_is_write;
	reg [5:0] m2_dd;
	reg m2_is_write;
	reg [31:0] m2_rdata;
//	reg [5:0] m3_dd;
//	reg m3_is_write;
//	reg [31:0] m3_rdata;

	reg [1:0] io_state;
	reg io_is_in;
	reg [5:0] io_tmp_addr;
	reg [7:0] io_tmp_data;
	wire io_busy_cond;

	assign io_busy_cond = io_state != 0 || ope[2:0] == 3'b011;
	assign is_busy = {6'b0,io_busy_cond};
	
	assign d_addr = $signed(ds_val[16:0]) + $signed(imm);
	assign d_wdata = dt_val;
	assign d_en = 1;
	assign d_we = ope[2:0] == 3'b111 ? ~ope[3] : 0;

	assign mem_addr = m2_is_write ? 0 : m2_dd;
	assign mem_dd_val = m2_rdata;
	//mem
	always @(posedge clk) begin
		if (~rstn) begin
//			mem_addr <= 0;
//			mem_dd_val <= 0;
//			m1_addr <= 0;
//			m1_wdata <= 0;
			m1_dd <= 0;
			m1_is_write <= 0;
			m2_dd <= 0;
			m2_is_write <= 0;
			m2_rdata <= 0;
//			m3_dd <= 0;
//			m3_is_write <= 0;
		end else begin			
			if(ope[2:0] == 3'b111) begin
//				m1_addr <= $signed(ds_val) + $signed(imm);
//				m1_wdata <= dt_val;
				m1_dd <= dd;
				m1_is_write <= ~ope[3];
			end else begin
				m1_dd <= 0;
				m1_is_write <= 0;
			end

			m2_dd <= m1_dd;
			m2_is_write <= m1_is_write;
			m2_rdata <= d_rdata;

//			m3_dd <= m2_dd;
//			m3_is_write <= m2_is_write;
//			m3_rdata <= d_rdata;

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
			io_tmp_data <= ds_val[7:0];
			io_state <= 1;
		end else if (io_state == 1) begin
			io_addr <= 0;
			if (io_is_in) begin // IN
				io_in_rdy <= 1;
			end else begin // OUT
				io_out_data <= io_tmp_data;
				io_out_vld <= 1;
			end
			io_state <= 2;
		end else if (io_state == 2 && ((io_is_in && io_in_vld) || (~io_is_in && io_out_rdy))) begin
			if(io_is_in) begin
				io_in_rdy <= 0;
				io_addr <= 0;
				io_tmp_data <= io_in_data;
				io_state <= 3;
			end else begin
				io_out_vld <= 0;
				io_addr <= 0;
				io_state <= 0;
			end
		end else if(io_state == 3) begin //IN only
			io_addr <= io_tmp_addr;
			io_dd_val <= {24'b0,io_tmp_data};
			io_state <= 0;
		end else begin
			io_addr <= 0;
			io_dd_val <= 0;
		end
	end
endmodule
