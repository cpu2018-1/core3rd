module unit3(
		input wire clk,
		input wire rstn,
		input wire [31:0] ds_val,
		input wire [31:0] dt_val,
		input wire [5:0] dd,
		input wire [15:0] imm,
		input wire [3:0] ctrl,
		output wire [6:0] is_busy,
		output wire [5:0] fpu_addr,
		output wire [31:0] fpu_dd_val
	);
	// FPU
	
	//ダミー
	reg [5:0] r_addr;
	reg [31:0] r_dd_val;
	
	assign is_busy = 0;
	assign fpu_addr = r_addr;
	assign fpu_dd_val = r_dd_val;

	always @(posedge clk) begin
		if (~rstn) begin
			r_addr <= 0;
			r_dd_val <= 0;
		end else begin
			r_addr <= 0;
			if(ctrl == 4'b0011) begin
				r_dd_val <= ds_val + dt_val;
			end else if(ctrl == 4'b0010) begin
				r_dd_val <= ds_val << dt_val[3:0];
			end else if(ctrl == 4'b1010) begin
				r_dd_val <= ds_val >> dt_val[4:0];
			end else if(ctrl == 4'b1100) begin
				r_dd_val <= ds_val >>> dt_val[4:0];
			end
		end
	end
endmodule
