module mem(
	input wire clk,
	input wire rstn,
	input wire [5:0] ope,
	input wire [31:0] ds_val,
	input wire [31:0] dt_val,
	input wire [5:0] dd,
	input wire [15:0] imm,
	output reg [5:0] reg_addr,
	output reg [31:0] reg_dd_val,

	output wire [16:0] d_addr,
	output wire [31:0] d_wdata,
	input wire [31:0] d_rdata,
	output wire d_en,
	output wire d_we
	);
	
	reg [16:0] s1_addr;
	reg [31:0] s1_wdata;
	reg [5:0] s1_dd;
	reg s1_is_write;
	
	reg [5:0] s2_dd;
	reg s2_is_write;

	reg [5:0] s3_dd;
	reg s3_is_write;
	
	assign d_addr = s1_addr;
	assign d_wdata = s1_wdata;
	assign d_en = 1;
	assign d_we = s1_is_write;

	always @(posedge clk) begin
		if(~rstn) begin
			reg_addr <= 0;
			reg_dd_val <= 0;
			s1_addr <= 0;
			s1_wdata <= 0;
			s1_dd <= 0;
			s1_is_write <= 0;
			s2_dd <= 0;
			s2_is_write <= 0;
			s3_dd <= 0;
			s3_is_write <= 0;
		end else begin
			s1_addr <= ds_val + imm;
			s1_wdata <= dt_val;
			s1_dd <= dd;
			s1_is_write <= ope != 0 && ~ope[3];
			
			s2_dd <= s1_dd;
			s2_is_write <= s1_is_write;

			s3_dd <= s2_dd;
			s3_is_write <= s2_is_write;

			reg_addr <= s3_is_write ? 0 : s3_dd;
			reg_dd_val <= d_rdata;
		end
	end
endmodule
