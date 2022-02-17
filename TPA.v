module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output reg  cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	reg [15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];
reg [10:0] cfg_load,sda_load,cfg_cnt,sda_cnt,cfg_step,sda_step;
reg [15:0] st3_flag;
reg [7:0] addr_temp,cfg_ctrl,sda_ctrl;
reg enout,SDA_in,who_first;//0:cfg 1:sda
// ===== Coding your RTL below here ================================= 
assign SDA = enout?SDA_in:1'bz;
always @(posedge clk or negedge reset_n) begin
	if(!reset_n)begin
		cfg_rdy <= 0;
		cfg_cnt <= 0;
		sda_cnt <= 64;
		cfg_step = 1;
		sda_step <= 1;
		cfg_load <= 0;
		sda_load <= 0;
		st3_flag <= 0;
		who_first <= 0;
		enout <= 0;
	end
	else begin
		if(cfg_cmd == 1 && cfg_req == 1 && sda_load == 0 && SDA == 1&& st3_flag == 1)begin//same time
			who_first <= 1;
		end
		else if(cfg_cmd == 1 && cfg_req == 1)begin
			who_first <= 1;
		end
		else if(sda_load == 0 && SDA == 1&& st3_flag == 1)begin//write
			who_first <= 0;
		end

		if(cfg_cmd == 1 && cfg_req == 1)begin//write
			cfg_rdy <= 1;
			cfg_ctrl <= 0;
		end
		else if(cfg_cmd == 0 && cfg_req == 1 && cfg_rdy != 1)begin//read
			cfg_rdy <= 1;
			cfg_ctrl <= 1;
		end
		else if(cfg_ctrl == 0)begin
			if(cfg_rdy == 1)begin
				Register_Spaces[cfg_addr] <= cfg_wdata;
				cfg_rdy <= 0;
			end
		end
		else if(cfg_ctrl == 1)begin
			if(cfg_rdy == 1)begin
				cfg_load <= cfg_load + 1;
				cfg_rdata <= Register_Spaces[cfg_addr];
				if(cfg_load == 1)begin
					cfg_rdy <= 0;
					cfg_load <= 0;
				end
			end
		end

		if(SDA == 0 && st3_flag == 0)begin
			st3_flag <= 1;
		end
		else if(st3_flag == 1)begin
			if(sda_load == 0 && SDA == 1)begin//write
				sda_load <= sda_load + 1;
				sda_ctrl <= 1;
			end
			else if(sda_load == 0 && SDA == 0)begin//read
				sda_load <= sda_load + 1;
				sda_ctrl <= 0;
			end
			else begin
				case (sda_ctrl)
					0:begin
						if(sda_load >= 1 && sda_load <= 8)begin
							sda_load <= sda_load + 1;
							addr_temp[sda_load-1] <= SDA;
						end
						else if(sda_load == 9)begin
							sda_load <= sda_load + 1;
						end
						else if(sda_load == 10)begin
							enout <= 1;
							SDA_in <= 1;
							sda_load <= sda_load + 1;
						end
						else if(sda_load == 11)begin
							SDA_in <= 0;
							sda_load <= sda_load + 1;
						end
						else if(sda_load <= 27 && sda_load >= 12)begin
							sda_load <= sda_load + 1;
							enout <= 1;
							SDA_in <= Register_Spaces[addr_temp][sda_load-12];
						end
						else begin
							enout <= 0;
							sda_load <= 0;
							st3_flag <= 0;
							addr_temp <= 8'hxx;
						end
					end
					1:begin
						if(sda_load >= 1 && sda_load <= 8)begin
							sda_load <= sda_load + 1;
							addr_temp[sda_load-1] <= SDA;
						end
						else if(sda_load <= 24)begin
							if(addr_temp == cfg_addr && who_first == 1)begin//0:cfg 1:sda
								sda_load <= 0;
								st3_flag <= 0;
								addr_temp <= 8'hxx;
							end
							else begin
								sda_load <= sda_load + 1;
								Register_Spaces[addr_temp][sda_load-9] <= SDA;
							end
						end
						else begin
							sda_load <= 0;
							st3_flag <= 0;
							addr_temp <= 8'hxx;
						end
					end
				endcase
			end
		end
	end
end
endmodule
