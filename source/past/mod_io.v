module io(
	input wire clk,
	input wire rstn,
	input wire [5:0] ope,
	input wire [31:0] ds_val,
	input wire [5:0] dd,
	output reg [5:0] reg_addr,
	output reg [31:0] reg_dd_val,
	output reg io_busy,

	input wire [7:0] io_in_data,
	output reg io_in_rdy,
	input wire io_in_vld,

	output reg [7:0] io_out_data,
	input wire io_out_rdy,
	output reg io_out_vld
	);
	
	reg state;
	reg is_in;
	reg [5:0] addr;

	always @(posedge clk) begin
		if(~rstn) begin
			reg_addr <= 0;
			reg_dd_val <= 0;
			io_busy <= 0;
			io_in_rdy <= 0;
			io_out_data <= 0;
			io_out_vld <= 0;
			state <= 0;
			is_in <= 0;
			addr <= 0;
		end else if (state == 0 && ope != 0) begin
			reg_addr <= 0;
			io_busy <= 1;
			is_in <= ope[3];
			addr <= dd;
			if(ope[3]) begin //IN
				io_in_rdy <= 1;
			end else begin  // OUT
				io_out_data <= ds_val[7:0];
				io_out_vld <= 1;
			end
			state <= 1;
		end else if (state == 1 && ((is_in && io_in_vld) || (~is_in && io_out_rdy))) begin
			if (is_in) begin
				io_in_rdy <= 0;
				reg_dd_val <= {24'b0,io_in_data};
				reg_addr <= addr;
			end else begin
				io_out_vld <= 0;
			end
			io_busy <= 0;
			state <= 0;
		end else begin
			reg_addr <= 0;
		end
	end

endmodule
