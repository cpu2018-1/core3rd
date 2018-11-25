module bp(
	input wire clk,
	input wire [13:0] r_pc,
	output wire is_taken0,
	output wire is_taken1,
	
	input wire is_b_ope,
	input wire is_branch,
	input wire [13:0] w_pc
	);

	reg [1:0] mem [1023:0];

	wire [9:0] addr0;
	wire [9:0] addr1;

	assign addr0 = {r_pc[9:0],1'b0};
	assign addr1 = {r_pc[9:0],1'b1};
	assign is_taken0 = mem[addr0][1];
	assign is_taken1 = mem[addr1][1];

	always @(posedge clk) begin
		if(is_b_ope & is_branch) begin
			mem[w_pc] <= mem[w_pc] != 2'b11 ? mem[w_pc]+1'b1 : 2'b11;
		end else if(is_b_ope & ~is_branch) begin
			mem[w_pc] <= mem[w_pc] != 2'b00 ? mem[w_pc]-1'b1 : 2'b00;
		end
	end
	

	integer i;
	initial begin
		for(i=0;i<1024;i=i+1) begin
			mem[i] <= 2'b01;
		end
	end

endmodule
