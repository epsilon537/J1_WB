/* ROM */

`default_nettype none

module rom
  #(parameter size       = 'h2000, // maximum code space for J1
    parameter addr_width = $clog2(size),
    parameter data_width = 16,
    parameter INIT_FILE)
   (input  wire                    clock,
    input  wire [addr_width - 1:0] address,
    output reg  [data_width - 1:0] q,
    input  wire                    cen);

   reg [data_width - 1:0] mem[0:size - 1];

   initial begin
    $readmemh(INIT_FILE, mem);
   end

   always @(posedge clock)
     if (cen)
       q <= mem[address];
endmodule

`resetall
